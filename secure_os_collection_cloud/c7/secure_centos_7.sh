#!/bin/bash
# CentOS 7 Hardening Script
# Version: 5.0 for CentOS 7
# Date: 2025-07-08

set -u  # undefined 변수 에러 처리

# 환경 설정
CONFIG_FILE="/etc/hardening.conf"
NTP_SERVER=${NTP_SERVER:-"kr.pool.ntp.org"}
RSYSLOG_SERVER=${RSYSLOG_SERVER:-"1.224.163.4"}
MIN_PASSWORD_LENGTH=${MIN_PASSWORD_LENGTH:-8}
SSH_PORT=${SSH_PORT:-38371}
BACKUP_DIR="/usr/local/src/scripts_org"
LOG_FILE="/var/log/centos7_hardening_$(date +%F_%T).log"

UserName=""
declare -A restarts_needed

# 환경 파일 로드
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE" || { echo "환경 설정 파일 로드 실패: $CONFIG_FILE"; exit 1; }
fi

# 로그 파일 초기화
mkdir -p "$(dirname "$LOG_FILE")" && touch "$LOG_FILE" && chmod 600 "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

# 유틸리티 함수
log_error() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 오류 [$1]: $2" >&2
}

backup_file() {
  mkdir -p "$BACKUP_DIR" && chmod 700 "$BACKUP_DIR" || { log_error "backup_file" "백업 디렉토리 생성 실패"; return 1; }
  for f; do
    if [ -e "$f" ]; then
      cp -p "$f" "$BACKUP_DIR/$(basename "$f").bak_$(date +%F_%T)" || log_error "backup_file" "$f 백업 실패"
    else
      echo "[WARN] $f 없음, 백업 생략"
    fi
  done
}

set_file_perms() {
  local file="$1" owner="$2" perms="$3"
  if [ -e "$file" ]; then
    chown "$owner" "$file" && echo "  → Set $file owner to $owner" \
      || { log_error "set_file_perms" "$file 소유자 설정 실패"; return 1; }
    chmod "$perms" "$file" && echo "  → Set $file permissions to $perms" \
      || { log_error "set_file_perms" "$file 권한 설정 실패"; return 1; }
  else
    echo "  → $file does not exist, skipping"
    return 1
  fi
}

# CentOS Vault 리포지토리 설정
configure_yum_repos() {
  echo "  → CentOS Vault 리포지토리로 업데이트 중..."
  backup_file /etc/yum.repos.d/CentOS-Base.repo
  cat <<'EOF' > /etc/yum.repos.d/CentOS-Base.repo
# CentOS-Base.repo
#
# The mirror system uses the connecting IP address of the client and the
# update status of each mirror to pick mirrors that are updated to and
# geographically close to the client.  You should use this for CentOS updates
# unless you are manually picking other mirrors.
#
# If the mirrorlist= does not work for you, as a fall back you can try the
# remarked out baseurl= line instead.
#
#
[base]
name=CentOS-$releasever - Base
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=os&infra=$infra
baseurl=http://vault.centos.org/7.9.2009/os/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#released updates
[updates]
name=CentOS-$releasever - Updates
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=updates&infra=$infra
baseurl=http://vault.centos.org/7.9.2009/updates/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#additional packages that may be useful
[extras]
name=CentOS-$releasever - Extras
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=extras&infra=$infra
baseurl=http://vault.centos.org/7.9.2009/extras/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#additional packages that extend functionality of existing packages
[centosplus]
name=CentOS-$releasever - Plus
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=centosplus&infra=$infra
baseurl=http://vault.centos.org/7.9.2009/centosplus/$basearch/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOF
  # YUM 캐시 정리
  yum clean all && yum makecache || log_error "configure_yum_repos" "YUM 캐시 정리 실패"
}

check_root() {
  [ "$EUID" -ne 0 ] && { log_error "check_root" "root 권한 필요"; exit 1; }
}

# 필수 패키지 설치
install_packages() {
  # EPEL 리포지토리 설치
  yum install -y epel-release || echo "  → epel-release 설치 실패, 무시"

  # 필수 패키지 설치
  local pkgs=(lsof net-tools psmisc screen iftop smartmontools vim unzip wget)
  for pkg in "${pkgs[@]}"; do
    if rpm -q "$pkg" &>/dev/null; then
      echo "  → $pkg 이미 설치됨"
    else
      echo "  → $pkg 설치 중..."
      yum install -y "$pkg" || log_error "install_packages" "$pkg 설치 실패"
    fi
  done
  yum -y update || log_error "install_packages" "yum update 실패"
}

# NTP 설정
configure_ntp() {
  backup_file /etc/ntp.conf
  yum install -y ntp || { log_error "configure_ntp" "ntp 설치 실패"; exit 1; }
  systemctl enable ntpd || { log_error "configure_ntp" "ntpd 활성화 실패"; exit 1; }
  systemctl stop ntpd 2>/dev/null
  sed -i '/^server /d' /etc/ntp.conf
  echo "server $NTP_SERVER iburst" >> /etc/ntp.conf
  systemctl start ntpd || { log_error "configure_ntp" "ntpd 시작 실패"; exit 1; }
  ntpdate -u "$NTP_SERVER" || log_error "configure_ntp" "즉시 동기화 실패"
}

# 불필요한 사용자 삭제
remove_unneeded_users() {
  for u in lp games sync shutdown halt; do
    if id "$u" &>/dev/null; then
      userdel -r "$u" && echo "  → $u 삭제" || log_error "remove_unneeded_users" "$u 삭제 실패"
    else
      echo "  → $u 없음"
    fi
  done
}

# 히스토리 및 세션 타임아웃 설정
configure_history_timeout() {
  backup_file /etc/profile
  grep -q HISTTIMEFORMAT /etc/profile || echo 'export HISTTIMEFORMAT="%Y-%m-%d[%H:%M:%S] "' >> /etc/profile
  grep -q TMOUT /etc/profile || echo 'export TMOUT=600' >> /etc/profile
}

# passwd, shadow, hosts, su 권한 설정
configure_etc_perms() {
  backup_file /etc/passwd /etc/shadow /etc/hosts /usr/bin/su
  set_file_perms /etc/passwd root:root 644
  set_file_perms /etc/shadow root:root 400
  set_file_perms /etc/hosts root:root 600
  set_file_perms /usr/bin/su root:wheel 4750
  if ! getent group wheel >/dev/null; then
    groupadd wheel && echo "  → wheel group created"
  fi
}

# FTP 계정 셸 변경
configure_ftp_shell() {
  backup_file /etc/passwd
  if getent passwd ftp | grep -q '/sbin/nologin'; then
    sed -i '/^ftp:/s#/sbin/nologin#/bin/false#' /etc/passwd \
      || log_error "configure_ftp_shell" "/etc/passwd 수정 실패"
    echo "  → ftp 계정 셸을 /bin/false로 변경"
  fi
}

# 중요 파일 권한 설정
configure_file_permissions() {
  backup_file /sbin/unix_chkpwd /usr/bin/newgrp /usr/bin/perl /usr/bin/screen /usr/bin/wget /usr/bin/curl /usr/bin/at
  chmod -s /sbin/unix_chkpwd /usr/bin/newgrp /usr/bin/at
  for f in /usr/bin/perl /usr/bin/screen /usr/bin/wget /usr/bin/curl; do
    set_file_perms "$f" root:root 755
  done
  chmod 1777 /tmp /var/tmp
  find / -perm -4000 -o -perm -2000 -exec chmod -s {} \; 2>/dev/null
  echo "  → SUID/SGID 파일 점검 및 제거 완료"
}

# MOTD 설정
configure_motd() {
  backup_file /etc/motd
  cat <<'EOF' > /etc/motd
********************************************************************
* 본 시스템은 허가된 사용자만 이용하실 수 있습니다.                    *
* 부당한 방법으로 전산망에 접속하거나 정보를 삭제/변경/유출하는         *
* 관련 법령에 따라 처벌 받게 됩니다.                                  *
********************************************************************
EOF
}

# .bashrc 및 Vim 설정
configure_bash_vim() {
  backup_file /root/.bashrc /root/.vimrc
  for a in "alias vi='vim'" "alias grep='grep --color=auto'" "alias ll='ls -alF --color=tty'"; do
    grep -qF "$a" /root/.bashrc || echo "$a" >> /root/.bashrc
  done
  cat <<'EOF' > /root/.vimrc
set ignorecase
set cindent
set sw=4 ts=4 sts=4 shiftwidth=4
set showmode bg=dark paste ruler expandtab linebreak wrap showcmd
set laststatus=2 textwidth=80 wm=1 smartcase smartindent ttyfast
EOF
}

# root 비밀번호 설정
step1_change_root_password() {
  while true; do
    read -r -s -p "root 비밀번호 입력 (최소 ${MIN_PASSWORD_LENGTH}자): " RootPassword; echo
    if [ "${#RootPassword}" -lt "$MIN_PASSWORD_LENGTH" ]; then
      echo "  → 비밀번호는 최소 ${MIN_PASSWORD_LENGTH}자 이상이어야 합니다."
      continue
    fi
    read -r -s -p "비밀번호 확인: " ConfirmPassword; echo
    if [ "$RootPassword" != "$ConfirmPassword" ]; then
      echo "  → 비밀번호가 일치하지 않습니다."
      continue
    fi
    break
  done
  echo "root:$RootPassword" | chpasswd || log_error "change_root_password" "root 비밀번호 설정 실패"
  echo "  → root 비밀번호 설정 완료"
}

# SSH 포트 변경
step2_change_ssh_port() {
  local old_port
  old_port=$(grep -i '^Port' /etc/ssh/sshd_config | awk '{print $2}' | head -1)
  [[ -z "$old_port" ]] && old_port=22
  local new_port
  read -r -p "변경할 SSH 포트 입력 (기본값 $SSH_PORT): " new_port
  new_port=${new_port:-$SSH_PORT}
  if [[ ! "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
    log_error "change_ssh_port" "유효한 포트 번호(1-65535)를 입력하세요"
    exit 1
  fi
  if [[ "$new_port" == "$old_port" ]]; then
    echo "  → 입력한 포트가 현재 포트와 동일, 변경 생략"
    return
  fi
  backup_file /etc/ssh/sshd_config
  sed -i "/^#Port /c\Port $new_port" /etc/ssh/sshd_config
  sed -i "/^Port /c\Port $new_port" /etc/ssh/sshd_config
  sshd -t || log_error "change_ssh_port" "SSHD 설정 파일 오류"
  firewall-cmd --permanent --add-port="$new_port/tcp" && firewall-cmd --reload
  systemctl restart sshd || log_error "change_ssh_port" "sshd 재시작 실패"
}

# 패스워드 정책 설정
set_password_policy() {
  local max_days=90 min_len=8 min_days=0 warn_days=7
  for user in $(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd); do
    chage -M "$max_days" -m "$min_days" -W "$warn_days" "$user" \
      || log_error "set_password_policy" "사용자 $user 설정 실패"
    echo "  → $user 패스워드 정책 설정 완료"
  done
  backup_file /etc/login.defs
  sed -i '/^PASS_MAX_DAYS/d' /etc/login.defs
  sed -i '/^PASS_MIN_LEN/d' /etc/login.defs
  sed -i '/^PASS_MIN_DAYS/d' /etc/login.defs
  sed -i '/^PASS_WARN_AGE/d' /etc/login.defs
  cat <<EOF >> /etc/login.defs
PASS_MAX_DAYS   $max_days
PASS_MIN_LEN    $min_len
PASS_MIN_DAYS   $min_days
PASS_WARN_AGE   $warn_days
EOF
}

# 일반 계정 생성 및 root 로그인 제한
create_fallback_and_restrict() {
  backup_file /etc/passwd /etc/shadow /etc/ssh/sshd_config
  local existing
  existing=$(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd)
  if [ -n "$existing" ]; then
    echo "  → 기존 일반 계정: $existing"
    read -r -p "새 계정 생성 없이 진행? (Y/N): " yn
    [[ "$yn" =~ ^[Yy]$ ]] && return
  fi
  while true; do
    read -r -p "생성할 일반 계정명 입력 (영문자, 숫자, _, -만 허용): " UserName
    if [[ -z "$UserName" ]]; then
      echo "  → 계정명을 입력하지 않았습니다. 다시 입력하세요."
      continue
    fi
    if [[ ! "$UserName" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      echo "  → 유효하지 않은 계정명입니다. 영문자, 숫자, 밑줄(_), 하이픈(-)만 사용 가능합니다."
      continue
    fi
    if id "$UserName" &>/dev/null; then
      echo "  → 계정 '$UserName' 이미 존재"
      continue
    fi
    break
  done
  local UserPassword
  while true; do
    read -r -s -p "계정 '$UserName' 비밀번호 입력 (최소 ${MIN_PASSWORD_LENGTH}자): " UserPassword; echo
    if [ "${#UserPassword}" -lt "$MIN_PASSWORD_LENGTH" ]; then
      echo "  → 최소 ${MIN_PASSWORD_LENGTH}자 이상이어야 합니다."
      continue
    fi
    read -r -s -p "비밀번호 확인: " PasswordConfirm; echo
    if [ "$UserPassword" != "$PasswordConfirm" ]; then
      echo "  → 비밀번호 불일치"
      continue
    fi
    break
  done
  useradd -m -G wheel "$UserName" || log_error "create_user" "계정 $UserName 생성 실패"
  echo "$UserName:$UserPassword" | chpasswd || log_error "create_user" "비밀번호 설정 실패"
  echo "  → 계정 '$UserName' 생성 완료"
  sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  systemctl restart sshd || log_error "restrict_root" "sshd 재시작 실패"
}

# 패스워드 품질 설정
configure_pwquality() {
  backup_file /etc/security/pwquality.conf
  cat <<EOF > /etc/security/pwquality.conf
lcredit=-1
ucredit=-1
dcredit=-1
ocredit=-1
minlen=8
difok=2
EOF
}

# PAM 계정 잠금 설정
configure_pam_lockout() {
  for pam_file in /etc/pam.d/system-auth /etc/pam.d/password-auth; do
    backup_file "$pam_file"
    sed -i '/pam_tally2.so/d' "$pam_file"
    sed -i '/^auth\s\+required\s\+pam_env.so/a \
auth        required      pam_tally2.so deny=3 unlock_time=300' "$pam_file"
    sed -i '/^auth\s\+sufficient\s\+pam_unix.so/a \
auth        [default=die] pam_tally2.so deny=3 unlock_time=300' "$pam_file"
    sed -i '/^account\s\+required\s\+pam_unix.so/a \
account     required      pam_tally2.so' "$pam_file"
  done
}

# su 명령 제한
configure_su_restriction() {
  local su_file="/etc/pam.d/su"
  backup_file "$su_file"
  if ! getent group wheel >/dev/null; then
    groupadd wheel
  fi
  set_file_perms /usr/bin/su root:wheel 4750
  if grep -q '^#auth\s\+required\s\+pam_wheel.so\s\+use_uid' "$su_file"; then
    sed -i 's/^#\(auth\s\+required\s\+pam_wheel.so\s\+use_uid\)/\1/' "$su_file"
  elif ! grep -q 'pam_wheel.so.*use_uid' "$su_file"; then
    sed -i '/pam_rootok.so/a auth       required    pam_wheel.so use_uid' "$su_file"
  fi
}

# SELinux 비활성화
disable_selinux() {
  backup_file /etc/selinux/config
  setenforce 0 || log_error "selinux" "setenforce 실패"
  sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
}

# rsyslog 설정
configure_rsyslog() {
  backup_file /etc/rsyslog.conf
  set_file_perms /etc/rsyslog.conf root:root 640
  echo "*.* @$RSYSLOG_SERVER" >> /etc/rsyslog.conf
  systemctl restart rsyslog || log_error "rsyslog" "rsyslog 재시작 실패"
}

# sysctl 설정
configure_sysctl() {
  backup_file /etc/sysctl.conf
  cat <<EOF > /etc/sysctl.conf
# IPv6 비활성화
net.ipv6.conf.all.disable_ipv6 = 1
# ICMP 브로드캐스트 무시
net.ipv4.icmp_echo_ignore_broadcasts = 1
# TCP 메모리 설정
net.ipv4.tcp_rmem = 4096 10000000 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
# TCP 재사용 및 타임아웃 설정
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 1800
net.ipv4.tcp_max_syn_backlog = 4096
# 네트워크 메모리 설정
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.somaxconn = 10240
# 로컬 포트 범위 설정
net.ipv4.ip_local_port_range = 4000 65535
EOF
  sysctl -p || log_error "sysctl" "적용 실패"
}

# limits.conf 설정
configure_limits() {
  backup_file /etc/security/limits.conf
  cat <<EOF > /etc/security/limits.conf
* soft nofile 61200
* hard nofile 61200
* soft nproc 61200
* hard nproc 61200
EOF
}

# TCP Wrappers 설정
configure_tcp_wrappers() {
  yum install -y tcp_wrappers || log_error "tcp_wrappers" "설치 실패"
  backup_file /etc/hosts.allow /etc/hosts.deny
  echo "sshd: ALL" > /etc/hosts.allow
  echo "ALL: ALL" > /etc/hosts.deny
  set_file_perms /etc/hosts.allow root:root 644
  set_file_perms /etc/hosts.deny root:root 644
}

# rhosts/hosts.equiv 제거
disable_rhosts_hosts_equiv() {
  backup_file /etc/hosts.equiv "$HOME/.rhosts"
  rm -f /etc/hosts.equiv "$HOME/.rhosts"
}

# Finger 서비스 비활성화
disable_finger() {
  if rpm -q finger &>/dev/null; then
    systemctl disable --now finger || log_error "disable_finger" "finger 비활성화 실패"
  fi
}

# Anonymous FTP 비활성화
disable_anonymous_ftp() {
  if rpm -q vsftpd &>/dev/null; then
    backup_file /etc/vsftpd/vsftpd.conf
    sed -i 's/^anonymous_enable=.*/anonymous_enable=NO/' /etc/vsftpd/vsftpd.conf
    systemctl restart vsftpd || log_error "disable_anonymous_ftp" "vsftpd 재시작 실패"
  fi
}

# rsh/rlogin/rexec 비활성화
disable_r_services() {
  for svc in rsh rlogin rexec; do
    if rpm -q "$svc" &>/dev/null; then
      systemctl disable --now "$svc" || log_error "disable_r_services" "$svc 비활성화 실패"
    fi
  done
}

# cron/at 권한 설정
configure_cron_permissions() {
  for f in /etc/cron.allow /etc/cron.deny /etc/at.allow /etc/at.deny; do
    if [ -e "$f" ]; then
      backup_file "$f"
      set_file_perms "$f" root:root 640
    else
      touch "$f"
      set_file_perms "$f" root:root 640
    fi
  done
}

# DoS 취약 서비스 비활성화
disable_dos_services() {
  for svc in echo discard daytime chargen; do
    if [ -f /etc/xinetd.d/$svc ]; then
      sed -i 's/disable *= *no/disable = yes/' /etc/xinetd.d/$svc
    fi
  done
  systemctl restart xinetd &>/dev/null || true
}

# automountd 비활성화
remove_automountd() {
  if rpm -q autofs &>/dev/null; then
    systemctl disable --now autofs || log_error "remove_automountd" "autofs 비활성화 실패"
  fi
}

# NIS 비활성화
disable_nis() {
  for svc in ypbind ypserv ypxfrd rpc.yppasswdd rpc.ypupdated; do
    if rpm -q "$svc" &>/dev/null; then
      systemctl disable --now "$svc" || log_error "disable_nis" "$svc 비활성화 실패"
    fi
  done
}

# tftp/talk 비활성화
disable_tftp_talk() {
  for svc in tftp talk; do
    if rpm -q "$svc" &>/dev/null; then
      systemctl disable --now "$svc" || log_error "disable_tftp_talk" "$svc 비활성화 실패"
    fi
  done
}

# Postfix vrfy 명령어 비활성화
configure_smtp_security() {
  if rpm -q postfix &>/dev/null; then
    backup_file /etc/postfix/main.cf
    if grep -q "^disable_vrfy_command[[:space:]]*=[[:space:]]*yes" /etc/postfix/main.cf; then
      echo "  → Postfix: vrfy 명령어 비활성화 이미 설정됨"
    else
      if grep -q "^disable_vrfy_command" /etc/postfix/main.cf; then
        sed -i 's/^disable_vrfy_command.*/disable_vrfy_command = yes/' /etc/postfix/main.cf || log_error "configure_smtp_security" "postfix main.cf 수정 실패"
      else
        echo "disable_vrfy_command = yes" >> /etc/postfix/main.cf || log_error "configure_smtp_security" "postfix main.cf 설정 추가 실패"
      fi
      systemctl restart postfix || log_error "configure_smtp_security" "postfix 재시작 실패"
      echo "  → Postfix: vrfy 명령어 비활성화 설정 완료"
    fi
  else
    echo "  → Postfix: 설치되지 않음, vrfy 명령어 비활성화 설정 생략"
  fi
}

main() {
  check_root
  configure_yum_repos
  install_packages
  configure_ntp
  remove_unneeded_users
  configure_history_timeout
  configure_etc_perms
  configure_file_permissions
  configure_motd
  configure_bash_vim
  step1_change_root_password
  step2_change_ssh_port
  set_password_policy
  create_fallback_and_restrict
  configure_pwquality
  configure_pam_lockout
  configure_su_restriction
  disable_selinux
  configure_rsyslog
  configure_sysctl
  configure_limits
  configure_tcp_wrappers
  disable_rhosts_hosts_equiv
  disable_finger
  disable_anonymous_ftp
  disable_r_services
  configure_cron_permissions
  disable_dos_services
  remove_automountd
  disable_nis
  configure_ftp_shell
  disable_tftp_talk
  configure_smtp_security
}

main "$@"