#!/bin/bash

BASE_DIR="/usr/local/src/secure_os_collection/u22"
source "$BASE_DIR/common.sh"

install_packages() {
    local pkgs=(lsof net-tools psmisc screen iftop smartmontools vim unzip wget curl)
    local pkg
    for pkg in "${pkgs[@]}"; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >/dev/null 2>&1 || true
        fi
    done
}

configure_etc_perms() {
    set_file_perms /etc/passwd root:root 644
    set_file_perms /etc/shadow root:shadow 640
    set_file_perms /etc/hosts root:root 644
}

configure_file_permissions() {
    local drop_suid=(/sbin/unix_chkpwd /usr/bin/newgrp /usr/bin/at)
    local target
    for target in "${drop_suid[@]}"; do
        [ -e "$target" ] && chmod -s "$target"
    done

    local files=(/usr/bin/perl /usr/bin/screen /usr/bin/wget /usr/bin/curl)
    local f
    for f in "${files[@]}"; do
        set_file_perms "$f" root:root 700
    done
}

configure_motd() {
    cat <<'EOF' > /etc/motd
********************************************************************
* This system is for authorized users only.                        *
* Unauthorized access or misuse will be prosecuted.                *
********************************************************************
EOF
}

configure_sysctl() {
    cat <<'EOF' > /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
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
    sysctl -p >/dev/null 2>&1 || true
}

install_packages
configure_etc_perms
configure_file_permissions
configure_motd
configure_sysctl
