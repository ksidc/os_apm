#!/bin/bash

# check_service_versions.sh
# 실행 중인 Apache2와 MySQL 버전을 확인합니다.

BASE_DIR="${BASE_DIR:-/usr/local/src/iteasy_tuning}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$BASE_DIR/scripts}"
source "$SCRIPTS_DIR/common.sh"
source "$SCRIPTS_DIR/lib/kv_parser.sh"

VERSION_FILE="$VERSION_LOG"
> "$VERSION_FILE"
chmod 600 "$VERSION_FILE" 2>/dev/null || true

SERVICE_LOG_PATH="$SERVICE_LOG"
[ -f "$SERVICE_LOG_PATH" ] || { log_warn "서비스 경로 로그가 없어 버전 확인을 건너뜁니다" "versions"; exit 0; }

write_version() {
    printf '%s=%s\n' "$1" "$2" >> "$VERSION_FILE"
}

apache_bin=$(kv_get_value "$SERVICE_LOG_PATH" "APACHE_BINARY")
if [ -n "$apache_bin" ] && [ -x "$apache_bin" ]; then
    apache_version=$("$apache_bin" -v 2>/dev/null | awk -F/ '/Server version/ {print $2}')
    apache_version=${apache_version:-unknown}
    write_version "APACHE_VERSION" "$apache_version"
    log_info "Apache2 버전을 수집했습니다" "versions" "$(json_kv version "$apache_version")"
fi

mysql_bin=$(kv_get_value "$SERVICE_LOG_PATH" "MYSQL_BINARY")
if [ -n "$mysql_bin" ] && [ -x "$mysql_bin" ]; then
    mysql_version=$("$mysql_bin" --version 2>/dev/null | awk '{print $3}')
    mysql_version=${mysql_version:-unknown}
    write_version "MYSQL_VERSION" "$mysql_version"
    log_info "MySQL 버전을 수집했습니다" "versions" "$(json_kv version "$mysql_version")"
fi

log_info "서비스 버전 확인을 완료했습니다" "versions" "$(json_kv file "$VERSION_FILE")"
