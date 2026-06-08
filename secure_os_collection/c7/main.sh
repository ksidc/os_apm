#!/bin/bash

# CentOS 7 hardening main script
set -u

NTP_SERVER=${NTP_SERVER:-"kr.pool.ntp.org"}
RSYSLOG_SERVER=${RSYSLOG_SERVER:-"1.224.163.4"}
MIN_PASSWORD_LENGTH=${MIN_PASSWORD_LENGTH:-8}
SSH_PORT=${SSH_PORT:-38371}
LOG_DIR="/usr/local/src/secure_os_collection/logs"
LOG_FILE="$LOG_DIR/go_$(date +%Y%m%d_%H%M%S).log"
RESULT_FILE="$LOG_DIR/result_$(date +%Y%m%d_%H%M%S).log"

SUMMARY=""
NEW_SSH_PORT="not changed (default 22)"
PASSWORD_POLICY_SUMMARY="not applied"
CREATED_USER="not created"
DELETED_USERS=""
SERVICES_DISABLED=""
RESTARTED_SERVICES=""

declare -A restarts_needed

mkdir -p "$LOG_DIR" && chmod 700 "$LOG_DIR" || {
    echo "[ERROR] Failed to create log directory: $LOG_DIR" >&2
    exit 1
}
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Log directory ready: $LOG_DIR" | tee -a "$LOG_FILE"

source /usr/local/src/secure_os_collection/c7/common.sh || {
    echo "[ERROR] Failed to load common.sh" >&2
    log_error "main" "Failed to load common.sh"
    exit 1
}

log_info "main start"
check_root

log_info "system.sh start"
source /usr/local/src/secure_os_collection/c7/system.sh || {
    log_error "main" "system.sh failed"
    exit 1
}
log_info "system.sh complete"

while true; do
    echo "Select firewall mode:"
    echo "  1) Configure iptables"
    echo "  2) Configure firewalld"
    echo "  3) Disable both firewall services"
    read -r -p "Choice (1/2/3): " FIREWALL_CHOICE < /dev/tty
    case "$FIREWALL_CHOICE" in
        1|2|3) break ;;
        *) echo "Invalid choice. Enter 1, 2, or 3." ;;
    esac
done

if [ "$FIREWALL_CHOICE" -eq 1 ]; then
    log_info "iptables.sh start"
    source /usr/local/src/secure_os_collection/c7/iptables.sh || {
        log_error "main" "iptables.sh failed"
        exit 1
    }
    log_info "iptables.sh complete"
elif [ "$FIREWALL_CHOICE" -eq 2 ]; then
    log_info "firewalld.sh start"
    source /usr/local/src/secure_os_collection/c7/firewalld.sh || {
        log_error "main" "firewalld.sh failed"
        exit 1
    }
    log_info "firewalld.sh complete"
else
    log_info "Disabling firewalld and iptables"
    systemctl stop firewalld iptables 2>/dev/null || true
    systemctl disable firewalld iptables 2>/dev/null || true
    systemctl mask firewalld iptables 2>/dev/null || true
    log_info "Firewall disable complete"
fi

log_info "accounts.sh start"
source /usr/local/src/secure_os_collection/c7/accounts.sh || {
    log_error "main" "accounts.sh failed"
    exit 1
}
log_info "accounts.sh complete"

log_info "services.sh start"
source /usr/local/src/secure_os_collection/c7/services.sh || {
    log_error "main" "services.sh failed"
    exit 1
}
log_info "services.sh complete"

log_info "yum update start"
yum -y update || {
    log_error "main" "yum update failed"
    exit 1
}
log_info "yum update complete"
SUMMARY+="Package update: applied\n"

log_info "로그 파일 권한 재설정 시작 (U-67)"
for f in /var/log/wtmp /var/log/lastlog; do
    [ -f "$f" ] && chmod 644 "$f"
done
for f in /var/log/btmp /var/log/btmp-*; do
    [ -f "$f" ] && chmod 600 "$f"
done
log_info "로그 파일 권한 재설정 완료"

# ────────────────────────────────────────────────────────────
# U-06: su 권한 재설정 (yum update 시 util-linux 업데이트로 4755/root:root 복원 방지)
# ────────────────────────────────────────────────────────────
log_info "su 권한 재설정 시작 (U-06)"
chown root:wheel /usr/bin/su && chmod 4750 /usr/bin/su \
    && log_info "/usr/bin/su 권한 4750 root:wheel 재설정 완료" \
    || log_error "main" "/usr/bin/su 권한 재설정 실패"

# ────────────────────────────────────────────────────────────
# U-37: cron.deny 권한 재설정 (yum update 시 cronie 업데이트로 644 복원 방지)
# ────────────────────────────────────────────────────────────
log_info "cron.deny 권한 재설정 시작 (U-37)"
if [ -f /etc/cron.deny ]; then
    chown root:root /etc/cron.deny
    chmod 640 /etc/cron.deny
    log_info "/etc/cron.deny 권한 640 재설정 완료"
fi

for svc in "${!restarts_needed[@]}"; do
    if [ "${restarts_needed[$svc]}" -eq 1 ]; then
        systemctl restart "$svc" && log_info "$svc restart complete" || {
            log_error "main" "$svc restart failed"
            exit 1
        }
        RESTARTED_SERVICES+="$svc "
    fi
done
log_info "Service restart phase complete"
SUMMARY+="Service restart: applied (targets: ${RESTARTED_SERVICES:-none})\n"

# ────────────────────────────────────────────────────────────
# U-25: world-writable 재처리 (서비스 재시작 이후 최종 정리)
# ────────────────────────────────────────────────────────────
log_info "world-writable 재처리 시작 (U-25)"
find / -xdev -type f -perm -0002 \
    ! -path '/proc/*' ! -path '/sys/*' ! -path '/dev/*' \
    -exec chmod o-w {} \; 2>/dev/null
log_info "world-writable 재처리 완료"

SUMMARY+="NTP: applied (server: $NTP_SERVER)\n"
SUMMARY+="Removed users: ${DELETED_USERS:-none}\n"
SUMMARY+="SSH port: $NEW_SSH_PORT\n"
SUMMARY+="Password policy: $PASSWORD_POLICY_SUMMARY\n"
SUMMARY+="Created user: $CREATED_USER\n"
SUMMARY+="Firewall: applied\n"
SUMMARY+="SELinux disable: applied\n"
SUMMARY+="sysctl/limits: applied\n"
SUMMARY+="Disabled services: ${SERVICES_DISABLED:-none}\n"

echo -e "$SUMMARY" > "$RESULT_FILE"
log_info "Summary written: $RESULT_FILE"

log_info "All tasks complete. Waiting for cleanup/reboot decision"

echo ""
echo "============================================================================"
echo " [WARN] If you choose 'Y', installation files under /usr/local/src/secure_os_collection"
echo "        will be deleted and the system will reboot immediately."
echo "============================================================================"

while true; do
    read -r -p "Delete installation files and reboot now? (Y/N): " confirm_finish < /dev/tty

    case "$confirm_finish" in
        [Yy]*)
            log_info "Cleanup and reboot requested by user"
            echo "  Removing installation files and temporary files..."

            SCRIPT_DIR="/usr/local/src/secure_os_collection"
            ZIP_FILE="/usr/local/src/secure_os_collection.zip"

            [ -d "$SCRIPT_DIR" ] && rm -rf "$SCRIPT_DIR"
            [ -f "$ZIP_FILE" ] && rm -f "$ZIP_FILE"
            rm -f /tmp/script_* /tmp/*.tmp 2>/dev/null || true

            echo "  Rebooting now..."
            sleep 1
            init 6
            break
            ;;
        [Nn]*)
            log_info "Cleanup and reboot canceled by user"
            echo "  Cleanup and reboot canceled."
            echo "  Logs and scripts remain on the system."
            exit 0
            ;;
        *)
            echo "Invalid input. Enter Y or N."
            ;;
    esac
done
