#!/bin/sh

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright © 2025 Sidharth Sankar

PASSWORD=$(cat)
try_mount() {
    if mount -o "$rflags" "$1" "$NEWROOT" >/dev/null 2>&1; then
        if [ -d "$NEWROOT"/proc ]; then exit 0; else umount "$1"; fi
    fi
}

if [ -z "$PASSWORD" ]; then for DEVICE in ${root#block:}; do try_mount "$DEVICE"; done
else for DEVICE in ${root#block:}; do
    if printf "%s" "$PASSWORD" | shufflecake open "$DEVICE" >/dev/null 2>&1; then
        for VOLUME in $(ls -rv /dev/dm-*); do try_mount "$VOLUME"; done
        shufflecake close "$DEVICE" >/dev/null 2>&1
    fi
done
fi
exit 1
