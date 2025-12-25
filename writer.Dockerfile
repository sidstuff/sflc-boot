FROM alpine:latest
RUN apk add --no-cache file tar xz zstd bzip2 e2fsprogs xfsprogs btrfs-progs f2fs-tools dosfstools
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
          root) mkfs.${fs:-ext4} "$1"
                mount "$1" $mnt
                tar --numeric-owner --xattrs-include='*.*' -xpf "$file" -C $mnt
                umount $mnt
                ;;
           uki) blkid "$1" | grep 'TYPE="vfat"' || mkfs.vfat "$1"
                mount "$1" $mnt
                cp -rf $isomnt $mnt
                umount $mnt
                ;;
             *) if tar -tf "$1" >/dev/null 2>&1; then
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
                  mount -o loop "$1" $isomnt
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
