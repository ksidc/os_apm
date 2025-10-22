#!/bin/bash
#
# Ubuntu 18.04 보안 스크립트 공용 함수 모음.

if [[ -n "${SECURE_OS_COMMON_LOADED:-}" ]]; then
  return 0
fi
readonly SECURE_OS_COMMON_LOADED=1

# ------------------------------------------------------------------------------
# 로깅 헬퍼
# ------------------------------------------------------------------------------

log_info() {
  local message="$1"
  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [정보] $message" >> "$LOG_FILE"
}

log_warn() {
  local message="$1"
  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [경고] $message" >> "$LOG_FILE"
}

log_error() {
  local context="$1"
  local message="$2"
  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [오류] ${context}: ${message}" >> "$LOG_FILE"
}

# ------------------------------------------------------------------------------
# 기본 보호 로직
# ------------------------------------------------------------------------------

check_root() {
  if [[ "$EUID" -ne 0 ]]; then
    log_error "check_root" "root 권한이 필요합니다."
    echo "오류: root 권한으로 실행해야 합니다." >&2
    exit 1
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

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
      log_info "백업 완료: $src -> $BACKUP_DIR"
    else
      log_warn "백업 건너뜀(파일 없음): $src"
    fi
  done
}

set_file_perms() {
  local file="$1" owner="$2" perms="$3"
  if [[ -e "$file" ]]; then
    chown "$owner" "$file"
    chmod "$perms" "$file"
    log_info "권한 조정: $file 소유자=$owner 권한=$perms"
  else
    log_warn "권한 조정 건너뜀(파일 없음): $file"
    return 1
  fi
}

wait_for_apt_lock() {
  local lock_file="/var/lib/dpkg/lock-frontend"
  while fuser "$lock_file" >/dev/null 2>&1; do
    log_info "apt 잠금 해제를 기다리는 중..."
    sleep 5
  done
}

# ------------------------------------------------------------------------------
# 재시작 추적
# ------------------------------------------------------------------------------

mark_restart_needed() {
  local service="$1"
  restarts_needed["$service"]=1
}

# ------------------------------------------------------------------------------
# 대화형 헬퍼
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
      *) echo "y 또는 n 으로 입력해주세요." ;;
    esac
  done
}

# ------------------------------------------------------------------------------
# 외부 설정 로드
# ------------------------------------------------------------------------------

load_external_config() {
  local candidate

  if [[ -n "${CONFIG_FILE:-}" && -r "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    log_info "외부 설정 파일을 불러왔습니다: $CONFIG_FILE"
    return 0
  fi

  candidate="/etc/hardening.conf"
  if [[ -r "$candidate" ]]; then
    # shellcheck source=/dev/null
    source "$candidate"
    log_info "기본 설정 파일을 불러왔습니다: $candidate"
  fi
}

