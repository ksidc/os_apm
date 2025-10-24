#!/bin/bash
# Rocky Linux 10 보안 검증 스크립트 (한국어 출력)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-}"

usage() {
  cat <<'EOF'
사용법: ./verify.sh [옵션]
  -c, --config <파일>   외부 설정 파일 로드
  -h, --help            도움말 출력

환경 변수:
  SSH_PORT, RSYSLOG_SERVER, BACKUP_DIR
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

if [[ "$EUID" -ne 0 ]]; then
  echo "오류: root 권한으로 실행해야 합니다." >&2
  exit 1
fi

SSH_PORT=${SSH_PORT:-38371}
RSYSLOG_SERVER=${RSYSLOG_SERVER:-"1.224.163.4"}
BACKUP_DIR=${BACKUP_DIR:-"/usr/local/src/scripts_org"}

load_external_config() {
  local candidate
  if [[ -n "$CONFIG_FILE" && -r "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    return
  fi
  candidate="${SCRIPT_DIR}/secure_rocky_10.conf"
  if [[ -r "$candidate" ]]; then
    source "$candidate"
  fi
}

load_external_config

declare -i PASS_COUNT=0
declare -i FAIL_COUNT=0
FAIL_DETAILS=()
CHECK_MESSAGE=""

trim() {
  local value="$1"
  value="${value#${value%%[![:space:]]*}}"
  value="${value%${value##*[![:space:]]}}"
  printf '%s' "$value"
}

normalize_spaces() {
  local value="$1"
  value="$(echo "$value" | tr -s '[:space:]' ' ')"
  value="${value# }"
  value="${value% }"
  printf '%s' "$value"
}

unit_enabled_status() {
  local unit="$1" output
  if output=$(systemctl is-enabled "$unit" 2>/dev/null); then
    trim "$output"
  else
    echo "unknown"
  fi
}

unit_active_status() {
  local unit="$1" output
  if output=$(systemctl is-active "$unit" 2>/dev/null); then
    trim "$output"
  else
    echo "unknown"
  fi
}

print_section() {
  printf '\n[%s]\n' "$1"
}

record_pass() {
  ((PASS_COUNT++))
  printf '  [성공] %s\n' "$1"
}

record_fail() {
  ((FAIL_COUNT++))
  local message="${CHECK_MESSAGE:-원인 미확인}"
  printf '  [실패] %s => %s\n' "$1" "$message"
  FAIL_DETAILS+=("$1 :: $message")
  CHECK_MESSAGE=""
}

run_check() {
  local desc="$1"
  shift
  CHECK_MESSAGE=""
  if "$@"; then
    record_pass "$desc"
  else
    record_fail "$desc"
  fi
}

check_history_timeout() {
  local profile="/etc/profile"
  if ! grep -Eq 'HISTTIMEFORMAT=.*%Y-%m-%d' "$profile"; then
    CHECK_MESSAGE="/etc/profile 에 HISTTIMEFORMAT 설정이 없습니다"
    return 1
  fi
  if ! grep -Eq '(^|\s)TMOUT=600\b' "$profile"; then
    CHECK_MESSAGE="/etc/profile 에 TMOUT=600 설정이 없습니다"
    return 1
  fi
  return 0
}

expect_stat() {
  local file="$1" expected_perm="$2" expected_owner="$3"
  if [[ ! -e "$file" ]]; then
    CHECK_MESSAGE="$file 이 존재하지 않습니다"
    return 1
  fi
  local actual
  actual="$(stat -c '%a %U:%G' "$file" 2>/dev/null)"
  if [[ "$actual" == "$expected_perm $expected_owner" ]]; then
    return 0
  fi
  CHECK_MESSAGE="$file 권한/소유자 불일치 (기대: $expected_perm $expected_owner, 현재: $actual)"
  return 1
}

check_file_permissions() {
  expect_stat /etc/passwd 644 "root:root" || return 1
  expect_stat /etc/shadow 400 "root:root" || return 1
  expect_stat /etc/hosts 600 "root:root" || return 1
  expect_stat /usr/bin/su 4750 "root:wheel" || return 1
  return 0
}

check_packages() {
  local entries=(
    "epel-release"
    "chrony"
    "rsyslog"
    "lsof"
    "net-tools"
    "psmisc"
    "lrzsz"
    "screen"
    "iftop"
    "smartmontools"
    "vim|vim-enhanced|vim-common"
    "unzip"
    "wget"
  )
  local missing=()
  local entry
  for entry in "${entries[@]}"; do
    IFS='|' read -ra candidates <<< "$entry"
    local installed=1
    for candidate in "${candidates[@]}"; do
      if rpm -q "$candidate" >/dev/null 2>&1; then
        installed=0
        break
      fi
    done
    if ((installed)); then
      missing+=("${candidates[0]}")
    fi
  done
  if ((${#missing[@]} == 0)); then
    return 0
  fi
  CHECK_MESSAGE="패키지 누락: ${missing[*]}"
  return 1
}

check_sysctl() {
  declare -A expected=(
    [net.ipv4.icmp_echo_ignore_broadcasts]=1
    [net.ipv4.tcp_rmem]="4096 10000000 16777216"
    [net.ipv4.tcp_wmem]="4096 65536 16777216"
    [net.ipv4.tcp_tw_reuse]=1
    [net.ipv4.tcp_fin_timeout]=10
    [net.ipv4.tcp_keepalive_time]=1800
    [net.ipv4.tcp_max_syn_backlog]=4096
    [net.core.rmem_max]=16777216
    [net.core.wmem_max]=16777216
    [net.core.somaxconn]=10240
    [net.ipv4.ip_local_port_range]="4000 65535"
  )
  local key current
  for key in "${!expected[@]}"; do
    current="$(sysctl -n "$key" 2>/dev/null || echo '')"
    if [[ -z "$current" ]]; then
      CHECK_MESSAGE="sysctl 키 누락: $key"
      return 1
    fi
    local normalized
    normalized="$(normalize_spaces "$current")"
    if [[ "$normalized" != "${expected[$key]}" ]]; then
      CHECK_MESSAGE="sysctl 불일치: $key (기대: ${expected[$key]}, 현재: $normalized)"
      return 1
    fi
  done
  return 0
}

check_limits() {
  local file="/etc/security/limits.conf"
  local required=(
    '* soft nofile 61200'
    '* hard nofile 61200'
    '* soft nproc 61200'
    '* hard nproc 61200'
  )
  local line
  for line in "${required[@]}"; do
    if ! grep -Fxq "$line" "$file"; then
      CHECK_MESSAGE="limits.conf 설정 누락: $line"
      return 1
    fi
  done
  return 0
}

check_selinux() {
  local status
  status="$(getenforce 2>/dev/null || echo '')"
  if [[ "$status" == "Enforcing" ]]; then
    CHECK_MESSAGE="SELinux 가 Enforcing 상태"
    return 1
  fi
  if ! grep -Eq '^SELINUX=disabled' /etc/selinux/config; then
    CHECK_MESSAGE="/etc/selinux/config 에서 SELINUX=disabled 로 설정되지 않음"
    return 1
  fi
  return 0
}

check_pam_lockout() {
  local files=(/etc/pam.d/system-auth /etc/pam.d/password-auth)
  local file
  for file in "${files[@]}"; do
    if [[ ! -L "$file" ]]; then
      CHECK_MESSAGE="$file 이 심볼릭 링크가 아닙니다"
      return 1
    fi
    if ! grep -q 'pam_faillock.so' "$file"; then
      CHECK_MESSAGE="$file 에 pam_faillock 설정이 없습니다"
      return 1
    fi
    if ! grep -Eq '^\s*account\s+required\s+pam_faillock\.so' "$file"; then
      CHECK_MESSAGE="$file 에 pam_faillock account 항목이 없습니다"
      return 1
    fi
  done
  return 0
}

check_root_ssh() {
  local files=(/etc/ssh/sshd_config)
  if compgen -G "/etc/ssh/sshd_config.d/*.conf" >/dev/null; then
    files+=(/etc/ssh/sshd_config.d/*.conf)
  fi
  if ! grep -Eq '^[[:space:]]*PermitRootLogin[[:space:]]+no' "${files[@]}" 2>/dev/null; then
    CHECK_MESSAGE="PermitRootLogin no 설정을 찾을 수 없습니다"
    return 1
  fi
  if grep -Eq '^[[:space:]]*PermitRootLogin[[:space:]]+yes' "${files[@]}" 2>/dev/null; then
    CHECK_MESSAGE="PermitRootLogin yes 설정이 남아 있습니다"
    return 1
  fi
  return 0
}

check_ssh_port() {
  local current
  current="$(sshd -T 2>/dev/null | awk '/^port /{print $2; exit}')"
  if [[ -z "$current" ]]; then
    CHECK_MESSAGE="sshd -T 결과에서 포트 값을 확인할 수 없습니다"
    return 1
  fi
  if [[ "$current" == "$SSH_PORT" ]]; then
    return 0
  fi
  CHECK_MESSAGE="SSH 포트가 $current (기대: $SSH_PORT)"
  return 1
}

check_rsyslog() {
  if grep -q "*.* @$RSYSLOG_SERVER" /etc/rsyslog.conf; then
    return 0
  fi
  CHECK_MESSAGE="rsyslog 원격 전송 설정이 없습니다 ($RSYSLOG_SERVER)"
  return 1
}

check_services_disabled() {
  local units=(
    finger.service
    autofs.service
    rsh.service
    rlogin.service
    rexec.service
    ypbind.service
    ypserv.service
    ypxfrd.service
    rpc.yppasswdd.service
    rpc.ypupdated.service
    tftp.service
    tftp-server.service
    tftp.socket
    talk.service
  )
  local problematic=()
  local unit status active
  for unit in "${units[@]}"; do
    if ! systemctl list-unit-files "$unit" >/dev/null 2>&1; then
      continue
    fi
    status="$(unit_enabled_status "$unit")"
    case "$status" in
      disabled|masked|static|indirect|generated|unknown)
        ;;
      *)
        problematic+=("$unit:상태=$status")
        ;;
    esac
    active="$(unit_active_status "$unit")"
    case "$active" in
      inactive|failed|unknown)
        ;;
      *)
        problematic+=("$unit:동작=$active")
        ;;
    esac
  done

  local cockpit_units=(cockpit.service cockpit.socket)
  for unit in "${cockpit_units[@]}"; do
    if ! systemctl list-unit-files "$unit" >/dev/null 2>&1; then
      continue
    fi
    status="$(unit_enabled_status "$unit")"
    if [[ "$status" != "masked" && "$status" != "unknown" ]]; then
      problematic+=("$unit:상태=$status")
    fi
    active="$(unit_active_status "$unit")"
    case "$active" in
      inactive|failed|unknown)
        ;;
      *)
        problematic+=("$unit:동작=$active")
        ;;
    esac
  done

  if ((${#problematic[@]} > 0)); then
    CHECK_MESSAGE="비활성화 필요 서비스: ${problematic[*]}"
    return 1
  fi
  return 0
}

check_rhosts() {
  if [[ -e /etc/hosts.equiv ]]; then
    CHECK_MESSAGE="/etc/hosts.equiv 파일이 존재합니다"
    return 1
  fi
  if find /root -maxdepth 1 -name '.rhosts' | grep -q '.'; then
    CHECK_MESSAGE="/root/.rhosts 파일이 존재합니다"
    return 1
  fi
  return 0
}

check_logs_backups() {
  local log_dir="/usr/local/src/secure_os_collection/logs"
  if [[ ! -d "$log_dir" ]]; then
    CHECK_MESSAGE="$log_dir 디렉터리가 없습니다"
    return 1
  fi
  if [[ ! -d "$BACKUP_DIR" ]]; then
    CHECK_MESSAGE="백업 디렉터리가 없습니다: $BACKUP_DIR"
    return 1
  fi
  return 0
}

print_section "셸 환경"
run_check "명령 기록 시간 및 자동 로그아웃" check_history_timeout
run_check "주요 시스템 파일 권한" check_file_permissions
run_check "필수 패키지 설치" check_packages
run_check "커널 파라미터(sysctl)" check_sysctl
run_check "자원 제한(limits)" check_limits
run_check "SELinux 비활성화" check_selinux

print_section "인증"
run_check "PAM 잠금 정책" check_pam_lockout
run_check "root SSH 로그인 차단" check_root_ssh
run_check "SSH 포트 설정" check_ssh_port

print_section "서비스 및 네트워크"
run_check "rsyslog 원격 전송" check_rsyslog
run_check "불필요 서비스 비활성화" check_services_disabled
run_check "rhosts/hosts.equiv 제거" check_rhosts

print_section "로그 및 백업"
run_check "로그/백업 디렉터리 존재" check_logs_backups

printf '\n=== 요약 ===\n'
printf '성공: %d, 실패: %d\n' "$PASS_COUNT" "$FAIL_COUNT"
if ((FAIL_COUNT > 0)); then
  printf '\n실패 상세:\n'
  for item in "${FAIL_DETAILS[@]}"; do
    printf ' - %s\n' "$item"
  done
  exit 1
fi

echo "모든 검증 항목을 통과했습니다."
