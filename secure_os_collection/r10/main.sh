#!/bin/bash

# Rocky Linux 10 보안 강화 메인 스크립트
# 실행: go.sh에서 호출

set -u

NTP_SERVER=${NTP_SERVER:-"kr.pool.ntp.org"}
RSYSLOG_SERVER=${RSYSLOG_SERVER:-"1.224.163.4"}
MIN_PASSWORD_LENGTH=${MIN_PASSWORD_LENGTH:-8}
SSH_PORT=${SSH_PORT:-38371}
BACKUP_DIR="/usr/local/src/scripts_org"
LOG_DIR="/usr/local/src/secure_os_collection/logs"
LOG_FILE="$LOG_DIR/go_$(date +%Y%m%d_%H%M%S).log"
RESULT_FILE="$LOG_DIR/result_$(date +%Y%m%d_%H%M%S).log"

SUMMARY_LINES=()
NEW_SSH_PORT="미설정(기본 22)"
PASSWORD_POLICY_SUMMARY="미적용"
CREATED_USER="미생성"
DELETED_USERS=""
SERVICES_DISABLED=""
RESTARTED_SERVICES=""

declare -A restarts_needed

format_value() {
    local value="${1:-}"
    value="${value#${value%%[![:space:]]*}}"
    value="${value%${value##*[![:space:]]}}"
    if [ -z "$value" ]; then
        printf '없음'
    else
        printf '%s' "$value"
    fi
}

if ! mkdir -p "$LOG_DIR"; then
    echo "[ERROR] 로그 디렉터리 $LOG_DIR 생성 실패" >&2
    exit 1
fi
chmod 700 "$LOG_DIR" || {
    echo "[ERROR] 로그 디렉터리 $LOG_DIR 권한 설정 실패" >&2
    exit 1
}

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] 로그 디렉터리 $LOG_DIR 준비 완료" | tee -a "$LOG_FILE"

if ! source /usr/local/src/secure_os_collection/r10/common.sh; then
    echo "[ERROR] common.sh 로드 실패" >&2
    exit 1
fi

log_info "main.sh 실행 시작"
check_root

log_info "system.sh 실행"
if ! source /usr/local/src/secure_os_collection/r10/system.sh; then
    log_error "main" "system.sh 실행 실패"
    exit 1
fi
log_info "system.sh 실행 완료"

log_info "iptables.sh 실행"
if ! source /usr/local/src/secure_os_collection/r10/iptables.sh; then
    log_error "main" "iptables.sh 실행 실패"
    exit 1
fi
log_info "iptables.sh 실행 완료"

log_info "accounts.sh 실행"
if ! source /usr/local/src/secure_os_collection/r10/accounts.sh; then
    log_error "main" "accounts.sh 실행 실패"
    exit 1
fi
log_info "accounts.sh 실행 완료"

log_info "services.sh 실행"
if ! source /usr/local/src/secure_os_collection/r10/services.sh; then
    log_error "main" "services.sh 실행 실패"
    exit 1
fi
log_info "services.sh 실행 완료"

log_info "apm.sh 실행"
if ! source /usr/local/src/secure_os_collection/r10/apm.sh; then
    log_error "main" "apm.sh 실행 실패"
    exit 1
fi
log_info "apm.sh 실행 완료"

log_info "dnf update 실행"
if ! dnf -y update; then
    log_error "main" "dnf update 실패"
    exit 1
fi
log_info "dnf update 완료"
SUMMARY_LINES+=("패키지 업데이트: 실행 완료")

log_info "재시작 대상 서비스 처리"
for svc in "${!restarts_needed[@]}"; do
    if [ "${restarts_needed[$svc]}" -eq 1 ]; then
        if systemctl restart "$svc"; then
            log_info "$svc 재시작 완료"
            RESTARTED_SERVICES+="$svc "
        else
            log_error "main" "$svc 재시작 실패"
            exit 1
        fi
    fi
done
SUMMARY_LINES+=("재시작 서비스: $(format_value "$RESTARTED_SERVICES")")

SUMMARY_LINES+=("NTP 설정: 적용됨 (서버: $NTP_SERVER)")
SUMMARY_LINES+=("불필요 계정 제거: $(format_value "$DELETED_USERS")")
SUMMARY_LINES+=("SSH 포트 변경: $NEW_SSH_PORT")
SUMMARY_LINES+=("비밀번호 정책: $PASSWORD_POLICY_SUMMARY")
SUMMARY_LINES+=("운영 계정 생성: $CREATED_USER")
SUMMARY_LINES+=("방화벽 설정: 적용됨")
SUMMARY_LINES+=("SELinux 상태: 비활성화")
SUMMARY_LINES+=("sysctl/limits 튜닝: 적용됨")
SUMMARY_LINES+=("서비스 비활성화: $(format_value "$SERVICES_DISABLED")")
SUMMARY_LINES+=("백업 위치: $BACKUP_DIR (롤백: bash /usr/local/src/secure_os_collection/r10/rollback.sh 실행)")

{
    printf '\n=== 실행 결과 요약 ===\n'
    printf '%s\n' "${SUMMARY_LINES[@]}"
} | tee "$RESULT_FILE"
log_info "결과 요약 출력 및 저장 완료: $RESULT_FILE"

log_info "재부팅 여부 확인"
read -r -p "시스템을 즉시 재부팅하시겠습니까? (Y/N): " reboot < /dev/tty
if [[ "$reboot" =~ ^[Yy]$ ]]; then
    log_info "사용자 선택: 재부팅 진행"
    systemctl reboot
else
    log_info "사용자 선택: 재부팅 보류"
    echo "설정이 모두 반영되도록 가능한 한 빨리 시스템을 재부팅하세요."
fi
