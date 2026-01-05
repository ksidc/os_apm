#!/bin/bash
#
# Ubuntu 20.04 common utilities shared by hardening modules.

if [[ -n "${SECURE_OS_COMMON_LOADED:-}" ]]; then
  return 0
fi
readonly SECURE_OS_COMMON_LOADED=1

# ------------------------------------------------------------------------------
# Logging helpers
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
# Basic guards
# ------------------------------------------------------------------------------

check_root() {
  if [[ "$EUID" -ne 0 ]]; then
    log_error "check_root" "root privileges required"
    echo "ERROR: run this script with root privileges." >&2
    exit 1
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# ------------------------------------------------------------------------------
# Permissions
# ------------------------------------------------------------------------------

set_file_perms() {
  local file="$1" owner="$2" perms="$3"
  if [[ -e "$file" ]]; then
    chown "$owner" "$file"
    chmod "$perms" "$file"
    log_info "Permissions updated: $file owner=$owner mode=$perms"
  else
    log_warn "Permissions skipped; file not found: $file"
    return 1
  fi
}

wait_for_apt_lock() {
  local lock_file="/var/lib/dpkg/lock-frontend"
  while fuser "$lock_file" >/dev/null 2>&1; do
    log_info "Waiting for apt lock to be released..."
    sleep 5
  done
}

# ------------------------------------------------------------------------------
# Restart tracking
# ------------------------------------------------------------------------------

mark_restart_needed() {
  local service="$1"
  restarts_needed["$service"]=1
}

# ------------------------------------------------------------------------------
# TTY helpers
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
      *) echo "Please answer with y or n." ;;
    esac
  done
}


