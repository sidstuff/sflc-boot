#!/bin/bash

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright © 2025 Sidharth Sankar

block_is_sflc() {
    local _dev=$1
    [ -e /sys/dev/block/"$_dev"/dm/uuid ] || return 1
    [[ $(cat /sys/dev/block/"$_dev"/dm/name) =~ sflc_[0-9]+_[0-9]+ ]] && return 0
    return 1
}

# called by dracut
check() {

    if cd /usr/src/shufflecake 2> /dev/null; then
        git pull origin main
        make KERNEL_DIR=/lib/modules/$kernel/build \
        && mv -f shufflecake /bin \
        && mkdir -p /lib/modules/$kernel/updates \
        && mv -f dm-sflc.ko /lib/modules/$kernel/updates \
        && depmod $kernel
        cd - > /dev/null
    fi
    
    require_binaries shufflecake || return 1
    require_kernel_modules dm_sflc || return 1

    [[ $hostonly ]] || [[ $mount_needs ]] && {
        local _rootdev
        _rootdev=$(find_root_block_device)
        [[ -b /dev/block/$_rootdev ]] || return 1
        check_block_and_slaves block_is_sflc "$_rootdev" || return 255
    }

    return 0
}

# called by dracut
depends() {
    echo dm
}

# called by dracut
installkernel() {
    local _arch=${DRACUT_ARCH:-$(uname -m)}
    local _s390drivers=
    if [[ $_arch == "s390" ]] || [[ $_arch == "s390x" ]]; then
        _s390drivers="=drivers/s390/crypto"
    fi

    hostonly="" instmods drbg dm_sflc ${_s390drivers:+"$_s390drivers"}

    # in case some of the crypto modules moved from compiled in
    # to module based, try to install those modules
    # best guess
    if [[ $hostonly_mode == "strict" ]] || [[ $mount_needs ]]; then
        # dmsetup returns s.th. like
        # cryptvol: 0 2064384 crypt aes-xts-plain64 :64:logon:cryptsetup:....
        dmsetup table | while read -r name _ _ is_crypt cipher _; do
            [[ $is_crypt == "crypt" ]] || continue
            # get the device name
            name=/dev/$(dmsetup info -c --noheadings -o blkdevname "${name%:}")
            # check if the device exists as a key in our host_fs_types (even with null string)
            if [[ ${host_fs_types[$name]+_} ]]; then
                # split the cipher aes-xts-plain64 in pieces
                IFS='-:' read -ra mods <<< "$cipher"
                # try to load the cipher part with "crypto-" prepended
                # in non-hostonly mode
                hostonly='' instmods "${mods[@]/#/crypto-}" "crypto-$cipher"
            fi
        done
    else
        hostonly='' instmods "=crypto"
    fi
    return 0
}

# called by dracut
install() {
    inst_hook cmdline 95 "$moddir/parse-cmdline.sh"
    inst_hook pre-mount 99 "$moddir/sflc-boot.sh"
    inst_script "$moddir/ask-password.sh" "/sbin/ask-password.sh"
    inst_script "$moddir/try-password.sh" "/sbin/try-password.sh"

    inst_multiple shufflecake
    inst_multiple -o stty

    # Install required libraries.
    _arch=${DRACUT_ARCH:-$(uname -m)}
    inst_libdir_file \
        {"tls/$_arch/",tls/,"$_arch/",}"/ossl-modules/fips.so" \
        {"tls/$_arch/",tls/,"$_arch/",}"/ossl-modules/legacy.so"
}
