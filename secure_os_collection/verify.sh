#!/bin/bash
#
# verify.sh — 보안 OS 하드닝 적용 결과 검증 스크립트
# 지원 OS: CentOS 7 / Rocky 8·9·10 / Ubuntu 18·20·22·24·26
# 사용법 : sudo bash verify.sh [--no-color] [--skip-worldwritable]
#
# 옵션:
#   --no-color           컬러 출력 비활성화 (파이프·파일 저장 시)
#   --skip-worldwritable world-writable 검사 생략 (시간이 오래 걸림)

# ── 옵션 파싱 ─────────────────────────────────────────────────────────────────
USE_COLOR=1
SKIP_WORLDWRITABLE=0
readonly REMOTE_LOG_SERVER="1.224.163.4"
for arg in "$@"; do
  case "$arg" in
    --no-color)           USE_COLOR=0 ;;
    --skip-worldwritable) SKIP_WORLDWRITABLE=1 ;;
  esac
done

# ── 색상 ──────────────────────────────────────────────────────────────────────
if [ "$USE_COLOR" -eq 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; NC=''
fi

# ── 카운터 ────────────────────────────────────────────────────────────────────
PASS=0; FAIL=0; WARN=0; SKIP=0

pass() { echo -e "  [${GREEN}PASS${NC}] $1"; PASS=$((PASS+1)); }
fail() { echo -e "  [${RED}FAIL${NC}] $1"; FAIL=$((FAIL+1)); }
warn() { echo -e "  [${YELLOW}WARN${NC}] $1"; WARN=$((WARN+1)); }
skip() { echo -e "  [${CYAN}SKIP${NC}] $1"; SKIP=$((SKIP+1)); }
info() { echo -e "  [${CYAN}INFO${NC}] $1"; }
hdr()  { echo -e "\n${BOLD}${CYAN}━━━ $1 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# ── OS 감지 ───────────────────────────────────────────────────────────────────
detect_os() {
  OS_ID="unknown"; OS_VERSION="0"; OS_MAJOR=0
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_VERSION="${VERSION_ID:-0}"
  elif [ -f /etc/centos-release ]; then
    OS_ID="centos"; OS_VERSION="7"
  fi
  OS_MAJOR="${OS_VERSION%%.*}"
}

is_rhel()   { [[ "$OS_ID" =~ ^(centos|rhel|rocky|almalinux)$ ]]; }
is_ubuntu() { [[ "$OS_ID" =~ ^(ubuntu|debian)$ ]]; }

is_supported_os() {
  case "${OS_ID}:${OS_MAJOR}" in
    centos:7|rocky:8|rocky:9|rocky:10|ubuntu:18|ubuntu:20|ubuntu:22|ubuntu:24|ubuntu:26) return 0 ;;
    *) return 1 ;;
  esac
}

is_forced_update_os() {
  case "${OS_ID}:${OS_MAJOR}" in
    centos:7|ubuntu:18|ubuntu:20) return 0 ;;
    *) return 1 ;;
  esac
}

# ── 공통 헬퍼 ────────────────────────────────────────────────────────────────
file_perm() {
  # file_perm <파일> <기대권한> <레이블>
  local f="$1" exp="$2" lbl="$3"
  [ -e "$f" ] || { warn "$lbl: $f 없음 (미설치)"; return; }
  local got; got=$(stat -c "%a" "$f")
  [ "$got" = "$exp" ] && pass "$lbl: $f (${got})" || fail "$lbl: $f (실제=${got}, 기대=${exp})"
}

file_owner() {
  # file_owner <파일> <기대소유자:그룹> <레이블>
  local f="$1" exp="$2" lbl="$3"
  [ -e "$f" ] || { warn "$lbl: $f 없음"; return; }
  local got; got=$(stat -c "%U:%G" "$f")
  [ "$got" = "$exp" ] && pass "$lbl: $f (소유자 ${got})" || fail "$lbl: $f (실제=${got}, 기대=${exp})"
}

svc_active() {
  systemctl is-active --quiet "$1" 2>/dev/null \
    && pass "서비스 실행: $1" || fail "서비스 미실행: $1"
}

svc_inactive() {
  # 설치되어 있으면 inactive여야 함, 미설치면 SKIP
  if is_rhel; then
    rpm -q "$1" &>/dev/null || { skip "미설치(정상): $1"; return; }
  elif is_ubuntu; then
    dpkg -s "$1" &>/dev/null 2>&1 || { skip "미설치(정상): $1"; return; }
  fi
  systemctl is-active --quiet "$1" 2>/dev/null \
    && fail "서비스가 여전히 실행 중: $1" || pass "서비스 비활성: $1"
}

grep_in() {
  # grep_in <패턴> <파일...> <레이블>
  local lbl="${@: -1}"
  local files=("${@:2:$#-2}")
  local pat="$1"
  if grep -qlr "$pat" "${files[@]}" 2>/dev/null; then
    pass "$lbl"
  else
    fail "$lbl"
  fi
}

sysctl_val() {
  # sysctl_val <키> <기대값> <레이블>
  local key="$1" exp="$2" lbl="$3"
  local got; got=$(sysctl -n "$key" 2>/dev/null)
  if [ "$got" = "$exp" ]; then
    pass "sysctl $lbl: ${key}=${got}"
  else
    fail "sysctl $lbl: ${key}=${got:-미설정} (기대=${exp})"
  fi
}

# 지정 파일에서 활성 설정이 정확히 한 줄인지 확인한다.
single_active_line() {
  local f="$1" pattern="$2" lbl="$3" count
  [ -f "$f" ] || { fail "$lbl: $f 없음"; return; }
  count=$(grep -Ec "$pattern" "$f" 2>/dev/null || true)
  [ "$count" -eq 1 ] \
    && pass "$lbl: 1개" \
    || fail "$lbl: ${count}개 (기대=1개)"
}

# 지정 파일에서 고정 문자열이 정확히 한 줄인지 확인한다.
single_fixed_line() {
  local f="$1" line="$2" lbl="$3" count
  [ -f "$f" ] || { fail "$lbl: $f 없음"; return; }
  count=$(grep -Fxc "$line" "$f" 2>/dev/null || true)
  [ "$count" -eq 1 ] \
    && pass "$lbl: 1개" \
    || fail "$lbl: ${count}개 (기대=1개)"
}

# 선택 설정은 없어도 허용하되 같은 활성 키가 두 번 이상 있으면 실패 처리한다.
no_duplicate_active_line() {
  local f="$1" pattern="$2" lbl="$3" count
  [ -f "$f" ] || { fail "$lbl: $f 없음"; return; }
  count=$(grep -Ec "$pattern" "$f" 2>/dev/null || true)
  [ "$count" -le 1 ] \
    && pass "$lbl: 중복 없음 (${count}개)" \
    || fail "$lbl: ${count}개 중복"
}

# 0. 지원 OS와 현재/기본 부팅 커널 상태를 확인한다.
check_platform() {
  hdr "0. OS / 커널 버전 정책"

  pass "지원 OS: ${OS_ID} ${OS_VERSION}"
  if is_forced_update_os; then
    info "업데이트 정책: EOS/구버전 최신 업데이트 강제 대상"
  else
    info "업데이트 정책: 전체 업데이트 선택형 대상"
  fi

  local running_kernel default_kernel="" installed_kernels=""
  running_kernel=$(uname -r)
  info "현재 실행 커널: ${running_kernel}"

  if [ "$OS_ID" = "centos" ] && [ "$OS_MAJOR" -eq 7 ]; then
    installed_kernels=$(rpm -q kernel 2>/dev/null | sed 's/^kernel-//' | paste -sd, - | sed 's/,/, /g')
    rpm -q "kernel-${running_kernel}" >/dev/null 2>&1 \
      && pass "실행 커널 패키지: kernel-${running_kernel}" \
      || fail "실행 커널 패키지 확인 실패: kernel-${running_kernel}"
    if command -v grubby >/dev/null 2>&1; then
      default_kernel=$(basename "$(grubby --default-kernel 2>/dev/null)")
    fi
  elif is_rhel; then
    installed_kernels=$(rpm -q kernel-core 2>/dev/null | sed 's/^kernel-core-//' | paste -sd, - | sed 's/,/, /g')
    rpm -q "kernel-core-${running_kernel}" >/dev/null 2>&1 \
      && pass "실행 커널 패키지: kernel-core-${running_kernel}" \
      || fail "실행 커널 패키지 확인 실패: kernel-core-${running_kernel}"
    if command -v grubby >/dev/null 2>&1; then
      default_kernel=$(basename "$(grubby --default-kernel 2>/dev/null)")
    fi
  else
    installed_kernels=$(dpkg-query -W -f='${binary:Package}\n' 'linux-image-[0-9]*' 2>/dev/null \
      | sed 's/:.*$//; s/^linux-image-//' | paste -sd, - | sed 's/,/, /g')
    dpkg-query -W -f='${Status}' "linux-image-${running_kernel}" 2>/dev/null | grep -q 'install ok installed' \
      && pass "실행 커널 패키지: linux-image-${running_kernel}" \
      || fail "실행 커널 패키지 확인 실패: linux-image-${running_kernel}"
    if [ -e /vmlinuz ]; then
      default_kernel=$(basename "$(readlink -f /vmlinuz 2>/dev/null)")
    fi
  fi
  info "설치된 커널: ${installed_kernels:-확인 불가}"

  if [ -n "$default_kernel" ]; then
    if [ "$default_kernel" = "vmlinuz-${running_kernel}" ]; then
      pass "기본 부팅 커널과 실행 커널 일치: ${running_kernel}"
    else
      warn "기본 부팅 커널(${default_kernel#vmlinuz-})과 실행 커널(${running_kernel}) 불일치"
    fi
  else
    warn "기본 부팅 커널 확인 불가"
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# 1. 시스템 기본 설정
# ══════════════════════════════════════════════════════════════════════════════
check_system_basic() {
  hdr "1. 시스템 기본 설정"

  # 시간대 (Ubuntu만 적용 대상)
  if is_ubuntu; then
    local tz
    tz=$(timedatectl show --property=Timezone --value 2>/dev/null \
      || timedatectl 2>/dev/null | awk '/Time zone/{print $3}')
    [ "$tz" = "Asia/Seoul" ] \
      && pass "시간대: Asia/Seoul" \
      || fail "시간대: '${tz:-미확인}' (기대값: Asia/Seoul)"
  fi

  # NTP 서비스
  local ntp_found=0
  for s in chronyd chrony systemd-timesyncd; do
    if systemctl is-active --quiet "$s" 2>/dev/null; then
      pass "NTP 서비스: $s 실행 중"
      ntp_found=1; break
    fi
  done
  [ "$ntp_found" -eq 0 ] && fail "NTP 서비스: 동기화 서비스 미실행"

  # RHEL: chrony.conf NTP 서버 항목 존재
  if is_rhel && [ -f /etc/chrony.conf ]; then
    grep -qE '^server ' /etc/chrony.conf \
      && pass "chrony.conf: server 항목 설정됨" \
      || fail "chrony.conf: server 항목 없음"
    # makestep cron (c7, r10)
    [ -f /etc/cron.d/chrony_makestep ] \
      && pass "chrony makestep cron: /etc/cron.d/chrony_makestep 존재" \
      || warn "chrony makestep cron: 미설정 (선택 항목)"
  fi

  # HISTTIMEFORMAT / TMOUT
  grep -qr 'HISTTIMEFORMAT' /etc/profile /etc/profile.d/ 2>/dev/null \
    && pass "HISTTIMEFORMAT: 설정됨" || fail "HISTTIMEFORMAT: /etc/profile 미설정"
  grep -qr 'TMOUT' /etc/profile /etc/profile.d/ 2>/dev/null \
    && pass "TMOUT: 설정됨" || fail "TMOUT: /etc/profile 미설정"

  # sysstat
  local ss_ok=0
  for s in sysstat sysstat-collect.timer; do
    systemctl is-active --quiet "$s" 2>/dev/null && { ss_ok=1; break; }
  done
  [ "$ss_ok" -eq 1 ] && pass "sysstat: 활성화됨" || warn "sysstat: 비활성 또는 미설치"

  # MOTD
  grep -q '허가된 사용자\|authorized users' /etc/motd 2>/dev/null \
    && pass "MOTD: 법적 경고 문구 설정됨" || fail "MOTD: 경고 문구 없음"

  # root .bashrc 별칭
  grep -qF "alias vi='vim'" /root/.bashrc 2>/dev/null \
    && pass "bash alias: vi='vim' 설정됨" || warn "bash alias: vi='vim' 미설정"

  # root .vimrc
  [ -f /root/.vimrc ] && grep -q 'ignorecase' /root/.vimrc \
    && pass "vimrc: /root/.vimrc 설정됨" || warn "vimrc: /root/.vimrc 미설정"

  # Ubuntu: APT 자동 업데이트 비활성화
  if is_ubuntu; then
    grep -q 'Update-Package-Lists.*"0"' /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null \
      && pass "APT 자동 업데이트: 비활성화됨" || fail "APT 자동 업데이트: 비활성화 미적용"
    # sshd runtime dir
    [ -d /run/sshd ] \
      && pass "sshd runtime dir: /run/sshd 존재" \
      || warn "sshd runtime dir: /run/sshd 없음"
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# 2. 파일 및 디렉터리 권한
# ══════════════════════════════════════════════════════════════════════════════
check_file_perms() {
  hdr "2. 파일 / 디렉터리 권한"

  file_perm  /etc/passwd    644  "U-54 /etc/passwd 권한"
  file_perm  /etc/shadow    400  "U-54 /etc/shadow 권한"
  file_perm  /etc/hosts     600  "U-54 /etc/hosts 권한"
  file_perm  /tmp           1777 "임시 디렉터리 /tmp sticky bit"
  file_perm  /var/tmp       1777 "임시 디렉터리 /var/tmp sticky bit"
  local wtmp_perm; wtmp_perm=$(stat -c "%a" /var/log/wtmp 2>/dev/null)
  if [ "$wtmp_perm" = "644" ]; then
    pass "U-67 /var/log/wtmp 권한: 644"
  else
    fail "U-67 /var/log/wtmp 권한: /var/log/wtmp (실제=${wtmp_perm}, 기대=644)"
  fi
  local btmp_perm; btmp_perm=$(stat -c "%a" /var/log/btmp 2>/dev/null)
  if [ "$btmp_perm" = "600" ]; then
    pass "U-67 /var/log/btmp 권한: 600"
  else
    fail "U-67 /var/log/btmp 권한: /var/log/btmp (실제=${btmp_perm}, 기대=600)"
  fi

  if is_rhel || is_ubuntu; then
    local tmpfiles_conf="/etc/tmpfiles.d/99-hardening-perms.conf"
    single_active_line "$tmpfiles_conf" '^z[[:space:]]+/var/log/wtmp[[:space:]]+0644[[:space:]]+root[[:space:]]+utmp' "wtmp tmpfiles 유지 설정"
    single_active_line "$tmpfiles_conf" '^z[[:space:]]+/var/log/btmp[[:space:]]+0600[[:space:]]+root[[:space:]]+utmp' "btmp tmpfiles 유지 설정"
  fi

  # rsyslog.conf
  file_perm  /etc/rsyslog.conf  640  "rsyslog.conf 권한"
  file_owner /etc/rsyslog.conf  "root:root" "rsyslog.conf 소유자"

  # su 권한
  local su_bin="/usr/bin/su"
  [ -f "$su_bin" ] || su_bin="/bin/su"
  file_perm "$su_bin" 4750 "U-06 su 권한"
  if is_rhel; then
    file_owner "$su_bin" "root:wheel" "U-06 su 소유자"
  else
    file_owner "$su_bin" "root:sudo" "U-06 su 소유자"
  fi

  # SUID 제거 대상 (RHEL r10 기준)
  if is_rhel && [ "$OS_MAJOR" -ge 10 ]; then
    for f in /usr/bin/perl /usr/bin/screen /usr/bin/wget /usr/bin/curl; do
      [ -e "$f" ] || continue
      local perm; perm=$(stat -c "%a" "$f")
      [[ "$perm" == "700" || "$perm" == "755" ]] \
        && pass "SUID 제거: $f (${perm})" \
        || warn "SUID 미제거 또는 변경: $f (${perm})"
    done
  fi

  # Ubuntu: SUID 제거 대상
  if is_ubuntu; then
    for f in /usr/bin/lpr /usr/bin/lprm /usr/bin/lpq /usr/bin/perl \
              /usr/bin/screen /usr/bin/wget /usr/bin/curl; do
      [ -e "$f" ] || continue
      local sgid; sgid=$(stat -c "%a" "$f")
      if [[ "$sgid" =~ ^[0-9]{3}$ ]]; then
        pass "SUID 제거: $f (${sgid})"
      else
        warn "SUID 확인 필요: $f (${sgid})"
      fi
    done
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# 3. U-30 UMASK / U-37 crontab / U-25 world-writable
# ══════════════════════════════════════════════════════════════════════════════
check_hardening_files() {
  hdr "3. U-25/U-30/U-37 파일 보안"

  # UMASK (전체 OS 적용)
  local umask_targets=()
  is_rhel   && umask_targets=(/etc/profile /etc/bashrc)
  is_ubuntu && umask_targets=(/etc/profile /etc/bash.bashrc)

  if is_rhel || is_ubuntu; then
    local umask_ok=0
    for f in "${umask_targets[@]}"; do
      grep -q 'umask 022' "$f" 2>/dev/null && { umask_ok=1; break; }
    done
    [ "$umask_ok" -eq 1 ] \
      && pass "U-30 UMASK: umask 022 설정됨" \
      || fail "U-30 UMASK: umask 022 미설정"
  else
    skip "U-30 UMASK: 해당 OS 미적용 대상 (${OS_ID} ${OS_VERSION})"
  fi

  # /etc/crontab 권한 (전체 OS 적용)
  if is_rhel || is_ubuntu; then
    file_perm /etc/crontab 640 "U-37 /etc/crontab 권한"
    file_perm /etc/cron.deny 640 "U-37 /etc/cron.deny 권한"
  else
    skip "U-37 crontab 권한: 해당 OS 미적용 대상"
  fi

  # world-writable (전체 OS 적용)
  if [ "$SKIP_WORLDWRITABLE" -eq 1 ]; then
    skip "U-25 world-writable: --skip-worldwritable 옵션으로 생략"
  elif is_rhel || is_ubuntu; then
    echo -n "  U-25 world-writable 검사 중..."
    local cnt
    cnt=$(find / -xdev -type f -perm -0002 \
      ! -path '/proc/*' ! -path '/sys/*' ! -path '/dev/*' 2>/dev/null | wc -l)
    echo ""
    [ "$cnt" -eq 0 ] \
      && pass "U-25 world-writable 파일: 없음" \
      || warn "U-25 world-writable 파일: ${cnt}개 존재 (검증 실패 집계 제외)"
  else
    skip "U-25 world-writable: 해당 OS 미적용 대상"
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# 4. SSH 설정
# ══════════════════════════════════════════════════════════════════════════════
check_ssh() {
  hdr "4. SSH 설정"

  # PermitRootLogin no
  local prl
  prl=$(sshd -T 2>/dev/null | awk '/^permitrootlogin/{print $2; exit}')
  [ "$prl" = "no" ] \
    && pass "U-01 SSH PermitRootLogin: no" \
    || fail "U-01 SSH PermitRootLogin: '${prl:-확인불가}' (기대값: no)"

  # drop-in 파일 확인
  if [ -d /etc/ssh/sshd_config.d ]; then
    grep -rl 'PermitRootLogin no' /etc/ssh/sshd_config.d/ 2>/dev/null | grep -q . \
      && pass "SSH drop-in: PermitRootLogin no 존재" \
      || warn "SSH drop-in: /etc/ssh/sshd_config.d/ 내 설정 없음"
  fi

  # SSH 포트
  local port
  port=$(sshd -T 2>/dev/null | awk '/^port /{print $2; exit}')
  [ "$port" != "22" ] && [ -n "$port" ] \
    && pass "SSH 포트: 기본값에서 변경됨 (port ${port})" \
    || warn "SSH 포트: 기본 22 사용 중"
}

# ══════════════════════════════════════════════════════════════════════════════
# 5. PAM / 계정 정책
# ══════════════════════════════════════════════════════════════════════════════
check_pam() {
  hdr "5. PAM / 계정 정책"

  # ── 5-1 로그인 실패 잠금 ─────────────────────────────────
  if is_rhel; then
    if [ "$OS_MAJOR" -ge 8 ]; then
      # faillock.conf
      local fconf="/etc/security/faillock.conf"
      [ -f "$fconf" ] && grep -q '^deny' "$fconf" \
        && pass "U-03 faillock.conf: 설정됨" \
        || fail "U-03 faillock.conf: 없거나 deny 미설정"
      local deny_v; deny_v=$(grep '^deny' "$fconf" 2>/dev/null | awk -F'=' '{gsub(/ /,"",$2); print $2}')
      [ "${deny_v:-0}" -ge 3 ] \
        && pass "U-03 faillock deny: ${deny_v}" \
        || warn "U-03 faillock deny: ${deny_v:-미설정} (기대 3)"
      local ul_v; ul_v=$(grep '^unlock_time' "$fconf" 2>/dev/null | awk -F'=' '{gsub(/ /,"",$2); print $2}')
      [ -n "$ul_v" ] \
        && pass "U-03 faillock unlock_time: ${ul_v}" \
        || warn "U-03 faillock unlock_time: 미설정"
      # pam_faillock in PAM
      grep -ql 'pam_faillock' /etc/pam.d/system-auth /etc/pam.d/password-auth 2>/dev/null \
        && pass "U-03 pam_faillock: system-auth/password-auth 설정됨" \
        || fail "U-03 pam_faillock: PAM 파일 미설정"
      # authselect
      authselect current 2>/dev/null | grep -q 'with-faillock' \
        && pass "authselect: with-faillock 활성화" \
        || fail "authselect: with-faillock 미적용"
    else
      # CentOS 7: pam_tally2
      grep -q 'pam_tally2' /etc/pam.d/system-auth 2>/dev/null \
        && pass "U-03 pam_tally2: system-auth 설정됨" \
        || fail "U-03 pam_tally2: 미설정"
    fi

  elif is_ubuntu; then
    if [ "$OS_MAJOR" -ge 20 ]; then
      grep -q 'pam_faillock' /etc/pam.d/common-auth 2>/dev/null \
        && pass "U-03 pam_faillock: common-auth 설정됨" \
        || fail "U-03 pam_faillock: 미설정"
      local deny_v; deny_v=$(grep -o 'deny=[0-9]*' /etc/pam.d/common-auth 2>/dev/null | head -1 | cut -d= -f2)
      [ "${deny_v:-0}" -ge 3 ] \
        && pass "U-03 faillock deny: ${deny_v}" \
        || warn "U-03 faillock deny: ${deny_v:-미설정} (기대 3)"
    else
      grep -q 'pam_tally2' /etc/pam.d/common-auth 2>/dev/null \
        && pass "U-03 pam_tally2: common-auth 설정됨 (Ubuntu 18)" \
        || fail "U-03 pam_tally2: 미설정"
    fi
  fi

  # ── 5-2 pwquality (전체 지원 OS) ──────────────────────────
  if is_rhel || is_ubuntu; then
    local pwq="/etc/security/pwquality.conf"
    [ -f "$pwq" ] && grep -q 'minlen' "$pwq" \
      && pass "U-02 pwquality.conf: 설정됨" \
      || fail "U-02 pwquality.conf: minlen 미설정"
    if ! { is_rhel && [ "$OS_MAJOR" -eq 7 ]; }; then
      grep -q 'enforce_for_root' "$pwq" 2>/dev/null \
        && pass "U-02 pwquality: enforce_for_root 적용됨" \
        || fail "U-02 pwquality: enforce_for_root 미적용"
    fi
    for k in lcredit ucredit dcredit ocredit; do
      grep -q "^${k}=-1" "$pwq" 2>/dev/null \
        && pass "U-02 pwquality: ${k}=-1" \
        || warn "U-02 pwquality: ${k} 확인 필요"
    done
  else
    skip "pwquality: 해당 OS 미적용 대상"
  fi

  # ── 5-3 pwhistory (r8+, u22+) ────────────────────────────
  if { is_rhel && [ "$OS_MAJOR" -ge 8 ]; } || { is_ubuntu && [ "$OS_MAJOR" -ge 22 ]; }; then
    local pwh="/etc/security/pwhistory.conf"
    [ -f "$pwh" ] \
      && pass "U-02 pwhistory.conf: 존재" \
      || fail "U-02 pwhistory.conf: 없음"
    grep -q 'enforce_for_root' "$pwh" 2>/dev/null \
      && pass "U-02 pwhistory: enforce_for_root 적용됨" \
      || warn "U-02 pwhistory: enforce_for_root 미적용"
    grep -q 'remember=4' "$pwh" 2>/dev/null \
      && pass "U-02 pwhistory: remember=4" \
      || warn "U-02 pwhistory: remember 값 확인 필요"
    file_perm /etc/security/opasswd 600 "opasswd 권한"
  else
    skip "pwhistory: 해당 OS 미적용 대상"
  fi

  # ── 5-4 su 제한 (pam_wheel) ──────────────────────────────
  grep -q 'pam_wheel.so.*use_uid' /etc/pam.d/su 2>/dev/null \
    && pass "U-06 pam_wheel.so use_uid: /etc/pam.d/su 설정됨" \
    || fail "U-06 pam_wheel.so use_uid: 미설정"

  # ── 5-5 불필요 계정 삭제 ─────────────────────────────────
  hdr "  5-5. 불필요 계정 삭제"
  if is_rhel; then
    for u in lp games ftp sync shutdown halt; do
      id "$u" &>/dev/null \
        && warn "불필요 계정 잔존: $u" \
        || pass "계정 삭제 확인: $u 없음"
    done
  elif is_ubuntu; then
    local -a ubuntu_remove_targets=(ftp shutdown halt)
    if [ "$OS_MAJOR" -ge 22 ]; then
      ubuntu_remove_targets=(lp uucp ftp shutdown halt)
    fi
    for u in "${ubuntu_remove_targets[@]}"; do
      id "$u" &>/dev/null \
        && warn "불필요 계정 잔존: $u" \
        || pass "계정 삭제 확인: $u 없음"
    done
    # sync 계정 shell
    if getent passwd sync &>/dev/null; then
      local sh; sh=$(getent passwd sync | cut -d: -f7)
      [[ "$sh" == "/usr/sbin/nologin" || "$sh" == "/bin/false" ]] \
        && pass "U-11 sync 계정 shell: ${sh}" \
        || fail "U-11 sync 계정 shell: ${sh} (기대: nologin/false)"
    fi
  fi

  # ftp 계정 shell
  if getent passwd ftp &>/dev/null; then
    local sh; sh=$(getent passwd ftp | cut -d: -f7)
    [[ "$sh" == "/bin/false" || "$sh" == "/usr/sbin/nologin" ]] \
      && pass "ftp 계정 shell: ${sh}" \
      || fail "ftp 계정 shell: ${sh} (기대: /bin/false)"
  else
    pass "ftp 계정: 없음"
  fi

  # ── 5-6 sudoers wheel 설정 (RHEL) ────────────────────────
  if is_rhel; then
    grep -Eq '^%wheel\s+ALL=\(ALL\)\s+ALL' /etc/sudoers 2>/dev/null \
      && pass "sudoers: %wheel ALL=(ALL) ALL 활성화됨" \
      || warn "sudoers: wheel 항목 확인 필요"
  fi

  # ── 5-7 root SSH 차단 전 관리자 일반 계정 확보 ───────────
  local admin_group admin_found=0 user_name
  local -a normal_users=()
  is_rhel && admin_group="wheel" || admin_group="sudo"
  mapfile -t normal_users < <(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd)
  if [ ${#normal_users[@]} -eq 0 ]; then
    fail "관리자 일반 계정: UID 1000~59999 계정 없음"
  else
    for user_name in "${normal_users[@]}"; do
      if id -nG "$user_name" 2>/dev/null | tr ' ' '\n' | grep -qx "$admin_group"; then
        pass "관리자 일반 계정: $user_name ($admin_group)"
        admin_found=1
        break
      fi
    done
    [ "$admin_found" -eq 1 ] || fail "관리자 일반 계정: ${admin_group} 그룹 구성원 없음"
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# 6. sysctl 커널 파라미터
# ══════════════════════════════════════════════════════════════════════════════
check_sysctl() {
  hdr "6. sysctl 커널 파라미터"

  sysctl_val net.ipv4.icmp_echo_ignore_broadcasts 1 "ICMP 브로드캐스트 무시"
  sysctl_val net.ipv4.tcp_fin_timeout             10 "TCP FIN timeout"
  sysctl_val net.ipv4.tcp_keepalive_time          1800 "TCP keepalive"
  sysctl_val net.ipv4.tcp_max_syn_backlog         4096 "SYN backlog"
  sysctl_val net.core.somaxconn                   10240 "소켓 최대 연결"

  sysctl_val net.ipv6.conf.all.disable_ipv6 1 "IPv6 비활성화"
}

# ══════════════════════════════════════════════════════════════════════════════
# 7. limits.conf
# ══════════════════════════════════════════════════════════════════════════════
check_limits() {
  hdr "7. 리소스 제한 (limits)"

  local lf
  if is_rhel || { is_ubuntu && [ "$OS_MAJOR" -le 20 ]; }; then
    lf="/etc/security/limits.conf"
  else
    lf="/etc/security/limits.d/99-secure-os.conf"
  fi

  if [ -f "$lf" ]; then
    grep -q 'nofile.*61200' "$lf" \
      && pass "limits: nofile 61200 설정됨 (${lf})" \
      || fail "limits: nofile 61200 미설정"
    grep -q 'nproc.*61200' "$lf" \
      && pass "limits: nproc 61200 설정됨" \
      || fail "limits: nproc 61200 미설정"
  else
    fail "limits: 설정 파일 없음 (${lf})"
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# 8. 로깅
# ══════════════════════════════════════════════════════════════════════════════
check_logging() {
  hdr "8. 로깅"

  # 모든 서버의 고정 중앙 로그 전송 대상과 중복 여부를 함께 확인한다.
  single_fixed_line /etc/rsyslog.conf "*.* @${REMOTE_LOG_SERVER}" "rsyslog 중앙 로그 전송(${REMOTE_LOG_SERVER})"
  local wrong_remote_count
  wrong_remote_count=$(grep -hEr '^[[:space:]]*\*\.\*[[:space:]]+@' /etc/rsyslog.conf /etc/rsyslog.d/ 2>/dev/null \
    | grep -Fvc "*.* @${REMOTE_LOG_SERVER}" || true)
  [ "$wrong_remote_count" -eq 0 ] \
    && pass "rsyslog 다른 원격 전송 대상: 없음" \
    || fail "rsyslog 다른 원격 전송 대상: ${wrong_remote_count}개"

  svc_active rsyslog

  # snoopy 명령 감사 로그
  if grep -q 'libsnoopy' /etc/ld.so.preload 2>/dev/null; then
    pass "snoopy: /etc/ld.so.preload 활성화됨"
  else
    fail "snoopy: /etc/ld.so.preload 미활성화"
  fi
  [ -f /etc/snoopy.ini ] \
    && pass "snoopy: /etc/snoopy.ini 존재" \
    || fail "snoopy: /etc/snoopy.ini 없음"
}

# 재실행 후에도 주요 설정이 한 번만 유지되는지 확인한다.
check_reexecution_stability() {
  hdr "9. 재실행 안정성"

  single_active_line /etc/profile '^[[:space:]]*(export[[:space:]]+)?HISTTIMEFORMAT=' "HISTTIMEFORMAT 활성 설정"
  single_active_line /etc/profile '^[[:space:]]*(export[[:space:]]+)?TMOUT=' "TMOUT 활성 설정"
  no_duplicate_active_line /etc/login.defs '^[[:space:]]*PASS_MAX_DAYS[[:space:]]+' "PASS_MAX_DAYS 설정"
  no_duplicate_active_line /etc/login.defs '^[[:space:]]*PASS_MIN_DAYS[[:space:]]+' "PASS_MIN_DAYS 설정"
  no_duplicate_active_line /etc/login.defs '^[[:space:]]*PASS_WARN_AGE[[:space:]]+' "PASS_WARN_AGE 설정"
  no_duplicate_active_line /etc/login.defs '^[[:space:]]*PASS_MIN_LEN[[:space:]]+' "PASS_MIN_LEN 설정"
  single_active_line /etc/pam.d/su '^[[:space:]]*auth[[:space:]]+required[[:space:]]+pam_wheel\.so.*use_uid' "pam_wheel 활성 설정"
  single_active_line /etc/ld.so.preload '^[[:space:]]*[^#]*libsnoopy[^#]*$' "Snoopy preload 설정"

  local cfg count duplicate_files=0
  local -a ssh_configs=(/etc/ssh/sshd_config)
  if [ -d /etc/ssh/sshd_config.d ]; then
    while IFS= read -r -d '' cfg; do
      ssh_configs+=("$cfg")
    done < <(find /etc/ssh/sshd_config.d -maxdepth 1 -type f -name '*.conf' -print0 2>/dev/null)
  fi
  for cfg in "${ssh_configs[@]}"; do
    count=$(grep -Ec '^[[:space:]]*PermitRootLogin[[:space:]]+' "$cfg" 2>/dev/null || true)
    if [ "$count" -gt 1 ]; then
      fail "PermitRootLogin 중복: $cfg (${count}개)"
      duplicate_files=$((duplicate_files+1))
    fi
  done
  [ "$duplicate_files" -eq 0 ] && pass "PermitRootLogin 파일별 중복: 없음"
}

# ══════════════════════════════════════════════════════════════════════════════
# 10. 서비스 비활성화
# ══════════════════════════════════════════════════════════════════════════════
check_services() {
  hdr "10. 불필요 서비스 비활성화"

  # rhosts / hosts.equiv
  [ ! -f /etc/hosts.equiv ] \
    && pass "U-16 hosts.equiv: 없음" \
    || fail "U-16 hosts.equiv: 존재"
  [ ! -f /root/.rhosts ] \
    && pass "U-16 .rhosts: 없음" \
    || fail "U-16 .rhosts: 존재"

  # finger
  svc_inactive finger

  # r-services
  for svc in rsh rlogin rexec; do svc_inactive "$svc"; done

  # autofs
  svc_inactive autofs

  # NIS
  for svc in ypbind ypserv; do svc_inactive "$svc"; done

  # tftp / talk
  svc_inactive tftp
  svc_inactive talk

  # anonymous FTP (vsftpd 설치 시)
  if is_rhel && rpm -q vsftpd &>/dev/null 2>&1; then
    grep -q '^anonymous_enable=NO' /etc/vsftpd/vsftpd.conf 2>/dev/null \
      && pass "FTP 익명 접속: anonymous_enable=NO" \
      || fail "FTP 익명 접속: anonymous_enable 미차단"
  elif is_ubuntu && dpkg -s vsftpd &>/dev/null 2>&1; then
    grep -q '^anonymous_enable=NO' /etc/vsftpd.conf 2>/dev/null \
      && pass "FTP 익명 접속: anonymous_enable=NO" \
      || fail "FTP 익명 접속: anonymous_enable 미차단"
  fi

  # cockpit (RHEL r10+)
  if is_rhel && [ "$OS_MAJOR" -ge 10 ]; then
    systemctl is-active --quiet cockpit.socket 2>/dev/null \
      && fail "cockpit.socket: 실행 중 (비활성화 필요)" \
      || pass "cockpit.socket: 비활성"
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# 11. RHEL 전용 추가 항목
# ══════════════════════════════════════════════════════════════════════════════
check_rhel_extra() {
  hdr "11. RHEL 추가 항목"

  # SELinux
  local sel; sel=$(getenforce 2>/dev/null)
  [[ "$sel" == "Disabled" || "$sel" == "Permissive" ]] \
    && pass "SELinux: ${sel}" \
    || warn "SELinux: ${sel} (스크립트는 disabled 설정)"

  # /etc/selinux/config
  grep -q '^SELINUX=disabled' /etc/selinux/config 2>/dev/null \
    && pass "SELinux config: SELINUX=disabled" \
    || warn "SELinux config: disabled 미설정"

  # chronyd 활성화
  svc_active chronyd

  # rc.local (r8+)
  if [ "$OS_MAJOR" -ge 8 ]; then
    [ -x /etc/rc.d/rc.local ] \
      && pass "rc.local: 실행 권한 있음" \
      || warn "rc.local: 실행 권한 없음"
  fi

  # 방화벽
  if systemctl is-active --quiet firewalld 2>/dev/null; then
    pass "방화벽: firewalld 실행 중"
  elif systemctl is-active --quiet iptables 2>/dev/null; then
    pass "방화벽: iptables 실행 중"
  elif [ "$(systemctl is-enabled firewalld 2>/dev/null)" = "masked" ] \
    && [ "$(systemctl is-enabled iptables 2>/dev/null)" = "masked" ]; then
    pass "방화벽: 사용자 선택에 따라 firewalld/iptables 비활성화됨"
  else
    warn "방화벽: firewalld/iptables 미실행"
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# 11. Ubuntu 전용 추가 항목
# ══════════════════════════════════════════════════════════════════════════════
check_ubuntu_extra() {
  hdr "11. Ubuntu 추가 항목"

  # chrony 또는 timesyncd
  if dpkg -s chrony &>/dev/null 2>&1; then
    svc_active chrony
  else
    svc_active systemd-timesyncd
  fi

  # UFW
  if command -v ufw &>/dev/null; then
    ufw status 2>/dev/null | grep -q 'Status: active' \
      && pass "UFW: 활성화됨" \
      || warn "UFW: 설치됨 but 비활성 (방화벽 스크립트 미적용)"
  else
    warn "UFW: 미설치 (방화벽 스크립트 없음)"
  fi

  # pam_unix minlen (u22+)
  if [ "$OS_MAJOR" -ge 22 ]; then
    grep -q 'minlen=' /etc/pam.d/common-password 2>/dev/null \
      && pass "pam_unix minlen: common-password 설정됨" \
      || warn "pam_unix minlen: 미설정"
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# 결과 요약
# ══════════════════════════════════════════════════════════════════════════════
print_summary() {
  echo ""
  echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD} 검증 결과 요약${NC}"
  echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${GREEN}PASS${NC} : $PASS"
  echo -e "  ${RED}FAIL${NC} : $FAIL"
  echo -e "  ${YELLOW}WARN${NC} : $WARN"
  echo -e "  ${CYAN}SKIP${NC} : $SKIP"
  echo ""
  local total=$((PASS+FAIL))
  [ "$total" -gt 0 ] && printf "  통과율 : %d%%\n" $((PASS*100/total))
  echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  if [ "$FAIL" -eq 0 ]; then
    echo -e "  결과 : ${GREEN}${BOLD}필수 항목 모두 통과${NC}"
  else
    echo -e "  결과 : ${RED}${BOLD}${FAIL}개 항목 조치 필요${NC}"
  fi
  echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ══════════════════════════════════════════════════════════════════════════════
# 실행
# ══════════════════════════════════════════════════════════════════════════════
[ "$EUID" -ne 0 ] && { echo "ERROR: root 권한으로 실행하세요."; exit 1; }

detect_os

if ! is_supported_os; then
  echo "ERROR: 지원하지 않는 OS입니다: ${OS_ID} ${OS_VERSION}" >&2
  echo "지원 OS: CentOS 7 / Rocky 8·9·10 / Ubuntu 18·20·22·24·26" >&2
  exit 2
fi

echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD} 보안 OS 하드닝 적용 결과 검증${NC}"
echo -e " OS  : ${BOLD}${OS_ID} ${OS_VERSION}${NC}"
echo -e " 일시: $(date '+%Y-%m-%d %H:%M:%S')"
echo -e " 옵션: world-writable=$([ $SKIP_WORLDWRITABLE -eq 1 ] && echo '생략' || echo '검사')"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

check_platform
check_system_basic
check_file_perms
check_hardening_files
check_ssh
check_pam
check_sysctl
check_limits
check_logging
check_reexecution_stability
check_services

if is_rhel; then
  check_rhel_extra
elif is_ubuntu; then
  check_ubuntu_extra
fi

print_summary
