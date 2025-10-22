#!/bin/bash
#
# Ubuntu 20.04 보안 하드닝 메인 스크립트.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NTP_SERVER=${NTP_SERVER:-"pool.ntp.org"}
RSYSLOG_SERVER=${RSYSLOG_SERVER:-"1.224.163.4"}
MIN_PASSWORD_LENGTH=${MIN_PASSWORD_LENGTH:-8}
SSH_PORT=${SSH_PORT:-38371}
BACKUP_DIR=${BACKUP_DIR:-"/usr/local/src/scripts_org"}
CONFIG_FILE=${CONFIG_FILE:-""}

LOG_DIR="/usr/local/src/secure_os_collection/logs"
LOG_FILE="$LOG_DIR/go_$(date +%Y%m%d_%H%M%S).log"
RESULT_FILE="$LOG_DIR/result_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$LOG_DIR" && chmod 700 "$LOG_DIR" || {
  echo "[ERROR] 로그 디렉터리($LOG_DIR) 생성 실패" >&2
  exit 1
}
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] 로그 디렉터리 준비 완료: $LOG_DIR" | tee -a "$LOG_FILE"

# shellcheck source=./common.sh
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

log_info "main 시작"

# shellcheck source=./system.sh
source "${SCRIPT_DIR}/system.sh" || {
  log_error "main" "system.sh 실행 실패"
  exit 1
}

# shellcheck source=./accounts.sh
source "${SCRIPT_DIR}/accounts.sh" || {
  log_error "main" "accounts.sh 실행 실패"
  exit 1
}

# shellcheck source=./services.sh
source "${SCRIPT_DIR}/services.sh" || {
  log_error "main" "services.sh 실행 실패"
  exit 1
}

log_info "필요 서비스 재시작 절차 시작"
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
log_info "필요 서비스 재시작 절차 종료"

if [[ -n "$DELETED_USERS" ]]; then
  DELETED_USERS="${DELETED_USERS# }"
fi
if [[ -n "$SERVICES_DISABLED" ]]; then
  SERVICES_DISABLED="${SERVICES_DISABLED# }"
fi
if [[ -n "$RESTARTED_SERVICES" ]]; then
  RESTARTED_SERVICES="${RESTARTED_SERVICES# }"
fi

SUMMARY=""
SUMMARY+="NTP 서버: $NTP_SERVER\n"
SUMMARY+="시스템 기본 설정: $SYSTEM_TUNING_SUMMARY\n"
SUMMARY+="루트 비밀번호 변경: $ROOT_PASSWORD_CHANGED\n"
SUMMARY+="SSH 포트 변경: ${NEW_SSH_PORT:-미변경}\n"
SUMMARY+="비밀번호 만료 정책: $PASSWORD_POLICY_SUMMARY\n"
SUMMARY+="생성한 관리자 계정: ${CREATED_USER:-미생성}\n"
SUMMARY+="삭제한 기본 계정: ${DELETED_USERS:-없음}\n"
SUMMARY+="비활성화된 서비스: ${SERVICES_DISABLED:-없음}\n"
SUMMARY+="재시작된 서비스: ${RESTARTED_SERVICES:-없음}\n"
SUMMARY+="백업 디렉터리: $BACKUP_DIR\n"
SUMMARY+="로그 파일: $LOG_FILE\n"

echo -e "$SUMMARY" > "$RESULT_FILE"
log_info "결과 요약을 ${RESULT_FILE}에 저장했습니다."

echo -e "\n=== 실행 결과 요약 ===\n$SUMMARY"
echo "자세한 내용은 로그 파일과 결과 요약 파일을 확인하세요."

if prompt_yes_no "지금 시스템을 재부팅할까요?"; then
  log_info "사용자가 재부팅을 선택했습니다."
  systemctl reboot
else
  log_info "사용자가 재부팅을 보류했습니다."
  echo "필요 시 직접 재부팅을 진행하세요."
fi
