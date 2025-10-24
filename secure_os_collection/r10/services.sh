#!/bin/bash

source /usr/local/src/secure_os_collection/r10/common.sh

# 서비스 비활성화 및 기본 보안 설정

disable_finger() {
    log_info "disable_finger 시작"
    if rpm -q finger &>/dev/null; then
        systemctl disable --now finger &>/dev/null || log_error "disable_finger" "finger 비활성화 실패"
        rm -f /etc/xinetd.d/finger
        sed -i '/finger/d' /etc/inetd.conf 2>/dev/null
        log_info "finger 서비스 비활성화 완료"
        SERVICES_DISABLED+="finger "
    else
        log_info "finger 패키지 미설치"
    fi
}

disable_anonymous_ftp() {
    log_info "disable_anonymous_ftp 시작"
    if rpm -q vsftpd &>/dev/null; then
        backup_file /etc/vsftpd/vsftpd.conf
        if grep -q '^anonymous_enable=NO' /etc/vsftpd/vsftpd.conf; then
            log_info "anonymous FTP 이미 제한됨"
        else
            sed -i 's/^anonymous_enable=.*/anonymous_enable=NO/' /etc/vsftpd/vsftpd.conf
            systemctl restart vsftpd &>/dev/null || log_error "disable_anonymous_ftp" "vsftpd 재시작 실패"
            log_info "anonymous FTP 비활성화 완료"
        fi
        SERVICES_DISABLED+="vsftpd "
    else
        log_info "vsftpd 패키지 미설치"
    fi
}

disable_r_services() {
    log_info "disable_r_services 시작"
    for svc in rsh rlogin rexec; do
        if rpm -q "$svc" &>/dev/null; then
            systemctl disable --now "$svc" &>/dev/null || log_error "disable_r_services" "$svc 비활성화 실패"
            rm -f /etc/xinetd.d/$svc
            sed -i "/$svc/d" /etc/inetd.conf 2>/dev/null
            log_info "$svc 서비스 비활성화 완료"
            SERVICES_DISABLED+="$svc "
        else
            log_info "$svc 패키지 미설치"
        fi
    done
}

disable_dos_services() {
    log_info "disable_dos_services 시작"
    local changed=0
    for svc in echo discard daytime chargen; do
        if [ -f /etc/xinetd.d/$svc ]; then
            sed -i 's/disable *= *no/disable = yes/' /etc/xinetd.d/$svc
            log_info "$svc 서비스 비활성화"
            SERVICES_DISABLED+="$svc "
            changed=1
        fi
    done
    if [ $changed -eq 1 ]; then
        systemctl restart xinetd &>/dev/null || log_error "disable_dos_services" "xinetd 재시작 실패"
    fi
    log_info "DoS 관련 서비스 비활성화 완료"
}

remove_automountd() {
    log_info "remove_automountd 시작"
    if rpm -q autofs &>/dev/null; then
        systemctl disable --now autofs &>/dev/null || log_error "remove_automountd" "autofs 비활성화 실패"
        log_info "autofs 서비스 비활성화"
        SERVICES_DISABLED+="autofs "
    else
        log_info "autofs 패키지 미설치"
    fi
}

disable_nis() {
    log_info "disable_nis 시작"
    for svc in ypbind ypserv ypxfrd rpc.yppasswdd rpc.ypupdated; do
        if rpm -q "$svc" &>/dev/null; then
            systemctl disable --now "$svc" &>/dev/null || log_error "disable_nis" "$svc 비활성화 실패"
            log_info "$svc 서비스 비활성화 완료"
            SERVICES_DISABLED+="$svc "
        else
            log_info "$svc 패키지 미설치"
        fi
    done
}

disable_tftp_talk() {
    log_info "disable_tftp_talk 시작"
    for svc in tftp-server talk; do
        if rpm -q "$svc" &>/dev/null; then
            systemctl disable --now "$svc" &>/dev/null || log_error "disable_tftp_talk" "$svc 비활성화 실패"
            [ -f /etc/xinetd.d/${svc%-server} ] && sed -i 's/disable *= *no/disable = yes/' /etc/xinetd.d/${svc%-server}
            log_info "$svc 서비스 비활성화 완료"
            SERVICES_DISABLED+="$svc "
        else
            log_info "$svc 패키지 미설치"
        fi
    done
}

disable_cockpit() {
    log_info "disable_cockpit 시작"
    local unit found=0
    for unit in cockpit.socket cockpit.service; do
        if systemctl list-unit-files "$unit" >/dev/null 2>&1; then
            systemctl disable --now "$unit" &>/dev/null || log_error "disable_cockpit" "$unit 비활성화 실패"
            systemctl mask "$unit" &>/dev/null || log_error "disable_cockpit" "$unit 마스크 실패"
            found=1
        fi
    done
    if [ "$found" -eq 1 ]; then
        log_info "cockpit 서비스/소켓 비활성화 및 마스크 완료"
        SERVICES_DISABLED+="cockpit "
    else
        log_info "cockpit 구성 요소 미설치"
    fi
}

configure_cron_permissions() {
    log_info "configure_cron_permissions 시작"
    for f in /etc/cron.allow /etc/cron.deny; do
        [ -e "$f" ] && backup_file "$f" && set_file_perms "$f" root:root 640
    done
    log_info "cron 접근 제어 파일 권한 설정 완료"
}

disable_rhosts_hosts_equiv() {
    log_info "disable_rhosts_hosts_equiv 시작"
    backup_file /etc/hosts.equiv "$HOME/.rhosts"
    rm -f /etc/hosts.equiv "$HOME/.rhosts"
    log_info "hosts.equiv 및 .rhosts 제거"
}

log_info "서비스 비활성화 작업 시작"
disable_finger
disable_anonymous_ftp
disable_r_services
disable_dos_services
disable_cockpit
remove_automountd
disable_nis
disable_tftp_talk
configure_cron_permissions
disable_rhosts_hosts_equiv
log_info "서비스 비활성화 작업 완료"
