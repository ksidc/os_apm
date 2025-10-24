#!/bin/bash

# 공통 유틸리티 함수
# main.sh에서 설정한 LOG_FILE에 로그를 기록합니다.

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1: $2" >> "$LOG_FILE"
}

backup_file() {
    local BACKUP_DIR="/usr/local/src/scripts_org"
    mkdir -p "$BACKUP_DIR" && chmod 700 "$BACKUP_DIR" || { log_error "backup_file" "백업 디렉터리 생성 실패"; return 1; }
    log_info "backup_file 실행: $*"
    for f; do
        if [ -e "$f" ]; then
            cp "$f" "$BACKUP_DIR/$(basename "$f").bak_$(date +%F_%T)" || { log_error "backup_file" "$f 백업 실패"; return 1; }
            log_info "$f 백업 완료"
        else
            log_info "$f 없음, 백업 건너뜀"
        fi
    done
    return 0
}

set_file_perms() {
    local file="$1" owner="$2" perms="$3"
    log_info "set_file_perms 실행: $file $owner $perms"
    if [ -f "$file" ]; then
        chown "$owner" "$file" && log_info "$file 소유자 $owner로 변경"             || { log_error "set_file_perms" "$file 소유자 변경 실패"; return 1; }
        chmod "$perms" "$file" && log_info "$file 권한 $perms로 변경"             || { log_error "set_file_perms" "$file 권한 변경 실패"; return 1; }
    else
        log_info "$file 이 존재하지 않아 권한 설정을 건너뜀"
        return 1
    fi
}

check_root() {
    log_info "check_root 실행"
    if [ "$EUID" -ne 0 ]; then
        log_error "check_root" "root 권한이 필요합니다"
        echo "ERROR: root 권한으로 실행해 주세요." >&2
        exit 1
    fi
    log_info "check_root 완료"
}
