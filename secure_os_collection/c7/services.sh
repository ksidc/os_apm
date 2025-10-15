#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

disable_finger() {
  log_info "[SERVICES] Disabling finger service"
  if rpm -q finger >/dev/null 2>&1; then
    systemctl disable --now finger >/dev/null 2>&1 || log_error "disable_finger" "Failed to disable finger"
  else
    log_info "[SERVICES] finger not installed"
  fi
}

disable_anonymous_ftp() {
  log_info "[SERVICES] Disabling anonymous FTP (vsftpd)"
  if rpm -q vsftpd >/dev/null 2>&1; then
    backup_file /etc/vsftpd/vsftpd.conf
    sed -i 's/^anonymous_enable=.*/anonymous_enable=NO/' /etc/vsftpd/vsftpd.conf
    systemctl restart vsftpd >/dev/null 2>&1 || log_error "disable_anonymous_ftp" "Failed to restart vsftpd"
  else
    log_info "[SERVICES] vsftpd not installed"
  fi
}

disable_r_services() {
  log_info "[SERVICES] Disabling legacy r-services"
  local services=(rsh rlogin rexec)
  for svc in "${services[@]}"; do
    if rpm -q "$svc" >/dev/null 2>&1; then
      systemctl disable --now "$svc" >/dev/null 2>&1 || log_error "disable_r_services" "Failed to disable $svc"
    fi
  done
}

configure_cron_permissions() {
  log_info "[SERVICES] Hardening cron/at permissions"
  for f in /etc/cron.allow /etc/cron.deny /etc/at.allow /etc/at.deny; do
    if [ -e "$f" ]; then
      backup_file "$f"
    else
      touch "$f"
    fi
    set_file_perms "$f" root:root 640
  done
}

disable_dos_services() {
  log_info "[SERVICES] Disabling xinetd echo/daytime/chargen"
  for svc in echo discard daytime chargen; do
    if [ -f "/etc/xinetd.d/$svc" ]; then
      sed -i 's/disable *= *no/disable = yes/' "/etc/xinetd.d/$svc"
    fi
  done
  systemctl restart xinetd >/dev/null 2>&1 || true
}

remove_automountd() {
  log_info "[SERVICES] Disabling autofs"
  if rpm -q autofs >/dev/null 2>&1; then
    systemctl disable --now autofs >/dev/null 2>&1 || log_error "remove_automountd" "Failed to disable autofs"
  fi
}

disable_nis() {
  log_info "[SERVICES] Disabling NIS components"
  local services=(ypbind ypserv ypxfrd rpc.yppasswdd rpc.ypupdated)
  for svc in "${services[@]}"; do
    if rpm -q "$svc" >/dev/null 2>&1; then
      systemctl disable --now "$svc" >/dev/null 2>&1 || log_error "disable_nis" "Failed to disable $svc"
    fi
  done
}

configure_ftp_shell() {
  log_info "[SERVICES] Restricting ftp shell access"
  if getent passwd ftp | grep -q '/sbin/nologin'; then
    backup_file /etc/passwd
    sed -i '/^ftp:/s#/sbin/nologin#/bin/false#' /etc/passwd || log_error "configure_ftp_shell" "Failed to update /etc/passwd"
  fi
}

disable_tftp_talk() {
  log_info "[SERVICES] Disabling tftp/talk services"
  local services=(tftp talk)
  for svc in "${services[@]}"; do
    if rpm -q "$svc" >/dev/null 2>&1; then
      systemctl disable --now "$svc" >/dev/null 2>&1 || log_error "disable_tftp_talk" "Failed to disable $svc"
    fi
  done
}

configure_smtp_security() {
  log_info "[SERVICES] Hardening postfix VRFY command"
  if rpm -q postfix >/dev/null 2>&1; then
    backup_file /etc/postfix/main.cf
    if grep -q "^disable_vrfy_command[[:space:]]*=[[:space:]]*yes" /etc/postfix/main.cf; then
      log_info "[SERVICES] Postfix VRFY already disabled"
    else
      if grep -q "^disable_vrfy_command" /etc/postfix/main.cf; then
        sed -i 's/^disable_vrfy_command.*/disable_vrfy_command = yes/' /etc/postfix/main.cf || log_error "configure_smtp_security" "Failed to update postfix main.cf"
      else
        echo "disable_vrfy_command = yes" >> /etc/postfix/main.cf || log_error "configure_smtp_security" "Failed to append postfix main.cf"
      fi
      postconf -e "inet_protocols = ipv4" || log_error "configure_smtp_security" "Failed to set inet_protocols"
      postconf -e "inet_interfaces = 127.0.0.1" || log_error "configure_smtp_security" "Failed to set inet_interfaces"
      if ! systemctl reload postfix >/dev/null 2>&1; then
        log_info "[SERVICES] postfix reload failed, attempting restart"
        if ! systemctl restart postfix >/dev/null 2>&1; then
          log_info "[SERVICES] postfix restart failed, attempting enable --now"
          if ! systemctl enable --now postfix >/dev/null 2>&1; then
            log_error "configure_smtp_security" "Failed to restart postfix"
          else
            log_info "[SERVICES] postfix enabled and started"
          fi
        else
          log_info "[SERVICES] postfix restarted successfully"
        fi
      else
        log_info "[SERVICES] postfix reloaded successfully"
      fi
    fi
  else
    log_info "[SERVICES] postfix not installed"
  fi
}

log_info "[SERVICES] Service hardening start"
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
log_info "[SERVICES] Service hardening complete"
