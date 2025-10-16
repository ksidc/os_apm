#!/bin/bash
# 시스템 설정 (필요없는 기능 제거됨)
# 제거됨: root차단, SSH포트변경, chrony, rsyslog, SELinux, limits.conf, history/profile, 방화벽

source /usr/local/src/secure_os_collection/r8/common.sh

install_packages() {
    log_info "install_packages 시작"
    local pkgs=(epel-release lsof net-tools psmisc lrzsz screen iftop smartmontools vim unzip wget)
    for pkg in "${pkgs[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            dnf install -y "$pkg" || { log_error "install_packages" "$pkg 설치 실패"; exit 1; }
            log_info "$pkg 설치 성공"
        fi
    done
    log_info "install_packages 완료"
}

configure_etc_perms() {
    log_info "configure_etc_perms 시작"
    set_file_perms /etc/passwd root:root 644
    set_file_perms /etc/shadow root:root 400
    set_file_perms /etc/hosts root:root 600
    set_file_perms /usr/bin/su root:wheel 4750
    getent group wheel >/dev/null || groupadd wheel
    log_info "configure_etc_perms 완료"
}

configure_file_permissions() {
    log_info "configure_file_permissions 시작"
    chmod -s /sbin/unix_chkpwd 2>/dev/null || true
    chmod -s /usr/bin/newgrp 2>/dev/null || true
    for f in /usr/bin/perl /usr/bin/screen /usr/bin/wget /usr/bin/curl; do
        [ -f "$f" ] && set_file_perms "$f" root:root 700
    done
    log_info "configure_file_permissions 완료"
}

configure_motd() {
    log_info "configure_motd 시작"
    cat <<'EOF' > /etc/motd
********************************************************************
* 본 시스템은 허가된 사용자만 이용하실 수 있습니다.               *
* 부당한 접속/정보 변경·유출 시 관련 법령에 따라 처벌될 수 있습니다. *
********************************************************************
EOF
    log_info "configure_motd 완료"
}

configure_sysctl() {
    log_info "configure_sysctl 시작"
    cat <<'EOF' > /etc/sysctl.conf
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.tcp_rmem = 4096 10000000 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 1800
net.ipv4.tcp_max_syn_backlog = 4096
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.somaxconn = 10240
net.ipv4.ip_local_port_range = 4000 65535
EOF
    sysctl -p || log_info "sysctl -p 적용 경고(무시)"
    log_info "configure_sysctl 완료"
}

configure_rc_local() {
    log_info "configure_rc_local 시작"
    [[ -f /etc/rc.d/rc.local ]] || touch /etc/rc.d/rc.local
    chmod +x /etc/rc.d/rc.local
    systemctl enable rc-local &>/dev/null || true
    log_info "configure_rc_local 완료"
}

# 실행 (불필요 항목 전부 제외)
log_info "시스템 설정 시작"
install_packages
configure_etc_perms
configure_file_permissions
configure_motd
configure_sysctl
configure_rc_local
log_info "시스템 설정 완료"
