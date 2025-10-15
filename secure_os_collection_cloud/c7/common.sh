#!/bin/bash
# c7/common.sh : 공통 함수 (변경 없음)

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "$LOG_FILE"
}
log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1: $2" >> "$LOG_FILE"
}
backup_file() {
    local BACKUP_DIR="/usr/local/src/scripts_org"
    mkdir -p "$BACKUP_DIR" && chmod 700 "$BACKUP_DIR" || { log_error "backup_file" "백업 디렉토리 생성 실패"; return 1; }
    log_info "backup_file 시작: $@"
    for f; do
        if [ -e "$f" ]; then
            cp "$f" "$BACKUP_DIR/$(basename "$f").bak_$(date +%F_%T)" || { log_error "backup_file" "$f 백업 실패"; return 1; }
            log_info "$f 백업 성공"
        else
            log_info "$f 없음, 백업 생략"
        fi
    done
    return 0
}
set_file_perms() {
    local file="$1" owner="$2" perms="$3"
    log_info "set_file_perms 시작: $file $owner $perms"
    if [ -f "$file" ]; then
        chown "$owner" "$file" || { log_error "set_file_perms" "$file 소유자 설정 실패"; return 1; }
        chmod "$perms" "$file" || { log_error "set_file_perms" "$file 권한 설정 실패"; return 1; }
        log_info "$file → $owner / $perms"
    else
        log_info "$file 없음"
        return 1
    fi
}
check_root() {
    log_info "check_root 시작"
    [ "$EUID" -ne 0 ] && { log_error "check_root" "root 권한 필요"; exit 1; }
    log_info "check_root 성공"
}