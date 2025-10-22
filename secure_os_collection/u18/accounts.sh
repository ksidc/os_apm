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

ROOT_PASSWORD_CHANGED="대기"
PASSWORD_POLICY_SUMMARY="대기"
CREATED_USER="없음"
DELETED_USERS=""
NEW_SSH_PORT="변경 없음"
NORMAL_USERS_LIST="없음"

update_normal_users_list() {
  local users
  users="$(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
  if [[ -n "$users" ]]; then
    NORMAL_USERS_LIST="$users"
  else
    NORMAL_USERS_LIST="없음"
  fi
  log_info "현재 일반 사용자: $NORMAL_USERS_LIST"
}

remove_unneeded_users() {
  log_info "불필요 계정 정리 시작"
  local user
  for user in lp games; do
    if id "$user" >/dev/null 2>&1; then
      if userdel -r "$user" >/dev/null 2>&1; then
        DELETED_USERS+=" ${user}"
        log_info "불필요 계정 삭제: $user"
      else
        log_warn "계정 삭제 실패: $user"
      fi
    else
      log_info "계정 미존재: $user"
    fi
  done
}

change_root_password() {
  log_info "root 비밀번호 변경 절차 시작"
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

  if echo "root:${password}" | chpasswd; then
    ROOT_PASSWORD_CHANGED="변경 완료"
    log_info "root 비밀번호가 변경되었습니다."
  else
    log_error "change_root_password" "root 비밀번호 변경 실패"
    exit 1
  fi
}

change_ssh_port() {
  log_info "SSH 포트 변경 절차 시작"
  local current_port new_port ssh_config="/etc/ssh/sshd_config"
  current_port="$(sshd -T 2>/dev/null | awk '/^port /{print $2; exit}')"
  current_port="${current_port:-22}"

  local attempts=0
  while (( attempts < 3 )); do
    read_from_tty "변경할 SSH 포트를 입력하세요 (기본 ${SSH_PORT}, 현재 ${current_port}): " new_port
    new_port="${new_port:-$SSH_PORT}"
    if [[ "$new_port" =~ ^[0-9]+$ ]] && (( new_port >= 1 && new_port <= 65535 )); then
      break
    fi
    echo "1~65535 사이의 숫자로 입력해주세요."
    ((attempts++))
  done

  if ! [[ "$new_port" =~ ^[0-9]+$ ]] || (( new_port < 1 || new_port > 65535 )); then
    log_error "change_ssh_port" "유효하지 않은 포트가 입력되었습니다."
    exit 1
  fi

  if [[ "$new_port" == "$current_port" ]]; then
    NEW_SSH_PORT="변경 없음 (${current_port})"
    log_info "SSH 포트는 변경되지 않았습니다."
    return 0
  fi

  backup_file "$ssh_config"
  if grep -q '^[[:space:]]*Port[[:space:]]' "$ssh_config"; then
    sed -i -E "s/^[[:space:]]*Port[[:space:]]+.*/Port ${new_port}/" "$ssh_config"
  else
    echo "Port ${new_port}" >> "$ssh_config"
  fi

  if command_exists ufw; then
    ufw allow "${new_port}/tcp" >/dev/null 2>&1 || log_warn "ufw에서 ${new_port}/tcp 허용 설정 실패"
  fi

  if sshd -t; then
    NEW_SSH_PORT="${current_port} -> ${new_port}"
    mark_restart_needed "ssh"
    log_info "SSH 포트가 ${new_port}로 변경되었습니다."
  else
    log_error "change_ssh_port" "sshd 설정 검증 실패"
    exit 1
  fi
}

configure_password_policy() {
  log_info "비밀번호 만료 정책 설정"
  if ! prompt_yes_no "비밀번호 만료 정책을 적용하시겠습니까?"; then
    PASSWORD_POLICY_SUMMARY="사용자 선택으로 건너뜀"
    log_info "비밀번호 만료 정책이 적용되지 않았습니다."
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
    log_warn "입력된 최소 길이가 기준보다 짧아 ${MIN_PASSWORD_LENGTH}자로 조정합니다."
    min_len="$MIN_PASSWORD_LENGTH"
  fi

  local user uid
  while IFS=: read -r user _ uid _; do
    if (( uid >= 1000 && uid < 60000 )); then
      chage -M "$max_days" -m "$min_days" -W "$warn_days" "$user" >/dev/null 2>&1 || \
        log_warn "chage 적용 실패: $user"
    fi
  done < /etc/passwd

  backup_file /etc/login.defs
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

  PASSWORD_POLICY_SUMMARY="최대 ${max_days}일 / 최소 ${min_days}일 / 경고 ${warn_days}일 / 길이 ${min_len}자"
}

setup_fallback_account_and_restrict_root() {
  log_info "추가 관리자 계정 생성 및 root 원격 접속 차단"
  local ssh_config="/etc/ssh/sshd_config"
  local extra_dir="/etc/ssh/sshd_config.d"
  local username=""

  backup_file /etc/passwd /etc/shadow "$ssh_config"
  set_file_perms "$ssh_config" root:root 600

  update_normal_users_list
  echo "현재 일반 사용자 목록: $NORMAL_USERS_LIST"

  if prompt_yes_no "추가 관리자 계정을 생성하시겠습니까?"; then
    while true; do
      read_from_tty "계정명(영문, 숫자, -, _ 허용)을 입력하세요: " username
      if [[ -z "$username" ]]; then
        echo "계정명을 비울 수 없습니다."
        continue
      fi
      if [[ ! "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "허용되지 않는 문자입니다. 다시 입력해주세요."
        continue
      fi
      if id "$username" >/dev/null 2>&1; then
        echo "이미 존재하는 계정입니다. 다른 이름을 입력해주세요."
        continue
      fi
      break
    done

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
        usermod -aG sudo "$username" >/dev/null 2>&1 || log_warn "sudo 그룹 추가 실패: $username"
        CREATED_USER="$username"
        log_info "새 관리자 계정을 생성했습니다: $username"
      else
        log_error "setup_fallback_account_and_restrict_root" "계정 비밀번호 설정 실패: $username"
      fi
    else
      log_error "setup_fallback_account_and_restrict_root" "계정 생성 실패: $username"
      exit 1
    fi
  else
    log_info "추가 관리자 계정 생성이 건너뛰어졌습니다."
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
    backup_file "$cfg"
    sed -i '/^[[:space:]]*#\?[[:space:]]*PermitRootLogin/d' "$cfg"
  done

  if ! grep -Eq '^[[:space:]]*PermitRootLogin[[:space:]]+no' "$ssh_config"; then
    echo "PermitRootLogin no" >> "$ssh_config"
  fi

  local bad_found=false
  for cfg in "${config_files[@]}"; do
    if grep -Eq '^[[:space:]]*PermitRootLogin[[:space:]]+yes' "$cfg"; then
      bad_found=true
      log_error "setup_fallback_account_and_restrict_root" "PermitRootLogin yes 발견: $cfg"
    fi
  done

  if [[ "$bad_found" == true ]]; then
    echo "일부 SSH 설정에서 PermitRootLogin yes가 남아 있습니다. 로그를 확인하세요."
    exit 1
  fi

  if sshd -t; then
    mark_restart_needed "ssh"
    log_info "SSH에서 root 원격 로그인을 차단했습니다."
  else
    log_error "setup_fallback_account_and_restrict_root" "sshd 설정 검증 실패"
    exit 1
  fi
}

configure_pass_min_length() {
  log_info "비밀번호 최소 길이 설정"
  backup_file /etc/login.defs /etc/pam.d/common-password

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
    log_warn "pam_unix.so 항목을 찾을 수 없습니다: $pam_file"
  fi
}

configure_pam_lockout() {
  log_info "로그인 실패 잠금 정책(pam_tally2) 설정"
  local pam_auth="/etc/pam.d/common-auth"
  local pam_account="/etc/pam.d/common-account"

  backup_file "$pam_auth" "$pam_account"

  if ! dpkg -s libpam-modules >/dev/null 2>&1; then
    wait_for_apt_lock
    apt install -y libpam-modules || { log_error "configure_pam_lockout" "libpam-modules 설치 실패"; return 1; }
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
  backup_file "$faillock_conf"
  {
    echo "deny = 3"
    echo "fail_interval = 900"
    echo "unlock_time = 300"
  } > "$faillock_conf"
}

configure_su_restriction() {
  log_info "su 명령 제한 설정"
  local su_file="/etc/pam.d/su"
  local su_bin="/bin/su"
  backup_file "$su_file" "$su_bin"

  if ! grep -Eq 'auth\s+required\s+pam_wheel.so\s+use_uid\s+group=sudo' "$su_file"; then
    sed -i '/pam_rootok.so/a auth       required   pam_wheel.so use_uid group=sudo' "$su_file"
  fi

  if [[ -f "$su_bin" ]]; then
    chgrp sudo "$su_bin"
    chmod 4750 "$su_bin"
  else
    log_warn "$su_bin 파일이 없습니다. util-linux 패키지를 확인하세요."
  fi

  if [[ -n "$CREATED_USER" && "$CREATED_USER" != "없음" ]]; then
    usermod -aG sudo "$CREATED_USER" >/dev/null 2>&1 || log_warn "sudo 그룹 추가 실패: $CREATED_USER"
  fi
}

perform_account_hardening() {
  log_info "계정 및 인증 보안 설정 시작"
  remove_unneeded_users
  change_root_password
  change_ssh_port
  configure_password_policy
  setup_fallback_account_and_restrict_root
  configure_pass_min_length
  configure_pam_lockout
  configure_su_restriction
  update_normal_users_list
  echo "최종 일반 사용자 목록: $NORMAL_USERS_LIST"
  if [[ -n "$DELETED_USERS" ]]; then
    DELETED_USERS="${DELETED_USERS# }"
  fi
  log_info "계정 및 인증 보안 설정 완료"
}

perform_account_hardening
