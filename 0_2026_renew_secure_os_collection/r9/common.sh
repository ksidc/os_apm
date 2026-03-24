#!/bin/bash

# 공통 함수
# 로그 파일: main.sh에서 정의된 LOG_FILE 사용

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1: $2" >> "$LOG_FILE"
}

set_file_perms() {
    local file="$1" owner="$2" perms="$3"
    log_info "set_file_perms 시작: $file $owner $perms"
    if [ -f "$file" ]; then
        chown "$owner" "$file" && log_info "Set $file owner to $owner" \
            || { log_error "set_file_perms" "$file 소유자 설정 실패"; return 1; }
        chmod "$perms" "$file" && log_info "Set $file permissions to $perms" \
            || { log_error "set_file_perms" "$file 권한 설정 실패"; return 1; }
    else
        log_info "$file does not exist, skipping permission setting"
        return 1
    fi
}

check_root() {
    log_info "check_root 시작"
    [ "$EUID" -ne 0 ] && { log_error "check_root" "root 권한 필요"; exit 1; }
    log_info "check_root 성공"
}