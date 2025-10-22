#!/bin/bash
#
# Ubuntu 24.04 시스템 기본 설정

if [[ -z "${SECURE_OS_COMMON_LOADED:-}" ]]; then
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
  systemctl disable --now unattended-upgrades >/dev/null 2>&1 || log_warn "unattended-upgrades 비활성화에 실패했습니다."
  log_info "APT 자동 업데이트 비활성화를 완료했습니다."
}

perform_system_update() {
  log_info "apt update/upgrade 실행"
  wait_for_apt_lock
  apt update || { log_error "perform_system_update" "apt update 실패"; exit 1; }
  apt upgrade -y || { log_error "perform_system_update" "apt upgrade 실패"; exit 1; }
  log_info "패키지 목록 갱신 및 업그레이드를 완료했습니다."
}

install_base_packages() {
  log_info "install_base_packages 시작"
  local pkg
  local packages=(lsof net-tools psmisc screen iftop smartmontools vim unzip wget iputils-ping lrzsz ufw rsyslog)
  wait_for_apt_lock
  for pkg in "${packages[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      log_info "패키지 '$pkg'는 이미 설치되어 있습니다."
    else
      apt install -y "$pkg" || { log_error "install_base_packages" "$pkg 설치 실패"; exit 1; }
      log_info "패키지 '$pkg'를 설치했습니다."
    fi
  done
}

configure_ntp() {
  log_info "configure_ntp 시작"
  if dpkg -s chrony >/dev/null 2>&1; then
    backup_file /etc/chrony/chrony.conf
    sed -i '/^pool /d' /etc/chrony/chrony.conf
    echo "pool $NTP_SERVER iburst" >> /etc/chrony/chrony.conf
    systemctl enable --now chrony || { log_error "configure_ntp" "chrony 시작 실패"; exit 1; }
    chronyc makestep || log_warn "chrony 시간 동기화에 실패했습니다."
  else
    backup_file /etc/systemd/timesyncd.conf
    if grep -q '^NTP=' /etc/systemd/timesyncd.conf; then
      sed -i "s/^NTP=.*/NTP=$NTP_SERVER/" /etc/systemd/timesyncd.conf
    else
      sed -i "s/^#\?NTP=.*/NTP=$NTP_SERVER/" /etc/systemd/timesyncd.conf
    fi
    systemctl enable --now systemd-timesyncd || { log_error "configure_ntp" "systemd-timesyncd 시작 실패"; exit 1; }
    timedatectl set-ntp true || log_warn "NTP 활성화에 실패했습니다."
  fi
  log_info "NTP 서버를 $NTP_SERVER 로 설정했습니다."
}

configure_history_timeout() {
  log_info "configure_history_timeout 시작"
  backup_file /etc/profile
  if ! grep -q 'HISTTIMEFORMAT' /etc/profile; then
    echo 'export HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S "' >> /etc/profile
  fi
  if ! grep -q 'TMOUT=' /etc/profile; then
    echo 'export TMOUT=600' >> /etc/profile
  fi
  log_info "/etc/profile에 히스토리 타임스탬프 및 세션 타임아웃을 설정했습니다."
}

configure_etc_perms() {
  log_info "configure_etc_perms 시작"
  backup_file /etc/passwd /etc/shadow /etc/hosts /usr/bin/su
  set_file_perms /etc/passwd root:root 644
  set_file_perms /etc/shadow root:shadow 640
  set_file_perms /etc/hosts root:root 644
  set_file_perms /usr/bin/su root:adm 4750
  if ! getent group adm >/dev/null; then
    groupadd adm
    log_info "adm 그룹을 생성했습니다."
  fi
}

configure_security_settings() {
  log_info "configure_security_settings 시작"
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

  backup_file /usr/bin/newgrp /usr/bin/perl /usr/bin/screen /usr/bin/wget /usr/bin/curl /sbin/unix_chkpwd /usr/bin/at

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
  log_info "주요 파일 및 임시 디렉터리 권한을 점검했습니다."
}

configure_motd() {
  log_info "configure_motd 시작"
  backup_file /etc/motd
  cat <<'EOF' > /etc/motd
********************************************************************
* 이 시스템은 허가된 사용자만 사용할 수 있습니다.                  *
* 무단 접속 또는 정보 유출 시 관련 법령에 따라 처벌됩니다.          *
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
  local sysctl_file="/etc/sysctl.d/99-secure-os.conf"
  cat <<'EOF' > "$sysctl_file"
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
  sysctl --system >/dev/null 2>&1 || sysctl -p "$sysctl_file"
  log_info "$sysctl_file 에 커널 파라미터를 적용했습니다."
}

configure_limits() {
  log_info "configure_limits 시작"
  local limits_file="/etc/security/limits.d/99-secure-os.conf"
  mkdir -p /etc/security/limits.d
  cat <<'EOF' > "$limits_file"
* soft nofile 61200
* hard nofile 61200
* soft nproc 61200
* hard nproc 61200
EOF
  log_info "$limits_file 에 자원 제한을 설정했습니다."
}

perform_system_hardening() {
  log_info "시스템 설정 작업 시작"
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
  log_info "시스템 설정 작업 완료"
}

perform_system_hardening
