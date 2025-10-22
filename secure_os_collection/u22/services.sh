#!/bin/bash
#
# Ubuntu 22.04 서비스 및 네트워크 설정

if [[ -z "${SECURE_OS_COMMON_LOADED:-}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
fi

if [[ -n "${SECURE_OS_SERVICES_LOADED:-}" ]]; then
  return 0
fi
readonly SECURE_OS_SERVICES_LOADED=1

SERVICES_DISABLED=""

configure_rsyslog() {
  log_info "configure_rsyslog 실행"
  if dpkg -s rsyslog >/dev/null 2>&1; then
    backup_file /etc/rsyslog.conf
    chown root:root /etc/rsyslog.conf
    chmod 640 /etc/rsyslog.conf
    if ! grep -qxF "*.* @$RSYSLOG_SERVER" /etc/rsyslog.conf; then
      echo "*.* @$RSYSLOG_SERVER" >> /etc/rsyslog.conf
    fi
    systemctl restart rsyslog >/dev/null 2>&1 || log_warn "rsyslog 재시작 실패"
    log_info "rsyslog 원격 전송을 $RSYSLOG_SERVER로 설정했습니다."
  else
    log_info "rsyslog 패키지가 없어 설정을 건너뜁니다."
  fi
}

disable_rhosts_hosts_equiv() {
  log_info "disable_rhosts_hosts_equiv 실행"
  backup_file /etc/hosts.equiv "$HOME/.rhosts"
  rm -f /etc/hosts.equiv "$HOME/.rhosts"
  log_info "hosts.equiv 및 .rhosts 파일을 제거했습니다."
}

disable_finger() {
  log_info "disable_finger 실행"
  if dpkg -s finger >/dev/null 2>&1; then
    systemctl disable --now finger >/dev/null 2>&1 || log_warn "finger 비활성화 실패"
    SERVICES_DISABLED+=" finger"
    log_info "finger 서비스를 비활성화했습니다."
  else
    log_info "finger 패키지가 설치되어 있지 않습니다."
  fi
}

disable_anonymous_ftp() {
  log_info "disable_anonymous_ftp 실행"
  if dpkg -s vsftpd >/dev/null 2>&1; then
    backup_file /etc/vsftpd.conf
    if grep -q '^anonymous_enable=' /etc/vsftpd.conf; then
      sed -i 's/^anonymous_enable=.*/anonymous_enable=NO/' /etc/vsftpd.conf
    else
      echo "anonymous_enable=NO" >> /etc/vsftpd.conf
    fi
    systemctl restart vsftpd >/dev/null 2>&1 || log_warn "vsftpd 재시작 실패"
    log_info "vsftpd 익명 FTP 접속을 차단했습니다."
  else
    log_info "vsftpd 패키지가 설치되어 있지 않습니다."
  fi
}

disable_r_services() {
  log_info "disable_r_services 실행"
  local svc
  for svc in rsh rlogin rexec; do
    if dpkg -s "$svc" >/dev/null 2>&1; then
      systemctl disable --now "$svc" >/dev/null 2>&1 || log_warn "$svc 비활성화 실패"
      SERVICES_DISABLED+=" $svc"
      log_info "$svc 서비스를 비활성화했습니다."
    fi
  done
}

configure_cron_permissions() {
  log_info "configure_cron_permissions 실행"
  local file
  for file in /etc/cron.allow /etc/cron.deny; do
    if [[ -e "$file" ]]; then
      backup_file "$file"
      set_file_perms "$file" root:root 640
    fi
  done
  log_info "cron 접근 제어 파일 권한을 정비했습니다."
}

disable_dos_services() {
  log_info "disable_dos_services 실행"
  if [[ -f /etc/inetd.conf ]]; then
    sed -i '/\(echo\|discard\|daytime\|chargen\)/d' /etc/inetd.conf
    systemctl restart openbsd-inetd >/dev/null 2>&1 || log_warn "openbsd-inetd 재시작 실패"
  fi
  log_info "inetd 기반 DoS 취약 서비스를 비활성화했습니다."
}

remove_automountd() {
  log_info "remove_automountd 실행"
  if dpkg -s autofs >/dev/null 2>&1; then
    systemctl disable --now autofs >/dev/null 2>&1 || log_warn "autofs 비활성화 실패"
    SERVICES_DISABLED+=" autofs"
    log_info "autofs 서비스를 비활성화했습니다."
  fi
}

disable_nis() {
  log_info "disable_nis 실행"
  local svc
  for svc in nis ypbind ypserv; do
    if dpkg -s "$svc" >/dev/null 2>&1; then
      systemctl disable --now "$svc" >/dev/null 2>&1 || log_warn "$svc 비활성화 실패"
      SERVICES_DISABLED+=" $svc"
      log_info "$svc 서비스를 비활성화했습니다."
    fi
  done
}

configure_ftp_shell() {
  log_info "configure_ftp_shell 실행"
  if getent passwd ftp >/dev/null; then
    backup_file /etc/passwd
    sed -i 's#^\(ftp:.*:\)\(/usr\)\?/sbin/nologin#\1/bin/false#' /etc/passwd
    log_info "ftp 계정 로그인 쉘을 /bin/false로 변경했습니다."
  fi
}

disable_tftp_talk() {
  log_info "disable_tftp_talk 실행"
  local svc
  for svc in tftp talk; do
    if dpkg -s "$svc" >/dev/null 2>&1; then
      systemctl disable --now "$svc" >/dev/null 2>&1 || log_warn "$svc 비활성화 실패"
      SERVICES_DISABLED+=" $svc"
      log_info "$svc 서비스를 비활성화했습니다."
    fi
  done
}

perform_service_hardening() {
  log_info "서비스 및 네트워크 설정 작업 시작"
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
  log_info "서비스 및 네트워크 설정 작업 완료"
}

perform_service_hardening
