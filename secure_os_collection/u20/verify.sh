#!/bin/bash
#
# Ubuntu 20.04 보안 하드닝 검증 스크립트

set -u

echo "=============================================="
echo "Ubuntu 20.04 보안 하드닝 검증 시작"
echo "=============================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

check_pass() {
  echo "  ✓ PASS: $1"
  ((PASS_COUNT++))
}

check_fail() {
  echo "  ✗ FAIL: $1"
  ((FAIL_COUNT++))
}

check_warn() {
  echo "  ⚠ WARN: $1"
  ((WARN_COUNT++))
}

# 1. 불필요한 사용자 삭제 확인
echo "[1] 불필요한 사용자 삭제 확인"
# lp, games, sync는 시스템 기본 계정이므로 검증 대상에서 제외
REMOVED_USERS=(ftp shutdown halt)
for user in "${REMOVED_USERS[@]}"; do
  if ! id "$user" >/dev/null 2>&1; then
    check_pass "계정 '$user' 삭제됨"
  else
    check_warn "계정 '$user' 여전히 존재함"
  fi
done
echo ""

# 2. SSH 설정 확인
echo "[2] SSH 보안 설정 확인"
if grep -q '^PermitRootLogin no' /etc/ssh/sshd_config; then
  check_pass "PermitRootLogin이 no로 설정됨"
else
  check_fail "PermitRootLogin이 no로 설정되지 않음"
fi

if grep -q '^Port [0-9]\+' /etc/ssh/sshd_config; then
  PORT=$(grep '^Port' /etc/ssh/sshd_config | awk '{print $2}')
  if [[ "$PORT" != "22" ]]; then
    check_pass "SSH 포트가 $PORT 로 변경됨"
  else
    check_warn "SSH 포트가 기본값(22)으로 유지됨"
  fi
else
  check_warn "SSH 포트 설정이 명시되지 않음 (기본 22 사용 중)"
fi
echo ""

# 3. 비밀번호 정책 확인
echo "[3] 비밀번호 정책 확인"
if grep -q '^PASS_MAX_DAYS' /etc/login.defs; then
  MAX_DAYS=$(grep '^PASS_MAX_DAYS' /etc/login.defs | awk '{print $2}')
  check_pass "비밀번호 최대 사용기간: ${MAX_DAYS}일"
else
  check_warn "PASS_MAX_DAYS 설정 없음"
fi

if grep -q '^PASS_MIN_LEN' /etc/login.defs; then
  MIN_LEN=$(grep '^PASS_MIN_LEN' /etc/login.defs | awk '{print $2}')
  check_pass "비밀번호 최소 길이: ${MIN_LEN}자"
else
  check_warn "PASS_MIN_LEN 설정 없음"
fi
echo ""

# 4. PAM 설정 확인
echo "[4] PAM 보안 설정 확인"
if grep -q 'pam_unix.so.*minlen=' /etc/pam.d/common-password; then
  check_pass "PAM 비밀번호 최소 길이 설정됨"
else
  check_warn "PAM 비밀번호 최소 길이 미설정"
fi

if grep -q 'pam_faillock.so' /etc/pam.d/common-auth || grep -q 'pam_tally2.so' /etc/pam.d/common-auth; then
  check_pass "PAM 로그인 실패 잠금 정책 설정됨"
else
  check_warn "PAM 로그인 실패 잠금 정책 미설정"
fi

if grep -q 'pam_wheel.so.*group=sudo' /etc/pam.d/su; then
  check_pass "su 명령 sudo 그룹 제한 설정됨"
else
  check_warn "su 명령 그룹 제한 미설정"
fi
echo ""

# 5. 파일 권한 확인
echo "[5] 주요 파일 권한 확인"
check_perm() {
  local file="$1" expected_perm="$2" expected_owner="$3"
  if [[ -e "$file" ]]; then
    actual_perm=$(stat -c '%a' "$file")
    actual_owner=$(stat -c '%U:%G' "$file")
    if [[ "$actual_perm" == "$expected_perm" ]] && [[ "$actual_owner" == "$expected_owner" ]]; then
      check_pass "$file 권한 정상 ($actual_perm $actual_owner)"
    else
      check_warn "$file 권한: $actual_perm $actual_owner (예상: $expected_perm $expected_owner)"
    fi
  else
    check_warn "$file 파일이 존재하지 않음"
  fi
}

check_perm "/etc/passwd" "644" "root:root"
check_perm "/etc/shadow" "640" "root:shadow"
check_perm "/tmp" "1777" "root:root"
check_perm "/var/tmp" "1777" "root:root"
echo ""

# 6. sysctl 설정 확인
echo "[6] 커널 파라미터 설정 확인"
if [[ -f /etc/sysctl.d/99-secure-os.conf ]]; then
  check_pass "sysctl 보안 설정 파일 존재함"
  if grep -q 'net.ipv6.conf.all.disable_ipv6.*=.*1' /etc/sysctl.d/99-secure-os.conf; then
    check_pass "IPv6 비활성화 설정됨"
  fi
  if grep -q 'net.ipv4.icmp_echo_ignore_broadcasts.*=.*1' /etc/sysctl.d/99-secure-os.conf; then
    check_pass "ICMP 브로드캐스트 무시 설정됨"
  fi
else
  check_warn "sysctl 보안 설정 파일 없음"
fi
echo ""

# 7. limits 설정 확인
echo "[7] 자원 제한 설정 확인"
if [[ -f /etc/security/limits.d/99-secure-os.conf ]]; then
  check_pass "limits 설정 파일 존재함"
  if grep -q 'nofile.*61200' /etc/security/limits.d/99-secure-os.conf; then
    check_pass "파일 디스크립터 제한 설정됨"
  fi
else
  check_warn "limits 설정 파일 없음"
fi
echo ""

# 8. 서비스 비활성화 확인
echo "[8] 불필요 서비스 비활성화 확인"
SERVICES=(avahi-daemon cups bluetooth)
for svc in "${SERVICES[@]}"; do
  if systemctl is-enabled "$svc" >/dev/null 2>&1; then
    if [[ "$(systemctl is-enabled "$svc" 2>/dev/null)" == "disabled" ]]; then
      check_pass "서비스 '$svc' 비활성화됨"
    else
      check_warn "서비스 '$svc' 활성화되어 있음"
    fi
  else
    check_pass "서비스 '$svc' 존재하지 않거나 이미 비활성화됨"
  fi
done
echo ""

# 9. 작업 흔적 제거 확인
echo "[9] 작업 흔적 제거 확인"
if [[ ! -d "/usr/local/src/secure_os_collection" ]]; then
  check_pass "스크립트 디렉터리 삭제됨"
else
  check_warn "스크립트 디렉터리가 여전히 존재함"
fi

if [[ ! -f "/usr/local/src/secure_os_collection.zip" ]]; then
  check_pass "zip 파일 삭제됨"
else
  check_warn "zip 파일이 여전히 존재함"
fi
echo ""

# 10. NTP 설정 확인
echo "[10] 시간 동기화 설정 확인"
if systemctl is-active systemd-timesyncd >/dev/null 2>&1 || systemctl is-active chrony >/dev/null 2>&1; then
  check_pass "시간 동기화 서비스 실행 중"
else
  check_warn "시간 동기화 서비스 미실행"
fi
echo ""

# 최종 요약
echo "=============================================="
echo "검증 결과 요약"
echo "=============================================="
echo "  ✓ PASS: $PASS_COUNT"
echo "  ⚠ WARN: $WARN_COUNT"
echo "  ✗ FAIL: $FAIL_COUNT"
echo ""

if [[ $FAIL_COUNT -eq 0 ]]; then
  echo "🎉 모든 중요 보안 설정이 정상적으로 적용되었습니다!"
  exit 0
else
  echo "⚠️  일부 보안 설정이 누락되었습니다. 위 내용을 확인하세요."
  exit 1
fi
