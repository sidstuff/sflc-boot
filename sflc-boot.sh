rescue()
{
  for i in 5 4 3 2 1; do
    printf "Setup Failed. Dropping to a rescue shell in $i\r"
    sleep 1
  done
  clear
  exec sh
}

setup()
(
  set -e

  mount -n -t proc     proc     /proc
  mount -n -t sysfs    sysfs    /sys
  mount -n -t devtmpfs devtmpfs /dev

  ln -s /proc/self/fd/0 /dev/stdin
  ln -s /proc/self/fd/1 /dev/stdout
  ln -s /proc/self/fd/2 /dev/stderr

  insmod usb-storage.ko
  insmod dm-mod.ko
  insmod dm-sflc.ko

  echo 0 > /proc/sys/kernel/printk
)
setup || rescue

interrupt()
{
  rm -f flag
  clear
  stty echo
  exec sh
}
trap interrupt SIGINT

PREFIX="Shufflecake v$(shufflecake -V)"
HELP="Press Ctrl+C to drop to a rescue shell."
MSG="$HELP"

get_device()
{
  clear
  printf "$PREFIX - $MSG\n\n$1"
  { sleep 5; printf "\0337\033[1;1H\033[0K%s\0338" "$PREFIX - $HELP"; } &

  touch flag
  while [ -f flag ]; do
    printf "\0337\033[6;1H\033[0J%s\n\n%s\0338" "Here are the detected partitions:" "$(cat /proc/partitions)"
    sleep 2
  done &
  read DEVICE
  rm flag

  if [ -z "$DEVICE" ]; then
    MSG="Device name is empty. Try again..."
    return 1
  fi
}

sflc_open()
{
  get_device "Name of the device to unlock: " || return 1

  printf "Password: "
  stty -echo
  read PASSWORD
  stty echo
  if [ -z "$PASSWORD" ]; then
    MSG="Password is empty. Try again..."
    return 1
  fi
  
  if printf "%s" "$PASSWORD" | shufflecake open "/dev/$DEVICE" >/dev/null 2>&1; then
    MSG="Device unlocked successfully."
  else
    MSG="Failed to unlock device. Try again..."
    return 1
  fi
}
until sflc_open ; do : ; done

mount_root()
{
  get_device "Name of the device to mount as root: " || return 1

  if ! mount -o ro "/dev/$DEVICE" /mnt/root >/dev/null 2>&1; then
    MSG="Failed to mount root. Try again..."
    return 1
  fi
}
until mount_root ; do : ; done

umount /proc
umount /sys
# `umount /dev` fails with `umount: can't unmount /dev: Device or resource busy`

exec switch_root /mnt/root /sbin/init
