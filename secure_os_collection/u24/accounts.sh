#!/bin/bash
#
# Ubuntu 24.04 계정 및 인증 설정

if [[ -z "${SECURE_OS_COMMON_LOADED:-}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
fi

if [[ -n "${SECURE_OS_ACCOUNTS_LOADED:-}" ]]; then
  return 0
fi
readonly SECURE_OS_ACCOUNTS_LOADED=1

ROOT_PASSWORD_CHANGED="미적용"
PASSWORD_POLICY_SUMMARY="미적용"
CREATED_USER="미생성"

remove_unneeded_users() {
  log_info "remove_unneeded_users 시작"
  local user
  for user in lp games; do
    if id "$user" >/dev/null 2>&1; then
      if output="$(userdel -r "$user" 2>&1)"; then
        DELETED_USERS+=" ${user}"
        log_info "불필요한 계정 '$user'를 삭제했습니다."
      else
        log_warn "계정 '$user' 삭제 경고: $output"
      fi
    else
      log_info "계정 '$user'는 존재하지 않습니다."
    fi
  done
}

change_root_password() {
  log_info "change_root_password 시작"
  local password confirm
  while true; do
    read_password_from_tty "root 새 비밀번호를 입력하세요 (최소 ${MIN_PASSWORD_LENGTH}자): " password
    if (( ${#password} < MIN_PASSWORD_LENGTH )); then
      echo "비밀번호 길이가 부족합니다. 다시 입력하세요."
      continue
    fi
    read_password_from_tty "비밀번호를 한 번 더 입력하세요: " confirm
    if [[ "$password" != "$confirm" ]]; then
      echo "비밀번호가 일치하지 않습니다. 다시 시도하세요."
      continue
    fi
    break
  done

  if echo "root:${password}" | chpasswd; then
    ROOT_PASSWORD_CHANGED="적용"
    log_info "root 계정 비밀번호를 변경했습니다."
  else
    log_error "change_root_password" "root 비밀번호 변경 실패"
    exit 1
  fi
}

change_ssh_port() {
  log_info "change_ssh_port 시작"
  local current_port new_port ssh_config="/etc/ssh/sshd_config"

  current_port="$(sshd -T 2>/dev/null | awk '/^port /{print $2; exit}')"
  current_port="${current_port:-22}"
  read_from_tty "변경할 SSH 포트를 입력하세요 (기본값 ${SSH_PORT}, 현재 ${current_port}): " new_port
  new_port="${new_port:-$SSH_PORT}"

  if ! [[ "$new_port" =~ ^[0-9]+$ ]] || (( new_port < 1 || new_port > 65535 )); then
    log_error "change_ssh_port" "유효하지 않은 포트 번호 입력"
    echo "1~65535 범위의 숫자를 입력하세요."
    exit 1
  fi

  if [[ "$new_port" == "$current_port" ]]; then
    NEW_SSH_PORT="변경 없음 (${current_port})"
    log_info "SSH 포트 변경이 필요하지 않습니다."
    return 0
  fi

  backup_file "$ssh_config"
  if grep -q '^[[:space:]]*Port[[:space:]]' "$ssh_config"; then
    sed -i -E "s/^[[:space:]]*Port[[:space:]]+.*/Port ${new_port}/" "$ssh_config"
  else
    echo "Port ${new_port}" >> "$ssh_config"
  fi

  if command_exists ufw; then
    ufw allow "${new_port}/tcp" >/dev/null 2>&1 || log_warn "ufw에서 ${new_port}/tcp 허용에 실패했습니다."
  fi

  if sshd -t; then
    NEW_SSH_PORT="${current_port} → ${new_port}"
    log_info "SSH 포트를 ${new_port}로 설정했습니다."
    mark_restart_needed "ssh"
  else
    log_error "change_ssh_port" "sshd 설정 검증 실패"
    exit 1
  fi
}

configure_password_policy() {
  log_info "configure_password_policy 시작"
  if ! prompt_yes_no "사용자 비밀번호 만료 정책을 설정할까요?"; then
    PASSWORD_POLICY_SUMMARY="사용자 선택으로 미적용"
    log_info "비밀번호 만료 정책 설정을 건너뛰었습니다."
    return 0
  fi

  local max_days min_days warn_days min_len
  read_from_tty "비밀번호 최대 사용 기간을 입력하세요 (기본 90일): " max_days
  read_from_tty "비밀번호 최소 사용 기간을 입력하세요 (기본 0일): " min_days
  read_from_tty "비밀번호 만료 경고 일수를 입력하세요 (기본 7일): " warn_days
  read_from_tty "비밀번호 최소 길이를 입력하세요 (기본 ${MIN_PASSWORD_LENGTH}자): " min_len

  max_days="${max_days:-90}"
  min_days="${min_days:-0}"
  warn_days="${warn_days:-7}"
  min_len="${min_len:-$MIN_PASSWORD_LENGTH}"

  local user
  for user in $(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd); do
    chage -M "$max_days" -m "$min_days" -W "$warn_days" "$user"
  done

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

  PASSWORD_POLICY_SUMMARY="최대 ${max_days}일 / 최소 ${min_days}일 / 경고 ${warn_days}일 / 최소 길이 ${min_len}자"
  log_info "비밀번호 만료 정책을 적용했습니다."
}

setup_fallback_account_and_restrict_root() {
  log_info "일반 계정 생성 및 root SSH 제한 시작"
  local fallback_user="" existing_users create_fallback=false
  existing_users="$(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd | xargs)"

  if [[ -n "$existing_users" ]]; then
    log_info "현재 일반 사용자 계정 목록: $existing_users"
    printf '\n현재 일반 사용자 계정 목록: %s\n' "$existing_users"
    if prompt_yes_no "위 계정 외에 일반 관리자 계정을 추가로 생성할까요?"; then
      create_fallback=true
    else
      log_info "일반 관리자 계정 추가 생성을 건너뜁니다."
      echo "일반 관리자 계정 추가 생성을 건너뜁니다."
    fi
  else
    create_fallback=true
    log_warn "일반 사용자 계정이 없어 새 일반 관리자 계정을 생성합니다."
    echo "일반 사용자 계정이 없어 새 일반 관리자 계정을 생성합니다."
  fi

  if [[ "$create_fallback" == true ]]; then
    while true; do
      read_from_tty "생성할 일반 계정 이름을 입력하세요: " fallback_user
      [[ -z "$fallback_user" ]] && { echo "계정 이름을 입력하세요."; continue; }
      if id "$fallback_user" >/dev/null 2>&1; then
        echo "이미 존재하는 계정입니다. 다른 이름을 입력하세요."
        continue
      fi
      break
    done

    local password confirm
    while true; do
      read_password_from_tty "계정 '${fallback_user}'의 비밀번호를 입력하세요 (최소 ${MIN_PASSWORD_LENGTH}자): " password
      if (( ${#password} < MIN_PASSWORD_LENGTH )); then
        echo "비밀번호 길이가 부족합니다. 다시 입력하세요."
        continue
      fi
      read_password_from_tty "비밀번호를 한 번 더 입력하세요: " confirm
      if [[ "$password" != "$confirm" ]]; then
        echo "비밀번호가 일치하지 않습니다. 다시 시도하세요."
        continue
      fi
      break
    done

    useradd -m -G adm,sudo -s /bin/bash "$fallback_user" || { log_error "setup_fallback_account" "계정 생성 실패"; exit 1; }
    echo "${fallback_user}:${password}" | chpasswd || { log_error "setup_fallback_account" "비밀번호 설정 실패"; exit 1; }
    CREATED_USER="$fallback_user"
    log_info "일반 계정 '${fallback_user}'를 생성했습니다."
  fi

  local ssh_config="/etc/ssh/sshd_config"
  backup_file "$ssh_config"
  if grep -q '^[[:space:]]*PermitRootLogin' "$ssh_config"; then
    sed -i -E 's/^[[:space:]]*PermitRootLogin.*/PermitRootLogin no/' "$ssh_config"
  else
    echo "PermitRootLogin no" >> "$ssh_config"
  fi

  if sshd -t; then
    mark_restart_needed "ssh"
    log_info "루트 계정의 SSH 로그인을 차단했습니다."
  else
    log_error "setup_fallback_account_and_restrict_root" "sshd 설정 검증 실패"
    exit 1
  fi
}

configure_pass_min_length() {
  log_info "configure_pass_min_length 시작"
  local pam_file="/etc/pam.d/common-password"
  backup_file "$pam_file"

  if grep -q 'pam_unix.so' "$pam_file"; then
    if grep -Eq 'pam_unix\.so.*minlen=' "$pam_file"; then
      sed -i -E "s/(pam_unix\.so.*)minlen=[0-9]+/\1minlen=${MIN_PASSWORD_LENGTH}/" "$pam_file"
    else
      sed -i -E "s/(pam_unix\.so.*)/\1 minlen=${MIN_PASSWORD_LENGTH}/" "$pam_file"
    fi
    log_info "$pam_file 에 비밀번호 최소 길이 ${MIN_PASSWORD_LENGTH}자를 설정했습니다."
  else
    log_warn "$pam_file 에서 pam_unix.so 항목을 찾지 못했습니다."
  fi
}

configure_pam_lockout() {
  log_info "PAM 잠금 정책 설정 시작"
  local pam_auth="/etc/pam.d/common-auth"
  local pam_account="/etc/pam.d/common-account"
  local preauth_line="auth    required pam_faillock.so preauth silent deny=3 unlock_time=300"
  local authfail_line="auth    [default=die] pam_faillock.so authfail deny=3 unlock_time=300"
  local authsucc_line="auth    sufficient pam_faillock.so authsucc deny=3 unlock_time=300"
  local account_line="account required pam_faillock.so"
  local module_found=false

  backup_file "$pam_auth" "$pam_account"

  if ! command_exists faillock; then
    log_warn "faillock 명령을 찾지 못했습니다. libpam-modules-bin 패키지 설치를 확인하세요."
    return 0
  fi

  local candidate
  for candidate in \
    /usr/lib/security/pam_faillock.so \
    /usr/lib/x86_64-linux-gnu/security/pam_faillock.so \
    /lib/security/pam_faillock.so \
    /lib/x86_64-linux-gnu/security/pam_faillock.so
  do
    if [[ -f "$candidate" ]]; then
      module_found=true
      break
    fi
  done

  if [[ "$module_found" != true ]]; then
    log_warn "pam_faillock.so 모듈이 없어 로그인 실패 잠금 정책을 건너뜁니다."
    return 0
  fi

  if ! grep -Fxq "$preauth_line" "$pam_auth"; then
    if grep -q '^[[:space:]]*auth[[:space:]]\+required[[:space:]]\+pam_faillock\.so[[:space:]]\+preauth' "$pam_auth"; then
      sed -i "s|^[[:space:]]*auth[[:space:]]\+required[[:space:]]\+pam_faillock\.so[[:space:]]\+preauth.*|$preauth_line|" "$pam_auth"
    else
      sed -i "/pam_unix\.so/ i $preauth_line" "$pam_auth"
    fi
  fi

  if ! grep -Fxq "$authfail_line" "$pam_auth"; then
    if grep -q 'pam_faillock\.so.*authfail' "$pam_auth"; then
      sed -i "s|^[[:space:]]*auth[[:space:]]\+\[default=die\][[:space:]]\+pam_faillock\.so.*|$authfail_line|" "$pam_auth"
    else
      sed -i "/pam_unix\.so/ a $authfail_line" "$pam_auth"
    fi
  fi

  if ! grep -Fxq "$authsucc_line" "$pam_auth"; then
    if grep -q 'pam_faillock\.so.*authsucc' "$pam_auth"; then
      sed -i "s|^[[:space:]]*auth[[:space:]]\+.*pam_faillock\.so[[:space:]]\+authsucc.*|$authsucc_line|" "$pam_auth"
    else
      if grep -q 'pam_faillock\.so authfail' "$pam_auth"; then
        sed -i "/pam_faillock\.so authfail/a $authsucc_line" "$pam_auth"
      else
        sed -i "/pam_unix\.so/ a $authsucc_line" "$pam_auth"
      fi
    fi
  fi

  if ! grep -Eq '^\s*account\s+required\s+pam_faillock\.so' "$pam_account"; then
    echo "$account_line" >>"$pam_account"
  fi

  faillock --reset >/dev/null 2>&1 || true
  log_info "PAM 로그인 실패 잠금 정책을 적용했습니다."
}

configure_su_restriction() {
  log_info "configure_su_restriction 시작"
  local su_file="/etc/pam.d/su"
  local su_bin="/usr/bin/su"
  backup_file "$su_file" "$su_bin"

  if ! grep -Eq 'auth\s+required\s+pam_wheel.so\s+use_uid\s+group=sudo' "$su_file"; then
    sed -i '/pam_rootok.so/a auth       required   pam_wheel.so use_uid group=sudo' "$su_file"
  fi

  chgrp sudo "$su_bin"
  chmod 4750 "$su_bin"
  log_info "su 명령 사용을 sudo 그룹으로 제한했습니다."
}

perform_account_hardening() {
  log_info "계정 및 인증 설정 시작"
  remove_unneeded_users
  change_root_password
  change_ssh_port
  configure_password_policy
  setup_fallback_account_and_restrict_root
  configure_pass_min_length
  configure_pam_lockout
  configure_su_restriction
  log_info "계정 및 인증 설정 완료"
}

perform_account_hardening