# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright © 2025 Sidharth Sankar

ARG distro="ubuntu"

FROM ubuntu:devel AS base
RUN apt update && apt install -y --no-install-recommends git wget ca-certificates arch-install-scripts libxml2-utils xz-utils zstd systemd genisoimage dosfstools
RUN mkdir -p /output/boot
ARG distro release TARGETPLATFORM TARGETARCH TARGETVARIANT

FROM base AS setup_ubuntu
RUN set -e; get() { wget -qO- "$1" | xmllint --recover --html --xpath '//a/text()' - | grep -oP "$2" | sort | tail -1; }; \
    case "${TARGET:=$TARGETARCH}" in ppc64le) TARGET="ppc64el" ;; 386) TARGET="i386" ;; arm) case "$TARGETVARIANT" in v6) TARGET="armel" ;; v7) TARGET="armhf" ;; esac ;; esac; \
    url="https://cdimage.ubuntu.com/ubuntu-base"; \
    if [ "$release" ]; then \
      url="$url/releases/$release/release"; \
      file=$(get "$url" "^ubuntu-base-$release-base-$TARGET.tar.gz$"); \
      file="${file:-$(get "$url" "^ubuntu-base-.*-base-$TARGET.tar.gz$")}"; \
    else \
      url="$url/daily/current"; \
      file=$(get "$url" "^.*-base-$TARGET.tar.gz$"); \
    fi; \
    wget -qO- "$url/$file" | tar --xattrs-include='*.*' --numeric-owner -xzp -C /output      # i386 dropped in 2012 by the Linux kernel 3.8
                                                                                             # i486 or i586 in [CURRENT YEAR]? probably not
FROM base AS setup_gentoo
RUN case "$TARGETARCH" in   386) MFLAGS="-march=i686 -mtune=generic"   ; ARCH1="x86"  ; ARCH2="i686"    ;; \
                          amd64) MFLAGS="-march=x86-64 -mtune=generic" ; ARCH1="amd64"; ARCH2="amd64"   ;; \
                          arm64) MFLAGS="-march=armv8-a -mtune=generic"; ARCH1="arm64"; ARCH2="arm64"   ;; \
                        ppc64le) MFLAGS="-mcpu=powerpc64le"            ; ARCH1="ppc"  ; ARCH2="ppc64le" ;; \
                              *) exit 1 ;; \
    esac && \
    wget -r -l1 -np -nd "https://distfiles.gentoo.org/releases/$ARCH1/autobuilds/current-stage3-$ARCH2-systemd/" -A "*.tar.xz" && \
    tar --xattrs-include='*.*' --numeric-owner -xpf stage3-*.tar.xz -C /output && \
    echo "sys-kernel/dracut ~amd64" > /output/etc/portage/package.accept_keywords/dracut && \
    cat > /output/etc/portage/make.conf << EOF
USE="dist-kernel systemd dbus"
COMMON_FLAGS="$MFLAGS -O2 -pipe -fvect-cost-model=dynamic -fno-semantic-interposition"
CFLAGS="\${COMMON_FLAGS}"
CXXFLAGS="\${COMMON_FLAGS}"
FFLAGS="\${COMMON_FLAGS}"
FCFLAGS="\${COMMON_FLAGS}"
LDFLAGS="\${COMMON_FLAGS} -Wl,-O1 -Wl,--as-needed -Wl,--sort-common"
GOOS="linux"
GOARCH="$TARGETARCH"
CGO_CFLAGS="\${COMMON_FLAGS}"
CGO_CXXFLAGS="\${COMMON_FLAGS}"
CGO_FFLAGS="\${COMMON_FLAGS}"
GCO_FCFLAGS="\${COMMON_FLAGS}"
CGO_LDFLAGS="\${LDFLAGS}"
RUSTFLAGS="-C strip=symbols"
EMERGE_DEFAULT_OPTS="--getbinpkg"
ACCEPT_LICENSE="-* @BINARY-REDISTRIBUTABLE"
EOF
COPY <<'EOF' /output/etc/portage/package.use/boot
sys-apps/systemd boot
sys-apps/systemd-utils boot kernel-install
sys-kernel/installkernel systemd-boot dracut uki
EOF

FROM base AS setup_archlinux
RUN set -e; get() { wget -qO- "$1" | xmllint --recover --html --xpath '//a/text()' - | grep -oP "$2" | sort | tail -1; }; \
    url="https://archive.archlinux.org/iso"; \
    date=$(get "$url" '^[0-9]{4}\.[0-9]{2}\.[0-9]{2}(?=/$)'); \
    wget -qO- "$url/$date/archlinux-bootstrap-x86_64.tar.zst" | \
    tar --xattrs-include='*.*' --numeric-owner --strip-components=1 --zstd -xp -C /output; \
    sed -i '/^CheckSpace/s/^/#/' /output/etc/pacman.conf
ADD https://github.com/archlinux/archlinux-docker/raw/master/rootfs/etc/pacman.d/mirrorlist /output/etc/pacman.d/mirrorlist

FROM setup_$distro AS pre_chroot 
RUN git clone https://codeberg.org/shufflecake/shufflecake-c /output/usr/src/shufflecake
RUN systemd-firstboot \
      --force \
      --root="/output" \
      --delete-root-password \
      --setup-machine-id \
      --hostname="$distro" \
      --locale="en_US.UTF-8" \
      --locale-messages="C.UTF-8"
RUN cp -L /etc/resolv.conf /output/etc/
RUN fallocate -l 512M /output/esp.img && mkfs.vfat /output/esp.img
COPY <<'EOF' /output/etc/dracut.conf.d/sflc.conf
uefi="yes"
hostonly="no"
add_dracutmodules+=" plymouth sflc "
omit_dracutmodules+=" crypt "
kernel_cmdline="quiet splash"
EOF
COPY <<'EOF' /output/etc/kernel/install.conf
layout=uki
initrd_generator=dracut
uki_generator=dracut
EOF
COPY 70sflc/ output/usr/lib/dracut/modules.d/70sflc/

FROM pre_chroot AS gentoo
RUN --security=insecure arch-chroot /output << 'EOF'
    mount esp.img /boot
    getuto
    emerge-webrsync
    emerge -1 mirrorselect && mirrorselect -i -o >> /etc/portage/make.conf
    emerge -quDN --keep-going @world
    emerge -qf gentoo-kernel-bin
    emerge -q dev-vcs/git wpa_supplicant libgcrypt plymouth dracut lvm2 pahole \
              gcc:$(eval "$(tar -xf /var/cache/distfiles/gentoo-kernel-*.gpkg.tar --wildcards -O */image.tar.xz | tar --wildcards -xJO image/usr/src/*/.config)" && echo "${CONFIG_GCC_VERSION%????}")
    emerge -q $([ "$TARGETARCH" = amd64 ] && echo intel-microcode) linux-firmware gentoo-kernel-bin
    emerge -c
    umount /boot
EOF

FROM pre_chroot AS ubuntu
RUN --security=insecure arch-chroot /output << 'EOF'
    mount esp.img /boot
    export DEBIAN_FRONTEND=noninteractive
    apt update
    apt full-upgrade -y
    apt install -y --no-install-recommends locales ubuntu-server-minimal wpasupplicant git make linux-headers-generic libgcrypt-dev libdevmapper-dev plymouth-theme-spinner dracut systemd-boot
    apt install -y gcc gcc-$(. /lib/modules/*/build/.config && echo "${CONFIG_GCC_VERSION%????}")
    apt install -y --no-install-recommends linux-image-generic
    apt autopurge
    umount /boot
EOF

FROM pre_chroot AS archlinux
RUN --security=insecure arch-chroot /output << 'EOF'
    mount esp.img /boot
    pacman-key  --init
    pacman-key  --populate
    pacman -Syu --noconfirm --needed amd-ucode intel-ucode linux-firmware linux-headers wpa_supplicant git make gcc libgcrypt lvm2 plymouth dracut
    pacman -S   --noconfirm linux
    pacman -Sc  --noconfirm
    umount /boot
EOF

FROM $distro AS final
RUN --security=insecure arch-chroot /output << 'EOF'
    mount esp.img /boot
    dracut -f --regenerate-all
    bootctl install --esp-path=/boot
    sed -i '/en_US\\.UTF-8/s/^# *//' /etc/locale.gen && locale-gen
    systemctl preset-all && systemctl disable systemd-networkd-wait-online.service
    umount /boot
EOF
RUN --security=insecure chroot /output ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
RUN --security=insecure cd /output && prefix="$(echo "${TARGETPLATFORM#*\/}" | tr '/' '-')-$distro${release:+-$release}" && \
    mount esp.img boot/ && genisoimage -o /$prefix-esp.iso boot/ && umount boot/ && rm esp.img && \
    tar --xattrs-include='*.*' --numeric-owner -cpJf /$prefix-rootfs.tar.xz .

FROM scratch
COPY --from=final *-esp.iso *-rootfs.tar.xz .
