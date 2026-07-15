#!/bin/bash

# CentOS 7 main script
set -u

NTP_SERVER=${NTP_SERVER:-"kr.pool.ntp.org"}
readonly RSYSLOG_SERVER="1.224.163.4"
MIN_PASSWORD_LENGTH=${MIN_PASSWORD_LENGTH:-8}
SSH_PORT=${SSH_PORT:-38371}

SUMMARY=""
NEW_SSH_PORT="not changed (default 22)"
PASSWORD_POLICY_SUMMARY="not applied"
CREATED_USER="not created"
DELETED_USERS=""
SERVICES_DISABLED=""
RESTARTED_SERVICES=""

declare -A restarts_needed

# 공통 권한/파일 설정 helper를 로드하고 root 실행 여부를 확인한다.
source /usr/local/src/secure_os_collection/c7/common.sh || {
    echo "[ERROR] Failed to load common.sh" >&2
    exit 1
}

check_root

# CentOS 7 저장소, 필수 패키지, NTP, SSH 포트, sysctl 등 시스템 기본값을 먼저 적용한다.
source /usr/local/src/secure_os_collection/c7/system.sh || {
    echo "ERROR: system.sh failed" >&2
    exit 1
}

# 운영 환경에 맞는 방화벽 방식을 선택한다.
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

# 선택한 방화벽 방식만 적용하고, 미사용 선택 시 양쪽 방화벽 서비스를 모두 비활성화한다.
if [ "$FIREWALL_CHOICE" -eq 1 ]; then
    source /usr/local/src/secure_os_collection/c7/iptables.sh || {
        echo "ERROR: iptables.sh failed" >&2
        exit 1
    }
elif [ "$FIREWALL_CHOICE" -eq 2 ]; then
    source /usr/local/src/secure_os_collection/c7/firewalld.sh || {
        echo "ERROR: firewalld.sh failed" >&2
        exit 1
    }
else
    systemctl stop firewalld iptables 2>/dev/null || true
    systemctl disable firewalld iptables 2>/dev/null || true
    systemctl mask firewalld iptables 2>/dev/null || true
fi

# 계정 정리, root 비밀번호 변경, 운영 계정 준비, root SSH 차단, PAM 정책을 적용한다.
source /usr/local/src/secure_os_collection/c7/accounts.sh || {
    echo "ERROR: accounts.sh failed" >&2
    exit 1
}

# 불필요하거나 취약한 레거시 서비스와 접근 제어 파일 권한을 정리한다.
source /usr/local/src/secure_os_collection/c7/services.sh || {
    echo "ERROR: services.sh failed" >&2
    exit 1
}

# CentOS 7 Vault 저장소 기준으로 패키지를 최신 상태로 맞춘다.
yum -y update || {
    echo "ERROR: yum update failed" >&2
    exit 1
}
SUMMARY+="Package update: applied\n"

# 업데이트 후 패키지 기본값으로 되돌아갈 수 있는 로그 파일 권한을 다시 고정한다.
for f in /var/log/wtmp /var/log/lastlog; do
    [ -f "$f" ] && chmod 644 "$f"
done
for f in /var/log/btmp /var/log/btmp-*; do
    [ -f "$f" ] && chmod 600 "$f"
done

# ────────────────────────────────────────────────────────────
# U-06: su 권한 재설정 (yum update 시 util-linux 업데이트로 4755/root:root 복원 방지)
# ────────────────────────────────────────────────────────────
# yum update 이후 util-linux가 su 권한을 복구할 수 있어 최종 단계에서 다시 제한한다.
chown root:wheel /usr/bin/su && chmod 4750 /usr/bin/su || {
    echo "ERROR: /usr/bin/su 권한 재설정 실패" >&2
    exit 1
}

# ────────────────────────────────────────────────────────────
# U-37: cron.deny 권한 재설정 (yum update 시 cronie 업데이트로 644 복원 방지)
# ────────────────────────────────────────────────────────────
# yum update 이후 cronie가 cron.deny 권한을 복구할 수 있어 최종 단계에서 다시 제한한다.
if [ -f /etc/cron.deny ]; then
    chown root:root /etc/cron.deny
    chmod 640 /etc/cron.deny
fi

# 하위 스크립트에서 재시작 대상으로 표시한 서비스만 마지막에 한 번 재시작한다.
for svc in "${!restarts_needed[@]}"; do
    if [ "${restarts_needed[$svc]}" -eq 1 ]; then
        systemctl restart "$svc" || {
            echo "ERROR: $svc restart failed" >&2
            exit 1
        }
        RESTARTED_SERVICES+="$svc "
    fi
done
SUMMARY+="Service restart: applied (targets: ${RESTARTED_SERVICES:-none})\n"

# ────────────────────────────────────────────────────────────
# U-25: world-writable 재처리 (서비스 재시작 이후 최종 정리)
# ────────────────────────────────────────────────────────────
# 서비스 재시작 또는 패키지 업데이트 후 다시 생긴 world-writable 파일을 최종 정리한다.
find / -xdev -type f -perm -0002 \
    ! -path '/proc/*' ! -path '/sys/*' ! -path '/dev/*' \
    -exec chmod o-w {} \; 2>/dev/null

# 파일 로그를 만들지 않고 화면에만 실행 요약을 출력한다.
SUMMARY+="NTP: applied (server: $NTP_SERVER)\n"
SUMMARY+="Removed users: ${DELETED_USERS:-none}\n"
SUMMARY+="SSH port: $NEW_SSH_PORT\n"
SUMMARY+="Password policy: $PASSWORD_POLICY_SUMMARY\n"
SUMMARY+="Created user: $CREATED_USER\n"
SUMMARY+="Firewall: applied\n"
SUMMARY+="SELinux disable: applied\n"
SUMMARY+="sysctl/limits: applied\n"
SUMMARY+="Disabled services: ${SERVICES_DISABLED:-none}\n"

echo -e "\n=== 실행 결과 요약 ===\n$SUMMARY"

echo ""
echo "============================================================================"
echo " [WARN] If you choose 'Y', installation files under /usr/local/src/secure_os_collection"
echo "        will be deleted and the system will reboot immediately."
echo "============================================================================"

# 사용자가 명시적으로 동의한 경우에만 설치 파일 삭제와 재부팅을 수행한다.
while true; do
    read -r -p "Delete installation files and reboot now? (Y/N): " confirm_finish < /dev/tty

    case "$confirm_finish" in
        [Yy]*)
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
            echo "  Cleanup and reboot canceled."
            echo "  Scripts remain on the system."
            exit 0
            ;;
        *)
            echo "Invalid input. Enter Y or N."
            ;;
    esac
done
