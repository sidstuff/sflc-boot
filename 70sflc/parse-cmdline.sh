#!/bin/sh

command -v getargbool > /dev/null || . /lib/dracut-lib.sh

if getargbool 1 rd.sflc; then

    root="/dev/block/*"

    CMDLINE=$(getcmdline)
    for opt in $CMDLINE; do
        case $opt in
            rd.sflc.*) opt="${opt##*.}"; root="/dev/disk/by-${opt/=/\/}" ;;
            root=*) root=$(label_uuid_to_dev "${opt#*=}") ;;
        esac
    done

    rootok=1

fi
