VERSION ?= 1.0.0
ARCH    ?= amd64
DIST    ?= dist

# Cross-compile for pfSense via Docker; artifacts land in ./dist
all: package

package:
	docker build \
		--build-arg ARCH=$(ARCH) \
		--build-arg VERSION=$(VERSION) \
		-f docker/Dockerfile -o $(DIST) .

# Both architectures (amd64 = x86 boxes, arm64 = Netgate 1100/2100)
package-all:
	$(MAKE) package ARCH=amd64
	$(MAKE) package ARCH=arm64

# Native build of the daemon, useful for local testing
native:
	$(MAKE) -C daemon

clean:
	rm -rf $(DIST)
	$(MAKE) -C daemon clean

.PHONY: all package package-all native clean
