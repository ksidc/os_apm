#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Repository setup must run before any package installation because the CentOS 7 mirrors are EOL.
configure_yum_repos() {
  log_info "[SYSTEM] Configuring CentOS Vault repositories"
  backup_file /etc/yum.repos.d/CentOS-Base.repo
  cat <<'EOF' > /etc/yum.repos.d/CentOS-Base.repo
# CentOS-Base.repo
#
# Legacy vault repositories for CentOS 7.9.2009
#
[base]
name=CentOS-$releasever - Base
baseurl=http://vault.centos.org/7.9.2009/os/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[updates]
name=CentOS-$releasever - Updates
baseurl=http://vault.centos.org/7.9.2009/updates/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[extras]
name=CentOS-$releasever - Extras
baseurl=http://vault.centos.org/7.9.2009/extras/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[centosplus]
name=CentOS-$releasever - Plus
baseurl=http://vault.centos.org/7.9.2009/centosplus/$basearch/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOF
  yum clean all && yum makecache || log_error "configure_yum_repos" "Failed to refresh YUM cache"
}

install_packages() {
  log_info "[SYSTEM] Installing baseline packages"
  yum install -y epel-release || log_info "[WARN] epel-release install failed (ignored)"

  local pkgs=(lsof net-tools psmisc screen iftop smartmontools vim unzip wget)
  for pkg in "${pkgs[@]}"; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
      log_info "[SYSTEM] $pkg already installed"
    else
      yum install -y "$pkg" || log_error "install_packages" "Failed to install $pkg"
    fi
  done

  yum -y update || log_error "install_packages" "System update failed"
}

configure_ntp() {
  log_info "[SYSTEM] Configuring chrony for NTP"
  backup_file /etc/chrony.conf /etc/cron.d/chrony_makestep
  yum install -y chrony || { log_error "configure_ntp" "Failed to install chrony"; exit 1; }
  systemctl enable --now chronyd || { log_error "configure_ntp" "Failed to enable/start chronyd"; exit 1; }
  sed -i '/^server /d' /etc/chrony.conf
  echo "server $NTP_SERVER iburst" >> /etc/chrony.conf
  restarts_needed["chronyd"]=1
  chronyc makestep || log_error "configure_ntp" "Immediate time sync failed"
  if [ ! -f /etc/cron.d/chrony_makestep ]; then
    echo "0 4 * * * root /usr/bin/chronyc makestep" > /etc/cron.d/chrony_makestep
    chmod 600 /etc/cron.d/chrony_makestep
    log_info "[SYSTEM] Added chrony makestep daily cron job"
  else
    log_info "[SYSTEM] chrony makestep cron job already present"
  fi
}

configure_history_timeout() {
  log_info "[SYSTEM] Enforcing shell history timestamp and timeout"
  backup_file /etc/profile
  grep -q HISTTIMEFORMAT /etc/profile || echo 'export HISTTIMEFORMAT="%Y-%m-%d[%H:%M:%S] "' >> /etc/profile
  grep -q TMOUT /etc/profile || echo 'export TMOUT=600' >> /etc/profile
}

configure_etc_perms() {
  log_info "[SYSTEM] Hardening core /etc files"
  backup_file /etc/passwd /etc/shadow /etc/hosts /usr/bin/su
  set_file_perms /etc/passwd root:root 644
  set_file_perms /etc/shadow root:root 400
  set_file_perms /etc/hosts root:root 600
  set_file_perms /usr/bin/su root:wheel 4750
  if ! getent group wheel >/dev/null; then
    groupadd wheel || log_error "configure_etc_perms" "Failed to create wheel group"
  fi
}

configure_file_permissions() {
  log_info "[SYSTEM] Adjusting privileged binary permissions"
  backup_file /sbin/unix_chkpwd /usr/bin/newgrp /usr/bin/perl /usr/bin/screen /usr/bin/wget /usr/bin/curl /usr/bin/at

  local setuid_targets=(/sbin/unix_chkpwd /usr/bin/newgrp /usr/bin/at)
  for target in "${setuid_targets[@]}"; do
    if [ -e "$target" ]; then
      chmod -s "$target" || log_error "configure_file_permissions" "Failed to drop setuid bit on $target"
    else
      log_info "[SYSTEM] $target not found, skipping setuid removal"
    fi
  done

  for f in /usr/bin/perl /usr/bin/screen /usr/bin/wget /usr/bin/curl; do
    if [ -f "$f" ]; then
      chmod 700 "$f" || log_error "configure_file_permissions" "Failed to set permissions on $f"
    else
      log_info "[SYSTEM] $f not found, skipping permission tightening"
    fi
  done
}

configure_motd() {
  log_info "[SYSTEM] Updating MOTD banner"
  backup_file /etc/motd
  cat <<'EOF' > /etc/motd
********************************************************************
*                                                                  *
* 이 시스템은 허가된 사용자만 사용할 수 있습니다.                 *
* 무단 접근 시 관련 법령에 따라 처벌될 수 있습니다.                *
*                                                                  *
* This system is for the use of authorized users only. Usage may   *
* be monitored and disclosed to law enforcement if abuse is found. *
*                                                                  *
********************************************************************
EOF
}

configure_bash_vim() {
  log_info "[SYSTEM] Applying root shell conveniences"
  backup_file /root/.bashrc /root/.vimrc
  local aliases=("alias vi='vim'" "alias grep='grep --color=auto'" "alias ll='ls -alF --color=tty'")
  for a in "${aliases[@]}"; do
    grep -qF "$a" /root/.bashrc || echo "$a" >> /root/.bashrc
  done
  cat <<'EOF' > /root/.vimrc
set ignorecase
set cindent
set sw=4 ts=4 sts=4 shiftwidth=4
set showmode bg=dark paste ruler expandtab linebreak wrap showcmd
set laststatus=2 textwidth=80 wm=1 smartcase smartindent ttyfast
EOF
}

disable_selinux() {
  log_info "[SYSTEM] Disabling SELinux"
  backup_file /etc/selinux/config
  setenforce 0 || log_error "disable_selinux" "setenforce failed"
  sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
}

configure_rsyslog() {
  log_info "[SYSTEM] Updating rsyslog forwarding"
  backup_file /etc/rsyslog.conf
  set_file_perms /etc/rsyslog.conf root:root 640
  local line="*.* @$RSYSLOG_SERVER"
  grep -qxF "$line" /etc/rsyslog.conf || echo "$line" >> /etc/rsyslog.conf
  restarts_needed["rsyslog"]=1
}

configure_sysctl() {
  log_info "[SYSTEM] Applying sysctl hardening"
  backup_file /etc/sysctl.conf
  cat <<'EOF' > /etc/sysctl.conf
# IPv6 disable
net.ipv6.conf.all.disable_ipv6 = 1
# ICMP broadcast ignore
net.ipv4.icmp_echo_ignore_broadcasts = 1
# TCP memory tuning
net.ipv4.tcp_rmem = 4096 10000000 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
# TCP state tuning
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 1800
net.ipv4.tcp_max_syn_backlog = 4096
# Socket buffers
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.somaxconn = 10240
# Dynamic port range
net.ipv4.ip_local_port_range = 4000 65535
EOF
  sysctl -p || log_error "configure_sysctl" "sysctl apply failed"
}

configure_limits() {
  log_info "[SYSTEM] Hardening /etc/security/limits.conf"
  backup_file /etc/security/limits.conf
  cat <<'EOF' > /etc/security/limits.conf
* soft nofile 61200
* hard nofile 61200
* soft nproc 61200
* hard nproc 61200
EOF
}

log_info "[SYSTEM] System configuration start"
configure_yum_repos
install_packages
configure_ntp
configure_history_timeout
configure_etc_perms
configure_file_permissions
configure_motd
configure_bash_vim
disable_selinux
configure_rsyslog
configure_sysctl
configure_limits
log_info "[SYSTEM] System configuration complete"
