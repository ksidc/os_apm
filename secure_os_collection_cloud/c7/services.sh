#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# [제거 대상 아님] 항목만 유지
# - finger 비활성화
# - anonymous FTP(vsftpd) 차단
# - r 계열(rsh/rlogin/rexec) 비활성화
# - cron/at 권한 강화
# - xinetd echo/daytime/chargen 비활성화
# - autofs, NIS 관련 비활성화
# - tftp/talk 비활성화
# - postfix VRFY 비활성화 (postfix 설치된 경우에만)

disable_finger() {
  rpm -q finger >/dev/null 2>&1 && systemctl disable --now finger || true
}

disable_anonymous_ftp() {
  if rpm -q vsftpd >/dev/null 2>&1; then
    [ -f /etc/vsftpd/vsftpd.conf ] && sed -i 's/^anonymous_enable=.*/anonymous_enable=NO/' /etc/vsftpd/vsftpd.conf || true
    systemctl restart vsftpd >/dev/null 2>&1 || true
  fi
}

disable_r_services() {
  for svc in rsh rlogin rexec; do
    rpm -q "$svc" >/dev/null 2>&1 && systemctl disable --now "$svc" || true
  done
}

configure_cron_permissions() {
  for f in /etc/cron.allow /etc/cron.deny /etc/at.allow /etc/at.deny; do
    [ -e "$f" ] || touch "$f"
    set_file_perms "$f" root:root 640
  done
}

disable_dos_services() {
  for svc in echo discard daytime chargen; do
    if [ -f "/etc/xinetd.d/$svc" ]; then
      sed -i 's/disable *= *no/disable = yes/' "/etc/xinetd.d/$svc" || true
    fi
  done
  systemctl restart xinetd >/dev/null 2>&1 || true
}

remove_automountd() {
  rpm -q autofs >/dev/null 2>&1 && systemctl disable --now autofs || true
}

disable_nis() {
  local services=(ypbind ypserv ypxfrd rpc.yppasswdd rpc.ypupdated)
  for svc in "${services[@]}"; do
    rpm -q "$svc" >/dev/null 2>&1 && systemctl disable --now "$svc" || true
  done
}

configure_ftp_shell() {
  # ftp 계정 shell 제한 (존재 시)
  if getent passwd ftp >/dev/null 2>&1; then
    sed -i '/^ftp:/s#/sbin/nologin#/bin/false#' /etc/passwd || true
  fi
}

disable_tftp_talk() {
  for svc in tftp talk; do
    rpm -q "$svc" >/dev/null 2>&1 && systemctl disable --now "$svc" || true
  done
}

configure_smtp_security() {
  # postfix 설치된 경우에만 적용
  if rpm -q postfix >/dev/null 2>&1; then
    if ! grep -qE '^disable_vrfy_command\s*=\s*yes' /etc/postfix/main.cf 2>/dev/null; then
      if grep -q '^disable_vrfy_command' /etc/postfix/main.cf 2>/dev/null; then
        sed -i 's/^disable_vrfy_command.*/disable_vrfy_command = yes/' /etc/postfix/main.cf || true
      else
        echo "disable_vrfy_command = yes" >> /etc/postfix/main.cf || true
      fi
    fi
    postconf -e "inet_protocols = ipv4" || true
    postconf -e "inet_interfaces = 127.0.0.1" || true
    systemctl reload postfix >/dev/null 2>&1 || systemctl restart postfix >/dev/null 2>&1 || true
  fi
}

# 실행
disable_finger
disable_anonymous_ftp
disable_r_services
configure_cron_permissions
disable_dos_services
remove_automountd
disable_nis
configure_ftp_shell
disable_tftp_talk
configure_smtp_security