#!/bin/sh

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright © 2025 Sidharth Sankar

try_mount() {
    if mount -o "$rflags" "$1" "$NEWROOT" >/dev/null 2>&1; then
        [ -d "$NEWROOT"/proc ] && exit 0 || umount "$1"
    fi
}
PASSWORD=$(cat)
if [ -z "$PASSWORD" ]; then for DEVICE in $root; do try_mount "$DEVICE"; done
else for DEVICE in $root; do
    if printf "%s" "$PASSWORD" | shufflecake open "$DEVICE" >/dev/null 2>&1; then
        for VOLUME in $(ls -rv /dev/dm-*); do try_mount "$VOLUME"; done
        shufflecake close "$DEVICE" >/dev/null 2>&1
    fi
done
fi
exit 1
