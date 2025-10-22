#!/bin/bash
#
# Ubuntu 20.04 system-level hardening tasks.

if [[ -z "${SECURE_OS_COMMON_LOADED:-}" ]]; then
  # shellcheck source=./common.sh
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
fi

if [[ -n "${SECURE_OS_SYSTEM_LOADED:-}" ]]; then
  return 0
fi
readonly SECURE_OS_SYSTEM_LOADED=1

SYSTEM_TUNING_SUMMARY="미적용"

disable_auto_updates() {
  log_info "disable_auto_updates 시작"
  backup_file /etc/apt/apt.conf.d/20auto-upgrades
  cat <<'EOF' > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
EOF
  if ! systemctl disable --now unattended-upgrades >/dev/null 2>&1; then
    log_warn "unattended-upgrades 비활성화 실패"
  fi
  log_info "자동 업데이트 비활성화 완료"
}

perform_system_update() {
  log_info "apt update/upgrade 실행"
  wait_for_apt_lock
  apt update || { log_error "perform_system_update" "apt update 실패"; exit 1; }
  apt upgrade -y || { log_error "perform_system_update" "apt upgrade 실패"; exit 1; }
}

install_base_packages() {
  log_info "기본 패키지 설치 시작"
  local packages=(
    lsof net-tools psmisc screen iftop smartmontools vim unzip wget
    iputils-ping lrzsz ufw rsyslog
  )
  local pkg
  wait_for_apt_lock
  for pkg in "${packages[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      log_info "패키지 이미 설치됨: $pkg"
    else
      apt install -y "$pkg" || { log_error "install_base_packages" "$pkg 설치 실패"; exit 1; }
      log_info "패키지 설치 완료: $pkg"
    fi
  done
}

configure_ntp() {
  log_info "configure_ntp 시작"
  if dpkg -s chrony >/dev/null 2>&1; then
    backup_file /etc/chrony/chrony.conf
    sed -i '/^pool /d' /etc/chrony/chrony.conf
    echo "pool $NTP_SERVER iburst" >> /etc/chrony/chrony.conf
    systemctl enable --now chrony || { log_error "configure_ntp" "chrony 서비스 시작 실패"; exit 1; }
    chronyc makestep || log_warn "chrony 시간 동기화 실패"
  else
    backup_file /etc/systemd/timesyncd.conf
    if grep -q '^NTP=' /etc/systemd/timesyncd.conf; then
      sed -i "s/^NTP=.*/NTP=$NTP_SERVER/" /etc/systemd/timesyncd.conf
    else
      sed -i "s/^#\?NTP=.*/NTP=$NTP_SERVER/" /etc/systemd/timesyncd.conf
    fi
    systemctl enable --now systemd-timesyncd || { log_error "configure_ntp" "timesyncd 서비스 시작 실패"; exit 1; }
    timedatectl set-ntp true || log_warn "timedatectl set-ntp true 실패"
  fi
  log_info "NTP 서버 설정 완료: $NTP_SERVER"
}

configure_history_timeout() {
  log_info "configure_history_timeout 시작"
  backup_file /etc/profile
  if ! grep -q 'HISTTIMEFORMAT' /etc/profile; then
    echo 'export HISTTIMEFORMAT="%Y-%m-%d[%H:%M:%S] "' >> /etc/profile
  fi
  if ! grep -q 'TMOUT=' /etc/profile; then
    echo 'export TMOUT=600' >> /etc/profile
  fi
}

configure_etc_perms() {
  log_info "configure_etc_perms 시작"
  backup_file /etc/passwd /etc/shadow /etc/hosts /usr/bin/su
  set_file_perms /etc/passwd root:root 644
  set_file_perms /etc/shadow root:shadow 640
  set_file_perms /etc/hosts root:root 644
  set_file_perms /usr/bin/su root:sudo 4750
  if ! getent group adm >/dev/null; then
    groupadd adm || { log_error "configure_etc_perms" "adm 그룹 생성 실패"; exit 1; }
    log_info "adm 그룹을 생성했습니다."
  fi
  if [[ "$(stat -c '%a' /usr/bin/su)" != "4750" ]] || [[ "$(stat -c '%U:%G' /usr/bin/su)" != "root:sudo" ]]; then
    log_error "configure_etc_perms" "/usr/bin/su 권한 또는 소유자 설정 실패"
    exit 1
  fi
}

configure_security_settings() {
  log_info "configure_security_settings 시작"
  backup_file /etc/passwd /etc/shadow /etc/hosts /usr/bin/newgrp /usr/bin/perl /usr/bin/screen /usr/bin/wget /usr/bin/curl /sbin/unix_chkpwd /usr/bin/at

  set_file_perms /etc/passwd root:root 644
  set_file_perms /etc/shadow root:root 400
  set_file_perms /etc/hosts root:root 600

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
  log_info "주요 SUID/Sticky bit 조정 완료"
}

configure_motd() {
  log_info "configure_motd 시작"
  backup_file /etc/motd
  cat <<'EOF' > /etc/motd
********************************************************************
* 본 시스템은 승인된 사용자만 사용할 수 있습니다.               *
* 무단 접근 또는 정보 유출 시 관련 법령에 따라 처벌될 수 있습니다. *
********************************************************************
EOF
}

configure_bash_vim() {
  log_info "configure_bash_vim 시작"
  backup_file /root/.bashrc /root/.vimrc
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
  log_info "ensure_sshd_runtime_dir 시작"
  mkdir -p /run/sshd
  chown root:root /run/sshd
  chmod 755 /run/sshd
}

configure_sysctl() {
  log_info "configure_sysctl 시작"
  backup_file /etc/sysctl.conf
  cat <<'EOF' > /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.tcp_rmem = 4096 10000000 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 1800
net.ipv4.tcp_max_syn_backlog = 4096
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.somaxconn = 10240
net.ipv4.ip_local_port_range = 4000 65535
EOF
  sysctl -p >/dev/null 2>&1 || log_warn "sysctl 적용 중 경고 발생"
}

configure_limits() {
  log_info "configure_limits 시작"
  backup_file /etc/security/limits.conf
  cat <<'EOF' > /etc/security/limits.conf
* soft nofile 61200
* hard nofile 61200
* soft nproc 61200
* hard nproc 61200
EOF
}

perform_system_hardening() {
  log_info "시스템 기본 설정 작업 시작"
  disable_auto_updates
  perform_system_update
  install_base_packages
  configure_ntp
  configure_history_timeout
  configure_etc_perms
  configure_security_settings
  configure_motd
  configure_bash_vim
  ensure_sshd_runtime_dir
  configure_sysctl
  configure_limits
  SYSTEM_TUNING_SUMMARY="적용 완료"
  log_info "시스템 기본 설정 작업 완료"
}

perform_system_hardening
