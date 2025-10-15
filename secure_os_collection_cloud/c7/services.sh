#!/bin/bash
# c7/services.sh : 불필요 서비스/설정 비활성화
# (root 로그인/SSH 포트/계정잠금/패스워드 만료 등은 다루지 않음)

source /usr/local/src/secure_os_collection/c7/common.sh

disable_finger() {
    log_info "disable_finger 시작"
    if rpm -q finger &>/dev/null; then
        systemctl disable --now finger &>/dev/null || log_error "disable_finger" "finger 비활성화 실패"
        rm -f /etc/xinetd.d/finger 2>/dev/null
        sed -i '/finger/d' /etc/inetd.conf 2>/dev/null
        log_info "finger 비활성화"
        SERVICES_DISABLED+="finger "
    else
        log_info "finger 미설치"
    fi
}

disable_r_services() {
    log_info "disable_r_services 시작"
    for svc in rsh rlogin rexec; do
        if rpm -q "$svc" &>/dev/null; then
            systemctl disable --now "$svc" &>/dev/null || log_error "disable_r_services" "$svc 비활성화 실패"
            rm -f /etc/xinetd.d/$svc 2>/dev/null
            sed -i "/$svc/d" /etc/inetd.conf 2>/dev/null
            log_info "$svc 비활성화"
            SERVICES_DISABLED+="$svc "
        else
            log_info "$svc 미설치"
        fi
    done
}

disable_dos_services() {
    log_info "disable_dos_services 시작"
    for svc in echo discard daytime chargen; do
        if [ -f /etc/xinetd.d/$svc ]; then
            sed -i 's/disable *= *no/disable = yes/' /etc/xinetd.d/$svc
            log_info "$svc 비활성화"
            SERVICES_DISABLED+="$svc "
        fi
    done
    systemctl restart xinetd &>/dev/null || log_error "disable_dos_services" "xinetd 재시작 실패"
}

remove_automountd() {
    log_info "remove_automountd 시작"
    if rpm -q autofs &>/dev/null; then
        systemctl disable --now autofs &>/dev/null || log_error "remove_automountd" "autofs 비활성화 실패"
        SERVICES_DISABLED+="autofs "
        log_info "autofs 비활성화"
    else
        log_info "autofs 미설치"
    fi
}

configure_cron_permissions() {
    log_info "configure_cron_permissions 시작"
    for f in /etc/cron.allow /etc/cron.deny; do
        [ -e "$f" ] && backup_file "$f" && set_file_perms "$f" root:root 640
    done
    log_info "cron 권한 설정 완료"
}

disable_rhosts_hosts_equiv() {
    log_info "disable_rhosts_hosts_equiv 시작"
    backup_file /etc/hosts.equiv "$HOME/.rhosts"
    rm -f /etc/hosts.equiv "$HOME/.rhosts"
    log_info "rhosts/hosts.equiv 제거 완료"
}

# 실행
disable_finger
disable_r_services
disable_dos_services
remove_automountd
configure_cron_permissions
disable_rhosts_hosts_equiv