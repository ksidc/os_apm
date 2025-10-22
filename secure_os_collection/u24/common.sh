#!/bin/bash
#
# Ubuntu 24.04 공통 유틸리티

if [[ -n "${SECURE_OS_COMMON_LOADED:-}" ]]; then
  return 0
fi
readonly SECURE_OS_COMMON_LOADED=1

# ------------------------------------------------------------------------------
# 로깅
# ------------------------------------------------------------------------------

log_info() {
  local message="$1"
  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $message" >> "$LOG_FILE"
}

log_warn() {
  local message="$1"
  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $message" >> "$LOG_FILE"
}

log_error() {
  local context="$1"
  local message="$2"
  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] ${context}: ${message}" >> "$LOG_FILE"
}

# ------------------------------------------------------------------------------
# 기본 점검
# ------------------------------------------------------------------------------

check_root() {
  if [[ "$EUID" -ne 0 ]]; then
    log_error "check_root" "root 권한이 필요합니다."
    echo "ERROR: root 권한으로 실행해야 합니다." >&2
    exit 1
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# ------------------------------------------------------------------------------
# 백업 및 권한
# ------------------------------------------------------------------------------

ensure_backup_dir() {
  mkdir -p "$BACKUP_DIR"
  chmod 700 "$BACKUP_DIR"
}

backup_file() {
  ensure_backup_dir
  local src
  for src in "$@"; do
    if [[ -e "$src" ]]; then
      cp "$src" "${BACKUP_DIR}/$(basename "$src").bak_$(date +%F_%T)"
      log_info "백업 완료: $src → $BACKUP_DIR"
    else
      log_warn "백업 생략: $src 파일이 존재하지 않습니다."
    fi
  done
}

set_file_perms() {
  local file="$1" owner="$2" perms="$3"
  if [[ -e "$file" ]]; then
    chown "$owner" "$file"
    chmod "$perms" "$file"
    log_info "권한 설정: $file → 소유자 $owner, 권한 $perms"
  else
    log_warn "권한 설정 생략: $file 파일이 존재하지 않습니다."
    return 1
  fi
}

wait_for_apt_lock() {
  local lock_file="/var/lib/dpkg/lock-frontend"
  while fuser "$lock_file" >/dev/null 2>&1; do
    log_info "다른 패키지 작업을 기다리는 중입니다. 5초 후 재시도합니다."
    sleep 5
  done
}

# ------------------------------------------------------------------------------
# 재시작 관리
# ------------------------------------------------------------------------------

mark_restart_needed() {
  local service="$1"
  restarts_needed["$service"]=1
}

# ------------------------------------------------------------------------------
# 대화형 입력
# ------------------------------------------------------------------------------

read_from_tty() {
  local prompt="$1"
  local var_name="$2"
  read -r -p "$prompt" "$var_name" < /dev/tty
}

read_password_from_tty() {
  local prompt="$1"
  local var_name="$2"
  read -r -s -p "$prompt" "$var_name" < /dev/tty
  echo
}

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

# ------------------------------------------------------------------------------
# 외부 설정 파일
# ------------------------------------------------------------------------------

load_external_config() {
  local candidate

  if [[ -n "${CONFIG_FILE:-}" ]] && [[ -r "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    log_info "환경 설정을 불러왔습니다: $CONFIG_FILE"
    return 0
  fi

  candidate="${SCRIPT_DIR}/secure_ubuntu_24.conf"
  if [[ -r "$candidate" ]]; then
    # shellcheck source=/dev/null
    source "$candidate"
    log_info "기본 환경 설정을 불러왔습니다: $candidate"
  fi
}
