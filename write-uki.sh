#!/bin/sh

mnt=$(mktemp -d)
while [ "$#" -gt 0 ] ; do
  case "$1" in
    -*) ;; # ignore flags and options
     *) if [ "$uki" ]; then
          mkfs.fat -F 32 "$1"
          mount "$1" $mnt
          mkdir -p $mnt/efi/boot
          cp "$uki" $mnt/efi/boot/bootx64.efi
          umount $mnt
        else
          uki="$1"
        fi
        ;;
  esac
  shift
done
rmdir $mnt
