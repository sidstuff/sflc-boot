#!/bin/sh
set -e

mkfs.ext4 "$1"
mount --mkdir "$1" /mnt/root

pacstrap -K /mnt/root base linux-firmware
arch-chroot /mnt/root << 'EOF'
ZONE="/usr/share/zoneinfo/$(curl -fsSL https://ipapi.co/timezone)"
if [ -f "$ZONE" ]; then ln -sf $ZONE /etc/localtime; fi
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >| /etc/locale.gen && locale-gen
printf 'LANG="en_US.UTF-8"\nLANGUAGE="en_US:en"\n' >| /etc/locale.conf
echo "arch" > /etc/hostname
passwd -d root
EOF

umount /mnt/root
rmdir /mnt/root
