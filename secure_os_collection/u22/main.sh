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
