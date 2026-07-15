#!/bin/bash
# c7/firewalld.sh : CentOS 7 firewalld 설정
source /usr/local/src/secure_os_collection/c7/common.sh

SSH_PORT="${NEW_SSH_PORT:-$(grep -iE '^[# ]*Port[[:space:]]+[0-9]+' /etc/ssh/sshd_config | awk '{print $2}' | tail -n1)}"
SSH_PORT="${SSH_PORT:-22}"

# iptables 비활성화
systemctl stop iptables 2>/dev/null || true
systemctl disable iptables 2>/dev/null || true
systemctl mask iptables 2>/dev/null || true

# firewalld 패키지 설치 확인
if ! rpm -q firewalld >/dev/null 2>&1; then
    yum install -y firewalld || { echo "ERROR: firewalld 패키지 설치 실패" >&2; exit 1; }
fi

systemctl unmask firewalld >/dev/null 2>&1 || true
systemctl enable --now firewalld >/dev/null 2>&1 || { echo "ERROR: firewalld 시작 실패" >&2; exit 1; }

# iptables와 동일한 firewalld 정책 설정
# KSIDC 관리 IP 전체 TCP 포트 허용 (리치 룰)
firewall-cmd --permanent --zone=public --add-rich-rule="rule family='ipv4' source address='116.122.36.109' protocol value='tcp' accept"
firewall-cmd --permanent --zone=public --add-rich-rule="rule family='ipv4' source address='218.50.1.130' protocol value='tcp' accept"
firewall-cmd --permanent --zone=public --add-rich-rule="rule family='ipv4' source address='110.9.167.210' protocol value='tcp' accept"
firewall-cmd --permanent --zone=public --add-rich-rule="rule family='ipv4' source address='211.200.178.141' protocol value='tcp' accept"
firewall-cmd --permanent --zone=public --add-rich-rule="rule family='ipv4' source address='218.237.67.200' protocol value='tcp' accept"
firewall-cmd --permanent --zone=public --add-rich-rule="rule family='ipv4' source address='121.166.140.142' protocol value='tcp' accept"

# 일반 포트 추가
# FTP 포트
firewall-cmd --permanent --zone=public --add-port=8080/tcp
firewall-cmd --permanent --zone=public --add-port=8090/tcp
firewall-cmd --permanent --zone=public --add-port=20/tcp
firewall-cmd --permanent --zone=public --add-port=21/tcp
firewall-cmd --permanent --zone=public --add-port=5000-5050/tcp
# Web 포트
firewall-cmd --permanent --zone=public --add-port=80/tcp
firewall-cmd --permanent --zone=public --add-port=443/tcp
# 관리 포트 (SSH 및 SNMP)
firewall-cmd --permanent --zone=public --add-port="${SSH_PORT}/tcp"
firewall-cmd --permanent --zone=public --add-port=161/udp
# 메일 포트
firewall-cmd --permanent --zone=public --add-port=25/tcp
firewall-cmd --permanent --zone=public --add-port=587/tcp
firewall-cmd --permanent --zone=public --add-port=110/tcp
firewall-cmd --permanent --zone=public --add-port=143/tcp
# MySQL 포트
firewall-cmd --permanent --zone=public --add-port=3306/tcp

# ICMP
firewall-cmd --permanent --zone=public --add-protocol=icmp

# 기본 차단(DROP) 정책
firewall-cmd --permanent --zone=public --set-target=DROP

# 영구 규칙 적용을 위한 reload
if ! firewall-cmd --reload; then
    echo "ERROR: firewalld 규칙 reload 실패" >&2
    exit 1
fi
