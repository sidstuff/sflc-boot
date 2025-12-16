#!/bin/sh

for param in "$@"; do
  case "$param" in
    --fs=*) fs="${param#\-\-fs=}"
  esac
done
mnt=$(mktemp -d)
while [ "$#" -gt 0 ] ; do
  case "$1" in
    -*) ;; # ignore flags and options
     *) if [ "$tarball" ]; then
          mkfs.${fs:-ext4} "$1"
          mount "$1" $mnt
          tar --numeric-owner \
              --xattrs-include='*.*' \
              -xpf "$tarball" \
              -C $mnt
          umount $mnt
        else
          tarball="$1"
        fi
        ;;
  esac
  shift
done
rmdir $mnt
