#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

remove_unneeded_users() {
  log_info "[ACCOUNTS] Removing legacy service accounts"
  local users=(lp games sync shutdown halt)
  for u in "${users[@]}"; do
    if id "$u" >/dev/null 2>&1; then
      userdel -r "$u" && log_info "[ACCOUNTS] Removed user $u" || log_error "remove_unneeded_users" "Failed to remove $u"
    else
      log_info "[ACCOUNTS] User $u not present"
    fi
  done
}

step1_change_root_password() {
  log_info "[ACCOUNTS] Updating root password"
  local root_password confirm_password
  while true; do
    read -r -s -p "새로운 root 비밀번호를 입력하세요 (최소 ${MIN_PASSWORD_LENGTH}자): " root_password < /dev/tty; echo
    if [ "${#root_password}" -lt "$MIN_PASSWORD_LENGTH" ]; then
      echo "비밀번호는 최소 ${MIN_PASSWORD_LENGTH}자 이상이어야 합니다."
      continue
    fi
    read -r -s -p "비밀번호를 다시 입력해 확인하세요: " confirm_password < /dev/tty; echo
    if [ "$root_password" != "$confirm_password" ]; then
      echo "비밀번호가 일치하지 않습니다. 다시 입력하세요."
      continue
    fi
    break
  done
  echo "root:${root_password}" | chpasswd || log_error "change_root_password" "Failed to change root password"
}

step2_change_ssh_port() {
  log_info "[ACCOUNTS] Changing SSH port"
  local old_port new_port
  old_port=$(grep -i '^Port' /etc/ssh/sshd_config | awk '{print $2}' | head -1)
  [[ -z "$old_port" ]] && old_port=22

  local attempts=0 max_attempts=5
  while true; do
    read -r -p "새로운 SSH 포트를 입력하세요 (기본값 ${SSH_PORT}): " new_port < /dev/tty
    new_port=${new_port:-$SSH_PORT}
    if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1 ] && [ "$new_port" -le 65535 ]; then
      break
    fi
    echo "1에서 65535 사이의 올바른 포트 번호를 입력하세요."
    attempts=$((attempts + 1))
    if [ "$attempts" -ge "$max_attempts" ]; then
      log_error "change_ssh_port" "Exceeded port selection retries; retaining existing SSH port $old_port"
      NEW_SSH_PORT="$old_port"
      return 1
    fi
  done

  if [[ "$new_port" == "$old_port" ]]; then
    log_info "[ACCOUNTS] SSH port remains $old_port"
    NEW_SSH_PORT="$old_port"
    return 0
  fi

  local tmp_config
  tmp_config=$(mktemp) || {
    log_error "change_ssh_port" "Failed to allocate temporary file; retaining existing SSH port"
    NEW_SSH_PORT="$old_port"
    return 1
  }

  cp /etc/ssh/sshd_config "$tmp_config" || {
    log_error "change_ssh_port" "Failed to snapshot sshd_config"
    rm -f "$tmp_config"
    NEW_SSH_PORT="$old_port"
    return 1
  }

  backup_file /etc/ssh/sshd_config
  sed -i "/^#Port /c\Port $new_port" /etc/ssh/sshd_config
  sed -i "/^Port /c\Port $new_port" /etc/ssh/sshd_config
  if sshd -t; then
    rm -f "$tmp_config"
  else
    log_error "change_ssh_port" "sshd configuration validation failed; reverting to previous configuration"
    cp "$tmp_config" /etc/ssh/sshd_config
    rm -f "$tmp_config"
    NEW_SSH_PORT="$old_port"
    return 1
  fi

  if command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --permanent --add-port="${new_port}/tcp" >/dev/null 2>&1 || log_info "[WARN] Could not add SSH port to firewalld"
    firewall-cmd --reload >/dev/null 2>&1 || log_info "[WARN] Could not reload firewalld"
  fi

  NEW_SSH_PORT="$new_port"
  restarts_needed["sshd"]=1
  return 0
}

set_password_policy() {
  log_info "[ACCOUNTS] 패스워드 만료 정책 설정 시작"
  read -r -p "패스워드 만료 정책을 설정하시겠습니까? (Y/N): " ans < /dev/tty
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    echo "다음 항목에 값을 입력하세요. (Enter만 입력하면 기본값이 적용됩니다.)"
    read -r -p "1. 최대 사용일수 (기본값: 90): " max_days < /dev/tty
    read -r -p "2. 최소 길이 (기본값: 8): " min_len < /dev/tty
    read -r -p "3. 최소 사용일수 (기본값: 0): " min_days < /dev/tty
    read -r -p "4. 경고일수 (기본값: 7): " warn_days < /dev/tty
    max_days=${max_days:-90}
    min_len=${min_len:-8}
    min_days=${min_days:-0}
    warn_days=${warn_days:-7}

    log_info "[ACCOUNTS] 패스워드 정책 적용: 최대 $max_days일, 최소 길이 $min_len, 최소 $min_days일, 경고 $warn_days일"
    PASSWORD_POLICY_SUMMARY="적용됨 (최대 $max_days일, 최소 길이 $min_len, 최소 $min_days일, 경고 $warn_days일)"

    local user_list
    user_list=($(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd 2>/dev/null)) || {
      log_error "set_password_policy" "사용자 목록 조회 실패"
      return 1
    }

    if [ "${#user_list[@]}" -eq 0 ]; then
      log_info "[ACCOUNTS] 일반 사용자 계정이 없어 패스워드 정책을 적용하지 않습니다."
    else
      for user in "${user_list[@]}"; do
        chage -M "$max_days" -m "$min_days" -W "$warn_days" "$user" \
          || log_error "set_password_policy" "사용자 $user 설정 실패"
        log_info "[ACCOUNTS] $user 계정 패스워드 정책 적용 완료"
        chage -l "$user" | grep -E 'Maximum|Minimum|Warning' >> "$LOG_FILE"
      done
    fi

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
    } >> /etc/login.defs || log_error "set_password_policy" "/etc/login.defs 설정 실패"
    log_info "[ACCOUNTS] /etc/login.defs 갱신 완료"
  else
    log_info "[ACCOUNTS] 패스워드 만료 정책 설정을 건너뜁니다."
    PASSWORD_POLICY_SUMMARY="미적용"
  fi
}

create_fallback_and_restrict() {
  log_info "[ACCOUNTS] Ensuring non-root administrative account"
  backup_file /etc/passwd /etc/shadow /etc/ssh/sshd_config

  local existing
  existing=$(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd)
  if [ -n "$existing" ]; then
    echo "기존 일반 계정이 확인되었습니다: $existing"
    read -r -p "새 관리자 계정을 생성하지 않고 계속하시겠습니까? (Y/N): " answer < /dev/tty
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      CREATED_USER="$existing (existing)"
      UserName="$existing"
      sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
      sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
      restarts_needed["sshd"]=1
      return
    else
      existing=""
    fi
  fi

  if [ -z "$existing" ]; then
    while true; do
      read -r -p "생성할 관리자 계정 이름을 입력하세요: " UserName < /dev/tty
      if [[ -z "$UserName" ]]; then
        echo "계정 이름은 비워둘 수 없습니다."
        continue
      fi
      if [[ ! "$UserName" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "영문, 숫자, 하이픈(-), 밑줄(_)만 사용할 수 있습니다."
        continue
      fi
      if id "$UserName" >/dev/null 2>&1; then
        echo "'$UserName' 계정이 이미 존재합니다."
        continue
      fi
      break
    done

    local user_password password_confirm
    while true; do
      read -r -s -p "'$UserName' 계정의 비밀번호를 입력하세요 (최소 ${MIN_PASSWORD_LENGTH}자): " user_password < /dev/tty; echo
      if [ "${#user_password}" -lt "$MIN_PASSWORD_LENGTH" ]; then
        echo "비밀번호는 최소 ${MIN_PASSWORD_LENGTH}자 이상이어야 합니다."
        continue
      fi
      read -r -s -p "비밀번호를 다시 입력해 확인하세요: " password_confirm < /dev/tty; echo
      if [ "$user_password" != "$password_confirm" ]; then
        echo "비밀번호가 일치하지 않습니다."
        continue
      fi
      break
    done

    useradd -m -G wheel "$UserName" || { log_error "create_user" "Failed to create $UserName"; return 1; }
    echo "$UserName:$user_password" | chpasswd || log_error "create_user" "Failed to set password for $UserName"
    CREATED_USER="$UserName"
  else
    CREATED_USER="$existing (existing)"
    UserName="$existing"
  fi

  sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  restarts_needed["sshd"]=1
}

configure_pwquality() {
  log_info "[ACCOUNTS] Enforcing password complexity (pwquality)"
  backup_file /etc/security/pwquality.conf
  cat <<'EOF' > /etc/security/pwquality.conf
lcredit=-1
ucredit=-1
dcredit=-1
ocredit=-1
minlen=8
difok=2
EOF
}

configure_pam_lockout() {
  log_info "[ACCOUNTS] Configuring PAM lockout (pam_tally2)"
  for pam_file in /etc/pam.d/system-auth /etc/pam.d/password-auth; do
    backup_file "$pam_file"
    sed -i '/pam_tally2.so/d' "$pam_file"
    sed -i '/^auth\s\+required\s\+pam_env.so/a auth        required      pam_tally2.so deny=3 unlock_time=300' "$pam_file"
    sed -i '/^auth\s\+sufficient\s\+pam_unix.so/a auth        [default=die] pam_tally2.so deny=3 unlock_time=300' "$pam_file"
    sed -i '/^account\s\+required\s\+pam_unix.so/a account     required      pam_tally2.so' "$pam_file"
  done
}

configure_su_restriction() {
  log_info "[ACCOUNTS] Restricting su access to wheel group"
  local su_file="/etc/pam.d/su"
  backup_file "$su_file"
  if ! getent group wheel >/dev/null; then
    groupadd wheel || log_error "configure_su_restriction" "Failed to create wheel group"
  fi
  set_file_perms /usr/bin/su root:wheel 4750
  if grep -q '^#auth\s\+required\s\+pam_wheel.so\s\+use_uid' "$su_file"; then
    sed -i 's/^#\(auth\s\+required\s\+pam_wheel.so\s\+use_uid\)/\1/' "$su_file"
  elif ! grep -q 'pam_wheel.so.*use_uid' "$su_file"; then
    sed -i '/pam_rootok.so/a auth       required    pam_wheel.so use_uid' "$su_file"
  fi
}

log_info "[ACCOUNTS] Account hardening start"
remove_unneeded_users
step1_change_root_password
if ! step2_change_ssh_port; then
  log_info "[WARN] SSH port change skipped; retaining current port"
fi
set_password_policy
create_fallback_and_restrict
configure_pwquality
configure_pam_lockout
configure_su_restriction
log_info "[ACCOUNTS] Account hardening complete"
