#!/bin/bash
#
# Ubuntu 24.04 계정 및 인증 설정 (2026 개선판)

if [[ -z "${SECURE_OS_COMMON_LOADED:-}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
fi

if [[ -n "${SECURE_OS_ACCOUNTS_LOADED:-}" ]]; then
  return 0
fi
readonly SECURE_OS_ACCOUNTS_LOADED=1

PASSWORD_POLICY_SUMMARY="미적용"
CREATED_USER="미생성"
DELETED_USERS=""
NEW_SSH_PORT="미변경 (기본 22)"

remove_unneeded_users() {
  local user
  for user in lp uucp ftp shutdown halt; do
    if id "$user" >/dev/null 2>&1; then
      userdel -r "$user" >/dev/null 2>&1 || true
      if ! id "$user" >/dev/null 2>&1; then
        DELETED_USERS+=" ${user}"
      fi
    fi
  done

  # U-11: sync 계정 셸 변경 (/bin/sync → nologin)
  if getent passwd sync >/dev/null 2>&1; then
    local sync_shell
    sync_shell=$(getent passwd sync | cut -d: -f7)
    if [[ "$sync_shell" != "/usr/sbin/nologin" && "$sync_shell" != "/bin/false" ]]; then
      usermod -s /usr/sbin/nologin sync
    fi
  fi
}

change_root_password() {
  local password confirm
  while true; do
    read_password_from_tty "root 계정 새 비밀번호를 입력하세요 (최소 ${MIN_PASSWORD_LENGTH}자): " password
    if (( ${#password} < MIN_PASSWORD_LENGTH )); then
      echo "비밀번호 길이가 부족합니다. 다시 시도해주세요."
      continue
    fi
    read_password_from_tty "비밀번호를 한 번 더 입력해주세요: " confirm
    if [[ "$password" != "$confirm" ]]; then
      echo "비밀번호가 일치하지 않습니다. 다시 시도해주세요."
      continue
    fi
    break
  done

  if ! echo "root:${password}" | chpasswd; then
    echo "ERROR: root 비밀번호 변경 실패" >&2
    exit 1
  fi
}

change_ssh_port() {
  local current_port new_port ssh_config="/etc/ssh/sshd_config"

  current_port="$(sshd -T 2>/dev/null | awk '/^port /{print $2; exit}')"
  current_port="${current_port:-22}"
  while true; do
    read_from_tty "변경할 SSH 포트를 입력하세요 (기본 ${SSH_PORT}, 현재 ${current_port}): " new_port
    new_port="${new_port:-$SSH_PORT}"

    if [[ "$new_port" =~ ^[0-9]+$ ]] && (( new_port >= 1 && new_port <= 65535 )); then
      break
    fi

    echo "1~65535 범위의 숫자를 입력해주세요."
  done

  if [[ "$new_port" == "$current_port" ]]; then
    NEW_SSH_PORT="변경 없음 (${current_port})"
    return 0
  fi

  if grep -q '^[[:space:]]*Port[[:space:]]' "$ssh_config"; then
    sed -i -E "s/^[[:space:]]*Port[[:space:]]+.*/Port ${new_port}/" "$ssh_config"
  else
    echo "Port ${new_port}" >> "$ssh_config"
  fi

  if command_exists ufw; then
    ufw allow "${new_port}/tcp" >/dev/null 2>&1 || true
  fi

  if sshd -t; then
    NEW_SSH_PORT="${current_port} -> ${new_port}"
    mark_restart_needed "ssh"
  else
    echo "ERROR: sshd 설정 검증 실패" >&2
    exit 1
  fi
}

# ────────────────────────────────────────────────────────────
# [2026 수정] U-02: 비밀번호 정책 — PASS_MIN_DAYS 기본 1, 일반 사용자(UID 1000~59999)에만 적용
# ────────────────────────────────────────────────────────────
configure_password_policy() {
  if ! prompt_yes_no "비밀번호 만료 정책을 설정하시겠습니까?"; then
    PASSWORD_POLICY_SUMMARY="미적용"
    return 0
  fi

  local max_days min_days warn_days min_len
  read_from_tty "비밀번호 최대 사용 기간을 입력하세요 (기본 90일): " max_days
  read_from_tty "비밀번호 최소 사용 기간을 입력하세요 (기본 1일): " min_days
  read_from_tty "비밀번호 만료 경고 일수를 입력하세요 (기본 7일): " warn_days
  read_from_tty "비밀번호 최소 길이를 입력하세요 (기본 ${MIN_PASSWORD_LENGTH}자): " min_len

  max_days="${max_days:-90}"
  min_days="${min_days:-1}"
  warn_days="${warn_days:-7}"
  min_len="${min_len:-$MIN_PASSWORD_LENGTH}"

  local user
  for user in $(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd); do
    chage -M "$max_days" -m "$min_days" -W "$warn_days" "$user" || true
  done

  sed -i '/^PASS_MAX_DAYS/d' /etc/login.defs
  sed -i '/^PASS_MIN_DAYS/d' /etc/login.defs
  sed -i '/^PASS_WARN_AGE/d' /etc/login.defs
  sed -i '/^PASS_MIN_LEN/d' /etc/login.defs
  cat <<EOF >> /etc/login.defs
PASS_MAX_DAYS   $max_days
PASS_MIN_DAYS   $min_days
PASS_WARN_AGE   $warn_days
PASS_MIN_LEN    $min_len
EOF

  PASSWORD_POLICY_SUMMARY="적용됨 (최대 ${max_days}일, 최소 길이 ${min_len}, 최소 ${min_days}일, 경고 ${warn_days}일)"
}

setup_fallback_account_and_restrict_root() {
  local fallback_user="" existing_users create_fallback=false
  local -a existing_user_array=()
  local ssh_config="/etc/ssh/sshd_config"
  local sshd_config_dir="/etc/ssh/sshd_config.d"

  existing_users="$(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd | xargs)"
  if [[ -n "$existing_users" ]]; then
    printf '\n현재 일반 사용자 계정: %s\n' "$existing_users"
    if prompt_yes_no "추가 관리자 계정을 새로 생성하시겠습니까?"; then
      create_fallback=true
    else
      read -r -a existing_user_array <<< "$existing_users"
      ensure_admin_access sudo "${existing_user_array[@]}" || exit 1
    fi
  else
    create_fallback=true
    echo "일반 사용자 계정이 없어 새 관리자 계정을 생성합니다."
  fi

  if [[ "$create_fallback" == true ]]; then
    while true; do
      read_from_tty "생성할 관리자 계정 이름을 입력하세요 (취소하려면 'cancel' 또는 'q' 입력): " fallback_user
      [[ -z "$fallback_user" ]] && { echo "계정 이름을 입력해주세요."; continue; }
      
      if [[ "${fallback_user,,}" =~ ^(!?cancel|!chain|quit|exit|q|!취소)$ ]]; then
        if [[ -z "$existing_users" ]]; then
          echo "관리자 권한이 있는 일반 계정이 없어 생성을 취소할 수 없습니다."
          continue
        fi
        read -r -a existing_user_array <<< "$existing_users"
        ensure_admin_access sudo "${existing_user_array[@]}" || exit 1
        echo "계정 생성을 취소합니다."
        create_fallback=false
        break
      fi

      if [[ ! "$fallback_user" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "허용되지 않는 문자입니다. (영문, 숫자, -, _ 만 허용)"
        continue
      fi

      if id "$fallback_user" >/dev/null 2>&1; then
        echo "이미 존재하는 계정입니다."
        if prompt_yes_no "이 계정($fallback_user)을 관리자 용도로 사용하고, 새 생성을 취소하시겠습니까?"; then
             ensure_admin_access sudo "$fallback_user" || exit 1
             create_fallback=false
             CREATED_USER="$fallback_user"
             break
        else
             echo "다른 이름을 입력해주세요."
             continue
         fi
       fi

      if ! confirm_account_name "$fallback_user"; then
        echo "계정명을 다시 입력해 주세요."
        continue
      fi
      break
    done

    if [[ "$create_fallback" == true ]]; then
      local password confirm
      while true; do
        read_password_from_tty "계정 '${fallback_user}'의 비밀번호를 입력하세요 (최소 ${MIN_PASSWORD_LENGTH}자): " password
        if (( ${#password} < MIN_PASSWORD_LENGTH )); then
          echo "비밀번호 길이가 부족합니다. 다시 입력해주세요."
          continue
        fi
        read_password_from_tty "비밀번호를 한 번 더 입력해주세요: " confirm
        if [[ "$password" != "$confirm" ]]; then
          echo "비밀번호가 일치하지 않습니다. 다시 입력해주세요."
          continue
        fi
        break
      done

      useradd -m -G adm,sudo -s /bin/bash "$fallback_user" || { echo "ERROR: 계정 생성 실패" >&2; exit 1; }
      echo "${fallback_user}:${password}" | chpasswd || { echo "ERROR: 비밀번호 설정 실패" >&2; exit 1; }
      CREATED_USER="$fallback_user"
    fi
  fi

  sed -i -E '/^[[:space:]]*#?[[:space:]]*PermitRootLogin[[:space:]]/d' "$ssh_config"
  echo "PermitRootLogin no" >> "$ssh_config"

  if [[ -d "$sshd_config_dir" ]]; then
    local file
    for file in "$sshd_config_dir"/*.conf; do
      [[ -f "$file" ]] || continue
      sed -i '/^[[:space:]]*#*[[:space:]]*PermitRootLogin/d' "$file"
    done
  fi

  if sshd -t; then
    mark_restart_needed "ssh"
  else
    echo "ERROR: sshd 설정 검증 실패" >&2
    exit 1
  fi
}

configure_pass_min_length() {
  local pam_file="/etc/pam.d/common-password"

  if grep -q 'pam_unix.so' "$pam_file"; then
    if grep -Eq 'pam_unix\.so.*minlen=' "$pam_file"; then
      sed -i -E "s/(pam_unix\.so.*)minlen=[0-9]+/\1minlen=${MIN_PASSWORD_LENGTH}/" "$pam_file"
    else
      sed -i -E "s/(pam_unix\.so.*)/\1 minlen=${MIN_PASSWORD_LENGTH}/" "$pam_file"
    fi
  else
    :
  fi
}

# ────────────────────────────────────────────────────────────
# [2026 수정] U-02: pwquality — enforce_for_root 추가
# ────────────────────────────────────────────────────────────
configure_pwquality() {
  # libpwquality 설치 확인
  if ! dpkg -s libpam-pwquality >/dev/null 2>&1; then
    wait_for_apt_lock
    apt install -y libpam-pwquality || { echo "ERROR: libpam-pwquality 설치 실패" >&2; return 1; }
  fi

  local conf="/etc/security/pwquality.conf"
  if [[ -f "$conf" ]]; then
    sed -i '/^lcredit\|^ucredit\|^dcredit\|^ocredit\|^minlen\|^difok\|^enforce_for_root/d' "$conf"
  fi
  cat <<EOF >> "$conf"
lcredit=-1
ucredit=-1
dcredit=-1
ocredit=-1
minlen=8
difok=2
enforce_for_root
EOF
}

# ────────────────────────────────────────────────────────────
# [2026 신규] U-02: pwhistory.conf 생성 — 비밀번호 이력 관리
# ────────────────────────────────────────────────────────────
configure_pwhistory() {
  cat <<EOF > /etc/security/pwhistory.conf
enforce_for_root
remember=4
file = /etc/security/opasswd
EOF
  [[ -f /etc/security/opasswd ]] || touch /etc/security/opasswd
  chmod 600 /etc/security/opasswd
  chown root:root /etc/security/opasswd
}

# ────────────────────────────────────────────────────────────
# [2026 수정] U-03: PAM 잠금 — deny=3, unlock_time=300
# ────────────────────────────────────────────────────────────
configure_pam_lockout() {
  local pam_auth="/etc/pam.d/common-auth"
  local pam_account="/etc/pam.d/common-account"
  local preauth_line="auth    required pam_faillock.so preauth silent deny=3 unlock_time=300"
  local authfail_line="auth    [default=die] pam_faillock.so authfail deny=3 unlock_time=300"
  local authsucc_line="auth    sufficient pam_faillock.so authsucc deny=3 unlock_time=300"
  local account_line="account required pam_faillock.so"

  sed -i '/pam_faillock.so/d' "$pam_auth"
  sed -i '/pam_faillock.so/d' "$pam_account"

  if ! grep -Fxq "$preauth_line" "$pam_auth"; then
    sed -i "/pam_unix\.so/ i $preauth_line" "$pam_auth"
  fi
  if ! grep -Fxq "$authfail_line" "$pam_auth"; then
    sed -i "/pam_unix\.so/ a $authfail_line" "$pam_auth"
  fi
  if ! grep -Fxq "$authsucc_line" "$pam_auth"; then
    if grep -q 'pam_faillock\.so authfail' "$pam_auth"; then
      sed -i "/pam_faillock\.so authfail/a $authsucc_line" "$pam_auth"
    else
      sed -i "/pam_unix\.so/ a $authsucc_line" "$pam_auth"
    fi
  fi
  if ! grep -Eq '^\s*account\s+required\s+pam_faillock\.so' "$pam_account"; then
    echo "$account_line" >> "$pam_account"
  fi
  faillock --reset >/dev/null 2>&1 || true
}

# ────────────────────────────────────────────────────────────
# [2026 수정] U-06: su 제한 — 설정 후 권한 재강제
# ────────────────────────────────────────────────────────────
configure_su_restriction() {
  local su_file="/etc/pam.d/su"
  local su_bin="/usr/bin/su"
  local wheel_line='auth       required   pam_wheel.so use_uid group=sudo'
  local include_line

  sed -i -E '/^[[:space:]]*auth[[:space:]].*pam_wheel\.so.*use_uid/d' "$su_file"
  include_line="$(grep -n -m1 -E '^[[:space:]]*@include[[:space:]]+common-auth' "$su_file" | cut -d: -f1)"
  if [[ -n "$include_line" ]]; then
    sed -i "${include_line}i ${wheel_line}" "$su_file"
  else
    echo "$wheel_line" >> "$su_file"
  fi

  # 권한 강제 재설정 (다른 작업에서 리셋될 수 있음)
  chgrp sudo "$su_bin"
  chmod 4750 "$su_bin"
}

perform_account_hardening() {
  remove_unneeded_users
  change_root_password
  change_ssh_port
  configure_password_policy
  setup_fallback_account_and_restrict_root
  configure_pass_min_length
  configure_pwquality
  configure_pwhistory
  configure_pam_lockout
  configure_su_restriction
}

perform_account_hardening
