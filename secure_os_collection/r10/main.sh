#!/bin/bash

# Rocky Linux 10 보안 강화 메인 스크립트
# 실행: go.sh에서 호출

set -u

NTP_SERVER=${NTP_SERVER:-"kr.pool.ntp.org"}
RSYSLOG_SERVER=${RSYSLOG_SERVER:-"1.224.163.4"}
MIN_PASSWORD_LENGTH=${MIN_PASSWORD_LENGTH:-8}
SSH_PORT=${SSH_PORT:-38371}
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

while true; do
    echo "방화벽 시스템을 선택하세요:"
    echo "  1) iptables 설정"
    echo "  2) firewalld 설정"
    echo "  3) 방화벽 미사용 (모두 비활성화)"
    read -r -p "선택 (1/2/3): " FIREWALL_CHOICE < /dev/tty
    case "$FIREWALL_CHOICE" in
        1|2|3) break ;;
        *) echo "잘못된 입력입니다. 1, 2, 3 중 하나를 선택해주세요." ;;
    esac
done

if [ "$FIREWALL_CHOICE" -eq 1 ]; then
    log_info "iptables.sh 실행 시작 (iptables 선택)"
    if ! source /usr/local/src/secure_os_collection/r10/iptables.sh; then
        log_error "main" "iptables.sh 실행 실패"
        exit 1
    fi
    log_info "iptables.sh 실행 완료"
elif [ "$FIREWALL_CHOICE" -eq 2 ]; then
    log_info "firewalld.sh 실행 시작 (firewalld 선택)"
    if ! source /usr/local/src/secure_os_collection/r10/firewalld.sh; then
        log_error "main" "firewalld.sh 실행 실패"
        exit 1
    fi
    log_info "firewalld.sh 실행 완료"
else
    log_info "방화벽 미사용 설정 시작"
    systemctl stop firewalld iptables 2>/dev/null || true
    systemctl disable firewalld iptables 2>/dev/null || true
    systemctl mask firewalld iptables 2>/dev/null || true
    log_info "방화벽 미사용 설정 완료"
fi

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

# ────────────────────────────────────────────────────────────
# U-67: 로그 파일 권한 재설정 (dnf update 이후 리셋 방지)
# ────────────────────────────────────────────────────────────
log_info "로그 파일 권한 재설정 시작 (U-67)"
for f in /var/log/wtmp /var/log/lastlog; do
    [ -f "$f" ] && chmod 644 "$f"
done
for f in /var/log/btmp /var/log/btmp-*; do
    [ -f "$f" ] && chmod 600 "$f"
done
log_info "로그 파일 권한 재설정 완료"

# ────────────────────────────────────────────────────────────
# U-06: su 권한 재설정 (dnf update 시 util-linux 업데이트로 4755/root:root 복원 방지)
# ────────────────────────────────────────────────────────────
log_info "su 권한 재설정 시작 (U-06)"
chown root:wheel /usr/bin/su && chmod 4750 /usr/bin/su \
    && log_info "/usr/bin/su 권한 4750 root:wheel 재설정 완료" \
    || log_error "main" "/usr/bin/su 권한 재설정 실패"

# ────────────────────────────────────────────────────────────
# U-37: cron.deny 권한 재설정 (dnf update 시 cronie 업데이트로 644 복원 방지)
# ────────────────────────────────────────────────────────────
log_info "cron.deny 권한 재설정 시작 (U-37)"
if [ -f /etc/cron.deny ]; then
    chown root:root /etc/cron.deny
    chmod 640 /etc/cron.deny
    log_info "/etc/cron.deny 권한 640 재설정 완료"
fi

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

# ────────────────────────────────────────────────────────────
# U-25: world-writable 재처리 (서비스 재시작 이후 최종 정리)
# ────────────────────────────────────────────────────────────
log_info "world-writable 재처리 시작 (U-25)"
find / -xdev -type f -perm -0002 \
    ! -path '/proc/*' ! -path '/sys/*' ! -path '/dev/*' \
    -exec chmod o-w {} \; 2>/dev/null
log_info "world-writable 재처리 완료"

SUMMARY_LINES+=("NTP 설정: 적용됨 (서버: $NTP_SERVER)")
SUMMARY_LINES+=("불필요 계정 제거: $(format_value "$DELETED_USERS")")
SUMMARY_LINES+=("SSH 포트 변경: $NEW_SSH_PORT")
SUMMARY_LINES+=("비밀번호 정책: $PASSWORD_POLICY_SUMMARY")
SUMMARY_LINES+=("운영 계정 생성: $CREATED_USER")
SUMMARY_LINES+=("방화벽 설정: 적용됨")
SUMMARY_LINES+=("SELinux 상태: 비활성화")
SUMMARY_LINES+=("sysctl/limits 튜닝: 적용됨")
SUMMARY_LINES+=("서비스 비활성화: $(format_value "$SERVICES_DISABLED")")

{
    printf '\n=== 실행 결과 요약 ===\n'
    printf '%s\n' "${SUMMARY_LINES[@]}"
} | tee "$RESULT_FILE"
log_info "결과 요약 출력 및 저장 완료: $RESULT_FILE"

# 리부팅 확인
log_info "모든 작업 완료. 정리 및 재부팅 대기."

echo ""
echo "============================================================================"
echo " [경고] 'Y' 선택 시 설치 파일(/usr/local/src/secure_os_collection)과"
echo "        로그 파일이 모두 삭제되며, 즉시 시스템이 재부팅됩니다."
echo "============================================================================"

while true; do
    read -r -p "설치 파일을 삭제하고 시스템을 재부팅하시겠습니까? (Y/N): " confirm_finish < /dev/tty
    
    case "$confirm_finish" in
        [Yy]*)
            log_info "사용자 요청에 의한 파일 삭제 및 재부팅 시작"
            echo "  → 설치 파일 및 로그 삭제 중..."
            
            # 디렉토리 변수 (하드코딩 방지용 로컬 선언)
            SCRIPT_DIR="/usr/local/src/secure_os_collection"
            ZIP_FILE="/usr/local/src/secure_os_collection.zip"
            
            # 1. zip 파일 및 스크립트 디렉토리 삭제
            [ -d "$SCRIPT_DIR" ] && rm -rf "$SCRIPT_DIR"
            [ -f "$ZIP_FILE" ] && rm -f "$ZIP_FILE"
            
            # 2. 임시 파일 정리
            rm -f /tmp/script_* /tmp/*.tmp 2>/dev/null || true
            
            echo "  → 시스템을 재부팅합니다..."
            sleep 1
            # 파일이 삭제되었어도 셸 메모리에 로드된 명령은 실행됨
            init 6
            break
            ;;
        [Nn]*)
            log_info "사용자 요청에 의해 정리 및 재부팅 취소됨."
            echo "  → 파일 삭제 및 재부팅을 취소했습니다."
            echo "  → 로그 및 스크립트가 유지됩니다."
            exit 0
            ;;
        *)
            echo "잘못된 입력입니다. 'Y' 또는 'N'을 입력해주세요."
            ;;
    esac
done
