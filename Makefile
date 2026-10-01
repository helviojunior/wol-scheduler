# Version comes from GitHub Releases (see scripts/version.sh):
#
#   channel   number from                  shown (wolscheduler -V)   package
#   release   the release tag (CI)         1.2.3                     pfSense-pkg-wolscheduler-1.2.3-<arch>
#   dev       latest release (local)       1.2.3-dev+<commit>        pfSense-pkg-wolscheduler-dev-v1.2.3-<arch>
#
# WOL_VERSION=X.Y.Z forces the number; CHANNEL=release|dev picks the channel.

ARCH    ?= amd64
DIST    ?= dist
CHANNEL ?= dev

# WOL_VERSION is passed explicitly: command-line make variables do not reach $(shell).
BASE_VERSION := $(shell WOL_VERSION='$(WOL_VERSION)' sh scripts/version.sh)
GIT_HASH     := $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)

ifeq ($(BASE_VERSION),)
$(error could not determine the version, see scripts/version.sh)
endif

ifeq ($(CHANNEL),release)
VERSION     := $(BASE_VERSION)
PKG_VERSION := $(BASE_VERSION)
else ifeq ($(CHANNEL),dev)
VERSION     := $(BASE_VERSION)-dev+$(GIT_HASH)
PKG_VERSION := dev-v$(BASE_VERSION)
else
$(error CHANNEL=$(CHANNEL): choose release or dev)
endif

# Cross-compile for pfSense via Docker; artifacts land in ./dist
all: package

package:
	docker build \
		--build-arg ARCH=$(ARCH) \
		--build-arg VERSION=$(VERSION) \
		--build-arg PKG_VERSION=$(PKG_VERSION) \
		-f docker/Dockerfile -o $(DIST) .

# Both architectures (amd64 = x86 boxes, arm64 = Netgate 1100/2100)
package-all:
	$(MAKE) package ARCH=amd64 WOL_VERSION=$(BASE_VERSION)
	$(MAKE) package ARCH=arm64 WOL_VERSION=$(BASE_VERSION)

# SHA-256 checksum next to each artifact in dist/
checksums:
	cd $(DIST) && for f in pfSense-pkg-wolscheduler-*.tar.gz; do \
		sha256sum "$$f" > "$$f.sha256" 2>/dev/null || shasum -a 256 "$$f" > "$$f.sha256"; \
	done

# Native build of the daemon, useful for local testing
native:
	$(MAKE) -C daemon VERSION=$(VERSION)

version:
	@echo $(VERSION)

clean:
	rm -rf $(DIST)
	$(MAKE) -C daemon clean

.PHONY: all package package-all checksums native version clean
