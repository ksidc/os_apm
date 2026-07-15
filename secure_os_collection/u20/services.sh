#!/bin/bash
#
# Ubuntu 20.04 service and network hardening tasks.

if [[ -z "${SECURE_OS_COMMON_LOADED:-}" ]]; then
  # shellcheck source=./common.sh
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
fi

if [[ -n "${SECURE_OS_SERVICES_LOADED:-}" ]]; then
  return 0
fi
readonly SECURE_OS_SERVICES_LOADED=1

SERVICES_DISABLED=""

configure_rsyslog() {
  if dpkg -s rsyslog >/dev/null 2>&1; then
    chown root:root /etc/rsyslog.conf
    chmod 640 /etc/rsyslog.conf
    sed -i "\|^\\*\\.\\* @${RSYSLOG_SERVER}$|d" /etc/rsyslog.conf
    echo "*.* @$RSYSLOG_SERVER" >> /etc/rsyslog.conf
    systemctl restart rsyslog >/dev/null 2>&1 || true
  else
    :
  fi
}

disable_rhosts_hosts_equiv() {
  rm -f /etc/hosts.equiv "$HOME/.rhosts"
}

disable_finger() {
  if dpkg -s finger >/dev/null 2>&1; then
    systemctl disable --now finger >/dev/null 2>&1 || true
    SERVICES_DISABLED+=" finger"
  else
    :
  fi
}

disable_anonymous_ftp() {
  if dpkg -s vsftpd >/dev/null 2>&1; then
    if grep -q '^anonymous_enable=' /etc/vsftpd.conf; then
      sed -i 's/^anonymous_enable=.*/anonymous_enable=NO/' /etc/vsftpd.conf
    else
      echo "anonymous_enable=NO" >> /etc/vsftpd.conf
    fi
    systemctl restart vsftpd >/dev/null 2>&1 || true
    SERVICES_DISABLED+=" vsftpd-anon"
  else
    :
  fi
}

disable_r_services() {
  local svc
  for svc in rsh rlogin rexec; do
    if dpkg -s "$svc" >/dev/null 2>&1; then
      systemctl disable --now "$svc" >/dev/null 2>&1 || true
      SERVICES_DISABLED+=" $svc"
    fi
  done
}

configure_cron_permissions() {
  local file
  for file in /etc/cron.allow /etc/cron.deny; do
    if [[ -e "$file" ]]; then
      set_file_perms "$file" root:root 640
    fi
  done
}

disable_dos_services() {
  if [[ -f /etc/inetd.conf ]]; then
    sed -i '/\(echo\|discard\|daytime\|chargen\)/d' /etc/inetd.conf
    systemctl restart openbsd-inetd >/dev/null 2>&1 || true
  fi
}

remove_automountd() {
  if dpkg -s autofs >/dev/null 2>&1; then
    systemctl disable --now autofs >/dev/null 2>&1 || true
    SERVICES_DISABLED+=" autofs"
  fi
}

disable_nis() {
  local svc
  for svc in nis ypbind ypserv; do
    if dpkg -s "$svc" >/dev/null 2>&1; then
      systemctl disable --now "$svc" >/dev/null 2>&1 || true
      SERVICES_DISABLED+=" $svc"
    fi
  done
}

configure_ftp_shell() {
  if getent passwd ftp >/dev/null; then
    sed -i 's#^\(ftp:.*:\)\(/usr\)\?/sbin/nologin#\1/bin/false#' /etc/passwd
  fi
}

disable_tftp_talk() {
  local svc
  for svc in tftp talk; do
    if dpkg -s "$svc" >/dev/null 2>&1; then
      systemctl disable --now "$svc" >/dev/null 2>&1 || true
      SERVICES_DISABLED+=" $svc"
    fi
  done
}

perform_service_hardening() {
  configure_rsyslog
  disable_rhosts_hosts_equiv
  disable_finger
  disable_anonymous_ftp
  disable_r_services
  configure_cron_permissions
  disable_dos_services
  remove_automountd
  disable_nis
  configure_ftp_shell
  disable_tftp_talk
  if [[ -n "$SERVICES_DISABLED" ]]; then
    SERVICES_DISABLED="${SERVICES_DISABLED# }"
  fi
}

perform_service_hardening
