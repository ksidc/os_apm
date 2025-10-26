#!/bin/bash

BASE_DIR="/usr/local/src/secure_os_collection/u24"
source "$BASE_DIR/common.sh"

remove_unneeded_users() {
    local users=(lp games news uucp sync shutdown halt)
    for u in "${users[@]}"; do
        if id "$u" >/dev/null 2>&1; then
            userdel -r "$u" 2>/dev/null || userdel "$u" 2>/dev/null || true
        fi
    done
}

configure_ftp_shell() {
    if id ftp >/dev/null 2>&1; then
        local nologin="/usr/sbin/nologin"
        [ -x "$nologin" ] || nologin="/usr/bin/nologin"
        usermod -s "$nologin" ftp 2>/dev/null || true
    fi
}

remove_unneeded_users
configure_ftp_shell
