#!/bin/bash
#
# Ubuntu 22.04 하드닝 메인 스크립트

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NTP_SERVER=${NTP_SERVER:-"pool.ntp.org"}
RSYSLOG_SERVER=${RSYSLOG_SERVER:-"1.224.163.4"}
MIN_PASSWORD_LENGTH=${MIN_PASSWORD_LENGTH:-8}
SSH_PORT=${SSH_PORT:-38371}
BACKUP_DIR=${BACKUP_DIR:-"/usr/local/src/scripts_org"}
CONFIG_FILE=${CONFIG_FILE:-""}

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

load_external_config

declare -Ag restarts_needed=()

SYSTEM_TUNING_SUMMARY="미적용"
ROOT_PASSWORD_CHANGED="미적용"
PASSWORD_POLICY_SUMMARY="미적용"
CREATED_USER="미생성"
DELETED_USERS=""
NEW_SSH_PORT="미변경"
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

SUMMARY=""
SUMMARY+="NTP 서버 설정: $NTP_SERVER\n"
SUMMARY+="시스템 기본 설정: $SYSTEM_TUNING_SUMMARY\n"
SUMMARY+="root 비밀번호 변경: $ROOT_PASSWORD_CHANGED\n"
SUMMARY+="SSH 포트 변경: $NEW_SSH_PORT\n"
SUMMARY+="비밀번호 만료 정책: $PASSWORD_POLICY_SUMMARY\n"
SUMMARY+="생성된 관리자 계정: ${CREATED_USER:-없음}\n"
SUMMARY+="삭제된 불필요 계정: ${DELETED_USERS:-없음}\n"
SUMMARY+="비활성화된 서비스: ${SERVICES_DISABLED:-없음}\n"
SUMMARY+="재시작된 서비스: ${RESTARTED_SERVICES:-없음}\n"
SUMMARY+="백업 디렉터리: $BACKUP_DIR\n"
SUMMARY+="로그 파일: $LOG_FILE\n"

echo -e "$SUMMARY" > "$RESULT_FILE"
log_info "결과 요약을 ${RESULT_FILE}에 저장했습니다."

echo -e "\n=== 실행 결과 요약 ===\n$SUMMARY"
echo "자세한 내용은 로그 파일과 결과 요약 파일을 확인하세요."

if prompt_yes_no "지금 시스템을 재부팅하시겠습니까?"; then
  log_info "사용자 요청으로 시스템을 재부팅합니다."
  systemctl reboot
else
  log_info "재부팅을 보류했습니다. 필요한 경우 수동으로 재부팅하세요."
  echo "변경 사항 적용을 위해 적절한 시점에 재부팅하시기 바랍니다."
fi
