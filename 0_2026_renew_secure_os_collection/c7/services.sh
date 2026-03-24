#!/bin/bash

source /usr/local/src/secure_os_collection/c7/common.sh

disable_finger() {
    log_info "disable_finger 시작"
    if rpm -q finger >/dev/null 2>&1; then
        systemctl disable --now finger >/dev/null 2>&1 || log_error "disable_finger" "finger 비활성화 실패"
        log_info "finger 서비스 비활성화 완료"
        SERVICES_DISABLED+="finger "
    else
        log_info "finger 패키지 미설치"
    fi
}

disable_anonymous_ftp() {
    log_info "disable_anonymous_ftp 시작"
    if rpm -q vsftpd >/dev/null 2>&1; then
        sed -i 's/^anonymous_enable=.*/anonymous_enable=NO/' /etc/vsftpd/vsftpd.conf \
            || log_error "disable_anonymous_ftp" "vsftpd.conf 수정 실패"
        systemctl restart vsftpd >/dev/null 2>&1 || log_error "disable_anonymous_ftp" "vsftpd 재시작 실패"
        log_info "vsftpd 익명 FTP 비활성화 완료"
    else
        log_info "vsftpd 패키지 미설치"
    fi
}

disable_r_services() {
    log_info "disable_r_services 시작"
    local services=(rsh rlogin rexec)
    for svc in "${services[@]}"; do
        if rpm -q "$svc" >/dev/null 2>&1; then
            systemctl disable --now "$svc" >/dev/null 2>&1 || log_error "disable_r_services" "$svc 비활성화 실패"
            log_info "$svc 비활성화 완료"
            SERVICES_DISABLED+="$svc "
        fi
    done
}

configure_cron_permissions() {
    log_info "configure_cron_permissions 시작"
    for f in /etc/cron.allow /etc/cron.deny /etc/at.allow /etc/at.deny; do
        if [ ! -e "$f" ]; then
            touch "$f"
        fi
        set_file_perms "$f" root:root 640
    done
    log_info "cron/at 권한 설정 완료"
}

disable_dos_services() {
    log_info "disable_dos_services 시작"
    for svc in echo discard daytime chargen; do
        if [ -f "/etc/xinetd.d/$svc" ]; then
            sed -i 's/disable *= *no/disable = yes/' "/etc/xinetd.d/$svc" \
                || log_error "disable_dos_services" "$svc 설정 실패"
        fi
    done
    systemctl restart xinetd >/dev/null 2>&1 || true
    log_info "xinetd DoS 서비스 비활성화 완료"
}

remove_automountd() {
    log_info "remove_automountd 시작"
    if rpm -q autofs >/dev/null 2>&1; then
        systemctl disable --now autofs >/dev/null 2>&1 || log_error "remove_automountd" "autofs 비활성화 실패"
        log_info "autofs 비활성화 완료"
        SERVICES_DISABLED+="autofs "
    else
        log_info "autofs 패키지 미설치"
    fi
}

disable_nis() {
    log_info "disable_nis 시작"
    local services=(ypbind ypserv ypxfrd rpc.yppasswdd rpc.ypupdated)
    for svc in "${services[@]}"; do
        if rpm -q "$svc" >/dev/null 2>&1; then
            systemctl disable --now "$svc" >/dev/null 2>&1 || log_error "disable_nis" "$svc 비활성화 실패"
            log_info "$svc 비활성화 완료"
            SERVICES_DISABLED+="$svc "
        fi
    done
}

disable_tftp_talk() {
    log_info "disable_tftp_talk 시작"
    local services=(tftp talk)
    for svc in "${services[@]}"; do
        if rpm -q "$svc" >/dev/null 2>&1; then
            systemctl disable --now "$svc" >/dev/null 2>&1 || log_error "disable_tftp_talk" "$svc 비활성화 실패"
            log_info "$svc 비활성화 완료"
            SERVICES_DISABLED+="$svc "
        fi
    done
}

configure_smtp_security() {
    log_info "configure_smtp_security 시작"
    if rpm -q postfix >/dev/null 2>&1; then
        if grep -q "^disable_vrfy_command[[:space:]]*=[[:space:]]*yes" /etc/postfix/main.cf; then
            log_info "Postfix VRFY 이미 비활성화됨"
        else
            if grep -q "^disable_vrfy_command" /etc/postfix/main.cf; then
                sed -i 's/^disable_vrfy_command.*/disable_vrfy_command = yes/' /etc/postfix/main.cf \
                    || log_error "configure_smtp_security" "postfix main.cf 수정 실패"
            else
                echo "disable_vrfy_command = yes" >> /etc/postfix/main.cf \
                    || log_error "configure_smtp_security" "postfix main.cf 추가 실패"
            fi
            postconf -e "inet_protocols = ipv4" || log_error "configure_smtp_security" "inet_protocols 설정 실패"
            postconf -e "inet_interfaces = 127.0.0.1" || log_error "configure_smtp_security" "inet_interfaces 설정 실패"

            if ! systemctl reload postfix >/dev/null 2>&1; then
                log_info "postfix reload 실패, restart 시도"
                if ! systemctl restart postfix >/dev/null 2>&1; then
                    log_info "postfix restart 실패, enable --now 시도"
                    if ! systemctl enable --now postfix >/dev/null 2>&1; then
                        log_error "configure_smtp_security" "postfix 재시작 실패"
                    else
                        log_info "postfix 활성화 및 시작 완료"
                    fi
                else
                    log_info "postfix 재시작 완료"
                fi
            else
                log_info "postfix reload 완료"
            fi
        fi
    else
        log_info "postfix 패키지 미설치"
    fi
}

# 서비스 강화 실행
log_info "서비스 강화 작업 시작"
disable_finger
disable_anonymous_ftp
disable_r_services
configure_cron_permissions
disable_dos_services
remove_automountd
disable_nis
disable_tftp_talk
configure_smtp_security
log_info "서비스 강화 작업 완료"
