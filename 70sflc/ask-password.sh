#!/bin/sh

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright © 2025 Sidharth Sankar

await() { until eval "$1" >/dev/null 2>&1; do sleep 1; done; }
nosplash() { for opt in x $CMDLINE; do case "$opt" in splash*) return 1 ;; esac; done; }

{   flock -s 9

    if command -v plymouth > /dev/null && ! nosplash; then
        printf "Waiting for plymouth...\n"
        await 'plymouth --ping'
        plymouth display-message --text="Waiting for device..."
        await 'ls $root'
        plymouth display-message --text=""
        plymouth ask-for-password --prompt "Enter passphrase: " --command="sh /sbin/try-password.sh"
    else
        stty --version >/dev/null 2>&1 && stty -echo
        printf "Waiting for device...\r"
        await 'ls $root'
        printf "                     \r"
        until
        {   printf "Enter passphrase: "
            read PASSWORD
            printf "%s" "$PASSWORD" | sh /sbin/try-password.sh
        } ; do printf "\nSorry, try again.\n"; done
        stty --version >/dev/null 2>&1 && stty echo
    fi

} 9> /.console_lock
