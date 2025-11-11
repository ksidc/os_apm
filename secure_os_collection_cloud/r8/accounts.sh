#!/bin/bash

BASE_DIR="/usr/local/src/secure_os_collection/r8"
source "$BASE_DIR/common.sh"

remove_unneeded_users() {
    local users=(lp games sync shutdown halt)
    for u in "${users[@]}"; do
        if id "$u" &>/dev/null; then
            userdel -r "$u" 2>/dev/null || userdel "$u" 2>/dev/null || true
        fi
    done
}

configure_ftp_shell() {
    if id ftp &>/dev/null; then
        usermod -s /sbin/nologin ftp 2>/dev/null || true
    fi
}

remove_unneeded_users
configure_ftp_shell
