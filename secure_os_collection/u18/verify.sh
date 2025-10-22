#!/bin/bash
#
# Ubuntu 18.04 보안 하드닝 검증 도구.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-}"

usage() {
  cat <<'EOF'
사용 방법: ./verify.sh [옵션]
  -c, --config <파일>   외부 설정 파일을 지정하여 로드합니다.
  -h, --help            도움말을 표시합니다.

환경 변수 SSH_PORT, RSYSLOG_SERVER, BACKUP_DIR 로 기본값을 조정할 수 있습니다.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--config)
      CONFIG_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "알 수 없는 옵션: $1" >&2
      usage
      exit 1
      ;;
  esac
done

# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

SSH_PORT=${SSH_PORT:-38371}
RSYSLOG_SERVER=${RSYSLOG_SERVER:-"1.224.163.4"}
BACKUP_DIR=${BACKUP_DIR:-"/usr/local/src/scripts_org"}

load_external_config

declare -i PASS_COUNT=0
declare -i FAIL_COUNT=0
FAIL_DETAILS=()
CHECK_MESSAGE=""

print_section() {
  printf '\n[%s]\n' "$1"
}

record_pass() {
  ((PASS_COUNT++))
  printf '  [성공] %s\n' "$1"
}

record_fail() {
  ((FAIL_COUNT++))
  local message="${CHECK_MESSAGE:-조건을 충족하지 못했습니다.}"
  printf '  [실패] %s => %s\n' "$1" "$message"
  FAIL_DETAILS+=("$1 :: $message")
  CHECK_MESSAGE=""
}

run_check() {
  local description="$1"
  shift
  if "$@"; then
    record_pass "$description"
  else
    record_fail "$description"
  fi
}

check_history_timeout() {
  local profile="/etc/profile"
  if ! grep -Eq 'HISTTIMEFORMAT=.*%Y-%m-%d\[%H:%M:%S\]' "$profile"; then
    CHECK_MESSAGE="$profile 에 HISTTIMEFORMAT 설정이 없습니다."
    return 1
  fi
  if grep -Eq '(^|\s)TMOUT=600\b' "$profile"; then
    return 0
  fi
  CHECK_MESSAGE="$profile 에 TMOUT=600 설정이 없습니다."
  return 1
}

expect_stat() {
  local file="$1" expected_perm="$2" expected_owner="$3"
  if [[ ! -e "$file" ]]; then
    CHECK_MESSAGE="$file 파일이 존재하지 않습니다."
    return 1
  fi
  local actual
  actual="$(stat -c '%a %U:%G' "$file")" || return 1
  if [[ "$actual" == "$expected_perm $expected_owner" ]]; then
    return 0
  fi
  CHECK_MESSAGE="기대: $expected_perm $expected_owner / 실제: $actual"
  return 1
}

check_file_permissions() {
  expect_stat /etc/passwd 644 "root:root" || return 1
  expect_stat /etc/shadow 400 "root:root" || return 1
  expect_stat /etc/hosts 600 "root:root" || return 1
  expect_stat /bin/su 4750 "root:sudo" || return 1
  return 0
}

check_packages() {
  local pkgs=(
    lsof net-tools psmisc screen iftop smartmontools vim unzip wget
    iputils-ping lrzsz ufw rsyslog libpam-modules
  )
  local missing=()
  local pkg
  for pkg in "${pkgs[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      missing+=("$pkg")
    fi
  done
  if ((${#missing[@]} == 0)); then
    return 0
  fi
  CHECK_MESSAGE="누락된 패키지: ${missing[*]}"
  return 1
}

check_sysctl() {
  local sysctl_conf="/etc/sysctl.conf"
  local required=(
    'net.ipv6.conf.all.disable_ipv6 = 1'
    'net.ipv4.icmp_echo_ignore_broadcasts = 1'
    'net.ipv4.tcp_fin_timeout = 10'
    'net.core.somaxconn = 10240'
  )
  local entry
  for entry in "${required[@]}"; do
    if ! grep -Fxq "$entry" "$sysctl_conf"; then
      CHECK_MESSAGE="sysctl 설정 누락: $entry"
      return 1
    fi
  done
  return 0
}

check_limits() {
  local limits="/etc/security/limits.conf"
  local required=(
    '* soft nofile 61200'
    '* hard nofile 61200'
    '* soft nproc 61200'
    '* hard nproc 61200'
  )
  local entry
  for entry in "${required[@]}"; do
    if ! grep -Fxq "$entry" "$limits"; then
      CHECK_MESSAGE="limits.conf 설정 누락: $entry"
      return 1
    fi
  done
  return 0
}

check_pam_lockout() {
  if ! grep -Eq 'pam_tally2\.so.*onerr=fail.*deny=3' /etc/pam.d/common-auth; then
    CHECK_MESSAGE="common-auth 에 pam_tally2 deny=3 설정이 없습니다."
    return 1
  fi
  if ! grep -Eq '^\s*account\s+required\s+pam_tally2\.so' /etc/pam.d/common-account; then
    CHECK_MESSAGE="common-account 에 pam_tally2 account 규칙이 없습니다."
    return 1
  fi
  return 0
}

check_root_ssh() {
  if grep -Eq '^[[:space:]]*PermitRootLogin[[:space:]]+no' /etc/ssh/sshd_config; then
    return 0
  fi
  CHECK_MESSAGE="sshd_config 에 PermitRootLogin no 설정이 없습니다."
  return 1
}

check_ssh_port() {
  local current
  current="$(sshd -T 2>/dev/null | awk '/^port /{print $2; exit}' || echo '')"
  if [[ -z "$current" ]]; then
    CHECK_MESSAGE="sshd -T 명령으로 포트를 확인하지 못했습니다."
    return 1
  fi
  if [[ "$current" == "$SSH_PORT" ]]; then
    return 0
  fi
  CHECK_MESSAGE="현재 SSH 포트 $current (기대값: $SSH_PORT)"
  return 1
}

check_rsyslog() {
  if grep -q "*.* @$RSYSLOG_SERVER" /etc/rsyslog.conf; then
    return 0
  fi
  CHECK_MESSAGE="rsyslog 원격 전송 설정이 없습니다: $RSYSLOG_SERVER"
  return 1
}

check_services_disabled() {
  local services=(finger autofs nis ypbind ypserv tftp talk)
  local problematic=()
  local svc status
  for svc in "${services[@]}"; do
    if systemctl list-unit-files "${svc}.service" >/dev/null 2>&1; then
      status="$(systemctl is-enabled "${svc}.service" 2>/dev/null || echo 'unknown')"
      case "$status" in
        disabled|masked|static|indirect|unknown)
          continue
          ;;
        *)
          problematic+=("${svc}:${status}")
          ;;
      esac
    fi
  done
  if ((${#problematic[@]} == 0)); then
    return 0
  fi
  CHECK_MESSAGE="비활성화 필요 서비스: ${problematic[*]}"
  return 1
}

check_rhosts() {
  if [[ -f /etc/hosts.equiv ]]; then
    CHECK_MESSAGE="/etc/hosts.equiv 파일이 아직 존재합니다."
    return 1
  fi
  if find /root -maxdepth 1 -name '.rhosts' | grep -q '.'; then
    CHECK_MESSAGE="/root/.rhosts 파일이 아직 존재합니다."
    return 1
  fi
  return 0
}

check_logs_backups() {
  local log_dir="/usr/local/src/secure_os_collection/logs"
  if [[ ! -d "$log_dir" ]]; then
    CHECK_MESSAGE="로그 디렉터리가 없습니다: $log_dir"
    return 1
  fi
  if [[ ! -d "$BACKUP_DIR" ]]; then
    CHECK_MESSAGE="백업 디렉터리가 없습니다: $BACKUP_DIR"
    return 1
  fi
  return 0
}

print_section "시스템 설정"
run_check "셸 기록 타임스탬프 및 세션 타임아웃" check_history_timeout
run_check "핵심 파일 권한" check_file_permissions
run_check "기본 패키지 설치" check_packages
run_check "커널 파라미터(sysctl)" check_sysctl
run_check "리소스 제한 설정" check_limits

print_section "계정 및 인증"
run_check "PAM 잠금 정책(pam_tally2)" check_pam_lockout
run_check "root SSH 로그온 차단" check_root_ssh
run_check "SSH 포트 설정" check_ssh_port

print_section "서비스 및 네트워크"
run_check "rsyslog 원격 전송" check_rsyslog
run_check "불필요 서비스 비활성화" check_services_disabled
run_check "rhosts/hosts.equiv 제거" check_rhosts

print_section "로그와 백업"
run_check "로그/백업 디렉터리 존재" check_logs_backups

printf '\n=== 검증 요약 ===\n'
printf '성공: %d, 실패: %d\n' "$PASS_COUNT" "$FAIL_COUNT"

if ((FAIL_COUNT > 0)); then
  printf '\n실패 항목 상세:\n'
  for detail in "${FAIL_DETAILS[@]}"; do
    printf ' - %s\n' "$detail"
  done
  exit 1
fi

echo "모든 검증 항목을 통과했습니다."
