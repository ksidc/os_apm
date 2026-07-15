#!/bin/bash

source /usr/local/src/secure_os_collection/c6/common.sh

# 설치된 SysV 서비스를 중지하고 모든 부팅 런레벨에서 비활성화한다.
disable_sysv_service() {
    local service_name="$1"
    [ -x "/etc/init.d/$service_name" ] || return 0
    service "$service_name" stop >/dev/null 2>&1 || true
    chkconfig "$service_name" off || {
        echo "ERROR: 서비스 비활성화 실패: $service_name" >&2
        return 1
    }
    SERVICES_DISABLED="${SERVICES_DISABLED}${service_name} "
}

# xinetd 서비스 파일이 존재하면 disable=yes를 한 줄로 설정한다.
disable_xinetd_entry() {
    local config_file="$1"
    [ -f "$config_file" ] || return 0
    if grep -qE '^[[:space:]]*disable[[:space:]]*=' "$config_file"; then
        sed -i 's/^[[:space:]]*disable[[:space:]]*=.*/        disable = yes/' "$config_file" || return 1
    else
        sed -i '/^[[:space:]]*}/i\        disable = yes' "$config_file" || return 1
    fi
}

# finger, r-command, DoS 테스트, tftp와 talk 계열 xinetd 서비스를 차단한다.
disable_legacy_xinetd_services() {
    local config_file
    for config_file in \
        /etc/xinetd.d/finger \
        /etc/xinetd.d/rsh /etc/xinetd.d/rlogin /etc/xinetd.d/rexec \
        /etc/xinetd.d/echo* /etc/xinetd.d/discard* \
        /etc/xinetd.d/daytime* /etc/xinetd.d/chargen* \
        /etc/xinetd.d/tftp /etc/xinetd.d/talk /etc/xinetd.d/ntalk; do
        [ -f "$config_file" ] || continue
        disable_xinetd_entry "$config_file" || return 1
    done
    if [ -x /etc/init.d/xinetd ] && service xinetd status >/dev/null 2>&1; then
        mark_restart xinetd
    fi
}

# vsftpd가 설치된 경우 익명 접속을 차단한다.
disable_anonymous_ftp() {
    [ -f /etc/vsftpd/vsftpd.conf ] || return 0
    if grep -qE '^[[:space:]]*anonymous_enable=' /etc/vsftpd/vsftpd.conf; then
        sed -i 's/^[[:space:]]*anonymous_enable=.*/anonymous_enable=NO/' /etc/vsftpd/vsftpd.conf || return 1
    else
        echo 'anonymous_enable=NO' >> /etc/vsftpd/vsftpd.conf || return 1
    fi
    service vsftpd status >/dev/null 2>&1 && mark_restart vsftpd || true
}

# autofs와 NIS 계열 SysV 서비스를 사용하지 않도록 비활성화한다.
disable_unneeded_sysv_services() {
    local service_name
    for service_name in autofs ypbind ypserv ypxfrd yppasswdd ypupdated; do
        disable_sysv_service "$service_name" || return 1
    done
}

# 기본 설치된 postfix의 VRFY를 막고 IPv4 localhost에서만 수신하게 한다.
configure_postfix_security() {
    rpm -q postfix >/dev/null 2>&1 || return 0
    command -v postconf >/dev/null 2>&1 || {
        echo "ERROR: postfix가 설치되어 있으나 postconf가 없습니다." >&2
        return 1
    }
    postconf -e 'disable_vrfy_command = yes' || return 1
    postconf -e 'inet_protocols = ipv4' || return 1
    postconf -e 'inet_interfaces = 127.0.0.1' || return 1
    mark_restart postfix
}

# 방화벽 선택과 관계없이 rhosts 기반 신뢰 파일을 제거한다.
disable_rhosts_trust() {
    rm -f /etc/hosts.equiv /root/.rhosts || return 1
}

# 서비스 조치 실패를 main.sh에 반환해 실패 뒤 재시작이나 방화벽 적용을 중단한다.
apply_service_hardening() {
    disable_legacy_xinetd_services || return 1
    disable_anonymous_ftp || return 1
    disable_unneeded_sysv_services || return 1
    configure_postfix_security || return 1
    disable_rhosts_trust || return 1
}

apply_service_hardening
