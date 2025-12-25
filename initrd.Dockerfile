# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright © 2025 Sidharth Sankar

ARG distro="ubuntu"

FROM scratch AS scripts
COPY <<'EOF' older-repos.sh
gpg --keyserver keyserver.ubuntu.com --recv-keys 3B4FE6ACC0B21F32 && gpg --export 3B4FE6ACC0B21F32 > /usr/share/keyrings/older.gpg
MIRROR=$(cat /etc/apt/sources.list.d/ubuntu.sources | grep -m1 -oP '(?<=^URIs: ).*')
for RELEASE in bionic bionic-updates focal focal-updates; do
  echo "deb [ signed-by=/usr/share/keyrings/older.gpg ] $MIRROR $RELEASE main universe" >> /etc/apt/sources.list.d/older.list
done        # should let us install
apt update  # old(er) GCC versions
EOF

FROM ubuntu:devel AS targetarch
RUN apt update && apt install -y --no-install-recommends wget ca-certificates gnupg make pahole libelf1t64 libgcrypt-dev libdevmapper-dev libxml2-utils binutils
FROM targetarch AS base
COPY --from=scripts older-repos.sh .
RUN sh -e older-repos.sh
RUN apt install -y --no-install-recommends xz-utils zstd lvm2 plymouth-theme-spinner dracut-core
ARG distro kernel TARGETPLATFORM TARGETARCH TARGETVARIANT version='[0-9]+\.[0-9]+\.?[0-9]*'

FROM targetarch AS sflc
RUN apt install -y gcc
ARG sflc_url
ADD $sflc_url .
RUN tar -xf *.tar.gz && make -C shufflecake-c/shufflecake-userland

FROM --platform=amd64 ubuntu:devel AS amd64
RUN apt update && apt install -y --no-install-recommends wget ca-certificates gnupg make pahole libelf1t64 libgcrypt-dev libdevmapper-dev libxml2-utils binutils
FROM amd64 AS module_ubuntu
COPY --from=scripts older-repos.sh .
RUN sh -e older-repos.sh
ARG distro kernel TARGETPLATFORM TARGETARCH TARGETVARIANT version='[0-9]+\.[0-9]+\.?[0-9]*'
RUN set -e; get() { wget -qO- "$url" | xmllint --recover --html --xpath '//a/text()' - | grep -oP "$format" | sort -V | tail -1; }; \
    case "${TARGET:=$TARGETARCH}" in 386) TARGET="i386" ;; ppc64le) TARGET="ppc64el" ;; arm) case "$TARGETVARIANT" in v6) TARGET="armel" ;; v7) TARGET="armhf" ;; esac ;; esac; \
    url="https://kernel.ubuntu.com/mainline"; \
    format="(?<=^v)$version(?=/$)"; \
    [ "$kernel" ] && kern="$kernel" || kern=$(get); \
    url="$url/v$kern/amd64"; format="^linux-headers-.*_all.deb$"               ; wget -qO- $url/$(get) | dpkg-deb -x - /; \
    url="${url%/*}/$TARGET"; format="^linux-headers-.*-generic_.*_$TARGET.deb$"; wget -qO- $url/$(get) | dpkg-deb -x - /;

FROM base AS module_gentoo
RUN set -e; get() { wget -qO- "$url" | xmllint --recover --html --xpath '//a/text()' - | grep -oP "$format" | sort -V | tail -1; }; \
    [ "$TARGETARCH" = 386 ] && TARGET="x86" || TARGET="$TARGETARCH"; \
    url="https://dev.gentoo.org/~mgorny/binpkg/$TARGET/kernel/sys-kernel/gentoo-kernel"; \
    format="(?<=^gentoo-kernel-)$version.*(?=\\.gpkg\\.tar$)"; \
    [ "$kernel" ] && kern="$kernel" || kern=$(get); \
    format="^gentoo-kernel-$kern.*\\.gpkg\\.tar$"; \
    wget -qO- $url/$(get) | tar -x; \
    tar --strip-components=1 -xf gentoo-kernel-*/image.tar.xz; \
    objcopy -O binary -j .linux /usr/src/*/arch/*/boot/uki.efi kernel.img

FROM base AS module_archlinux
RUN set -e; get() { wget -qO- "$url" | xmllint --recover --html --xpath '//a/text()' - | grep -oP "$format" | sort -V | tail -1; }; \
    url="https://archive.archlinux.org/packages/l/linux"; \
    format="(?<=^linux-)$version(?=\\.arch.-.-x86_64\\.pkg\\.tar\\.zst$)"; \
    [ "$kernel" ] && kern="$kernel" || kern=$(get); \
    format="^linux-$kern.*-x86_64\\.pkg\\.tar\\.zst$"; \
    wget -qO- $url/$(get) | tar --zstd -x; \
    url="https://archive.archlinux.org/packages/l/linux-headers"; \
    format="^linux-headers-$kern.*-x86_64\\.pkg\\.tar\\.zst$"; \
    wget -qO- $url/$(get) | tar --zstd -x; \
    cp /usr/lib/modules/*/vmlinuz kernel.img

FROM module_$distro AS module
RUN case "$TARGETARCH" in s390x) PRE="390x" ;; 386) PRE="i686" ;; amd64) PRE="x86-64" ;; ppc64le) PRE="powerpc64le" ;; arm64) PRE="aarch64" ;; arm) PRE="arm" ;; *) exit 1 ;; esac; \
    case "$TARGETVARIANT" in v6) SUF="eabi" ;; v7) SUF="eabihf" ;; esac; \
    apt install -y --no-install-recommends gcc-$(. /lib/modules/*/build/.config && echo "${CONFIG_GCC_VERSION%????}")-$PRE-linux-gnu$SUF
COPY --from=sflc shufflecake-c/dm-sflc/ dm-sflc/
RUN case "$TARGETARCH" in s390x) ARCH="s390" ;; 386) ARCH="x86" ;; amd64) ARCH="x86" ;; ppc64le) ARCH="powerpc" ;; arm64) ARCH="arm64" ;; arm) ARCH="arm" ;; esac; \
    GCC=$(basename /usr/bin/*-linux-gnu-gcc-[0-9]*); CC="${GCC%-*}"; for link in gcc gcc-${GCC##*-} $CC; do ln -s /usr/bin/$GCC /usr/bin/$link; done; \
    make -C dm-sflc KERNEL_DIR=$(realpath /lib/modules/*/build) ARCH="$ARCH" CROSS_COMPILE="${CC%-*}-"

FROM module AS gentoo
FROM module AS archlinux
FROM base AS ubuntu
RUN set -e; get() { wget -qO- "$url" | xmllint --recover --html --xpath '//a/text()' - | grep -oP "$format" | sort -V | tail -1; }; \
    case "${TARGET:=$TARGETARCH}" in 386) TARGET="i386" ;; ppc64le) TARGET="ppc64el" ;; arm) case "$TARGETVARIANT" in v6) TARGET="armel" ;; v7) TARGET="armhf" ;; esac ;; esac; \
    url="https://kernel.ubuntu.com/mainline"; \
    format="(?<=^v)$version(?=/$)"; \
    [ "$kernel" ] && kern="$kernel" || kern=$(get); \
    url="$url/v$kern/$TARGET"; \
    format="^linux-image-.*-generic_.*_$TARGET.deb$"  ; wget -qO- $url/$(get) | dpkg-deb -x - /; \
    format="^linux-modules-.*-generic_.*_$TARGET.deb$"; wget -qO- $url/$(get) | dpkg-deb -x - /; \
    cp /boot/vm* kernel.img

FROM $distro AS initrd
COPY --from=module dm-sflc/bin/dm-sflc.ko .
COPY --from=sflc shufflecake-c/shufflecake-userland/bin/proj_build/shufflecake /bin
COPY 70sflc/ /usr/lib/dracut/modules.d/70sflc/
COPY assets/bgrt-fallback.png assets/watermark.png /usr/share/plymouth/themes/spinner/
RUN kver=$(ls /lib/modules); prefix="$(echo "${TARGETPLATFORM#*\/}" | tr '/' '-')-$distro-$kver"; \
    mkdir /lib/modules/$kver/updates; mv dm-sflc.ko /lib/modules/$kver/updates; mv kernel.img $prefix-kernel.img; \
    depmod $kver && dracut --no-hostonly -a "plymouth sflc" -o "crypt" $prefix-initrd.img $kver

FROM scratch
COPY --from=initrd *-kernel.img *-initrd.img .
