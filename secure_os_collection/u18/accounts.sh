#!/bin/bash
#
# Ubuntu 18.04 계정 및 인증 보안 설정 작업 집합.

if [[ -z "${SECURE_OS_COMMON_LOADED:-}" ]]; then
  # shellcheck source=./common.sh
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
NORMAL_USERS_LIST="없음"

update_normal_users_list() {
  local users
  users="$(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
  if [[ -n "$users" ]]; then
    NORMAL_USERS_LIST="$users"
  else
    NORMAL_USERS_LIST="없음"
  fi
}

remove_unneeded_users() {
  local user
  # lp, games, sync는 시스템 기본 계정이므로 삭제 대상에서 제외
  for user in ftp shutdown halt; do
    if id "$user" >/dev/null 2>&1; then
      userdel -r "$user" >/dev/null 2>&1 || true
      if ! id "$user" >/dev/null 2>&1; then
        DELETED_USERS+=" ${user}"
      fi
    fi
  done
}

change_root_password() {
  local password confirm
  while true; do
    read_password_from_tty "root 새 비밀번호를 입력하세요 (최소 ${MIN_PASSWORD_LENGTH}자): " password
    if (( ${#password} < MIN_PASSWORD_LENGTH )); then
      echo "비밀번호 길이가 부족합니다. 다시 입력해주세요."
      continue
    fi
    read_password_from_tty "비밀번호를 다시 입력하세요: " confirm
    if [[ "$password" != "$confirm" ]]; then
      echo "비밀번호가 일치하지 않습니다. 다시 입력해주세요."
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
    echo "1~65535 사이의 숫자로 입력해주세요."
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

configure_password_policy() {
  if ! prompt_yes_no "비밀번호 만료 정책을 적용하시겠습니까?"; then
    PASSWORD_POLICY_SUMMARY="미적용"
    return 0
  fi

  local max_days min_days warn_days min_len
  read_from_tty "최대 사용 기간(일, 기본 90): " max_days
  read_from_tty "최소 사용 기간(일, 기본 0): " min_days
  read_from_tty "만료 경고 기간(일, 기본 7): " warn_days
  read_from_tty "최소 길이(기본 ${MIN_PASSWORD_LENGTH}): " min_len

  max_days="${max_days:-90}"
  min_days="${min_days:-0}"
  warn_days="${warn_days:-7}"
  min_len="${min_len:-$MIN_PASSWORD_LENGTH}"

  if (( min_len < MIN_PASSWORD_LENGTH )); then
    min_len="$MIN_PASSWORD_LENGTH"
  fi

  local user uid
  while IFS=: read -r user _ uid _; do
    if (( uid >= 1000 && uid < 60000 )); then
      chage -M "$max_days" -m "$min_days" -W "$warn_days" "$user" >/dev/null 2>&1 || true
    fi
  done < /etc/passwd

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
  local ssh_config="/etc/ssh/sshd_config"
  local extra_dir="/etc/ssh/sshd_config.d"
  local username=""
  local -a existing_user_array=()

  set_file_perms "$ssh_config" root:root 600

  update_normal_users_list
  echo "현재 일반 사용자 목록: $NORMAL_USERS_LIST"

  if [[ "$NORMAL_USERS_LIST" == "없음" ]] || prompt_yes_no "추가 관리자 계정을 생성하시겠습니까?"; then
    if [[ "$NORMAL_USERS_LIST" == "없음" ]]; then
      echo "일반 사용자 계정이 없어 관리자 계정을 생성합니다."
    fi
    while true; do
      read_from_tty "계정명(영문, 숫자, -, _ 허용)을 입력하세요 (취소하려면 'cancel' 또는 'q' 입력): " username
      if [[ -z "$username" ]]; then
        echo "계정명을 비울 수 없습니다."
        continue
      fi
      
      # Expanded cancellation keywords (case-insensitive)
      if [[ "${username,,}" =~ ^(!?cancel|!chain|quit|exit|q|!취소)$ ]]; then
          if [[ "$NORMAL_USERS_LIST" == "없음" ]]; then
            echo "관리자 권한이 있는 일반 계정이 없어 생성을 취소할 수 없습니다."
            continue
          fi
          read -r -a existing_user_array <<< "$NORMAL_USERS_LIST"
          ensure_admin_access sudo "${existing_user_array[@]}" || exit 1
          echo "계정 생성을 취소합니다."
          username="!cancel" # Normalize cancellation flag
          break
      fi

      # Regex validation for username
      if [[ ! "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "허용되지 않는 문자입니다. (영문, 숫자, -, _ 만 허용)"
        continue
      fi

       if id "$username" >/dev/null 2>&1; then
         echo "이미 존재하는 계정입니다."
          if prompt_yes_no "이 계정($username)을 관리자 용도로 사용하고, 새 생성을 취소하시겠습니까?"; then
             ensure_admin_access sudo "$username" || exit 1
             CREATED_USER="$username"
             break
        else
             echo "다른 이름을 입력해주세요."
             continue
         fi
       fi

      if ! confirm_account_name "$username"; then
        echo "계정명을 다시 입력해 주세요."
        continue
      fi
      break
    done
    
    # Check if we cancelled or selected existing user
    if [[ "$username" == "!cancel" || "$username" == "!취소" ]]; then
      :
    elif id "$username" >/dev/null 2>&1; then
         # 기존 계정은 위에서 관리자 권한 확인을 마쳤으므로 생성을 건너뛴다.
         :
    else
        local password confirm
        while true; do
          read_password_from_tty "'${username}' 계정 비밀번호(최소 ${MIN_PASSWORD_LENGTH}자)를 입력하세요: " password
          if (( ${#password} < MIN_PASSWORD_LENGTH )); then
            echo "비밀번호 길이가 부족합니다."
            continue
          fi
          read_password_from_tty "비밀번호를 다시 입력하세요: " confirm
          if [[ "$password" != "$confirm" ]]; then
            echo "비밀번호가 일치하지 않습니다."
            continue
          fi
          break
        done

        if useradd -m -G adm,sudo "$username"; then
          if echo "${username}:${password}" | chpasswd; then
            CREATED_USER="$username"
          else
            echo "ERROR: 계정 비밀번호 설정 실패: $username" >&2
          fi
        else
          echo "ERROR: 계정 생성 실패: $username" >&2
          exit 1
        fi
    fi
  else
    read -r -a existing_user_array <<< "$NORMAL_USERS_LIST"
    ensure_admin_access sudo "${existing_user_array[@]}" || exit 1
  fi

  local config_files=("$ssh_config")
  if [[ -d "$extra_dir" ]]; then
    while IFS= read -r -d '' cfg; do
      config_files+=("$cfg")
    done < <(find "$extra_dir" -type f -name '*.conf' -print0)
  fi

  local cfg
  for cfg in "${config_files[@]}"; do
    [[ -f "$cfg" ]] || continue
    sed -i '/^[[:space:]]*#\?[[:space:]]*PermitRootLogin/d' "$cfg"
  done

  if ! grep -Eq '^[[:space:]]*PermitRootLogin[[:space:]]+no' "$ssh_config"; then
    echo "PermitRootLogin no" >> "$ssh_config"
  fi

  local bad_found=false
  for cfg in "${config_files[@]}"; do
    if grep -Eq '^[[:space:]]*PermitRootLogin[[:space:]]+yes' "$cfg"; then
      bad_found=true
      echo "ERROR: PermitRootLogin yes 발견: $cfg" >&2
    fi
  done

  if [[ "$bad_found" == true ]]; then
    echo "일부 SSH 설정에서 PermitRootLogin yes가 남아 있습니다. 로그를 확인하세요."
    exit 1
  fi

  if sshd -t; then
    mark_restart_needed "ssh"
  else
    echo "ERROR: sshd 설정 검증 실패" >&2
    exit 1
  fi
}

configure_pass_min_length() {

  sed -i '/^PASS_MIN_LEN/d' /etc/login.defs
  echo "PASS_MIN_LEN    $MIN_PASSWORD_LENGTH" >> /etc/login.defs

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

configure_pwquality() {
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

configure_pam_lockout() {
  local pam_auth="/etc/pam.d/common-auth"
  local pam_account="/etc/pam.d/common-account"


  if ! dpkg -s libpam-modules >/dev/null 2>&1; then
    wait_for_apt_lock
    apt install -y libpam-modules || { echo "ERROR: libpam-modules 설치 실패" >&2; return 1; }
  fi

  if ! grep -Eq 'pam_tally2\.so.*onerr=fail.*deny=3' "$pam_auth"; then
    sed -i '/pam_tally2\.so/d' "$pam_auth"
    sed -i "/pam_unix\.so/i auth required pam_tally2.so onerr=fail deny=3 unlock_time=300" "$pam_auth"
  fi

  if ! grep -Eq '^\s*account\s+required\s+pam_tally2\.so' "$pam_account"; then
    sed -i '/pam_tally2\.so/d' "$pam_account"
    echo "account required pam_tally2.so" >> "$pam_account"
  fi

  local faillock_conf="/etc/security/faillock.conf"
  {
    echo "deny = 3"
    echo "fail_interval = 900"
    echo "unlock_time = 300"
  } > "$faillock_conf"
}

# ────────────────────────────────────────────────────────────
# U-11: sync 계정 shell을 nologin으로 변경 (삭제 대신 shell 제한)
# ────────────────────────────────────────────────────────────
configure_sync_shell() {
  if getent passwd sync &>/dev/null; then
    usermod -s /usr/sbin/nologin sync || true
  else
    :
  fi
}

configure_su_restriction() {
  local su_file="/etc/pam.d/su"
  local su_bin="/bin/su"
  local wheel_line='auth       required   pam_wheel.so use_uid group=sudo'
  local include_line

  sed -i -E '/^[[:space:]]*auth[[:space:]].*pam_wheel\.so.*use_uid/d' "$su_file"
  include_line="$(grep -n -m1 -E '^[[:space:]]*@include[[:space:]]+common-auth' "$su_file" | cut -d: -f1)"
  if [[ -n "$include_line" ]]; then
    sed -i "${include_line}i ${wheel_line}" "$su_file"
  else
    echo "$wheel_line" >> "$su_file"
  fi

  if [[ -f "$su_bin" ]]; then
    chgrp sudo "$su_bin"
    chmod 4750 "$su_bin"
  else
    :
  fi
}

perform_account_hardening() {
  remove_unneeded_users
  change_root_password
  change_ssh_port
  configure_password_policy
  setup_fallback_account_and_restrict_root
  configure_pass_min_length
  configure_pwquality
  configure_pam_lockout
  configure_sync_shell
  configure_su_restriction
  update_normal_users_list
  echo "최종 일반 사용자 목록: $NORMAL_USERS_LIST"
  if [[ -n "$DELETED_USERS" ]]; then
    DELETED_USERS="${DELETED_USERS# }"
  fi
}

perform_account_hardening
