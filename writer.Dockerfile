# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright © 2025 Sidharth Sankar

FROM alpine:latest
RUN apk add --no-cache tar file mount grep xz zstd bzip2 e2fsprogs xfsprogs btrfs-progs f2fs-tools dosfstools jfsutils
COPY <<'EOF' write.sh
mnt=$(mktemp -d)
isomnt=$(mktemp -d)
cleanup()
{
  umount $mnt >/dev/null 2>&1 || true
  umount $isomnt >/dev/null 2>&1 || true
}
trap cleanup INT EXIT

for param in "$@"; do
  case "$param" in
    --fs=*) fs="${param#\-\-fs=}"
  esac
done

while [ "$#" -gt 0 ]; do
  case "$1" in
    -*) ;; # ignore flags and options
     *) case "$format" in
          root) mkfs.${fs:-ext4 -b 4096} "$1"
                mount "$1" $mnt
                STRIP=$(tar -tf "$file" | grep -P '(?<![^/])proc/$' | sed 's/^\.\///' | awk -F '/' '{print NF-2}' | sort -n | head -1)
                tar --numeric-owner --xattrs-include='*.*' --strip-components=${STRIP:-0} -xpf "$file" -C $mnt
                umount $mnt
                ;;
           uki) blkid "$1" | grep 'TYPE="vfat"' || mkfs.vfat "$1"
                mount "$1" $mnt
                cp -rf $isomnt/. $mnt
                umount $mnt
                ;;
             *) if [ "$(tar -tf "$1" 2>&1)" ]; then
                  format="root"
                  file=$(mktemp)
                  case "$(file "$1")" in
                    *Zstandard*) zstdcat "$1" > $file ;;
                    *bzip2*) bz2cat "$1" > $file ;;
                    *gzip*) zcat "$1" > $file ;;
                    *XZ*) xzcat "$1" > $file ;;
                    *tar*) file="$1" ;;
                    *) echo "Tarball not of supported format. Exiting..." >&2 && exit 1 ;;
                  esac
                elif file "$1" | grep "ISO 9660 CD-ROM filesystem data"; then
                  format="uki"
                  mount "$1" $isomnt
                else
                  echo "First file not ISO or tar archive. Exiting..." >&2 && exit 1
                fi
                ;;
        esac
        ;;
  esac
  shift
done
EOF
ENTRYPOINT ["sh", "-e", "write.sh"]
