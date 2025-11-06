#!/bin/bash
#
# kv_parser.sh
# KEY=VALUE 형식의 파일을 다루기 위한 보조 함수 모음입니다.

kv_trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    echo "$value"
}

kv_get_value() {
    local file="$1"
    local key="$2"
    [ -f "$file" ] || return 1
    awk -v target="$key" '
        function ltrim(s){sub(/^[ \t\r\n]+/, "", s); return s}
        function rtrim(s){sub(/[ \t\r\n]+$/, "", s); return s}
        /^[ \t]*#/ { next }
        /^[ \t]*$/ { next }
        {
            line=$0
            split(line, arr, "=")
            keyname=ltrim(rtrim(arr[1]))
            if (keyname == target) {
                sub(/^[^=]*=/, "", line)
                value=ltrim(rtrim(line))
                print value
                exit
            }
        }
    ' "$file"
}

kv_has_key() {
    local file="$1"
    local key="$2"
    kv_get_value "$file" "$key" >/dev/null
}

kv_list_keys() {
    local file="$1"
    [ -f "$file" ] || return 1
    awk '
        function ltrim(s){sub(/^[ \t\r\n]+/, "", s); return s}
        /^[ \t]*#/ { next }
        /^[ \t]*$/ { next }
        {
            split($0, arr, "=")
            key=ltrim(arr[1])
            print key
        }
    ' "$file"
}
