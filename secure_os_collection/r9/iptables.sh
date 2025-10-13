#!/bin/bash
# iptables.sh : Rocky 9 방화벽 설정 (사용자 선택 기반)
# 사용: source 로 호출되거나 단독 실행 가능

set -euo pipefail
source /usr/local/src/secure_os_collection/r9/common.sh

# 기본값: 22 → 권장 기본값: 38371 → 고객 입력값
SSH_PORT="${NEW_SSH_PORT:-$(grep -iE '^[# ]*Port[[:space:]]+[0-9]+' /etc/ssh/sshd_config | awk '{print $2}' | tail -n1)}"
SSH_PORT="${SSH_PORT:-22}"

# iptables 규칙 파일 경로 (전역 변수)
rules="/etc/sysconfig/iptables"

########################################
# 1. firewalld 완전 비활성화 (공통 처리)
########################################
if command -v firewall-cmd >/dev/null 2>&1; then
    systemctl stop firewalld || true
    systemctl disable firewalld || true
    systemctl mask firewalld || true
    log_info "firewalld 비활성화(mask) 완료"
fi

########################################
# 2. 사용자 선택
########################################
echo "로컬 방화벽(iptables)를 사용하시겠습니까? (y/n)"
read -r USE_IPTABLES

########################################
# 3. iptables 적용 여부 분기
########################################
if [[ "$USE_IPTABLES" =~ ^[Yy]$ ]]; then
    log_info "iptables 방화벽을 설정합니다."

    # iptables 패키지 설치
    if ! rpm -q iptables >/dev/null 2>&1 || ! rpm -q iptables-services >/dev/null 2>&1; then
        dnf install -y iptables iptables-services || { log_error "iptables" "설치 실패"; exit 1; }
        log_info "iptables/iptables-services 설치 완료"
    else
        log_info "iptables/iptables-services 이미 설치됨"
    fi

    # 규칙 파일 작성
    cat > "$rules" <<EOF
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
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

# FTP Service Port & Passive Port
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 8080 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 8090 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 20 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 21 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 5000:5050 -j ACCEPT

# Web Service Port
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 80 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 443 -j ACCEPT

# Managed Port ( SSH & SNMP )
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport ${SSH_PORT} -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p udp --dport 161 -j ACCEPT

# Mail Service Port
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 25 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 587 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 110 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 143 -j ACCEPT

# Mysql Service Port (옵션: 필요 시 차단)
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 3306 -j ACCEPT

# DROP 정책
-A RH-Firewall-1-INPUT -p icmp --icmp-type any -j DROP
-A RH-Firewall-1-INPUT -j REJECT --reject-with icmp-host-prohibited

COMMIT
EOF

    chmod 600 "$rules"
    log_info "iptables 규칙 파일 생성: $rules"

    # 서비스 적용
    systemctl enable iptables
    systemctl restart iptables || {
        echo "❌ iptables 규칙 적용 실패 - /etc/sysconfig/iptables 확인 필요"
        exit 1
    }
    log_info "iptables 적용 및 검증 완료"

else
    log_info "iptables 사용하지 않음 → firewalld 비활성화 상태로 유지"
fi