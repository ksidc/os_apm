#!/bin/bash
#
# Ubuntu 22.04 하드닝 메인 스크립트

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NTP_SERVER=${NTP_SERVER:-"pool.ntp.org"}
readonly RSYSLOG_SERVER="1.224.163.4"
MIN_PASSWORD_LENGTH=${MIN_PASSWORD_LENGTH:-8}
SSH_PORT=${SSH_PORT:-38371}

source "${SCRIPT_DIR}/common.sh" || {
  echo "[ERROR] common.sh 로드 실패" >&2
  exit 1
}

declare -Ag restarts_needed=()

SUMMARY=""
NEW_SSH_PORT="미변경 (기본 22)"
PASSWORD_POLICY_SUMMARY="미적용"
CREATED_USER="미생성"
DELETED_USERS=""
SERVICES_DISABLED=""
RESTARTED_SERVICES=""

check_root

# 시스템 기본 설정, 계정 정책, 서비스 정리를 순서대로 적용한다.
source "${SCRIPT_DIR}/system.sh" || { echo "ERROR: system.sh 실행 실패" >&2; exit 1; }
source "${SCRIPT_DIR}/accounts.sh" || { echo "ERROR: accounts.sh 실행 실패" >&2; exit 1; }
source "${SCRIPT_DIR}/services.sh" || { echo "ERROR: services.sh 실행 실패" >&2; exit 1; }

# 하위 스크립트에서 재시작 대상으로 표시한 서비스만 마지막에 한 번 재시작한다.
set +u
for svc in "${!restarts_needed[@]}"; do
  if systemctl restart "$svc" >/dev/null 2>&1; then
    RESTARTED_SERVICES+=" $svc"
  else
    echo "ERROR: 서비스 재시작 실패: $svc" >&2
    exit 1
  fi
done
set -u

# Ubuntu 기본 tmpfiles 권한을 보안 기준으로 보정하고 서비스 재시작 후 최종 적용한다.
cat > /etc/tmpfiles.d/99-hardening-perms.conf <<'EOF'
z /var/log/wtmp 0644 root utmp -
z /var/log/btmp 0600 root utmp -
EOF
systemd-tmpfiles --create /etc/tmpfiles.d/99-hardening-perms.conf >/dev/null 2>&1 || true
for f in /var/log/wtmp /var/log/lastlog; do
  [[ -f "$f" ]] && chmod 644 "$f"
done
for f in /var/log/btmp /var/log/btmp-*; do
  [[ -f "$f" ]] && chmod 600 "$f"
done

# 서비스 재시작 이후 다시 생긴 world-writable 파일을 최종 정리한다.
find / -xdev -type f -perm -0002 \
  ! -path '/proc/*' ! -path '/sys/*' ! -path '/dev/*' \
  -exec chmod o-w {} \; 2>/dev/null

# 파일 로그를 만들지 않고 화면에만 실행 요약을 출력한다.
SUMMARY+="NTP 설정: 적용됨 (서버: $NTP_SERVER)\n"
SUMMARY+="불필요 사용자 삭제: 적용됨 (대상: ${DELETED_USERS:-없음})\n"
SUMMARY+="SSH 포트 변경: $NEW_SSH_PORT\n"
SUMMARY+="패스워드 정책: $PASSWORD_POLICY_SUMMARY\n"
SUMMARY+="새 계정 생성: $CREATED_USER\n"
SUMMARY+="서비스 비활성화: 적용됨 (대상: ${SERVICES_DISABLED:-없음})\n"
SUMMARY+="서비스 재시작: 적용됨 (대상: ${RESTARTED_SERVICES:-없음})\n"

echo -e "\n=== 실행 결과 요약 ===\n$SUMMARY"

echo ""
echo "============================================================================"
echo " [경고] 'Y' 선택 시 설치 파일(/usr/local/src/secure_os_collection)이 삭제되고"
echo "        즉시 시스템이 재부팅됩니다."
echo "============================================================================"

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
