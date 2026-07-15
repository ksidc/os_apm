#!/bin/bash
# iptables.sh : Rocky 10 방화벽 설정 (사용자 선택 기반)

set -euo pipefail
source /usr/local/src/secure_os_collection/r10/common.sh

SSH_PORT="${NEW_SSH_PORT:-$(grep -iE '^[# ]*Port[[:space:]]+[0-9]+' /etc/ssh/sshd_config | awk '{print $2}' | tail -n1)}"
SSH_PORT="${SSH_PORT:-22}"

rules="/etc/sysconfig/iptables"

# firewalld를 비활성화해 iptables 단독 정책이 적용되도록 한다.
if command -v firewall-cmd >/dev/null 2>&1; then
    systemctl stop firewalld || true
    systemctl disable firewalld || true
    systemctl mask firewalld || true
fi

# iptables-services를 설치하고 기준 방화벽 정책 파일을 생성한다.
if ! rpm -q iptables >/dev/null 2>&1 || ! rpm -q iptables-services >/dev/null 2>&1; then
    dnf install -y iptables iptables-services || {
        echo "ERROR: iptables 설치 실패" >&2
        exit 1
    }
fi

systemctl unmask iptables >/dev/null 2>&1 || true

# U-28: INPUT/FORWARD 기본 정책 DROP
cat > "$rules" <<EOF
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
:RH-Firewall-1-INPUT - [0:0]

-A INPUT -j RH-Firewall-1-INPUT
-A FORWARD -j RH-Firewall-1-INPUT

# 기본 허용
-A RH-Firewall-1-INPUT -i lo -j ACCEPT
-A RH-Firewall-1-INPUT -p icmp --icmp-type any -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

######################################################################################################
# KSIDC SSH Allow (관리자 IP)
-A RH-Firewall-1-INPUT -p tcp -s 116.122.36.109 -j ACCEPT
-A RH-Firewall-1-INPUT -p tcp -s 218.50.1.130 -j ACCEPT
-A RH-Firewall-1-INPUT -p tcp -s 110.9.167.210 -j ACCEPT
-A RH-Firewall-1-INPUT -p tcp -s 211.200.178.141 -j ACCEPT
-A RH-Firewall-1-INPUT -p tcp -s 218.237.67.200 -j ACCEPT
-A RH-Firewall-1-INPUT -p tcp -s 121.166.140.142 -j ACCEPT
######################################################################################################

# FTP 서비스 포트 및 Passive 포트
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 8080 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 8090 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 20 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 21 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 5000:5050 -j ACCEPT

# Web 서비스 포트
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 80 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 443 -j ACCEPT

# 관리 포트 (SSH 및 SNMP)
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport ${SSH_PORT} -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p udp --dport 161 -j ACCEPT

# 메일 서비스 포트
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 25 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 587 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 110 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 143 -j ACCEPT

# MySQL 서비스 포트
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 3306 -j ACCEPT

# 기본 차단(DROP) 정책
-A RH-Firewall-1-INPUT -j REJECT --reject-with icmp-host-prohibited

COMMIT
EOF

chmod 600 "$rules"

systemctl enable iptables
systemctl restart iptables || {
    echo "ERROR: iptables 규칙 적용 실패 - /etc/sysconfig/iptables 확인 필요" >&2
    exit 1
}
