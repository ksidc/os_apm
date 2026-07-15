#!/bin/bash

# Rocky Linux 10 보안 강화 메인 스크립트
# 실행: go.sh에서 호출됨

set -u

# 환경 설정 (고정값)
NTP_SERVER=${NTP_SERVER:-"kr.pool.ntp.org"}
readonly RSYSLOG_SERVER="1.224.163.4"
MIN_PASSWORD_LENGTH=${MIN_PASSWORD_LENGTH:-8}
SSH_PORT=${SSH_PORT:-38371}

# 요약 변수 초기화
SUMMARY=""
NEW_SSH_PORT="미변경 (기본 22)"
PASSWORD_POLICY_SUMMARY="미적용"
CREATED_USER="미생성"
DELETED_USERS=""
SERVICES_DISABLED=""
RESTARTED_SERVICES=""

declare -A restarts_needed

# 공통 권한/파일 설정 helper를 로드하고 root 실행 여부를 확인한다.
source /usr/local/src/secure_os_collection/r10/common.sh || {
    echo "[ERROR] common.sh 로드 실패" >&2
    exit 1
}

check_root

# 필수 패키지, NTP, SSH 포트, sysctl, 감사 설정 등 시스템 기본값을 먼저 적용한다.
source /usr/local/src/secure_os_collection/r10/system.sh || {
    echo "ERROR: system.sh 실행 실패" >&2
    exit 1
}

# 운영 환경에 맞는 방화벽 방식을 선택한다.
while true; do
    echo "방화벽 시스템을 선택하세요:"
    echo "  1) iptables 설정"
    echo "  2) firewalld 설정"
    echo "  3) 방화벽 미사용 (모두 비활성화)"
    read -r -p "선택 (1/2/3): " FIREWALL_CHOICE < /dev/tty
    case "$FIREWALL_CHOICE" in
        1|2|3) break ;;
        *) echo "잘못된 입력입니다. 1, 2, 3 중 하나를 선택해주세요." ;;
    esac
done

# 선택한 방화벽 방식만 적용하고, 미사용 선택 시 양쪽 방화벽 서비스를 모두 비활성화한다.
if [ "$FIREWALL_CHOICE" -eq 1 ]; then
    source /usr/local/src/secure_os_collection/r10/iptables.sh || {
        echo "ERROR: iptables.sh 실행 실패" >&2
        exit 1
    }
elif [ "$FIREWALL_CHOICE" -eq 2 ]; then
    source /usr/local/src/secure_os_collection/r10/firewalld.sh || {
        echo "ERROR: firewalld.sh 실행 실패" >&2
        exit 1
    }
else
    systemctl stop firewalld iptables 2>/dev/null || true
    systemctl disable firewalld iptables 2>/dev/null || true
    systemctl mask firewalld iptables 2>/dev/null || true
fi

# 계정 정리, root 비밀번호 변경, 운영 계정 준비, root SSH 차단, PAM 정책을 적용한다.
source /usr/local/src/secure_os_collection/r10/accounts.sh || {
    echo "ERROR: accounts.sh 실행 실패" >&2
    exit 1
}

# 불필요하거나 취약한 레거시 서비스와 접근 제어 파일 권한을 정리한다.
source /usr/local/src/secure_os_collection/r10/services.sh || {
    echo "ERROR: services.sh 실행 실패" >&2
    exit 1
}

# 선택 시 APM 구성요소를 설치한다. 미선택이면 기본 보안 강화만 진행한다.
source /usr/local/src/secure_os_collection/r10/apm.sh || {
    echo "ERROR: apm.sh 실행 실패" >&2
    exit 1
}

# dnf update는 전체 패키지 업데이트이므로 커널/OS 마이너 고정이 필요하면 실행하지 않는다.
echo "Y 선택 시 dnf update 전체 업데이트를 실행합니다."
echo "활성 저장소가 더 높은 Rocky 10.x 기준이면 커널과 OS 마이너 패키지도 그 기준으로 업데이트됩니다."
echo "특정 Rocky 10.x 버전을 고정해야 하면 N을 선택하세요."
if prompt_yes_no "dnf update를 진행하시겠습니까?"; then
    dnf -y update || {
        echo "ERROR: dnf update 실패" >&2
        exit 1
    }
    SUMMARY+="패키지 업데이트: 적용됨\n"
else
    SUMMARY+="패키지 업데이트: 건너뜀 (사용자 선택)\n"
fi

# 업데이트 후 패키지 기본값으로 되돌아갈 수 있는 wtmp/btmp 권한을 다시 고정한다.
for f in /var/log/wtmp /var/log/lastlog; do
    [ -f "$f" ] && chmod 644 "$f"
done
for f in /var/log/btmp /var/log/btmp-*; do
    [ -f "$f" ] && chmod 600 "$f"
done

# dnf update 이후 setup/systemd 패키지가 복구할 수 있는 파일 권한을 다시 고정한다.
chown root:root /etc/hosts 2>/dev/null || true
chmod 600 /etc/hosts 2>/dev/null || true
if [ -f /etc/rc.d/rc.local ]; then
    chmod +x /etc/rc.d/rc.local 2>/dev/null || true
fi

# U-06: dnf update 이후 util-linux가 su 권한을 복구할 수 있어 최종 단계에서 다시 제한한다.
chown root:wheel /usr/bin/su && chmod 4750 /usr/bin/su || {
    echo "ERROR: /usr/bin/su 권한 재설정 실패" >&2
    exit 1
}

# U-37: dnf update 이후 cronie가 cron.deny 권한을 복구할 수 있어 최종 단계에서 다시 제한한다.
if [ -f /etc/cron.deny ]; then
    chown root:root /etc/cron.deny
    chmod 640 /etc/cron.deny
fi

# 하위 스크립트에서 재시작 대상으로 표시한 서비스만 마지막에 한 번 재시작한다.
set +u
for svc in "${!restarts_needed[@]}"; do
    if [ "${restarts_needed[$svc]}" -eq 1 ]; then
        set -u
        systemctl restart "$svc" || {
            echo "ERROR: $svc 재시작 실패" >&2
            exit 1
        }
        RESTARTED_SERVICES+="$svc "
        set +u
    fi
done
set -u
SUMMARY+="서비스 재시작: 적용됨 (대상: ${RESTARTED_SERVICES:-없음})\n"

# U-25: 서비스 재시작 또는 패키지 업데이트 후 다시 생긴 world-writable 파일을 최종 정리한다.
find / -xdev -type f -perm -0002 \
    ! -path '/proc/*' ! -path '/sys/*' ! -path '/dev/*' \
    -exec chmod o-w {} \; 2>/dev/null

# 파일 로그를 만들지 않고 화면에만 실행 요약을 출력한다.
SUMMARY+="NTP 설정: 적용됨 (서버: $NTP_SERVER)\n"
SUMMARY+="불필요 사용자 삭제: 적용됨 (대상: ${DELETED_USERS:-없음})\n"
SUMMARY+="SSH 포트 변경: $NEW_SSH_PORT\n"
SUMMARY+="패스워드 정책: $PASSWORD_POLICY_SUMMARY\n"
SUMMARY+="새 계정 생성: $CREATED_USER\n"
SUMMARY+="방화벽 설정: 적용됨\n"
SUMMARY+="SELinux 비활성화: 적용됨\n"
SUMMARY+="sysctl/limits 튜닝: 적용됨\n"
SUMMARY+="서비스 비활성화: 적용됨 (대상: ${SERVICES_DISABLED:-없음})\n"

echo -e "\n=== 실행 결과 요약 ===\n$SUMMARY"

echo ""
echo "============================================================================"
echo " [경고] 'Y' 선택 시 설치 파일(/usr/local/src/secure_os_collection)이 삭제되고"
echo "        즉시 시스템이 재부팅됩니다."
echo "============================================================================"

# 사용자가 명시적으로 동의한 경우에만 설치 파일 삭제와 재부팅을 수행한다.
while true; do
    read -r -p "설치 파일을 삭제하고 시스템을 재부팅하시겠습니까? (Y/N): " confirm_finish < /dev/tty

    case "$confirm_finish" in
        [Yy]*)
            echo "  → 설치 파일 삭제 중..."

            SCRIPT_DIR="/usr/local/src/secure_os_collection"
            ZIP_FILE="/usr/local/src/secure_os_collection.zip"

            [ -d "$SCRIPT_DIR" ] && rm -rf "$SCRIPT_DIR"
            [ -f "$ZIP_FILE" ] && rm -f "$ZIP_FILE"

            rm -f /tmp/script_* /tmp/*.tmp 2>/dev/null || true

            echo "  → 시스템을 재부팅합니다..."
            sleep 1
            init 6
            break
            ;;
        [Nn]*)
            echo "  → 파일 삭제 및 재부팅을 취소했습니다."
            echo "  → 스크립트가 유지됩니다."
            exit 0
            ;;
        *)
            echo "잘못된 입력입니다. 'Y' 또는 'N'을 입력해주세요."
            ;;
    esac
done
