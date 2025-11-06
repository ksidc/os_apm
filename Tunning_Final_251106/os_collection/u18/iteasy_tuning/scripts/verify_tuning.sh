#!/bin/bash

# verify_tuning.sh
# 튜닝 적용 후 기본 상태를 빠르게 확인합니다.

BASE_DIR="${BASE_DIR:-/usr/local/src/iteasy_tuning}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$BASE_DIR/scripts}"
source "$SCRIPTS_DIR/common.sh"

BACKUP_DIR_PATH="$BACKUP_DIR"
APACHE_INCLUDE="/etc/apache2/conf-enabled/zz-iteasy_tuning.conf"
MYSQL_INCLUDE="/etc/mysql/mysql.conf.d/zz-iteasy_tuning.cnf"

OK_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

note_ok()   { printf '[OK]   %s\n' "$1";   OK_COUNT=$((OK_COUNT+1)); }
note_warn() { printf '[경고] %s\n' "$1"; WARN_COUNT=$((WARN_COUNT+1)); }
note_fail() { printf '[오류] %s\n' "$1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

if [ "${EUID}" -ne 0 ]; then
    note_fail "루트 권한으로 실행해야 합니다."
    exit 1
fi

if [ -d "$BACKUP_DIR_PATH" ]; then
    note_ok "백업 디렉터리를 확인했습니다: $BACKUP_DIR_PATH"
else
    note_warn "백업 디렉터리를 찾지 못했습니다: $BACKUP_DIR_PATH"
fi

if [ -f "$APACHE_INCLUDE" ]; then
    note_ok "Apache 포함 파일을 확인했습니다: $APACHE_INCLUDE"
else
    note_warn "Apache 포함 파일이 없습니다: $APACHE_INCLUDE"
fi

if [ -f "$MYSQL_INCLUDE" ]; then
    note_ok "MySQL 포함 파일을 확인했습니다: $MYSQL_INCLUDE"
else
    note_warn "MySQL 포함 파일이 없습니다: $MYSQL_INCLUDE"
fi

printf '\n요약: %d OK / %d 경고 / %d 오류\n' "$OK_COUNT" "$WARN_COUNT" "$FAIL_COUNT"
exit 0
