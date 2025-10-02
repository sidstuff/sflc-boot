#!/bin/sh
set -e

mount -o remount,size=2G /run/archiso/cowspace
pacman --noconfirm -Sy git make gcc
if ! pacman -Qs systemd-ukify; then
  SYSTEMDVER=$(pacman -Qi systemd | sed -nE 's/^Version *: (.*)/\1/p')
  pacman --noconfirm -U https://archive.archlinux.org/packages/s/systemd-ukify/systemd-ukify-$SYSTEMDVER-x86_64.pkg.tar.zst
fi

if [ "$1" ]; then
  PARENT=$(lsblk -ndo PKNAME "$1")
  PARTNUM=$(lsblk -ndo PARTN "$1")
  parted /dev/$PARENT set $PARTNUM boot on

  mkfs.fat -F 32 "$1"
  mount --mkdir "$1" /mnt/esp
fi

if [ ! -f busybox ]; then
  git clone --depth 1 https://git.busybox.net/busybox busybox-git
  cd busybox-git
  make defconfig
  # disable tc as it has a bug that causes compilation to fail
  # https://lists.busybox.net/pipermail/busybox-cvs/2024-January/041752.html
  sed -e 's/CONFIG_TC=y/CONFIG_TC=n/' -e 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' -i .config
  make
  mv busybox ..
  cd ..
  rm -rf busybox-git
fi

if [ ! -f shufflecake ] || [ ! -f dm-sflc.ko ]; then
  [ -d shufflecake-c ] || git clone --depth 1 https://codeberg.org/shufflecake/shufflecake-c
  cd shufflecake-c
  pacman --noconfirm -S device-mapper libgcrypt
  pacman -Qs linux-headers || pacman --noconfirm -U https://archive.archlinux.org/packages/l/linux-headers/linux-headers-$(uname -r | sed 's/-/\./')-x86_64.pkg.tar.zst
  make
  mv -f shufflecake dm-sflc.ko ..
  cd ..
  rm -rf shufflecake-c
fi

unzstd /lib/modules/$(uname -r)/kernel/drivers/md/dm-mod.ko.zst -o dm-mod.ko
unzstd /lib/modules/$(uname -r)/kernel/drivers/usb/storage/usb-storage.ko.zst -o usb-storage.ko
curl -fLO https://raw.githubusercontent.com/sidstuff/sflc-boot/master/init
curl -fLO https://raw.githubusercontent.com/sidstuff/sflc-boot/master/sflc-boot.sh

curl -fLO https://raw.githubusercontent.com/sidstuff/sflc-boot/master/initramfs.list
ldd shufflecake | sed -nE 's/^\s*lib.* => (\S*).*/file \1 \1 755 0 0/p' >> initramfs.list
ldd shufflecake | sed -nE 's/^\s*(\/lib64\/\S*).*/file \1 \1 755 0 0/p' >> initramfs.list

curl -fLO https://raw.githubusercontent.com/torvalds/linux/master/usr/gen_init_cpio.c
gcc gen_init_cpio.c -o gen_init_cpio
./gen_init_cpio initramfs.list | gzip --best > initramfs.cpio.gz

[ "$1" ] && mkdir -p /mnt/esp/efi/boot
ukify build --linux=/lib/modules/$(uname -r)/vmlinuz \
            --initrd=initramfs.cpio.gz \
            --output=${1:+/mnt/esp/efi/boot/}bootx64.efi

rm dm-mod.ko usb-storage.ko init sflc-boot.sh initramfs.list gen_init_cpio.c gen_init_cpio
if [ "$1" ]; then
  rm initramfs.cpio.gz
  umount /mnt/esp
  rmdir /mnt/esp
fi
