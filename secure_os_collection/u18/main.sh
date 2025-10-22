#!/bin/bash
#
# Ubuntu 18.04 보안 하드닝 메인 진입점.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NTP_SERVER=${NTP_SERVER:-"pool.ntp.org"}
RSYSLOG_SERVER=${RSYSLOG_SERVER:-"1.224.163.4"}
MIN_PASSWORD_LENGTH=${MIN_PASSWORD_LENGTH:-8}
SSH_PORT=${SSH_PORT:-38371}
BACKUP_DIR=${BACKUP_DIR:-"/usr/local/src/scripts_org"}
CONFIG_FILE=${CONFIG_FILE:-"/etc/hardening.conf"}

LOG_DIR="/usr/local/src/secure_os_collection/logs"
mkdir -p "$LOG_DIR"
chmod 700 "$LOG_DIR" >/dev/null 2>&1 || true

LOG_FILE="$LOG_DIR/u18_$(date +%Y%m%d_%H%M%S).log"
RESULT_FILE="$LOG_DIR/u18_result_$(date +%Y%m%d_%H%M%S).log"
touch "$LOG_FILE" "$RESULT_FILE"
chmod 600 "$LOG_FILE" "$RESULT_FILE"

# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh" || {
  echo "오류: 공용 헬퍼(common.sh)를 불러오지 못했습니다." >&2
  exit 1
}

load_external_config

declare -Ag restarts_needed=()

SYSTEM_TUNING_SUMMARY="대기"
ROOT_PASSWORD_CHANGED="대기"
PASSWORD_POLICY_SUMMARY="대기"
CREATED_USER="없음"
DELETED_USERS=""
NEW_SSH_PORT="변경 없음"
SERVICES_DISABLED=""
RESTARTED_SERVICES=""

check_root

log_info "메인 실행 시작"

# shellcheck source=./system.sh
source "${SCRIPT_DIR}/system.sh" || {
  log_error "main" "system.sh 로드 실패"
  exit 1
}

# shellcheck source=./accounts.sh
source "${SCRIPT_DIR}/accounts.sh" || {
  log_error "main" "accounts.sh 로드 실패"
  exit 1
}

# shellcheck source=./services.sh
source "${SCRIPT_DIR}/services.sh" || {
  log_error "main" "services.sh 로드 실패"
  exit 1
}

log_info "추가 서비스 재시작 처리"
if (( ${#restarts_needed[@]} > 0 )); then
  for svc in "${!restarts_needed[@]}"; do
    if systemctl restart "$svc" >/dev/null 2>&1; then
      RESTARTED_SERVICES+=" $svc"
      log_info "서비스 재시작 성공: $svc"
    else
      log_warn "서비스 재시작 실패: $svc"
    fi
  done
fi

if [[ -n "$DELETED_USERS" ]]; then
  DELETED_USERS="${DELETED_USERS# }"
fi
if [[ -n "$SERVICES_DISABLED" ]]; then
  SERVICES_DISABLED="${SERVICES_DISABLED# }"
fi
if [[ -n "$RESTARTED_SERVICES" ]]; then
  RESTARTED_SERVICES="${RESTARTED_SERVICES# }"
fi

SUMMARY=$(
  cat <<EOF
NTP 서버            : $NTP_SERVER
시스템 기본 설정     : $SYSTEM_TUNING_SUMMARY
root 비밀번호 상태   : $ROOT_PASSWORD_CHANGED
SSH 포트             : $NEW_SSH_PORT
비밀번호 정책        : $PASSWORD_POLICY_SUMMARY
생성된 관리자 계정    : $CREATED_USER
현재 일반 사용자      : ${NORMAL_USERS_LIST:-없음}
삭제된 불필요 계정    : ${DELETED_USERS:-없음}
비활성화된 서비스     : ${SERVICES_DISABLED:-없음}
재시작된 서비스       : ${RESTARTED_SERVICES:-없음}
백업 디렉터리         : $BACKUP_DIR
로그 파일             : $LOG_FILE
EOF
)

echo "$SUMMARY" > "$RESULT_FILE"
log_info "요약 정보를 $RESULT_FILE 파일에 기록했습니다."

echo
echo "=== 작업 요약 ==="
echo "$SUMMARY"
echo
echo "상세 로그는 $LOG_FILE 에서 확인할 수 있습니다."

if prompt_yes_no "지금 즉시 시스템을 재부팅하시겠습니까?"; then
  log_info "사용자가 즉시 재부팅을 선택했습니다."
  systemctl reboot
else
  log_info "사용자가 재부팅을 보류했습니다."
  echo "재부팅이 보류되었습니다. 필요한 경우 직접 재부팅을 진행하세요."
fi
