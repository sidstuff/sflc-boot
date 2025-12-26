ARG distro="ubuntu" version='[0-9]+\.[0-9]+\.?[0-9]*' sflc_path="shufflecake-c/shufflecake-userland/bin/proj_build/shufflecake"
ARG mod_path="shufflecake-c/dm-sflc/bin/dm-sflc.ko" mod_dir="lib/modules/*/kernel/drivers"

FROM ubuntu:questing AS target
RUN apt update && apt install -y --no-install-recommends wget ca-certificates gnupg make pahole \
                      libelf1t64 libxml2-utils libgcrypt-dev libdevmapper-dev busybox-static
COPY toolchain.list /etc/apt/sources.list.d/
ARG sflc_url sflc_path mod_path mod_dir version
ADD $sflc_url common.sh https://raw.githubusercontent.com/torvalds/linux/master/usr/gen_init_cpio.c .
RUN sh common.sh

FROM --platform=amd64 ubuntu:questing AS amd64
RUN apt update && apt install -y --no-install-recommends wget ca-certificates gnupg make pahole \
                      libelf1t64 libxml2-utils libgcrypt-dev libdevmapper-dev busybox-static
COPY toolchain.list /etc/apt/sources.list.d/
ARG sflc_url sflc_path mod_path mod_dir version
ADD $sflc_url common.sh https://raw.githubusercontent.com/torvalds/linux/master/usr/gen_init_cpio.c .
RUN sh common.sh

ARG TARGETARCH TARGETVARIANT kernel
RUN set -e; get() { wget -qO- "$url" | xmllint --recover --html --xpath '//a/text()' - | grep -oP "$format" | sort -V | tail -1; }; \
    case "$TARGETARCH" in \
      s390x)   ARCH="s390"   ; CC="390x-linux-gnu"       ; TARGET="s390x"    ;; \
      386)     ARCH="x86"    ; CC="i686-linux-gnu"       ; TARGET="i386"     ;; \
      amd64)   ARCH="x86"    ; CC="x86_64-linux-gnu"     ; TARGET="amd64"    ;; \
      ppc64le) ARCH="powerpc"; CC="powerpc64le-linux-gnu"; TARGET="ppc64el"  ;; \
      arm64)   ARCH="arm64"  ; CC="aarch64-linux-gnu"    ; TARGET="arm64"    ;; \
      arm)     ARCH="arm"    ; { [ "$TARGETVARIANT" = v6 ] && TARGET="armel" && CC="arm-linux-gnueabi"  ; } || \
                               { [ "$TARGETVARIANT" = v7 ] && TARGET="armhf" && CC="arm-linux-gnueabihf"; } ;; \
    esac; \
    url="https://kernel.ubuntu.com/mainline"; \
    format="(?<=^v)$version(?=/$)"; \
    [ "$kernel" ] && kern="$kernel" || kern=$(get); \
    url="$url/v$kern/amd64"; \
    format="^linux-headers-.*_all.deb$"; wget -qO- $url/$(get) | dpkg-deb -x - image; \
    url="${url%/*}/$TARGET"; \
    format="^linux-headers-.*-generic_.*_$TARGET.deb$"; wget -qO- $url/$(get) | dpkg-deb -x - image; \
    format="^linux-image-.*-generic_.*_$TARGET.deb$"  ; wget -qO- $url/$(get) | dpkg-deb -x - image; \
    format="^linux-modules-.*-generic_.*_$TARGET.deb$"; wget -qO- $url/$(get) | dpkg-deb -x - image; \
    GCC="gcc-$(. image/usr/src/*-generic/.config && printf "%.2s" "$CONFIG_GCC_VERSION")"; \
    apt install -y --no-install-recommends $GCC$([ "$TARGET" = amd64 ] || echo "-$CC"); \
    make -C shufflecake-c/dm-sflc KERNEL_DIR=$(realpath image/usr/src/*-generic) ARCH=$ARCH CROSS_COMPILE=$CC-; \ 
    if [ "$TARGET" = amd64 ]; then \
      ln -s /usr/bin/$GCC /usr/bin/gcc; \
      make -C shufflecake-c/shufflecake-userland; \
      gcc gen_init_cpio.c -o gen_init_cpio; \
    fi; \
    mv image/boot/vm* $kern-ubuntu; \
    mv $mod_path $(ls image/$mod_dir/md/dm-mod.ko image/$mod_dir/usb/storage/usb-storage.ko) .

FROM target AS ubuntu
ARG TARGETARCH kernel
COPY --from=amd64 *$sflc_path *gen_init_cpio *.ko *-ubuntu .
RUN [ "$TARGETARCH" = amd64 ] || { set -e; \
      apt install -y --no-install-recommends gcc; \
      make -C shufflecake-c/shufflecake-userland && mv $sflc_path .; \
      gcc gen_init_cpio.c -o gen_init_cpio; \
      mv *-ubuntu $(./shufflecake -V)-shufflecake-$(ls *-ubuntu); \
    }

FROM target AS gentoo
RUN apt install -y xz-utils
ARG TARGETARCH kernel
RUN set -e; get() { wget -qO- "$url" | xmllint --recover --html --xpath '//a/text()' - | grep -oP "$format" | sort -V | tail -1; }; \
    [ "$TARGETARCH" = 386 ] && TARGET="x86" || TARGET="$TARGETARCH"; \
    url="https://dev.gentoo.org/~mgorny/binpkg/$TARGET/kernel/sys-kernel/gentoo-kernel"; \
    format="(?<=^gentoo-kernel-)$version.*(?=\\.gpkg\\.tar$)"; \
    [ "$kernel" ] && kern="$kernel" || kern=$(get); \
    format="^gentoo-kernel-$kern.*\\.gpkg\\.tar$"; \
    wget -qO- $url/$(get) | tar -x; \
    tar -xf gentoo-kernel-*/image.tar.xz; \
    GCC="gcc-$(. image/usr/src/*/.config && printf "%.2s" "$CONFIG_GCC_VERSION")"; \
    apt install -y --no-install-recommends $GCC; ln -s /usr/bin/$GCC /usr/bin/gcc; \
    make -C shufflecake-c/dm-sflc KERNEL_DIR=$(realpath image/usr/src/*/); \
    make -C shufflecake-c/shufflecake-userland; \
    gcc gen_init_cpio.c -o gen_init_cpio; \
    mv $sflc_path $mod_path $(ls image/$mod_dir/md/dm-mod.ko image/$mod_dir/usb/storage/usb-storage.ko) .; \
    objcopy -O binary -j .linux image/usr/src/*/arch/*/boot/uki.efi $(./shufflecake -V)-shufflecake-$kern-gentoo; \

FROM target AS archlinux
RUN apt install -y zstd
ARG kernel
RUN set -e; get() { wget -qO- "$url" | xmllint --recover --html --xpath '//a/text()' - | grep -oP "$format" | sort -V | tail -1; }; \
    mkdir image; \
    url="https://archive.archlinux.org/packages/l/linux"; \
    format="(?<=^linux-)$version(?=\\.arch.-.-x86_64\\.pkg\\.tar\\.zst$)"; \
    [ "$kernel" ] && kern="$kernel" || kern=$(get); \
    format="^linux-$kern.*-x86_64\\.pkg\\.tar\\.zst$"; \
    wget -qO- $url/$(get) | tar --zstd -xC image; \
    url="https://archive.archlinux.org/packages/l/linux-headers"; \
    format="^linux-headers-$kern.*-x86_64\\.pkg\\.tar\\.zst$"; \
    wget -qO- $url/$(get) | tar --zstd -xC image; \
    GCC="gcc-$(. image/usr/src/*/.config && printf "%.2s" "$CONFIG_GCC_VERSION")"; \
    apt install -y --no-install-recommends $GCC; ln -s /usr/bin/$GCC /usr/bin/gcc; \
    make -C shufflecake-c/dm-sflc KERNEL_DIR=$(realpath image/usr/src/*/); \
    make -C shufflecake-c/shufflecake-userland; \
    gcc gen_init_cpio.c -o gen_init_cpio; \
    mv $sflc_path $mod_path $(ls image/usr/$mod_dir/md/dm-mod.ko.zst image/usr/$mod_dir/usb/storage/usb-storage.ko.zst) .; \
    mv image/usr/lib/modules/*/vmlinuz $(./shufflecake -V)-shufflecake-$kern-arch; \
    if ls *.ko.zst; then unzstd *.ko.zst; fi

FROM $distro AS build
COPY initramfs.list .
RUN for module in *.ko; do echo "file $module $module 644 0 0" >> initramfs.list; done; \
    ldd shufflecake | sed -nE 's/^\s*(\/lib64\/\S*).*/file \1 \1 755 0 0/p' >> initramfs.list; \
    for lib in $(ldd shufflecake | sed -nE 's/^\s*lib.* => (\S*).*/\1/p'); \
    do echo "file /lib/${lib##*/} $lib 755 0 0" >> initramfs.list; done
COPY init sflc-boot.sh .
RUN ./gen_init_cpio initramfs.list | gzip --best > initramfs.cpio.gz

FROM alpine:latest AS ukify
RUN apk add --no-cache ukify systemd-efistub
COPY --from=build *-shufflecake-* initramfs.cpio.gz .
ARG TARGETPLATFORM cmdline
RUN name=$(ls *-shufflecake-*); \
    ukify build --linux=$name \
                --initrd=initramfs.cpio.gz \
                --cmdline="$cmdline" \
                --output=$name-$(echo "$TARGETPLATFORM" | tr '/' '-').efi
FROM scratch
COPY --from=ukify *.efi .
