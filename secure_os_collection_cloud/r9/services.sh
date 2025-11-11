#!/bin/bash

BASE_DIR="/usr/local/src/secure_os_collection/r9"
source "$BASE_DIR/common.sh"

disable_finger() {
    if rpm -q finger &>/dev/null; then
        systemctl disable --now finger &>/dev/null || true
        rm -f /etc/xinetd.d/finger
        sed -i '/finger/d' /etc/inetd.conf 2>/dev/null || true
    fi
}

disable_anonymous_ftp() {
    if rpm -q vsftpd &>/dev/null; then
        if grep -q '^anonymous_enable=' /etc/vsftpd/vsftpd.conf; then
            sed -i 's/^anonymous_enable=.*/anonymous_enable=NO/' /etc/vsftpd/vsftpd.conf
        else
            printf '\nanonymous_enable=NO\n' >> /etc/vsftpd/vsftpd.conf
        fi
        systemctl restart vsftpd &>/dev/null || true
    fi
}

disable_r_services() {
    local services=(rsh rlogin rexec)
    for svc in "${services[@]}"; do
        if rpm -q "$svc" &>/dev/null; then
            systemctl disable --now "$svc" &>/dev/null || true
            rm -f "/etc/xinetd.d/$svc"
            sed -i "/$svc/d" /etc/inetd.conf 2>/dev/null || true
        fi
    done
}

disable_dos_services() {
    local services=(echo discard daytime chargen)
    for svc in "${services[@]}"; do
        if [ -f "/etc/xinetd.d/$svc" ]; then
            sed -i 's/disable *= *no/disable = yes/' "/etc/xinetd.d/$svc"
        fi
    done
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart xinetd &>/dev/null || true
    fi
}

remove_automountd() {
    if rpm -q autofs &>/dev/null; then
        systemctl disable --now autofs &>/dev/null || true
    fi
}

disable_nis() {
    local services=(ypbind ypserv ypxfrd rpc.yppasswdd rpc.ypupdated)
    for svc in "${services[@]}"; do
        if rpm -q "$svc" &>/dev/null; then
            systemctl disable --now "$svc" &>/dev/null || true
        fi
    done
}

disable_tftp_talk() {
    local services=(tftp-server talk)
    for svc in "${services[@]}"; do
        if rpm -q "$svc" &>/dev/null; then
            systemctl disable --now "$svc" &>/dev/null || true
            local conf="/etc/xinetd.d/${svc%-server}"
            if [ -f "$conf" ]; then
                sed -i 's/disable *= *no/disable = yes/' "$conf"
            fi
        fi
    done
}

configure_cron_permissions() {
    local files=(/etc/cron.allow /etc/cron.deny)
    for f in "${files[@]}"; do
        [ -e "$f" ] || continue
        set_file_perms "$f" root:root 640
    done
}

disable_rhosts_hosts_equiv() {
    local home_dir="${HOME:-/root}"
    rm -f /etc/hosts.equiv "$home_dir/.rhosts"
}

disable_finger
disable_anonymous_ftp
disable_r_services
disable_dos_services
remove_automountd
disable_nis
disable_tftp_talk
configure_cron_permissions
disable_rhosts_hosts_equiv
