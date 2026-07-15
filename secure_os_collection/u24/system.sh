#!/bin/bash
#
# Ubuntu 24.04 시스템 기본 설정 (2026 개선판)

if [[ -z "${SECURE_OS_COMMON_LOADED:-}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
fi

if [[ -n "${SECURE_OS_SYSTEM_LOADED:-}" ]]; then
  return 0
fi
readonly SECURE_OS_SYSTEM_LOADED=1

disable_auto_updates() {
  cat <<'EOF' > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
EOF
  systemctl disable --now unattended-upgrades >/dev/null 2>&1 || true
}

perform_system_update() {
  wait_for_apt_lock
  apt update -y || { echo "ERROR: apt update 실패" >&2; exit 1; }
  echo "Y 선택 시 apt upgrade 전체 업데이트를 실행합니다."
  echo "커널 또는 Ubuntu 패키지 버전 고정이 필요하면 N을 선택하세요."
  if prompt_yes_no "apt upgrade를 진행하시겠습니까?"; then
    apt upgrade -y || { echo "ERROR: apt upgrade 실패" >&2; exit 1; }
    SUMMARY+="패키지 업데이트: 적용됨\n"
  else
    SUMMARY+="패키지 업데이트: 건너뜀 (사용자 선택)\n"
  fi
}

install_base_packages() {
  local pkg
local packages=(lsof net-tools psmisc screen iftop smartmontools vim unzip wget iputils-ping lrzsz ufw rsyslog sysstat)
  wait_for_apt_lock
  for pkg in "${packages[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      apt install -y "$pkg" || { echo "ERROR: $pkg 설치 실패" >&2; exit 1; }
    fi
  done
}

configure_ntp() {
  if dpkg -s chrony >/dev/null 2>&1; then
    sed -i '/^pool /d' /etc/chrony/chrony.conf
    echo "pool $NTP_SERVER iburst" >> /etc/chrony/chrony.conf
    systemctl enable --now chrony || { echo "ERROR: chrony 시작 실패" >&2; exit 1; }
    chronyc makestep || true
  else
    if grep -q '^NTP=' /etc/systemd/timesyncd.conf; then
      sed -i "s/^NTP=.*/NTP=$NTP_SERVER/" /etc/systemd/timesyncd.conf
    else
      sed -i "s/^#\?NTP=.*/NTP=$NTP_SERVER/" /etc/systemd/timesyncd.conf
    fi
    systemctl enable --now systemd-timesyncd || { echo "ERROR: systemd-timesyncd 시작 실패" >&2; exit 1; }
    timedatectl set-ntp true || true
  fi
  timedatectl set-timezone Asia/Seoul || true
}

configure_sysstat() {
  local unit_enabled=0

  if ! dpkg -s sysstat >/dev/null 2>&1; then
    echo "ERROR: sysstat 패키지가 설치되어 있지 않습니다." >&2
    exit 1
  fi

  local default_conf="/etc/default/sysstat"
  if [[ -f "$default_conf" ]]; then
    if grep -q '^ENABLED=' "$default_conf"; then
      sed -i 's/^ENABLED=.*/ENABLED="true"/' "$default_conf"
    else
      echo 'ENABLED="true"' >> "$default_conf"
    fi
  else
    :
  fi

  if systemctl list-unit-files | grep '^sysstat.service' >/dev/null; then
    systemctl enable --now sysstat >/dev/null 2>&1 || {
      echo "ERROR: sysstat 서비스 활성화 실패" >&2
      exit 1
    }
    unit_enabled=1
  fi

  if systemctl list-unit-files | grep '^sysstat-collect.timer' >/dev/null; then
    systemctl enable --now sysstat-collect.timer >/dev/null 2>&1 || {
      echo "ERROR: sysstat-collect.timer 활성화 실패" >&2
      exit 1
    }
    unit_enabled=1
  fi

  if systemctl list-unit-files | grep '^sysstat-summary.timer' >/dev/null; then
    systemctl enable --now sysstat-summary.timer >/dev/null 2>&1 || {
      echo "ERROR: sysstat-summary.timer 활성화 실패" >&2
      exit 1
    }
    unit_enabled=1
  fi

  if [ "$unit_enabled" -eq 0 ]; then
    echo "ERROR: 활성화할 sysstat 서비스 또는 timer 유닛을 찾지 못했습니다." >&2
    exit 1
  fi

}

configure_history_timeout() {
  sed -i '/^[[:space:]]*\(export[[:space:]]\+\)\?HISTTIMEFORMAT=/d; /^[[:space:]]*\(export[[:space:]]\+\)\?TMOUT=/d' /etc/profile
  echo 'export HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S "' >> /etc/profile
  echo 'export TMOUT=600' >> /etc/profile
}

# ────────────────────────────────────────────────────────────
# [2026 수정] /etc/hosts 권한 644 → 600
# ────────────────────────────────────────────────────────────
configure_etc_perms() {
  set_file_perms /etc/passwd root:root 644
  set_file_perms /etc/shadow root:root 400
  set_file_perms /etc/hosts root:root 600
  set_file_perms /usr/bin/su root:sudo 4750
  if ! getent group adm >/dev/null; then
    groupadd adm
  fi
}

configure_security_settings() {
  local removable_suid=(
    /sbin/dump
    /usr/bin/lpq-lpd
    /usr/bin/lpr
    /usr/sbin/lpc
    /usr/bin/lpr-lpd
    /usr/sbin/lpc-lpd
    /usr/bin/lprm
    /usr/sbin/traceroute
    /usr/bin/lpq
    /usr/bin/lprm-lpd
    /usr/bin/perl
    /usr/bin/screen
    /usr/bin/wget
    /usr/bin/curl
  )
  local essential_suid=(
    /usr/bin/newgrp
    /sbin/unix_chkpwd
    /usr/bin/at
  )

  local file
  for file in "${removable_suid[@]}"; do
    if [[ -e "$file" ]]; then
      chmod -s "$file"
      set_file_perms "$file" root:root 755
    fi
  done

  for file in "${essential_suid[@]}"; do
    if [[ -e "$file" ]]; then
      set_file_perms "$file" root:root 4755
    fi
  done

  set_file_perms /tmp root:root 1777
  set_file_perms /var/tmp root:root 1777
}

configure_motd() {

  SCRIPT_VERSION="unknown"
  if [[ -f /usr/local/src/secure_os_collection/version.conf ]]; then
    source /usr/local/src/secure_os_collection/version.conf
  fi

  cat <<EOF > /etc/motd
********************************************************************
*                                                                  *
*  이 시스템은 허가된 사용자만 사용할 수 있습니다.              *
*  무단 접근 및 정보 탈취/변조 행위는 관련 법령에 따라 처벌됩니다. *
*                                                                  *
*  This system is for the use of authorized users only.  Usage of   *
*  this system may be monitored and recorded by system personnel.   *
*                                                                  *
*  Anyone using this system expressly consents to such monitoring   *
*  and is advised that if such monitoring reveals possible          *
*  evidence of criminal activity, system personnel may provide the  *
*  evidence from such monitoring to law enforcement officials.      *
*                                                                  *
*  Apply version ${SCRIPT_VERSION}                                 *
********************************************************************
EOF
}

configure_bash_vim() {
  local aliases=(
    "alias vi='vim'"
    "alias grep='grep --color=auto'"
    "alias ll='ls -alF --color=tty'"
  )
  local alias_line
  for alias_line in "${aliases[@]}"; do
    if ! grep -qxF "$alias_line" /root/.bashrc 2>/dev/null; then
      echo "$alias_line" >> /root/.bashrc
    fi
  done

  cat <<'EOF' > /root/.vimrc
set ignorecase
set cindent
set sw=4 ts=4 sts=4 shiftwidth=4
set showmode bg=dark paste ruler expandtab linebreak wrap showcmd
set laststatus=2 textwidth=80 wm=1 smartcase smartindent ttyfast
EOF
}

ensure_sshd_runtime_dir() {
  mkdir -p /run/sshd
  chown root:root /run/sshd
  chmod 755 /run/sshd
}

configure_sysctl() {
  local sysctl_file="/etc/sysctl.d/99-secure-os.conf"
  cat <<'EOF' > "$sysctl_file"
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.tcp_rmem = 4096 10000000 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 1800
net.ipv4.tcp_max_syn_backlog = 4096
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.somaxconn = 10240
net.ipv4.ip_local_port_range = 4000 65535
EOF
  sysctl --system >/dev/null 2>&1 || sysctl -p "$sysctl_file"
}

configure_limits() {
  local limits_file="/etc/security/limits.d/99-secure-os.conf"
  mkdir -p /etc/security/limits.d
  cat <<'EOF' > "$limits_file"
* soft nofile 61200
* hard nofile 61200
* soft nproc 61200
* hard nproc 61200
EOF
}

# ────────────────────────────────────────────────────────────
# [2026 신규] U-30: UMASK 설정
# ────────────────────────────────────────────────────────────
configure_umask() {
  for f in /etc/profile /etc/bash.bashrc; do
    if [[ -f "$f" ]]; then
      if grep -q 'umask[[:space:]]\+[0-9]' "$f"; then
        sed -i 's/umask[[:space:]]\+[0-9]\+/umask 022/g' "$f"
      else
        echo 'umask 022' >> "$f"
      fi
    fi
  done
}

# ────────────────────────────────────────────────────────────
# [2026 신규] U-37: /etc/crontab 권한 강화
# ────────────────────────────────────────────────────────────
configure_crontab_perms() {
  if [[ -f /etc/crontab ]]; then
    chown root:root /etc/crontab
    chmod 640 /etc/crontab
  fi
  if [[ -f /etc/cron.deny ]]; then
    chown root:root /etc/cron.deny
    chmod 640 /etc/cron.deny
  fi
}

configure_snoopy() {
  if grep -q 'libsnoopy' /etc/ld.so.preload 2>/dev/null; then
    return 0
  fi
  wait_for_apt_lock
  apt-get install -y snoopy || { echo "ERROR: snoopy 설치 실패" >&2; return 1; }
  local lib; lib=$(find /usr/lib /usr/local/lib /usr/lib64 /usr/local/lib64 -maxdepth 4 -name 'libsnoopy.so' 2>/dev/null | head -1)
  [ -z "$lib" ] && { echo "ERROR: libsnoopy.so 탐색 실패" >&2; return 1; }
  grep -qxF "$lib" /etc/ld.so.preload 2>/dev/null || echo "$lib" >> /etc/ld.so.preload
  ldconfig
  cat > /etc/snoopy.ini << 'SNOOPY_CONF'
[snoopy]
message_format = "[login:%{login}][uid:%{uid}][user:%{username}][tty:%{tty}][cwd:%{cwd}]: %{cmdline}"
syslog_facility = LOG_AUTH
syslog_level = LOG_INFO
SNOOPY_CONF
}

# ────────────────────────────────────────────────────────────
# [2026 신규] U-25: world writable 파일 제거
# ────────────────────────────────────────────────────────────
fix_world_writable() {
  local cnt=0
  while IFS= read -r f; do
    chmod o-w "$f" \
      || { echo "ERROR: $f 권한 변경 실패" >&2; return 1; }
    cnt=$((cnt + 1))
  done < <(find / -xdev -type f -perm -0002 ! -path '/proc/*' ! -path '/sys/*' ! -path '/dev/*' 2>/dev/null)
}

perform_system_hardening() {
  disable_auto_updates
  perform_system_update
  install_base_packages
  configure_ntp
  configure_sysstat
  configure_history_timeout
  configure_etc_perms
  configure_security_settings
  configure_motd
  configure_bash_vim
  ensure_sshd_runtime_dir
  configure_sysctl
  configure_limits
  configure_umask
  configure_crontab_perms
  fix_world_writable
  configure_snoopy
}

perform_system_hardening
