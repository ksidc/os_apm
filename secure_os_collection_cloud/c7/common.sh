#!/bin/bash
# 로그/백업/요약 제거. 필수 유틸만 제공.

check_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "[ERROR] root 권한이 필요합니다." >&2
    exit 1
  fi
}

set_file_perms() {
  # set_file_perms <path> <owner:group> <mode>
  local file="$1" owner="$2" mode="$3"
  [ -e "$file" ] || return 0
  chown "$owner" "$file" || true
  chmod "$mode" "$file" || true
}