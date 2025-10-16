#!/bin/bash

set -euo pipefail

BASE_DIR="/usr/local/src/secure_os_collection/r9"
LOG_DIR="/usr/local/src/secure_os_collection/logs"
mkdir -p "$LOG_DIR" && chmod 700 "$LOG_DIR"

export LOG_FILE="$LOG_DIR/go_$(date +%Y%m%d_%H%M%S).log"
RESULT_FILE="$LOG_DIR/result_$(date +%Y%m%d_%H%M%S).log"

source "$BASE_DIR/common.sh"

check_root
log_info "main 시작"

log_info "system.sh 실행"
source "$BASE_DIR/system.sh"

log_info "accounts.sh 실행"
source "$BASE_DIR/accounts.sh"

log_info "services.sh 실행"
source "$BASE_DIR/services.sh"

# log_info "dnf update 시작"
# dnf -y update || log_error "main" "dnf update 실패(무시되지 않음)"
# log_info "dnf update 완료"


log_info "자동 리부팅 수행"
if command -v systemctl >/dev/null 2>&1; then
  systemctl reboot
else
  /sbin/shutdown -r now || /usr/sbin/reboot
fi

exit 0
