#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECTION_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$COLLECTION_DIR/logs"

CONFIG_FILE="/etc/hardening.conf"
NTP_SERVER=${NTP_SERVER:-"kr.pool.ntp.org"}
RSYSLOG_SERVER=${RSYSLOG_SERVER:-"1.224.163.4"}
MIN_PASSWORD_LENGTH=${MIN_PASSWORD_LENGTH:-8}
SSH_PORT=${SSH_PORT:-38371}
BACKUP_DIR=${BACKUP_DIR:-"/usr/local/src/scripts_org"}

if [ -f "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE" || {
    echo "[ERROR] Failed to load config file: $CONFIG_FILE" >&2
    exit 1
  }
fi

mkdir -p "$LOG_DIR" && chmod 700 "$LOG_DIR"
LOG_FILE="$LOG_DIR/c7_$(date +%Y%m%d_%H%M%S).log"
touch "$LOG_FILE" && chmod 600 "$LOG_FILE"

exec > >(tee -a "$LOG_FILE") 2>&1

source "$SCRIPT_DIR/common.sh"

log_info "[MAIN] CentOS 7 hardening start"

check_root

UserName=""
CREATED_USER="none"
NEW_SSH_PORT="$SSH_PORT"
declare -Ag restarts_needed
restarts_needed=()
restarted_services=()

source "$SCRIPT_DIR/system.sh"
source "$SCRIPT_DIR/accounts.sh"
source "$SCRIPT_DIR/iptables.sh"
source "$SCRIPT_DIR/services.sh"

if [ "${#restarts_needed[@]}" -gt 0 ]; then
  log_info "[MAIN] Restarting services flagged by modules"
  for svc in "${!restarts_needed[@]}"; do
    if [ "${restarts_needed[$svc]}" -eq 1 ]; then
      if systemctl restart "$svc"; then
        log_info "[MAIN] Restarted $svc"
        restarted_services+=("$svc")
      else
        log_error "main" "Failed to restart $svc"
      fi
    fi
  done
fi

echo
echo "=== CentOS 7 Hardening Summary ==="
echo "Log file           : $LOG_FILE"
echo "SSH port           : $NEW_SSH_PORT"
echo "Admin account      : ${CREATED_USER:-none}"
echo "Backup directory   : $BACKUP_DIR"
if [ "${#restarted_services[@]}" -gt 0 ]; then
  echo "Services restarted : ${restarted_services[*]}"
else
  echo "Services restarted : none"
fi

log_info "[MAIN] CentOS 7 hardening complete"
echo
read -r -p "지금 바로 서버를 재시작하시겠습니까? (Y/N): " reboot_now < /dev/tty
if [[ "$reboot_now" =~ ^[Yy]$ ]]; then
  log_info "[MAIN] 사용자가 재시작을 선택했습니다. 시스템을 재부팅합니다."
  systemctl reboot
else
  log_info "[MAIN] 사용자가 재시작을 보류했습니다."
  echo "변경 사항 적용을 위해 가급적 빠른 시일 내에 재부팅하시기 바랍니다."
fi