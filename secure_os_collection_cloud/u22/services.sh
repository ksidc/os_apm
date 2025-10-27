#!/bin/bash

BASE_DIR="/usr/local/src/secure_os_collection/u22"
source "$BASE_DIR/common.sh"

disable_finger() {
    if systemctl list-unit-files finger.service >/dev/null 2>&1; then
        systemctl disable --now finger >/dev/null 2>&1 || true
    fi
    rm -f /etc/xinetd.d/finger
    sed -i '/finger/d' /etc/inetd.conf 2>/dev/null || true
}

disable_anonymous_ftp() {
    if dpkg -s vsftpd >/dev/null 2>&1; then
        if [ -f /etc/vsftpd.conf ]; then
            if grep -q '^anonymous_enable=' /etc/vsftpd.conf; then
                sed -i 's/^anonymous_enable=.*/anonymous_enable=NO/' /etc/vsftpd.conf
            else
                printf '\nanonymous_enable=NO\n' >> /etc/vsftpd.conf
            fi
        fi
        systemctl restart vsftpd >/dev/null 2>&1 || true
    fi
}

disable_r_services() {
    local services=(rsh rlogin rexec)
    local svc
    for svc in "${services[@]}"; do
        if dpkg -s "$svc" >/dev/null 2>&1; then
            systemctl disable --now "$svc" >/dev/null 2>&1 || true
        fi
    done
    sed -i "/rsh/d;/rlogin/d;/rexec/d" /etc/inetd.conf 2>/dev/null || true
}

configure_cron_permissions() {
    local files=(/etc/cron.allow /etc/cron.deny /etc/at.allow /etc/at.deny)
    local f
    for f in "${files[@]}"; do
        [ -e "$f" ] || touch "$f"
        set_file_perms "$f" root:root 640
    done
}

disable_dos_services() {
    local services=(echo discard daytime chargen)
    local svc
    for svc in "${services[@]}"; do
        if [ -f "/etc/xinetd.d/$svc" ]; then
            sed -i 's/disable *= *no/disable = yes/' "/etc/xinetd.d/$svc"
        fi
    done
    if systemctl list-unit-files xinetd.service >/dev/null 2>&1; then
        systemctl restart xinetd >/dev/null 2>&1 || true
    fi
}

remove_autofs() {
    if dpkg -s autofs >/dev/null 2>&1; then
        systemctl disable --now autofs >/dev/null 2>&1 || true
    fi
}

disable_nis() {
    local services=(ypbind ypserv ypxfrd rpc.yppasswdd rpc.ypupdated)
    local svc
    for svc in "${services[@]}"; do
        if dpkg -s "$svc" >/dev/null 2>&1; then
            systemctl disable --now "$svc" >/dev/null 2>&1 || true
        fi
    done
}

disable_tftp_talk() {
    local services=(tftpd-hpa talk)
    local svc
    for svc in "${services[@]}"; do
        if dpkg -s "$svc" >/dev/null 2>&1; then
            systemctl disable --now "$svc" >/dev/null 2>&1 || true
        fi
    done
}

disable_finger
disable_anonymous_ftp
disable_r_services
configure_cron_permissions
disable_dos_services
remove_autofs
disable_nis
disable_tftp_talk
