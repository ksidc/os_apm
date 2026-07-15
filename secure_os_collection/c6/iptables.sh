#!/bin/bash

source /usr/local/src/secure_os_collection/c6/common.sh

SSH_PORT="${NEW_SSH_PORT:-38371}"
RULES_FILE="/etc/sysconfig/iptables"

# SSH는 iptables 관리 IP 정책과 함께 적용하고 TCP Wrappers 기본 차단을 설정한다.
configure_tcp_wrappers() {
    rpm -q tcp_wrappers >/dev/null 2>&1 || yum install -y tcp_wrappers || return 1
    echo 'sshd: ALL' > /etc/hosts.allow
    echo 'ALL: ALL' > /etc/hosts.deny
    set_file_perms /etc/hosts.allow root:root 644 || return 1
    set_file_perms /etc/hosts.deny root:root 644 || return 1
}

# rhosts 기반 신뢰 관계 파일을 제거한다.
disable_rhosts_trust() {
    rm -f /etc/hosts.equiv /root/.rhosts
}

# C6 iptables 형식으로 고정 서비스 포트와 선택한 SSH 포트를 설정한다.
configure_iptables_rules() {
    echo "$SSH_PORT" | grep -Eq '^[0-9]+$' || {
        echo "ERROR: SSH 포트 값이 올바르지 않습니다: $SSH_PORT" >&2
        return 1
    }

    cat > "$RULES_FILE" <<EOF
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
:RH-Firewall-1-INPUT - [0:0]
-A INPUT -j RH-Firewall-1-INPUT
-A FORWARD -j RH-Firewall-1-INPUT
-A RH-Firewall-1-INPUT -i lo -j ACCEPT
-A RH-Firewall-1-INPUT -p icmp --icmp-type any -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A RH-Firewall-1-INPUT -p tcp -s 116.122.36.109 -j ACCEPT
-A RH-Firewall-1-INPUT -p tcp -s 218.50.1.130 -j ACCEPT
-A RH-Firewall-1-INPUT -p tcp -s 110.9.167.210 -j ACCEPT
-A RH-Firewall-1-INPUT -p tcp -s 211.200.178.141 -j ACCEPT
-A RH-Firewall-1-INPUT -p tcp -s 218.237.67.200 -j ACCEPT
-A RH-Firewall-1-INPUT -p tcp -s 121.166.140.142 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 8080 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 8090 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 20 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 21 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 5000:5050 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 80 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 443 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport ${SSH_PORT} -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p udp --dport 161 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 25 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 587 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 110 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 143 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 3306 -j ACCEPT
-A RH-Firewall-1-INPUT -j REJECT --reject-with icmp-host-prohibited
COMMIT
EOF

    set_file_perms "$RULES_FILE" root:root 600 || return 1
    iptables-restore < "$RULES_FILE" || {
        echo "ERROR: iptables 규칙 적용 실패" >&2
        return 1
    }
    service iptables save >/dev/null 2>&1 || true
    chkconfig iptables on || return 1
    service iptables restart || return 1
}

# 방화벽 조치 실패를 main.sh에 반환해 sshd 재시작 전에 실행을 중단한다.
apply_iptables_policy() {
    configure_tcp_wrappers || return 1
    disable_rhosts_trust || return 1
    configure_iptables_rules || return 1
}

apply_iptables_policy
