#!/bin/bash
#
# Ubuntu 18.04 서비스 및 네트워크 보안 설정 작업 집합.

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
  log_info "rsyslog 원격 전송 설정"
  if dpkg -s rsyslog >/dev/null 2>&1; then
    backup_file /etc/rsyslog.conf
    chown root:root /etc/rsyslog.conf
    chmod 640 /etc/rsyslog.conf
    if ! grep -qxF "*.* @$RSYSLOG_SERVER" /etc/rsyslog.conf; then
      echo "*.* @$RSYSLOG_SERVER" >> /etc/rsyslog.conf
    fi
    systemctl restart rsyslog >/dev/null 2>&1 || log_warn "rsyslog 재시작 실패"
  else
    log_info "rsyslog 패키지가 설치되지 않아 전송 설정을 건너뜁니다."
  fi
}

disable_rhosts_hosts_equiv() {
  log_info "rhosts 및 hosts.equiv 제거"
  backup_file /etc/hosts.equiv "$HOME/.rhosts"
  rm -f /etc/hosts.equiv "$HOME/.rhosts"
}

disable_finger() {
  log_info "finger 서비스 비활성화"
  if dpkg -s finger >/dev/null 2>&1; then
    systemctl disable --now finger >/dev/null 2>&1 || log_warn "finger 서비스 비활성화 실패"
    SERVICES_DISABLED+=" finger"
  fi
}

disable_anonymous_ftp() {
  log_info "익명 FTP 접근 차단"
  if dpkg -s vsftpd >/dev/null 2>&1; then
    backup_file /etc/vsftpd.conf
    if grep -q '^anonymous_enable=' /etc/vsftpd.conf; then
      sed -i 's/^anonymous_enable=.*/anonymous_enable=NO/' /etc/vsftpd.conf
    else
      echo "anonymous_enable=NO" >> /etc/vsftpd.conf
    fi
    systemctl restart vsftpd >/dev/null 2>&1 || log_warn "vsftpd 재시작 실패"
    SERVICES_DISABLED+=" vsftpd-anon"
  fi
}

disable_r_services() {
  log_info "r계열 원격 서비스(rsh 등) 비활성화"
  local svc
  for svc in rsh rlogin rexec; do
    if dpkg -s "$svc" >/dev/null 2>&1; then
      systemctl disable --now "$svc" >/dev/null 2>&1 || log_warn "$svc 서비스 비활성화 실패"
      SERVICES_DISABLED+=" ${svc}"
    fi
  done
}

configure_cron_permissions() {
  log_info "cron 접근 제어 파일 권한 정리"
  local file
  for file in /etc/cron.allow /etc/cron.deny; do
    if [[ -e "$file" ]]; then
      backup_file "$file"
      set_file_perms "$file" root:root 640
    fi
  done
}

disable_dos_services() {
  log_info "inetd 기반 DoS 취약 서비스 제거"
  if [[ -f /etc/inetd.conf ]]; then
    sed -i '/\(echo\|discard\|daytime\|chargen\)/d' /etc/inetd.conf
    systemctl restart openbsd-inetd >/dev/null 2>&1 || log_warn "openbsd-inetd 재시작 실패"
  fi
}

remove_automountd() {
  log_info "자동 마운트 서비스 비활성화"
  if dpkg -s autofs >/dev/null 2>&1; then
    systemctl disable --now autofs >/dev/null 2>&1 || log_warn "autofs 비활성화 실패"
    SERVICES_DISABLED+=" autofs"
  fi
}

disable_nis() {
  log_info "NIS 관련 서비스 비활성화"
  local svc
  for svc in nis ypbind ypserv; do
    if dpkg -s "$svc" >/dev/null 2>&1; then
      systemctl disable --now "$svc" >/dev/null 2>&1 || log_warn "$svc 비활성화 실패"
      SERVICES_DISABLED+=" ${svc}"
    fi
  done
}

configure_ftp_shell() {
  log_info "ftp 계정 기본 셸 변경"
  if getent passwd ftp >/dev/null; then
    backup_file /etc/passwd
    sed -i 's#^\(ftp:.*:\)\(/usr\)\?/sbin/nologin#\1/bin/false#' /etc/passwd
  fi
}

disable_tftp_talk() {
  log_info "tftp 및 talk 서비스 비활성화"
  local svc
  for svc in tftp talk; do
    if dpkg -s "$svc" >/dev/null 2>&1; then
      systemctl disable --now "$svc" >/dev/null 2>&1 || log_warn "$svc 비활성화 실패"
      SERVICES_DISABLED+=" ${svc}"
    fi
  done
  if [[ -f /etc/inetd.conf ]]; then
    backup_file /etc/inetd.conf
    rm -f /etc/inetd.conf
  fi
}

perform_service_hardening() {
  log_info "서비스 및 네트워크 보안 설정 시작"
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
  log_info "서비스 및 네트워크 보안 설정 완료"
}

perform_service_hardening

