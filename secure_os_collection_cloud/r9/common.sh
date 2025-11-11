#!/bin/bash

BASE_DIR="/usr/local/src/secure_os_collection/r9"

set_file_perms() {
    local file="$1" owner="$2" perms="$3"
    [ -f "$file" ] || return 0
    chown "$owner" "$file"
    chmod "$perms" "$file"
}

check_root() {
    [ "$EUID" -eq 0 ] || exit 1
}
