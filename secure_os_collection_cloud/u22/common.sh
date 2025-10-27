#!/bin/bash

BASE_DIR="/usr/local/src/secure_os_collection/u22"

set_file_perms() {
    local file="$1" owner="$2" perms="$3"
    [ -f "$file" ] || return 0
    chown "$owner" "$file"
    chmod "$perms" "$file"
}

check_root() {
    [ "${EUID:-$(id -u)}" -eq 0 ] || exit 1
}
