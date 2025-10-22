#!/bin/bash
#
# Ubuntu 24.04 보안 하드닝 메인 스크립트 (r8/r9 스타일과 통일)

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
  echo "[ERROR] 로그 디렉터리 $LOG_DIR 생성 실패" >&2
  exit 1
}
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

log_info "main 시작"

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

log_info "서비스 재시작 점검 시작"
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
log_info "서비스 재시작 점검 완료"

SUMMARY=""
SUMMARY+="NTP 설정: $NTP_SERVER\n"
SUMMARY+="시스템 기본 설정: $SYSTEM_TUNING_SUMMARY\n"
SUMMARY+="루트 비밀번호 변경: $ROOT_PASSWORD_CHANGED\n"
SUMMARY+="SSH 포트 변경: $NEW_SSH_PORT\n"
SUMMARY+="비밀번호 만료 정책: $PASSWORD_POLICY_SUMMARY\n"
SUMMARY+="일반 계정 생성: $CREATED_USER\n"
SUMMARY+="삭제된 기본 계정: ${DELETED_USERS:-없음}\n"
SUMMARY+="비활성화한 서비스: ${SERVICES_DISABLED:-없음}\n"
SUMMARY+="재시작한 서비스: ${RESTARTED_SERVICES:-없음}\n"
SUMMARY+="백업 위치: $BACKUP_DIR\n"
SUMMARY+="로그 파일: $LOG_FILE\n"

echo -e "$SUMMARY" > "$RESULT_FILE"
log_info "결과 요약 저장: $RESULT_FILE"

echo -e "\n=== 실행 결과 요약 ===\n$SUMMARY"
echo "자세한 내용은 로그 파일과 결과 요약 파일을 확인하세요."

if prompt_yes_no "지금 시스템을 재부팅할까요?"; then
  log_info "사용자 선택: 재부팅 진행"
  systemctl reboot
else
  log_info "사용자 선택: 재부팅 보류"
  echo "변경 사항 일부는 재부팅 후 적용됩니다. 운영 일정에 따라 재부팅을 진행해 주세요."
fi
