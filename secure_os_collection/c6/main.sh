#!/bin/bash

# CentOS 6.10 전용 1차 보안조치 실행 순서와 운영 고정값을 관리한다.
set -u

readonly NTP_SERVER="kr.pool.ntp.org"
readonly RSYSLOG_SERVER="1.224.163.4"
MIN_PASSWORD_LENGTH="${MIN_PASSWORD_LENGTH:-8}"
PASSWORD_MIN_LENGTH="$MIN_PASSWORD_LENGTH"
NEW_SSH_PORT="${SSH_PORT:-38371}"

SUMMARY=""
PASSWORD_POLICY_SUMMARY="not applied"
CREATED_USER="not created"
DELETED_USERS=""
SERVICES_DISABLED=""
RESTARTS_NEEDED=""
RESTARTED_SERVICES=""
FIREWALL_SUMMARY="not selected"
ADMIN_USER=""

BASE_DIR="/usr/local/src/secure_os_collection"
C6_DIR="$BASE_DIR/c6"

source "$C6_DIR/common.sh" || {
    echo "ERROR: c6/common.sh 로드 실패" >&2
    exit 1
}

check_root

# 다른 OS에 C6 전용 조치가 실행되지 않도록 6.10 릴리스를 먼저 고정 검증한다.
if ! grep -q '^CentOS release 6\.10' /etc/centos-release 2>/dev/null; then
    echo "ERROR: 이 스크립트는 CentOS 6.10 전용입니다." >&2
    exit 1
fi

# 저장소, 강제 업데이트, 패키지, SSH 포트와 시스템 기본 정책을 적용한다.
source "$C6_DIR/system.sh" || {
    echo "ERROR: c6/system.sh 실행 실패" >&2
    exit 1
}

# 관리자 일반 계정을 확보한 뒤 root SSH와 C6 PAM 정책을 적용한다.
source "$C6_DIR/accounts.sh" || {
    echo "ERROR: c6/accounts.sh 실행 실패" >&2
    exit 1
}

# 불필요한 SysV/xinetd 서비스와 기본 postfix 노출을 제한한다.
source "$C6_DIR/services.sh" || {
    echo "ERROR: c6/services.sh 실행 실패" >&2
    exit 1
}

# SSH 포트 변경 전에 새 포트를 허용하도록 iptables 적용 여부를 먼저 결정한다.
while true; do
    echo "방화벽 방식을 선택하세요."
    echo "  1) iptables 고정 정책 적용"
    echo "  2) iptables 비활성화"
    read -r -p "선택 (1/2): " FIREWALL_CHOICE < /dev/tty
    case "$FIREWALL_CHOICE" in
        1|2) break ;;
        *) echo "1 또는 2를 입력하세요." ;;
    esac
done

if [ "$FIREWALL_CHOICE" -eq 1 ]; then
    source "$C6_DIR/iptables.sh" || {
        echo "ERROR: c6/iptables.sh 실행 실패" >&2
        exit 1
    }
    FIREWALL_SUMMARY="iptables applied"
else
    service iptables stop >/dev/null 2>&1 || true
    chkconfig iptables off || {
        echo "ERROR: iptables 부팅 비활성화 실패" >&2
        exit 1
    }
    FIREWALL_SUMMARY="iptables disabled"
fi

# 방화벽에 새 SSH 포트가 반영된 뒤 변경 대상 서비스만 한 번씩 재시작한다.
for service_name in $RESTARTS_NEEDED; do
    [ -x "/etc/init.d/$service_name" ] || {
        echo "ERROR: 재시작 대상 서비스가 없습니다: $service_name" >&2
        exit 1
    }
    service "$service_name" restart || {
        echo "ERROR: 서비스 재시작 실패: $service_name" >&2
        exit 1
    }
    RESTARTED_SERVICES="${RESTARTED_SERVICES}${service_name} "
done

# 서비스 재시작 후 변경될 수 있는 핵심 권한을 마지막에 다시 고정한다.
configure_core_file_permissions || exit 1
configure_command_permissions || exit 1
configure_scheduler_permissions || exit 1
configure_login_log_permissions || exit 1
fix_world_writable || exit 1

SUMMARY="${SUMMARY}NTP: ntpd ($NTP_SERVER)\n"
SUMMARY="${SUMMARY}Removed users: ${DELETED_USERS:-none}\n"
SUMMARY="${SUMMARY}SSH port: $NEW_SSH_PORT\n"
SUMMARY="${SUMMARY}Password policy: $PASSWORD_POLICY_SUMMARY\n"
SUMMARY="${SUMMARY}Admin account: $CREATED_USER\n"
SUMMARY="${SUMMARY}Restarted services: ${RESTARTED_SERVICES:-none}\n"
SUMMARY="${SUMMARY}Disabled services: ${SERVICES_DISABLED:-none}\n"
SUMMARY="${SUMMARY}Firewall: $FIREWALL_SUMMARY\n"
SUMMARY="${SUMMARY}SELinux: disabled\n"
SUMMARY="${SUMMARY}sysctl/limits/rsyslog/Snoopy: applied\n"

echo -e "\n=== CentOS 6.10 조치 결과 ===\n$SUMMARY"
echo "검증은 업데이트 커널 적용을 위해 재부팅한 뒤 수행하십시오."
echo "검증 명령: sudo bash $C6_DIR/verify.sh"
echo
echo "설치 파일을 삭제하면 verify.sh도 함께 삭제됩니다. 먼저 검증하는 것을 권장합니다."

# 사용자가 명시적으로 동의한 경우에만 설치 파일을 삭제하고 재부팅한다.
while true; do
    read -r -p "설치 파일을 삭제하고 지금 재부팅하시겠습니까? (Y/N): " confirm_finish < /dev/tty
    case "$confirm_finish" in
        [Yy])
            cp "$C6_DIR/verify.sh" /root/verify_c6.sh || {
                echo "ERROR: 재부팅 후 검증기 보존 실패" >&2
                exit 1
            }
            chmod 700 /root/verify_c6.sh
            [ -d "$BASE_DIR" ] && rm -rf "$BASE_DIR"
            [ -f "${BASE_DIR}.zip" ] && rm -f "${BASE_DIR}.zip"
            echo "재부팅 후 검증 명령: sudo bash /root/verify_c6.sh"
            echo "재부팅합니다."
            sleep 1
            init 6
            break
            ;;
        [Nn])
            echo "설치 파일 삭제와 재부팅을 취소했습니다."
            exit 0
            ;;
        *) echo "Y 또는 N을 입력하세요." ;;
    esac
done
