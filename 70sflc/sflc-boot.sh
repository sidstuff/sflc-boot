#!/bin/sh

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright © 2025 Sidharth Sankar

command -v getargbool > /dev/null || . /lib/dracut-lib.sh

if getargbool 1 rd.sflc; then

    export NEWROOT="${NEWROOT:-"/sysroot"}"
    [ -d "$NEWROOT"/proc ] && exit 0
    
    export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    [ -d /sys/module/dm_sflc ] || modprobe dm_sflc || die 'Cannot load the dm_sflc module!'

    export CMDLINE="${CMDLINE-"$(getcmdline)"}"
    root="${root#block:}" && export root="${root:-"/dev/disk/by-id/*"}"

    _ctty="$(RD_DEBUG='' getarg rd.ctty=)" && _ctty="/dev/${_ctty##*/}"
    if [ -z "$_ctty" ]; then
        _ctty=console
        while [ -f "/sys/class/tty/$_ctty/active" ]; do
            read -r _ctty < "/sys/class/tty/$_ctty/active"
            _ctty=${_ctty##* } # last one in the list
        done
        _ctty=/dev/$_ctty
    fi
    [ -c "$_ctty" ] || _ctty=/dev/tty1
    case "$(setsid --help 2>&1)" in *--ctty*) CTTY="--ctty" ;; esac
    setsid ${CTTY:+"${CTTY}"} sh /sbin/ask-password.sh 0<> "$_ctty" 1<> "$_ctty" 2<> "$_ctty"

    need_shutdown

fi
