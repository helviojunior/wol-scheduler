# Cross-compiles wolscheduler for FreeBSD (pfSense) using clang + a FreeBSD
# sysroot extracted from the official base.txz, and assembles the package
# tarball. pfSense 2.7.0 is based on FreeBSD 14.0.
#
#   docker build --build-arg ARCH=amd64 -o dist -f docker/Dockerfile .
#
# ARCH: amd64 (most pfSense boxes) or arm64 (Netgate 1100/2100).

FROM debian:bookworm-slim AS sysroot

ARG FREEBSD_VERSION=14.0-RELEASE
ARG ARCH=amd64
ARG FREEBSD_MIRROR=http://ftp-archive.freebsd.org/pub/FreeBSD-Archive/old-releases

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl xz-utils libarchive-tools \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    case "$ARCH" in \
      amd64) path="amd64" ;; \
      arm64) path="arm64/aarch64" ;; \
      *) echo "unsupported ARCH=$ARCH" >&2; exit 1 ;; \
    esac; \
    mkdir -p /sysroot; \
    for url in "$FREEBSD_MIRROR/$path/$FREEBSD_VERSION/base.txz" \
               "https://download.freebsd.org/releases/$path/$FREEBSD_VERSION/base.txz"; do \
      if curl -fsSL -o /tmp/base.txz "$url"; then break; fi; \
    done; \
    test -s /tmp/base.txz; \
    bsdtar -xf /tmp/base.txz -C /sysroot ./lib ./usr/lib ./usr/include; \
    rm /tmp/base.txz

FROM debian:bookworm-slim AS build

ARG ARCH=amd64
# VERSION: shown by `wolscheduler -V` and in info.xml (e.g. 1.2.3 or 1.2.3-dev+abc123)
# PKG_VERSION: used in the package file name (e.g. 1.2.3 or dev-v1.2.3)
ARG VERSION=0.0.0-dev
ARG PKG_VERSION=dev-v0.0.0

RUN apt-get update \
 && apt-get install -y --no-install-recommends clang lld make file \
 && rm -rf /var/lib/apt/lists/*

COPY --from=sysroot /sysroot /sysroot
COPY daemon /src/daemon
COPY pkg /src/pkg
COPY scripts /src/scripts

WORKDIR /src/daemon
RUN set -eux; \
    case "$ARCH" in \
      amd64) triple="x86_64-unknown-freebsd14.0" ;; \
      arm64) triple="aarch64-unknown-freebsd14.0" ;; \
    esac; \
    make clean; \
    make CC=clang VERSION="$VERSION" \
         CFLAGS="--target=$triple --sysroot=/sysroot -O2" \
         LDFLAGS="--target=$triple --sysroot=/sysroot -fuse-ld=lld -static -s"; \
    file wolscheduler; \
    file wolscheduler | grep -q "ELF.*FreeBSD"

# Assemble the package tree: files/ mirrors the pfSense filesystem.
RUN set -eux; \
    name="pfSense-pkg-wolscheduler-$PKG_VERSION-$ARCH"; \
    out="/out/$name"; \
    mkdir -p "$out/files/usr/local/bin"; \
    cp -R /src/pkg/files/. "$out/files/"; \
    install -m 0755 /src/daemon/wolscheduler "$out/files/usr/local/bin/wolscheduler"; \
    sed -i "s|%%VERSION%%|$VERSION|g" "$out/files/usr/local/share/pfSense-pkg-wolscheduler/info.xml"; \
    install -m 0755 /src/scripts/install.sh /src/scripts/uninstall.sh "$out/"; \
    cd /out && tar -czf "$name.tar.gz" "$name"; \
    cp /src/daemon/wolscheduler "/out/wolscheduler-$ARCH"

FROM scratch
COPY --from=build /out/*.tar.gz /out/wolscheduler-* /
