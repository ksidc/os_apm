#!/bin/bash

BASE_DIR="/usr/local/src/secure_os_collection/r8"
source "$BASE_DIR/common.sh"

install_packages() {
    local pkgs=(epel-release lsof net-tools psmisc lrzsz screen iftop smartmontools vim unzip wget)
    for pkg in "${pkgs[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            dnf install -y "$pkg"
        fi
    done
}

configure_etc_perms() {
    set_file_perms /etc/passwd root:root 644
    set_file_perms /etc/shadow root:root 400
    set_file_perms /etc/hosts root:root 600

    if ! getent group wheel >/dev/null; then
        groupadd wheel
    fi
    set_file_perms /usr/bin/su root:wheel 4750
}

configure_file_permissions() {
    chmod -s /sbin/unix_chkpwd 2>/dev/null || true
    chmod -s /usr/bin/newgrp 2>/dev/null || true

    local files=(/usr/bin/perl /usr/bin/screen /usr/bin/wget /usr/bin/curl)
    for f in "${files[@]}"; do
        set_file_perms "$f" root:root 700
    done
}

configure_motd() {
    cat <<'EOF' > /etc/motd
********************************************************************
* This system is for authorized users only.                        *
* Unauthorized access or misuse will be prosecuted.                *
*                                                                  *
* Apply version 2025                                               *
********************************************************************
EOF
}

configure_sysctl() {
    cat <<'EOF' > /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.tcp_rmem = 4096 10000000 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 1800
net.ipv4.tcp_max_syn_backlog = 4096
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.somaxconn = 10240
net.ipv4.ip_local_port_range = 4000 65535
EOF
    sysctl -p >/dev/null 2>&1 || true
}

configure_limits() {
    cat <<'EOF' > /etc/security/limits.conf
* soft nofile 61200
* hard nofile 61200
* soft nproc 61200
* hard nproc 61200
EOF
}

configure_rc_local() {
    local file=/etc/rc.d/rc.local
    [ -f "$file" ] || touch "$file"
    chmod +x "$file"
    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable rc-local.service &>/dev/null || true
    fi
}

install_packages
configure_etc_perms
configure_file_permissions
configure_motd
configure_sysctl
configure_limits
configure_rc_local
