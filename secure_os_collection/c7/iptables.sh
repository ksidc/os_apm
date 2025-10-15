#!/bin/bash
# iptables.sh : CentOS 7 firewall configuration (interactive)
# Usage: source or execute directly

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Default SSH port resolution order: NEW_SSH_PORT -> sshd_config -> fallback 22
SSH_PORT="${NEW_SSH_PORT:-$(grep -iE '^[# ]*Port[[:space:]]+[0-9]+' /etc/ssh/sshd_config | awk '{print $2}' | tail -n1)}"
SSH_PORT="${SSH_PORT:-22}"

# iptables rules file path
RULES_FILE="/etc/sysconfig/iptables"

configure_tcp_wrappers() {
  log_info "[NETWORK] Configuring TCP wrappers"
  yum install -y tcp_wrappers || log_error "configure_tcp_wrappers" "Failed to install tcp_wrappers"
  backup_file /etc/hosts.allow /etc/hosts.deny
  echo "sshd: ALL" > /etc/hosts.allow
  echo "ALL: ALL" > /etc/hosts.deny
  set_file_perms /etc/hosts.allow root:root 644
  set_file_perms /etc/hosts.deny root:root 644
}

disable_rhosts_hosts_equiv() {
  log_info "[NETWORK] Removing rhosts/hosts.equiv trust files"
  backup_file /etc/hosts.equiv "$HOME/.rhosts"
  rm -f /etc/hosts.equiv "$HOME/.rhosts"
}

########################################
# 1. Disable firewalld entirely (if present)
########################################
if command -v firewall-cmd >/dev/null 2>&1; then
  systemctl stop firewalld || true
  systemctl disable firewalld || true
  systemctl mask firewalld || true
  log_info "[NETWORK] firewalld disabled and masked"
fi

# Always apply TCP wrapper hardening even if iptables is skipped
configure_tcp_wrappers
disable_rhosts_hosts_equiv

########################################
# 2. Prompt for iptables usage
########################################
echo "로컬 방화벽(iptables)을 활성화하시겠습니까? (y/n)"
read -r USE_IPTABLES

########################################
# 3. Configure iptables if requested
########################################
if [[ "$USE_IPTABLES" =~ ^[Yy]$ ]]; then
  log_info "[NETWORK] Configuring iptables firewall"

  # Ensure required packages are installed
  if ! rpm -q iptables >/dev/null 2>&1 || ! rpm -q iptables-services >/dev/null 2>&1; then
    yum install -y iptables iptables-services || { log_error "iptables" "Failed to install iptables packages"; exit 1; }
    log_info "[NETWORK] Installed iptables/iptables-services"
  else
    log_info "[NETWORK] iptables/iptables-services already present"
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

# MySQL service port (adjust as needed)
-A RH-Firewall-1-INPUT -m state --state NEW -p tcp --dport 3306 -j ACCEPT

# Default drop policies
-A RH-Firewall-1-INPUT -p icmp --icmp-type any -j DROP
-A RH-Firewall-1-INPUT -j REJECT --reject-with icmp-host-prohibited

COMMIT
EOF

  chmod 600 "$RULES_FILE"
  log_info "[NETWORK] iptables rules written to $RULES_FILE"

  # Enable and restart service to apply rules
  systemctl enable iptables >/dev/null 2>&1 || log_error "iptables" "Failed to enable iptables service"
  if systemctl restart iptables; then
    log_info "[NETWORK] iptables service restarted successfully"
  else
    echo "iptables 규칙 적용에 실패했습니다 - $RULES_FILE 파일을 확인하세요" >&2
    exit 1
  fi
else
  log_info "[NETWORK] Skipping iptables configuration (firewalld remains disabled)"
fi
