FROM debian:testing-slim
RUN mkdir output; apt update && apt install -y --no-install-recommends wget ca-certificates systemd arch-install-scripts xz-utils
ARG TARGETARCH distro
RUN << EOI
case "$distro" in
ubuntu)    apt install -y libxml2-utils ;;
archlinux) apt install -y libxml2-utils zstd ;;
gentoo)                        # i386 dropped in 2012 by the Linux kernel 3.8
case "$TARGETARCH" in          # i486 or i586 in [CURRENT YEAR]? probably not
      386) ARCH1="x86"  ; ARCH2="i686"    ; MFLAGS="-march=i686 -mtune=generic"    ;;
    amd64) ARCH1="amd64"; ARCH2="amd64"   ; MFLAGS="-march=x86-64 -mtune=generic"  ;;
    arm64) ARCH1="arm64"; ARCH2="arm64"   ; MFLAGS="-march=armv8-a -mtune=generic" ;;
  ppc64le) ARCH1="ppc"  ; ARCH2="ppc64le" ; MFLAGS="-mcpu=powerpc64le"             ;;
        *) exit 1 ;;
esac
wget -r -l1 -np -nd "https://distfiles.gentoo.org/releases/$ARCH1/autobuilds/current-stage3-$ARCH2-systemd/" -A "*.tar.xz"
tar --xattrs-include='*.*' --numeric-owner -xpf stage3-*.tar.xz -C /output
cat >| /output/etc/portage/make.conf << 'EOF'
USE="systemd dbus -initramfs"
COMMON_FLAGS="MFLAGS -mtune=generic -O2 -pipe -fvect-cost-model=dynamic -fno-semantic-interposition"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
LDFLAGS="${COMMON_FLAGS} -Wl,-O1 -Wl,--as-needed -Wl,--sort-common"
GOOS="linux"
GOARCH="TARGETARCH"
CGO_CFLAGS="${COMMON_FLAGS}"
CGO_CXXFLAGS="${COMMON_FLAGS}"
CGO_FFLAGS="${COMMON_FLAGS}"
GCO_FCFLAGS="${COMMON_FLAGS}"
CGO_LDFLAGS="${LDFLAGS}"
RUSTFLAGS="-C strip=symbols"
EMERGE_DEFAULT_OPTS="--getbinpkg"
ACCEPT_LICENSE="-* @BINARY-REDISTRIBUTABLE"
EOF
sed -i -e "s/MFLAGS/$MFLAGS/" -e "s/TARGETARCH/$TARGETARCH/" /output/etc/portage/make.conf
cp --dereference /etc/resolv.conf /output/etc/
;;
*) exit 1
;;
esac
EOI
ARG TARGETVARIANT release
RUN get() { wget -qO- "$1" | xmllint --recover --html --xpath '//a/text()' - | grep -oP "$2" | sort | tail -1; }; \
    case "$distro" in \
      ubuntu) \
        case "$TARGETARCH" in \
          ppc64le) TARGET="ppc64el"     ;; \
              386) TARGET="i386"        ;; \
              arm) { [ "$TARGETVARIANT" = v6 ] && TARGET="armel"; } || \
                   { [ "$TARGETVARIANT" = v7 ] && TARGET="armhf"; } ;; \
                *) TARGET="$TARGETARCH" ;; \
        esac; \
        url="https://cdimage.ubuntu.com/ubuntu-base"; \
        if [ "$release" ]; then \
          url="$url/releases/$release/release"; \
          file=$(get "$url" "^ubuntu-base-$release-base-$TARGET.tar.gz$"); \
          file="${file:-$(get "$url" "^ubuntu-base-.*-base-$TARGET.tar.gz$")}"; \
        else \
          url="$url/daily/current"; \
          file=$(get "$url" "^.*-base-$TARGET.tar.gz$"); \
        fi; \
        wget -qO- "$url/$file" | \
        tar --xattrs-include='*.*' --numeric-owner -xzp -C /output \
        ;; \
      archlinux) \
        url="https://archive.archlinux.org/iso"; \
        date=$(get "$url" '^[0-9]{4}\.[0-9]{2}\.[0-9]{2}(?=/$)'); \
        wget -qO- "$url/$date/archlinux-bootstrap-x86_64.tar.zst" | \
        tar --xattrs-include='*.*' --numeric-owner --strip-components=1 --zstd -xp -C /output; \
        sed -i '/^CheckSpace/s/^/#/' /output/etc/pacman.conf; \
        wget -O /output/etc/pacman.d/mirrorlist \
             https://raw.githubusercontent.com/archlinux/archlinux-docker/master/rootfs/etc/pacman.d/mirrorlist \
        ;; \
    esac; \
    systemd-firstboot \
      --force \
      --root="/output" \
      --delete-root-password \
      --setup-machine-id \
      --hostname="$distro" \
      --locale="en_US.UTF-8" \
      --locale-messages="C.UTF-8"
ARG firmware
RUN --security=insecure arch-chroot /output << EOI
case "$distro" in
  ubuntu)
    export DEBIAN_FRONTEND=noninteractive
    apt update
    apt full-upgrade -y
    apt install -y locales ubuntu-server-minimal wpasupplicant $(case "$firmware" in [Nn]*) ;; *) echo linux-firmware ;; esac)
    ;;
  gentoo)
    getuto
    emerge-webrsync
    emerge -quDN --keep-going @world wpa_supplicant $(case "$firmware" in [Nn]*) ;; *) echo linux-firmware ;; esac)
    emerge -1 mirrorselect && mirrorselect -i -o >> /etc/portage/make.conf
    emerge -c
    ;;
  archlinux)
    pacman-key --init
    pacman-key --populate
    pacman -Sy --noconfirm --asdeps reflector
    reflector  --protocol http,https \
               --score 5 \
               --sort rate \
               --save /etc/pacman.d/mirrorlist
    pacman -Su --noconfirm wpa_supplicant $(case "$firmware" in [Nn]*) ;; *) echo linux-firmware ;; esac)
    pacman -Sc --noconfirm
    ;;
esac
systemctl preset-all
systemctl disable systemd-networkd-wait-online.service
sed -i '/en_US\\.UTF-8/s/^# *//' /etc/locale.gen && locale-gen
EOI
RUN --security=insecure chroot /output ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
ARG TARGETPLATFORM
RUN tar --xattrs-include='*.*' --numeric-owner \
        -cpJf $distro${release:+-$release}-rootfs-$(echo "${TARGETPLATFORM#*\/}" | tr '/' '-').tar.xz -C /output .
FROM scratch
COPY --from=0 *-rootfs-*.tar.xz .
