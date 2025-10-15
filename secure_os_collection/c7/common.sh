#!/bin/bash

# Shared utility functions. main.sh must define LOG_FILE and BACKUP_DIR before sourcing this file.

log_info() {
  local message="[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
  echo "$message"
}

log_error() {
  local context="$1"
  local detail="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] ${context}: ${detail}" >&2
}

backup_file() {
  mkdir -p "$BACKUP_DIR" && chmod 700 "$BACKUP_DIR" || {
    log_error "backup_file" "Failed to create backup directory ($BACKUP_DIR)"
    return 1
  }

  for target in "$@"; do
    if [ -e "$target" ]; then
      local dest="$BACKUP_DIR/$(basename "$target").bak_$(date +%F_%T)"
      cp -p "$target" "$dest" || log_error "backup_file" "Failed to back up $target"
    else
      log_info "[WARN] $target not found, skipping backup"
    fi
  done
}

set_file_perms() {
  local file="$1"
  local owner="$2"
  local perms="$3"

  if [ -e "$file" ]; then
    chown "$owner" "$file" || {
      log_error "set_file_perms" "Failed to set owner on $file ($owner)"
      return 1
    }
    chmod "$perms" "$file" || {
      log_error "set_file_perms" "Failed to set permissions on $file ($perms)"
      return 1
    }
  else
    log_info "[WARN] $file not found, skipping permission update"
    return 1
  fi
}

check_root() {
  if [ "$EUID" -ne 0 ]; then
    log_error "check_root" "root privileges are required"
    exit 1
  fi
}
