#!/bin/bash
#
# Ubuntu 22.04 하드닝 메인 스크립트

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NTP_SERVER=${NTP_SERVER:-"pool.ntp.org"}
RSYSLOG_SERVER=${RSYSLOG_SERVER:-"1.224.163.4"}
MIN_PASSWORD_LENGTH=${MIN_PASSWORD_LENGTH:-8}
SSH_PORT=${SSH_PORT:-38371}

LOG_DIR="${LOG_DIR:-/usr/local/src/secure_os_collection/logs}"
mkdir -p "$LOG_DIR" && chmod 700 "$LOG_DIR" || {
  echo "[ERROR] 로그 디렉터리 $LOG_DIR 생성 실패" >&2
  exit 1
}

LOG_FILE="$LOG_DIR/u22_$(date +%Y%m%d_%H%M%S).log"
RESULT_FILE="$LOG_DIR/u22_result_$(date +%Y%m%d_%H%M%S).log"
touch "$LOG_FILE" "$RESULT_FILE"
chmod 600 "$LOG_FILE" "$RESULT_FILE"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] 로그 디렉터리 $LOG_DIR 생성 완료" | tee -a "$LOG_FILE"

source "${SCRIPT_DIR}/common.sh" || {
  echo "[ERROR] common.sh 로드 실패" >&2
  exit 1
}

declare -Ag restarts_needed=()

SUMMARY=""
NEW_SSH_PORT="미변경 (기본 22)"
PASSWORD_POLICY_SUMMARY="미적용"
CREATED_USER="미생성"
DELETED_USERS=""
SERVICES_DISABLED=""
RESTARTED_SERVICES=""

check_root

log_info "Ubuntu 22.04 하드닝을 시작합니다."

source "${SCRIPT_DIR}/system.sh" || {
  log_error "main" "system.sh 실행 실패"
  exit 1
}

source "${SCRIPT_DIR}/accounts.sh" || {
  log_error "main" "accounts.sh 실행 실패"
  exit 1
}

source "${SCRIPT_DIR}/services.sh" || {
  log_error "main" "services.sh 실행 실패"
  exit 1
}

log_info "지연된 서비스 재시작 작업 시작"
if [[ "${#restarts_needed[@]}" -gt 0 ]]; then
  for svc in "${!restarts_needed[@]}"; do
    if systemctl restart "$svc" >/dev/null 2>&1; then
      RESTARTED_SERVICES+=" $svc"
      log_info "서비스 재시작 성공: $svc"
    else
      log_warn "서비스 재시작 실패: $svc"
    fi
  done
else
  log_info "재시작이 필요한 서비스가 없습니다."
fi
log_info "지연된 서비스 재시작 작업 완료"

# 요약 생성
SUMMARY+="NTP 설정: 적용됨 (서버: $NTP_SERVER)\n"
SUMMARY+="불필요 사용자 삭제: 적용됨 (대상: ${DELETED_USERS:-없음})\n"
SUMMARY+="SSH 포트 변경: $NEW_SSH_PORT\n"
SUMMARY+="패스워드 정책: $PASSWORD_POLICY_SUMMARY\n"
SUMMARY+="새 계정 생성: $CREATED_USER\n"
SUMMARY+="서비스 비활성화: 적용됨 (대상: ${SERVICES_DISABLED:-없음})\n"
SUMMARY+="서비스 재시작: 적용됨 (대상: ${RESTARTED_SERVICES:-없음})\n"

# 요약 출력 및 저장
echo -e "\n=== 실행 결과 요약 ===\n$SUMMARY"
echo -e "$SUMMARY" > "$RESULT_FILE"
log_info "결과 요약 저장: $RESULT_FILE"

log_info "리부팅 확인 시작"
read -r -p "시스템을 지금 리부팅하시겠습니까? (Y/N): " reboot < /dev/tty

# 로그 파일 출력 중지 (디렉토리 삭제 전)
LOG_FILE=/dev/null
RESULT_FILE=/dev/null

# 작업 흔적 제거
echo -e "\n=== 작업 흔적 제거 중 ==="

# 1. zip 파일 및 스크립트 디렉토리 삭제
echo "  → 스크립트 및 zip 파일 삭제 중..."
SCRIPT_DIR="/usr/local/src/secure_os_collection"
ZIP_FILE="/usr/local/src/secure_os_collection.zip"
[ -d "$SCRIPT_DIR" ] && rm -rf "$SCRIPT_DIR"
[ -f "$ZIP_FILE" ] && rm -f "$ZIP_FILE"

# 3. 임시 파일 정리
rm -f /tmp/script_* /tmp/*.tmp 2>/dev/null || true

# 4. 모든 사용자 히스토리 삭제
echo "  → 명령 히스토리 삭제 중..."
rm -f /root/.bash_history /root/.history
printf 'history -c\nhistory -w\n' > /root/.bash_logout

for user_home in /home/*; do
    [ -d "$user_home" ] || continue
    rm -f "$user_home/.bash_history" "$user_home/.history"
    printf 'history -c\nhistory -w\n' > "$user_home/.bash_logout"
    chown "$(basename "$user_home")":"$(basename "$user_home")" "$user_home/.bash_logout" 2>/dev/null || true
    chmod 600 "$user_home/.bash_logout" 2>/dev/null || true
done

echo "  ✓ 모든 작업 흔적 제거 완료"

# 실행 셸 히스토리도 즉시 비우고 기록을 끔
history -c 2>/dev/null || true
history -w 2>/dev/null || true
unset HISTFILE
sleep 3

# 리부팅 또는 종료
action_cmd="kill -9 $$"
action_msg=$'  → 설정 적용을 위해 시스템 리부팅을 권장합니다.\n  → 3초 후 로그아웃됩니다...'
wait_seconds=3

if [[ "$reboot" =~ ^[Yy]$ ]]; then
    action_cmd="init 6"
    action_msg="  → 시스템을 재부팅합니다..."
    wait_seconds=1
fi

echo -e "$action_msg"
sleep "$wait_seconds"
eval "$action_cmd"
