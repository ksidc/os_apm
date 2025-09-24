#!/bin/bash

# 롤백 스크립트
LOG_DIR="/usr/local/src/secure_os_collection/logs"
LOG_FILE="$LOG_DIR/go_$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="/usr/local/src/scripts_org"

# 로그 디렉토리 생성
mkdir -p "$LOG_DIR" && chmod 700 "$LOG_DIR" || { echo "[ERROR] 로그 디렉토리 $LOG_DIR 생성 실패" >> "$LOG_FILE"; exit 1; }
log_info "로그 디렉토리 $LOG_DIR 생성 성공"

# 로그 함수
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1: $2" >> "$LOG_FILE"
}

# 루트 권한 확인
log_info "check_root 시작"
[ "$EUID" -ne 0 ] && { log_error "check_root" "root 권한 필요"; exit 1; }
log_info "check_root 성공"

# 롤백 함수
rollback_files() {
    log_info "rollback_files 시작"
    if [ ! -d "$BACKUP_DIR" ]; then
        log_error "rollback_files" "백업 디렉토리 $BACKUP_DIR 없음"; exit 1
    fi
    for bak_file in "$BACKUP_DIR"/*.bak_*; do
        if [ -f "$bak_file" ]; then
            orig_file="/$(basename "$bak_file" | sed 's/\.bak_.*//')"
            cp "$bak_file" "$orig_file" && log_info "$orig_file 복원 성공" \
                || log_error "rollback_files" "$orig_file 복원 실패"
        fi
    done
    log_info "rollback_files 완료"
}

# 서비스 재시작
rollback_services() {
    log_info "rollback_services 시작"
    for svc in sshd chronyd rsyslog firewalld vsftpd xinetd autofs finger rsh rlogin rexec ypbind ypserv ypxfrd rpc.yppasswdd rpc.ypupdated tftp-server talk rc-local; do
        if systemctl is-active "$svc" &>/dev/null; then
            systemctl restart "$svc" && log_info "$svc 재시작 성공" \
                || log_error "rollback_services" "$svc 재시작 실패"
        fi
    done
    log_info "rollback_services 완료"
}

# 롤백 실행
log_info "롤백 시작"
rollback_files
rollback_services
log_info "롤백 완료, 시스템 재부팅 권장"
echo "롤백 완료. 설정 적용을 위해 시스템 재부팅을 권장합니다."