#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# [제거됨]
# - YUM repo 설정/패키지 설치(chrony 포함) 제거
# - rsyslog 설정 제거
# - /etc/profile (HISTTIMEFORMAT/TMOUT) 수정 제거
# - SELinux 비활성화/설정 변경 제거
# - vim, bash 편의 설정 제거
# 그 외는 기존 동작 유지

configure_etc_perms() {
  # 핵심 /etc 권한 하드닝 (현상 유지)
  set_file_perms /etc/passwd root:root 644
  set_file_perms /etc/shadow root:root 400
  set_file_perms /etc/hosts  root:root 600

  # /usr/bin/su 제한 (wheel)
  if ! getent group wheel >/dev/null; then
    groupadd wheel || true
  fi
  set_file_perms /usr/bin/su root:wheel 4750
}

configure_file_permissions() {
  # 특권 비트/권한 정리 (현상 유지, 대상 없으면 무시)
  for t in /sbin/unix_chkpwd /usr/bin/newgrp /usr/bin/at; do
    [ -e "$t" ] && chmod -s "$t" || true
  done

  # 선택 도구 권한 보수 (존재 시에만)
  for f in /usr/bin/perl /usr/bin/screen /usr/bin/wget /usr/bin/curl; do
    [ -f "$f" ] && chmod 700 "$f" || true
  done
}

configure_motd() {
  cat > /etc/motd <<'EOF'
********************************************************************
* 본 시스템은 허가된 사용자만 이용하실 수 있습니다.               *
* 부당한 접속/정보 변경·유출 시 관련 법령에 따라 처벌될 수 있습니다. *
********************************************************************
EOF
}

configure_sysctl() {
  # 네트워크/소켓 튜닝 (현상 유지)
  cat > /etc/sysctl.conf <<'EOF'
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
  sysctl -p || true
}

configure_limits() {
  cat > /etc/security/limits.conf <<'EOF'
* soft nofile 61200
* hard nofile 61200
* soft nproc  61200
* hard nproc  61200
EOF
}

# 실행
configure_etc_perms
configure_file_permissions
configure_motd
configure_sysctl
configure_limits