#!/bin/bash
# Ubuntu 22.04 Hardening Script
# Version: 1.0
# Date: 2025-07-01

set -u  # undefined variable error handling

# Environment configuration
CONFIG_FILE="/etc/hardening.conf"
NTP_SERVER=${NTP_SERVER:-"pool.ntp.org"}
RSYSLOG_SERVER=${RSYSLOG_SERVER:-"1.224.163.4"}
MIN_PASSWORD_LENGTH=${MIN_PASSWORD_LENGTH:-8}
SSH_PORT=${SSH_PORT:-38371}
BACKUP_DIR="/usr/local/src/scripts_org"
LOG_FILE="/var/log/ubuntu_hardening_$(date +%F_%T).log"

UserName=""
declare -A restarts_needed

# Load environment file
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE" || { echo "환경 설정 파일 로드 실패: $CONFIG_FILE"; exit 1; }
fi

# Initialize log file
mkdir -p "$(dirname "$LOG_FILE")" && touch "$LOG_FILE" && chmod 600 "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

# Utility functions
log_error() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR [$1]: $2" >&2
}

backup_file() {
  mkdir -p "$BACKUP_DIR" && chmod 700 "$BACKUP_DIR" || { log_error "backup_file" "Failed to create backup directory"; return 1; }
  for f; do
    if [ -e "$f" ]; then
      cp "$f" "$BACKUP_DIR/$(basename "$f").bak_$(date +%F_%T)" || log_error "backup_file" "Failed to backup $f"
    else
      echo "[경고] $f 파일이 존재하지 않아 백업을 생략합니다."
    fi
  done
}

set_file_perms() {
  local file="$1" owner="$2" perms="$3"
  if [ -e "$file" ]; then
    chown "$owner" "$file" && echo "  → $file 소유자를 $owner로 설정했습니다." \
      || { log_error "set_file_perms" "Failed to set owner for $file"; return 1; }
    chmod "$perms" "$file" && echo "  → $file 권한을 $perms로 설정했습니다." \
      || { log_error "set_file_perms" "Failed to set permissions for $file"; return 1; }
  else
    echo "  → $file 파일이 존재하지 않아 권한 설정을 생략합니다."
    return 1
  fi
}

check_root() {
  [ "$EUID" -ne 0 ] && { log_error "check_root" "Root privileges required"; exit 1; }
}

wait_for_apt_lock() {
  while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    echo "apt 잠금 해제를 기다리는 중..."
    sleep 5
  done
}

# Disable automatic updates
disable_auto_updates() {
  backup_file /etc/apt/apt.conf.d/20auto-upgrades
  cat <<EOF > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
EOF
  systemctl disable --now unattended-upgrades || log_error "disable_auto_updates" "Failed to disable unattended-upgrades"
  echo "  → 자동 업데이트를 비활성화했습니다."
}

# Install essential packages
install_packages() {
  local pkgs=(lsof net-tools psmisc screen iftop smartmontools vim unzip wget iputils-ping lrzsz ufw rsyslog)
  wait_for_apt_lock
  apt update || { log_error "install_packages" "apt update failed"; exit 1; }
  for pkg in "${pkgs[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
      echo "  → $pkg 이미 설치되어 있습니다."
    else
      echo "  → $pkg 설치 중..."
      apt install -y "$pkg" || { log_error "install_packages" "Failed to install $pkg"; exit 1; }
    fi
  done
}

# NTP configuration (using systemd-timesyncd or chrony)
configure_ntp() {
  backup_file /etc/systemd/timesyncd.conf
  if dpkg -s chrony &>/dev/null; then
    backup_file /etc/chrony/chrony.conf
    sed -i '/^pool /d' /etc/chrony/chrony.conf
    echo "pool $NTP_SERVER iburst" >> /etc/chrony/chrony.conf
    systemctl enable --now chrony || { log_error "configure_ntp" "Failed to start chrony"; exit 1; }
    systemctl restart chrony || { log_error "configure_ntp" "Failed to restart chrony"; exit 1; }
    chronyc makestep || log_error "configure_ntp" "Failed to sync time"
  else
    sed -i "s/^#NTP=/NTP=$NTP_SERVER/" /etc/systemd/timesyncd.conf
    systemctl enable --now systemd-timesyncd || { log_error "configure_ntp" "Failed to start timesyncd"; exit 1; }
    systemctl restart systemd-timesyncd || { log_error "configure_ntp" "Failed to restart timesyncd"; exit 1; }
    timedatectl set-ntp true || log_error "configure_ntp" "Failed to enable NTP"
  fi
}

# Remove unnecessary users (lp, games)
remove_unneeded_users() {
  for u in lp games; do
    if id "$u" &>/dev/null; then
      userdel -r "$u" && echo "  → $u 사용자를 삭제했습니다." || log_error "remove_unneeded_users" "Failed to delete $u"
    else
      echo "  → $u 사용자가 존재하지 않습니다."
    fi
  done
}

# Configure history and session timeout
configure_history_timeout() {
  backup_file /etc/profile
  grep -q HISTTIMEFORMAT /etc/profile || echo 'export HISTTIMEFORMAT="%Y-%m-%d[%H:%M:%S] "' >> /etc/profile
  grep -q TMOUT /etc/profile || echo 'export TMOUT=600' >> /etc/profile
}

# Configure permissions for passwd, shadow, hosts, su
configure_etc_perms() {
  backup_file /etc/passwd /etc/shadow /etc/hosts /usr/bin/su
  set_file_perms /etc/passwd root:root 644
  set_file_perms /etc/shadow root:shadow 640
  set_file_perms /etc/hosts root:root 644
  set_file_perms /usr/bin/su root:adm 4750

  # Ensure adm group exists
  if ! getent group adm >/dev/null; then
    groupadd adm && echo "  → adm 그룹을 생성했습니다." \
      || { log_error "configure_etc_perms" "Failed to create adm group"; exit 1; }
  else
    echo "  → adm 그룹이 이미 존재합니다."
  fi

  # Verify final permissions
  if [ "$(stat -c '%a' /usr/bin/su)" = "4750" ] && [ "$(stat -c '%U:%G' /usr/bin/su)" = "root:adm" ]; then
    echo "  → /usr/bin/su 권한과 소유자가 올바르게 설정되었습니다."
  else
    echo "  → 오류: /usr/bin/su 권한 또는 소유자 설정이 잘못되었습니다."
    exit 1
  fi
}

# Configure FTP account shell (/sbin/nologin → /bin/false)
configure_ftp_shell() {
  backup_file /etc/passwd
  if getent passwd ftp | grep -q '/sbin/nologin'; then
    sed -i '/^ftp:/s#/sbin/nologin#/bin/false#' /etc/passwd \
      || { log_error "configure_ftp_shell" "Failed to modify /etc/passwd"; return 1; }
    echo "  → ftp 계정 셸을 /bin/false로 변경했습니다."
  else
    echo "  → ftp 계정 셸 변경이 필요 없거나 이미 적용되었습니다."
  fi
}

# Configure permissions for critical files and SUID/SGID (U-07, U-08, U-09, U-13)
configure_security_settings() {
  backup_file /etc/passwd /etc/shadow /etc/hosts /usr/bin/newgrp /usr/bin/perl /usr/bin/screen /usr/bin/wget /usr/bin/curl /sbin/unix_chkpwd /usr/bin/at

  # U-07: /etc/passwd permissions
  set_file_perms /etc/passwd root:root 644
  [ "$(stat -c '%U:%G %a' /etc/passwd 2>/dev/null)" = "root:root 644" ] || log_error "configure_security_settings" "/etc/passwd 권한 설정 실패"

  # U-08: /etc/shadow permissions
  set_file_perms /etc/shadow root:root 400
  [ "$(stat -c '%U:%G %a' /etc/shadow 2>/dev/null)" = "root:root 400" ] || log_error "configure_security_settings" "/etc/shadow 권한 설정 실패"

  # U-09: /etc/hosts permissions
  set_file_perms /etc/hosts root:root 600
  [ "$(stat -c '%U:%G %a' /etc/hosts 2>/dev/null)" = "root:root 600" ] || log_error "configure_security_settings" "/etc/hosts 권한 설정 실패"

  # U-13: Minimize SUID/SGID
  local files="/sbin/dump /usr/bin/lpq-lpd /usr/bin/lpr /usr/sbin/lpc /usr/bin/lpr-lpd /usr/sbin/lpc-lpd /usr/bin/lprm /usr/sbin/traceroute /usr/bin/lpq /usr/bin/lprm-lpd /usr/bin/perl /usr/bin/screen /usr/bin/wget /usr/bin/curl"
  for f in $files; do
    if [ -e "$f" ]; then
      chmod -s "$f" && set_file_perms "$f" root:root 755
      [ $? -eq 0 ] && echo "  → $f에서 SUID/SGID 제거 및 권한 설정: root:root, 755"
    fi
  done

  # U-13: Maintain essential SUID files
  local essential_files="/usr/bin/newgrp /sbin/unix_chkpwd /usr/bin/at"
  for f in $essential_files; do
    if [ -e "$f" ]; then
      set_file_perms "$f" root:root 4755
      [ "$(stat -c '%a' "$f" 2>/dev/null)" = "4755" ] && echo "  → $f SUID 유지: root:root, 4755" || log_error "configure_security_settings" "Failed to set SUID for $f"
    fi
  done

  # U-13: Maintain Sticky bit for /tmp, /var/tmp
  set_file_perms /tmp root:root 1777
  set_file_perms /var/tmp root:root 1777
  echo "  → /tmp, /var/tmp Sticky bit 유지: root:root, 1777"
}

# Configure MOTD
configure_motd() {
  echo "MOTD 설정"
  backup_file /etc/motd
  cat <<'EOF' > /etc/motd
********************************************************************
* 본 시스템은 허가된 사용자만 이용하실 수 있습니다.                    *
* 부당한 방법으로 전산망에 접속하거나 정보를 삭제/변경/유출하는         *
* 관련 법령에 따라 처벌 받게 됩니다.                                  *
********************************************************************
EOF
}

# Configure .bashrc and Vim
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

# Change root password
step1_change_root_password() {
  while true; do
    read -r -s -p "root 비밀번호를 입력하세요 (최소 ${MIN_PASSWORD_LENGTH}자): " RootPassword; echo
    if [ "${#RootPassword}" -lt "$MIN_PASSWORD_LENGTH" ]; then
      echo "  → 비밀번호는 최소 ${MIN_PASSWORD_LENGTH}자 이상이어야 합니다."
      continue
    fi
    read -r -s -p "비밀번호 확인: " ConfirmPassword; echo
    if [ "$RootPassword" != "$ConfirmPassword" ]; then
      echo "  → 비밀번호가 일치하지 않습니다. 다시 입력해주세요."
      continue
    fi
    break
  done

  echo "root:$RootPassword" | chpasswd \
    || { log_error "change_root_password" "Failed to set root password"; exit 1; }
  passwd -S root >> "$LOG_FILE" \
    || log_error "change_root_password" "Failed to query root status"
  echo "  → root 비밀번호 설정이 완료되었습니다."
}

# Change SSH port
step2_change_ssh_port() {
  local old_port
  old_port=$(grep -i '^Port' /etc/ssh/sshd_config | awk '{print $2}' | head -1)
  [[ -z "$old_port" ]] && old_port=22
  local max_retries=3
  local new_port
  echo "현재 SSH 포트: $old_port, 기본값: $SSH_PORT"
  for ((i=1; i<=max_retries; i++)); do
    read -r -p "변경할 포트를 입력하세요 (Enter로 기본값 $SSH_PORT 사용, $i/$max_retries): " new_port < /dev/tty
    new_port=${new_port:-$SSH_PORT}
    if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1 ] && [ "$new_port" -le 65535 ]; then
      break
    fi
    echo "오류: 유효한 포트 번호(1-65535)를 입력하세요."
    [ "$i" -eq "$max_retries" ] && { log_error "change_ssh_port" "Failed to enter valid port"; exit 1; }
  done
  if [[ "$new_port" == "$old_port" ]]; then
    echo "입력한 포트가 현재 포트와 동일합니다."
    read -r -p "변경 없이 진행하시겠습니까? (Y/N): " proceed < /dev/tty
    if [[ "$proceed" =~ ^[Yy]$ ]]; then
      echo "[정보] SSH 포트 변경을 생략했습니다."
      return
    else
      step2_change_ssh_port
      return
    fi
  fi
  backup_file /etc/ssh/sshd_config
  sed -i "/^#Port /c\Port $new_port" /etc/ssh/sshd_config
  sed -i "/^Port /c\Port $new_port" /etc/ssh/sshd_config
  sshd -t || { log_error "change_ssh_port" "SSHD config file error"; exit 1; }
  ufw allow "$new_port"/tcp || { log_error "change_ssh_port" "Failed to update firewall"; exit 1; }
  read -r -p "지금 sshd를 재시작하시겠습니까? (Y/N): " restart < /dev/tty
  if [[ "$restart" =~ ^[Yy]$ ]]; then
    systemctl restart ssh || { log_error "change_ssh_port" "Failed to restart sshd"; exit 1; }
  else
    restarts_needed["ssh"]=1
  fi
}

# Configure password expiration policy
set_password_policy() {
  read -r -p "비밀번호 만료 정책을 설정하시겠습니까? (Y/N): " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    echo "다음 항목에 대해 값을 입력하세요. (Enter로 기본값 사용)"
    read -r -p "1. 최대 사용일수 (기본값: 90): " max_days
    read -r -p "2. 최소 길이 (기본값: 8): " min_len
    read -r -p "3. 최소 사용일수 (기본값: 0): " min_days
    read -r -p "4. 경고일수 (기본값: 7): " warn_days
    max_days=${max_days:-90}
    min_len=${min_len:-8}
    min_days=${min_days:-0}
    warn_days=${warn_days:-7}

    echo "설정 요약: 최대 $max_days일, 최소 $min_days일, 경고 $warn_days일 전"

    # Apply to existing users
    for user in $(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd); do
      chage -M "$max_days" -m "$min_days" -W "$warn_days" "$user" \
        || log_error "set_password_policy" "Failed to set policy for $user"
      echo "→ $user 설정 완료"
      chage -l "$user" | grep -E 'Maximum|Minimum|Warning'
    done

    # Update /etc/login.defs
    backup_file /etc/login.defs
    sed -i '/^PASS_MAX_DAYS/d' /etc/login.defs
    sed -i '/^PASS_MIN_LEN/d' /etc/login.defs
    sed -i '/^PASS_MIN_DAYS/d' /etc/login.defs
    sed -i '/^PASS_WARN_AGE/d' /etc/login.defs
    {
      echo "PASS_MAX_DAYS   $max_days"
      echo "PASS_MIN_LEN    $min_len"
      echo "PASS_MIN_DAYS   $min_days"
      echo "PASS_WARN_AGE   $warn_days"
    } >> /etc/login.defs \
      || log_error "set_password_policy" "Failed to update /etc/login.defs"
    echo "/etc/login.defs에 전역 비밀번호 만료 정책이 적용되었습니다."
  else
    echo "비밀번호 만료 정책 설정을 생략했습니다."
  fi
}

# Create fallback account and restrict root login
create_fallback_and_restrict() {
  backup_file /etc/passwd /etc/shadow /etc/ssh/sshd_config /etc/pam.d/su

  # Ensure /run/sshd directory exists
  mkdir -p /run/sshd
  chown root:root /run/sshd
  chmod 755 /run/sshd
  echo "  → /run/sshd 디렉토리 생성 및 권한 설정 완료"

  # (A) 기존 사용자 확인 (UID>=1000)
  local existing
  existing=$(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd)
  if [ -n "$existing" ]; then
    echo "  → 기존 일반 계정 발견: $existing"
    read -r -p "새 계정 생성 없이 넘어가시겠습니까? (Y/N): " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      echo "  → 계정 생성을 생략했습니다."
    else
      # (B) 새 계정명 입력
      read -r -p "생성할 일반 계정명을 입력하세요: " UserName
      if [ -z "$UserName" ]; then
        log_error "create_user" "계정명 필요"
        return 1
      fi
      if id "$UserName" &>/dev/null; then
        echo "  → 계정 '$UserName'이(가) 이미 존재합니다. 생략합니다."
      else
        # (C) 비밀번호 입력 및 확인
        local UserPassword PasswordConfirm
        while true; do
          read -r -s -p "계정 '$UserName'의 비밀번호를 입력하세요 (최소 ${MIN_PASSWORD_LENGTH}자): " UserPassword; echo
          if [ "${#UserPassword}" -lt "$MIN_PASSWORD_LENGTH" ]; then
            echo "  → 비밀번호는 최소 ${MIN_PASSWORD_LENGTH}자 이상이어야 합니다."
            continue
          fi
          read -r -s -p "비밀번호 확인: " PasswordConfirm; echo
          if [ "$UserPassword" != "$PasswordConfirm" ]; then
            echo "  → 비밀번호가 일치하지 않습니다. 다시 입력해주세요."
            continue
          fi
          break
        done

        # (D) 계정 생성 및 비밀번호 설정
        useradd -m -G adm,sudo "$UserName" \
          || { log_error "create_user" "계정 $UserName 생성 실패"; return 1; }
        echo "$UserName:$UserPassword" | chpasswd \
          || { log_error "create_user" "$UserName 비밀번호 설정 실패"; return 1; }
        echo "  → 계정 '$UserName' 생성 및 비밀번호 설정이 완료되었습니다."
      fi
    fi
  fi

  # (E) root 원격 로그인 제한
  echo "  → /etc/ssh/sshd_config 파일 권한 확인 및 설정 중..."
  set_file_perms /etc/ssh/sshd_config root:root 600

  # 포함된 설정 파일 처리 (활성 설정 파일만 대상)
  local sshd_config_dir="/etc/ssh/sshd_config.d"
  local config_files=("/etc/ssh/sshd_config")
  if [ -d "$sshd_config_dir" ]; then
    for file in "$sshd_config_dir"/*.conf; do
      [ -f "$file" ] && config_files+=("$file")
    done
  fi

  # 모든 활성 SSH 설정 파일에서 PermitRootLogin 설정 제거
  echo "  → 활성 SSH 설정 파일에서 PermitRootLogin 설정 수정 중..."
  for config_file in "${config_files[@]}"; do
    if [ -f "$config_file" ]; then
      backup_file "$config_file"
      # 주석 포함 모든 PermitRootLogin 라인 제거
      sed -i '/^[[:space:]]*#*[[:space:]]*PermitRootLogin/d' "$config_file" \
        || { log_error "restrict_root" "$config_file 수정 실패"; exit 1; }
      echo "  → $config_file에서 PermitRootLogin 설정 제거 완료."
    fi
  done

  # /etc/ssh/sshd_config에 PermitRootLogin no 추가
  echo "PermitRootLogin no" >> /etc/ssh/sshd_config \
    || { log_error "restrict_root" "/etc/ssh/sshd_config에 PermitRootLogin no 추가 실패"; exit 1; }
  echo "  → /etc/ssh/sshd_config에 PermitRootLogin no 설정 추가 완료."

  # 수정된 설정 확인 (활성 파일만 점검)
  echo "  → 활성 SSH 설정 파일에서 PermitRootLogin 설정 확인 중..."
  local yes_found=false
  {
    echo ">>> /etc/ssh/sshd_config 내용:"
    grep -E '^[[:space:]]*PermitRootLogin' /etc/ssh/sshd_config || echo "없음"
    if [ -d "$sshd_config_dir" ]; then
      echo ">>> $sshd_config_dir/*.conf 내용:"
      for file in "${config_files[@]}"; do
        [ "$file" != "/etc/ssh/sshd_config" ] && grep -E '^[[:space:]]*PermitRootLogin' "$file" 2>/dev/null || echo "없음 ($file)"
      done
    fi
    echo ">>> 비활성 파일 (/etc/ssh/sshd_config.ucf-dist 등) 확인:"
    grep -r -E '^[[:space:]]*PermitRootLogin' /etc/ssh/*.ucf-dist 2>/dev/null || echo "없음"
  } >> "$LOG_FILE"

  # PermitRootLogin yes가 활성 파일에 있는지 확인
  for config_file in "${config_files[@]}"; do
    if grep -E '^[[:space:]]*PermitRootLogin[[:space:]]+yes' "$config_file" 2>/dev/null; then
      yes_found=true
      log_error "restrict_root" "PermitRootLogin yes가 활성 파일 $config_file에서 발견되었습니다."
      grep -n -E '^[[:space:]]*PermitRootLogin[[:space:]]+yes' "$config_file" >> "$LOG_FILE"
      exit 1
    fi
  done

  # /etc/ssh/sshd_config에 PermitRootLogin no가 있는지 확인
  if ! grep -q -E '^PermitRootLogin[[:space:]]+no' /etc/ssh/sshd_config; then
    log_error "restrict_root" "/etc/ssh/sshd_config에 PermitRootLogin no가 설정되지 않았습니다."
    exit 1
  fi

  if [ "$yes_found" = false ]; then
    echo "  → PermitRootLogin no가 올바르게 설정되었으며, 활성 설정 파일에서 PermitRootLogin yes는 발견되지 않았습니다."
    echo "  → 참고: /etc/ssh/sshd_config.ucf-dist와 같은 비활성 파일은 SSH 동작에 영향을 주지 않습니다."
  fi

  # SSH 설정 유효성 검사
  echo "  → SSH 설정 유효성 검사 중..."
  if ! sshd -t; then
    log_error "restrict_root" "SSHD 설정 유효성 검사 실패. 로그를 확인하세요: $LOG_FILE"
    exit 1
  fi

  # SSH 서비스 재시작
  read -r -p "SSH 서비스를 지금 재시작하시겠습니까? (Y/N): " restart
  if [[ "$restart" =~ ^[Yy]$ ]]; then
    systemctl restart ssh || { log_error "restrict_root" "SSHD 재시작 실패"; exit 1; }
    echo "  → SSH 서비스가 재시작되었습니다."
  else
    restarts_needed["ssh"]=1
    echo "  → SSH 서비스 재시작이 보류되었습니다. 나중에 수동으로 재시작하세요."
  fi
  echo "  → root 원격 로그인이 제한되었습니다."

  # (F) 디버그 정보 기록
  {
    if [ -n "$UserName" ]; then
      echo ">>> 계정 $UserName 상태:"
      passwd -S "$UserName"
      echo ">>> 계정 $UserName 그룹:"
      groups "$UserName"
      echo ">>> 홈 디렉토리 권한:"
      ls -ld "/home/$UserName"
    fi
    echo ">>> SSH PermitRootLogin 설정 (활성 파일):"
    grep -E '^[[:space:]]*PermitRootLogin' /etc/ssh/sshd_config || echo "없음"
    echo ">>> /etc/ssh/sshd_config.d/*.conf에서 PermitRootLogin 검색:"
    for file in "${config_files[@]}"; do
      [ "$file" != "/etc/ssh/sshd_config" ] && grep -E '^[[:space:]]*PermitRootLogin' "$file" 2>/dev/null || echo "없음 ($file)"
    done
    echo ">>> 비활성 파일 (/etc/ssh/*.ucf-dist)에서 PermitRootLogin 검색:"
    grep -r -E '^[[:space:]]*PermitRootLogin' /etc/ssh/*.ucf-dist 2>/dev/null || echo "없음"
  } >> "$LOG_FILE"
}

configure_pass_min_length() {
  local pam_file="/etc/pam.d/common-password"
  backup_file "$pam_file"

  # pam_unix.so 라인에 minlen=8이 없으면 추가, 있으면 보정
  if grep -q 'pam_unix.so' "$pam_file"; then
    if grep -q 'pam_unix.so.*minlen=' "$pam_file"; then
      sed -i 's/\(pam_unix.so.*\)minlen=[0-9]\+/\1minlen=8/' "$pam_file"
    else
      sed -i 's/^\(.*pam_unix.so.*\)$/\1 minlen=8/' "$pam_file"
    fi
    echo "  → $pam_file pam_unix.so에 minlen=8 옵션 적용"
  else
    echo "  → $pam_file에 pam_unix.so 라인이 없습니다. (수동 점검 필요)"
  fi
}

# Configure PAM lockout (U-03, pam_faillock for Ubuntu 24.04)
configure_pam_lockout() {
  local pam_auth_file="/etc/pam.d/common-auth"
  local pam_account_file="/etc/pam.d/common-account"
  backup_file "$pam_auth_file" "$pam_account_file"

  # Configure pam_faillock (default for Ubuntu 24.04)
  sed -i '/pam_faillock.so/d' "$pam_auth_file"
  grep -q "pam_faillock.so preauth" "$pam_auth_file" || \
    sed -i '/^auth.*required.*pam_unix.so/i auth required pam_faillock.so preauth silent deny=3 unlock_time=300' "$pam_auth_file"
  grep -q "pam_faillock.so authfail" "$pam_auth_file" || \
    sed -i '/^auth.*required.*pam_unix.so/a auth [default=die] pam_faillock.so authfail deny=3 unlock_time=300' "$pam_auth_file"
  grep -q "account required pam_faillock.so" "$pam_account_file" || \
    sed -i '/^account.*required.*pam_unix.so/a account required pam_faillock.so' "$pam_account_file"
  echo "  → $pam_auth_file 및 $pam_account_file에 pam_faillock.so (deny=3, unlock_time=300) 설정 적용"
}

# Restrict su command (U-45, Ubuntu 24.04 기준)
configure_su_restriction() {
  local su_file="/etc/pam.d/su"
  local su_bin="/usr/bin/su"
  local target_group="sudo"   # Ubuntu는 wheel보다 sudo가 기본

  # 1. pam_wheel.so use_uid 활성화 (sudo 그룹)
  if ! grep -Eq 'auth\s+required\s+pam_wheel.so\s+use_uid' "$su_file"; then
    sed -i '/pam_rootok.so/a auth       required    pam_wheel.so use_uid group=sudo' "$su_file" \
      && echo "  → pam_wheel.so use_uid group=sudo 추가"
  else
    echo "  → pam_wheel.so use_uid group=sudo 이미 적용"
  fi

  # 2. su 바이너리의 그룹 및 권한 변경
  chgrp "$target_group" "$su_bin"
  chmod 4750 "$su_bin"
  echo "  → $su_bin 소유 그룹 $target_group, 권한 4750 적용"

  # 3. sudo(=wheel) 그룹에 일반 계정 추가 안내
  # (자동화 가능, 아래에서 <계정명> 부분을 운영계정으로 치환)
  # usermod -aG sudo <계정명>
}

# Configure rsyslog (optional, as systemd-journald is default)
configure_rsyslog() {
  if dpkg -s rsyslog &>/dev/null; then
    backup_file /etc/rsyslog.conf
    chown root:root /etc/rsyslog.conf \
      || log_error "configure_rsyslog" "Failed to set owner for /etc/rsyslog.conf"
    chmod 640 /etc/rsyslog.conf \
      || log_error "configure_rsyslog" "Failed to set permissions for /etc/rsyslog.conf"
    RSYSLOG_LINE="*.* @$RSYSLOG_SERVER"
    grep -qxF "$RSYSLOG_LINE" /etc/rsyslog.conf || echo "$RSYSLOG_LINE" >> /etc/rsyslog.conf
    systemctl restart rsyslog \
      || log_error "configure_rsyslog" "Failed to restart rsyslog"
  else
    echo "  → rsyslog가 설치되지 않아 systemd-journald를 사용합니다."
  fi
}

# Configure sysctl
configure_sysctl() {
  backup_file /etc/sysctl.conf
  cat <<EOF > /etc/sysctl.conf
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
  sysctl -p || log_error "sysctl" "Failed to apply sysctl settings"
}

# Configure limits
configure_limits() {
  backup_file /etc/security/limits.conf
  cat <<EOF > /etc/security/limits.conf
* soft nofile 61200
* hard nofile 61200
* soft nproc 61200
* hard nproc 61200
EOF
}

# Remove .rhosts/hosts.equiv
disable_rhosts_hosts_equiv() {
  backup_file /etc/hosts.equiv "$HOME/.rhosts"
  rm -f /etc/hosts.equiv "$HOME/.rhosts"
}

# Disable finger service
disable_finger() {
  if dpkg -s finger &>/dev/null; then
    systemctl disable --now finger &>/dev/null || log_error "disable_finger" "Failed to disable finger"
    rm -f /etc/inetd.conf
  else
    echo "  → finger 서비스가 설치되지 않았습니다."
  fi
}

# Disable anonymous FTP
disable_anonymous_ftp() {
  if dpkg -s vsftpd &>/dev/null; then
    backup_file /etc/vsftpd.conf
    grep -q '^anonymous_enable=NO' /etc/vsftpd.conf || \
      sed -i 's/^anonymous_enable=.*/anonymous_enable=NO/' /etc/vsftpd.conf
    systemctl restart vsftpd &>/dev/null || log_error "disable_anonymous_ftp" "Failed to restart vsftpd"
  else
    echo "  → vsftpd 서비스가 설치되지 않았습니다."
  fi
}

# Disable rsh/rlogin/rexec
disable_r_services() {
  for svc in rsh rlogin rexec; do
    if dpkg -s "$svc" &>/dev/null; then
      systemctl disable --now "$svc" &>/dev/null || log_error "disable_r_services" "Failed to disable $svc"
      rm -f /etc/inetd.conf
    else
      echo "  → $svc 서비스가 설치되지 않았습니다."
    fi
  done
}

# Configure cron permissions
configure_cron_permissions() {
  for f in /etc/cron.allow /etc/cron.deny; do
    [ -e "$f" ] && backup_file "$f" && set_file_perms "$f" root:root 640
  done
}

# Disable DoS-prone services
disable_dos_services() {
  for svc in echo discard daytime chargen; do
    if [ -f /etc/inetd.conf ]; then
      sed -i "/$svc/d" /etc/inetd.conf
    fi
  done
  systemctl restart openbsd-inetd &>/dev/null || echo "  → inetd 서비스가 실행 중이 아닙니다."
}

# Remove automountd
remove_automountd() {
  if dpkg -s autofs &>/dev/null; then
    systemctl disable --now autofs &>/dev/null || log_error "remove_automountd" "Failed to disable"; autofs
  else
    echo "  → autofs 서비스가 설치되지 않았습니다."
  fi
}

# Disable NIS/NIS+
disable_nis() {
  for svc in nis ypbind ypserv; do
    if dpkg -s "$svc" &>/dev/null; then
      systemctl disable --now "$svc" &>/dev/null || log_error "disable_nis" "Failed to disable $svc"
    else
      echo "  → $svc 서비스가 설치되지 않았습니다."
    fi
  done
}

# Disable tftp/talk
disable_tftp_talk() {
  for svc in tftp talk; do
    if dpkg -s "$svc" &>/dev/null; then
      systemctl disable --now "$svc" &>/dev/null || log_error "disable_tftp_talk" "Failed to disable $svc"; exit 1
      rm -f /etc/inetd.conf
    else
      echo "  → $svc 서비스가 설치되지 않았습니다."
    fi
  done
}

main() {
  check_root
  disable_auto_updates
  wait_for_apt_lock
  apt update && apt upgrade -y || log_error "post_tasks" "apt 업그레이드 실패"
  install_packages
  configure_ntp
  remove_unneeded_users
  configure_history_timeout
  configure_etc_perms
  configure_security_settings
  configure_motd
  configure_bash_vim
  step1_change_root_password
  step2_change_ssh_port
  set_password_policy
  create_fallback_and_restrict
  configure_pass_min_length
  configure_pam_lockout
  configure_su_restriction
  configure_rsyslog
  configure_sysctl
  configure_limits
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
}

main "$@"

#reboot