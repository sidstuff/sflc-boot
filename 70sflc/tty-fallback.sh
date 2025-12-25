#!/bin/sh

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright © 2025 Sidharth Sankar

stty_orig=$(stty -g 2> /dev/null) && stty -echo
until
{   printf "Enter passphrase: "
    read PASSWORD
    printf "%s" "$PASSWORD" | sh /sbin/try-password.sh
} ; do printf "\nSorry, try again.\n"; done
[ "$stty_orig" ] && stty "$stty_orig"
