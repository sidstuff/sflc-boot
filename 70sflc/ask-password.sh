#!/bin/sh

command -v getargbool > /dev/null || . /lib/dracut-lib.sh

if getargbool 1 rd.sflc; then

    export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    export NEWROOT=${NEWROOT:-"/sysroot"}

    [ -f "$NEWROOT"/proc ] && exit 0
    [ -d /sys/module/usb_storage ] || modprobe usb_storage
    [ -d /sys/module/dm_sflc ] || modprobe dm_sflc || die 'Cannot load the dm_sflc module!'

    {   flock -s 9

        if command -v plymouth > /dev/null && plymouth --ping 2> /dev/null; then
            plymouth ask-for-password --prompt "Enter passphrase: " --command="sh /sbin/try-password.sh"
        else
            stty_orig=$(stty -g 2> /dev/null) && stty -echo
            until
            {   printf "Enter passphrase: "
                read PASSWORD
                printf "%s" "$PASSWORD" | sh /sbin/try-password.sh
            } ; do printf "\nSorry, try again.\n"; done
            [ "$stty_orig" ] && stty "$stty_orig"
        fi

    } 9> /.console_lock

    need_shutdown

fi
