#!/bin/bash
#
# Ubuntu 18.04 공통 유틸리티

if [[ -n "${SECURE_OS_COMMON_LOADED:-}" ]]; then
  return 0
fi
readonly SECURE_OS_COMMON_LOADED=1

# 스크립트가 root 권한으로 실행 중인지 확인한다.
check_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: root 권한으로 실행해야 합니다." >&2
    exit 1
  fi
}

# 명령어 존재 여부를 확인한다.
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# 지정 파일의 소유자와 권한을 보안 기준값으로 맞춘다.
set_file_perms() {
  local file="$1" owner="$2" perms="$3"
  if [[ -e "$file" ]]; then
    chown "$owner" "$file" || { echo "ERROR: $file 소유자 설정 실패" >&2; return 1; }
    chmod "$perms" "$file" || { echo "ERROR: $file 권한 설정 실패" >&2; return 1; }
  else
    return 1
  fi
}

# 다른 apt/dpkg 작업이 끝날 때까지 대기한다.
wait_for_apt_lock() {
  local lock_file="/var/lib/dpkg/lock-frontend"
  while fuser "$lock_file" >/dev/null 2>&1; do
    sleep 5
  done
}

# 마지막 단계에서 재시작할 서비스를 표시한다.
mark_restart_needed() {
  local service="$1"
  restarts_needed["$service"]=1
}

# /dev/tty에서 일반 입력을 받는다.
read_from_tty() {
  local prompt="$1"
  local var_name="$2"
  read -r -p "$prompt" "$var_name" < /dev/tty
}

# /dev/tty에서 비밀번호 입력을 받는다.
read_password_from_tty() {
  local prompt="$1"
  local var_name="$2"
  read -r -s -p "$prompt" "$var_name" < /dev/tty
  echo
}

# y/N 선택 입력을 받는다.
prompt_yes_no() {
  local prompt="$1"
  local reply
  while true; do
    read_from_tty "$prompt [y/N]: " reply
    case "${reply:-N}" in
      [Yy]) return 0 ;;
      [Nn]|"") return 1 ;;
      *) echo "y 또는 n으로 입력해 주세요." ;;
    esac
  done
}

# 입력한 신규 계정명을 다시 표시하고 생성 여부를 확인한다.
confirm_account_name() {
  local user_name="$1"
  echo "입력한 계정명: $user_name"
  prompt_yes_no "이 계정명으로 생성하시겠습니까?"
}

# 기존 일반 계정 중 sudo 그룹 구성원이 있는지 확인하고, 없을 때만 추가 여부를 묻는다.
ensure_admin_access() {
  local admin_group="$1" user_name
  shift

  for user_name in "$@"; do
    if id -nG "$user_name" 2>/dev/null | tr ' ' '\n' | grep -qx "$admin_group"; then
      echo "관리자 권한 확인: $user_name ($admin_group)"
      return 0
    fi
  done

  for user_name in "$@"; do
    echo "관리자 권한 없음: $user_name ($admin_group)"
    if prompt_yes_no "$user_name 계정을 $admin_group 그룹에 추가하시겠습니까?"; then
      usermod -aG "$admin_group" "$user_name" || {
        echo "ERROR: $user_name 계정의 $admin_group 그룹 추가 실패" >&2
        return 1
      }
      return 0
    fi
  done

  echo "ERROR: root SSH 로그인을 차단하려면 관리자 권한이 있는 일반 계정이 필요합니다." >&2
  return 1
}
