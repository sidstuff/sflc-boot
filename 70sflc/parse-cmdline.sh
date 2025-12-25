#!/bin/sh

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright © 2025 Sidharth Sankar

command -v getargbool > /dev/null || . /lib/dracut-lib.sh

if getargbool 1 rd.sflc; then

    root="/dev/disk/by-id/*"

    CMDLINE=$(getcmdline) && export CMDLINE
    for opt in x $CMDLINE; do
        case $opt in
            rd.sflc.*) root="/dev/disk/by-$(echo "${opt##*.}" | sed 's/=/\//')" ;;
            root=*) root=$(label_uuid_to_dev "${opt#*=}") ;;
        esac
    done

    rootok=1

fi
