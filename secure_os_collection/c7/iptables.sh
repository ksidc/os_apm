#!/bin/bash

source /usr/local/src/secure_os_collection/c7/common.sh

# Default SSH port resolution order: NEW_SSH_PORT -> sshd_config -> fallback 22
SSH_PORT="${NEW_SSH_PORT:-$(grep -iE '^[# ]*Port[[:space:]]+[0-9]+' /etc/ssh/sshd_config | awk '{print $2}' | tail -n1)}"
SSH_PORT="${SSH_PORT:-22}"

# iptables rules file path
RULES_FILE="/etc/sysconfig/iptables"

configure_tcp_wrappers() {
    log_info "configure_tcp_wrappers 시작"
    yum install -y tcp_wrappers || { log_error "configure_tcp_wrappers" "tcp_wrappers 설치 실패"; exit 1; }
    echo "sshd: ALL" > /etc/hosts.allow
    echo "ALL: ALL" > /etc/hosts.deny
    set_file_perms /etc/hosts.allow root:root 644
    set_file_perms /etc/hosts.deny root:root 644
    log_info "TCP wrappers 설정 완료"
}

disable_rhosts_hosts_equiv() {
    log_info "disable_rhosts_hosts_equiv 시작"
    rm -f /etc/hosts.equiv "$HOME/.rhosts" 2>/dev/null || true
    log_info "rhosts/hosts.equiv 제거 완료"
}

# Disable firewalld if present
if command -v firewall-cmd >/dev/null 2>&1; then
    systemctl stop firewalld 2>/dev/null || true
    systemctl disable firewalld 2>/dev/null || true
    systemctl mask firewalld 2>/dev/null || true
    log_info "firewalld 비활성화 및 마스킹 완료"
fi

# Always apply TCP wrapper hardening
configure_tcp_wrappers
disable_rhosts_hosts_equiv

# Prompt for iptables usage
echo "방화벽(iptables)을 활성화하시겠습니까? (Y/N)"
read -r USE_IPTABLES < /dev/tty

# Configure iptables if requested
if [[ "$USE_IPTABLES" =~ ^[Yy]$ ]]; then
    log_info "iptables 방화벽 설정 시작"

    # Ensure required packages are installed
    if ! rpm -q iptables >/dev/null 2>&1 || ! rpm -q iptables-services >/dev/null 2>&1; then
        yum install -y iptables iptables-services || { log_error "iptables" "iptables 패키지 설치 실패"; exit 1; }
        log_info "iptables/iptables-services 설치 완료"
    else
        log_info "iptables/iptables-services 이미 설치됨"
    fi

    # Write iptables rules
    cat > "$RULES_FILE" <<EOF
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:RH-Firewall-1-INPUT - [0:0]

-A INPUT -j RH-Firewall-1-INPUT
-A FORWARD -j RH-Firewall-1-INPUT

# Base allowances
-A RH-Firewall-1-INPUT -i lo -j ACCEPT
-A RH-Firewall-1-INPUT -p icmp --icmp-type any -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

######################################################################################################
# KSIDC SSH Allow (management IPs)
-A RH-Firewall-1-INPUT -p tcp -s 116.122.36.109 -j ACCEPT
-A RH-Firewall-1-INPUT -p tcp -s 218.50.1.130 -j ACCEPT
-A RH-Firewall-1-INPUT -p tcp -s 110.9.167.210 -j ACCEPT
-A RH-Firewall-1-INPUT -p tcp -s 211.200.178.141 -j ACCEPT
-A RH-Firewall-1-INPUT -p tcp -s 218.237.67.200 -j ACCEPT
-A RH-Firewall-1-INPUT -p tcp -s 121.166.140.142 -j ACCEPT
######################################################################################################

# FTP service ports
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 8080 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 8090 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 20 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 21 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 5000:5050 -j ACCEPT

# Web service ports
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 80 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 443 -j ACCEPT

# Managed ports (SSH & SNMP)
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport ${SSH_PORT} -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p udp --dport 161 -j ACCEPT

# Mail service ports
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 25 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 587 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 110 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 143 -j ACCEPT

# MySQL service port
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 3306 -j ACCEPT

# Default drop policies
-A RH-Firewall-1-INPUT -p icmp --icmp-type any -j DROP
-A RH-Firewall-1-INPUT -j REJECT --reject-with icmp-host-prohibited

COMMIT
EOF

    chmod 600 "$RULES_FILE"
    log_info "iptables 규칙 파일 생성 완료: $RULES_FILE"

    # Enable and restart service to apply rules
    systemctl enable iptables >/dev/null 2>&1 || { log_error "iptables" "iptables 서비스 활성화 실패"; exit 1; }
    if systemctl restart iptables; then
        log_info "iptables 서비스 재시작 성공"
    else
        echo "iptables 규칙 적용에 실패했습니다 - $RULES_FILE 파일을 확인하세요" >&2
        log_error "iptables" "iptables 서비스 재시작 실패"
        exit 1
    fi
else
    log_info "iptables 설정 생략 (firewalld는 비활성화됨)"
fi
