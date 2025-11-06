#!/bin/bash

# apply_apache.sh
# Deploy the generated apache_tuning.conf into the detected MPM config file.

set -euo pipefail

BASE_DIR="${BASE_DIR:-/usr/local/src/iteasy_tuning}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$BASE_DIR/scripts}"
source "$SCRIPTS_DIR/common.sh"
source "$SCRIPTS_DIR/lib/kv_parser.sh"

RECOMM_FILE="$TMP_CONF_DIR/apache_tuning.conf"
SERVICE_LOG_PATH="$SERVICE_LOG"

check_root || exit 1
setup_logging || exit 1

if [ ! -f "$RECOMM_FILE" ]; then
    echo "[오류] 추천 설정 파일(${RECOMM_FILE})이 없습니다. 먼저 calculate_mpm_config.sh를 실행하세요." >&2
    log_error "추천 설정 파일 없음" "apply_apache" "$(json_kv file "$RECOMM_FILE")"
    exit 1
fi

if [ ! -f "$SERVICE_LOG_PATH" ]; then
    echo "[오류] service_paths.log를 찾을 수 없습니다." >&2
    log_error "service_paths.log 없음" "apply_apache"
    exit 1
fi

APACHE_BIN=$(kv_get_value "$SERVICE_LOG_PATH" "APACHE_BINARY")
APACHE_BIN=${APACHE_BIN:-/usr/sbin/apache2}

TARGET_FILE=$(kv_get_value "$SERVICE_LOG_PATH" "APACHE_MPM_CONF")
TARGET_FILE=${TARGET_FILE:-/etc/apache2/mods-available/mpm_event.conf}
TARGET_DIR=$(dirname "$TARGET_FILE")

mkdir -p "$TARGET_DIR" 2>/dev/null || {
    echo "[오류] ${TARGET_DIR} 디렉터리를 생성하지 못했습니다." >&2
    log_error "대상 디렉터리 생성 실패" "apply_apache" "$(json_kv dir "$TARGET_DIR")"
    exit 1
}

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
if [ -f "$TARGET_FILE" ]; then
    cp -a "$TARGET_FILE" "${TARGET_FILE}.backup.${TIMESTAMP}"
    log_info "기존 Apache 설정을 백업했습니다" "apply_apache" "$(json_kv backup "${TARGET_FILE}.backup.${TIMESTAMP}")"
fi

cp -a "$RECOMM_FILE" "$TARGET_FILE" || {
    echo "[오류] ${TARGET_FILE} 파일을 생성하지 못했습니다." >&2
    log_error "추천 설정 복사 실패" "apply_apache" "$(json_kv target "$TARGET_FILE")"
    exit 1
}
chmod 644 "$TARGET_FILE" 2>/dev/null || true

if command -v apachectl >/dev/null 2>&1; then
    CONTROL_BIN="apachectl"
elif command -v apache2ctl >/dev/null 2>&1; then
    CONTROL_BIN="apache2ctl"
else
    CONTROL_BIN="$APACHE_BIN"
fi

if command -v "$CONTROL_BIN" >/dev/null 2>&1; then
    if ! "$CONTROL_BIN" configtest >/dev/null 2>&1; then
        echo "[오류] Apache 설정 검증에 실패했습니다. ${TARGET_FILE} 파일을 확인하세요." >&2
        log_error "Apache configtest 실패" "apply_apache"
        exit 1
    fi
fi

if systemctl --quiet is-active apache2.service 2>/dev/null; then
    systemctl reload apache2.service >/dev/null 2>&1 || systemctl restart apache2.service >/dev/null 2>&1
elif [ -x "$APACHE_BIN" ]; then
    "$APACHE_BIN" -k graceful >/dev/null 2>&1 || true
fi

log_info "Apache 설정이 적용되었습니다" "apply_apache" "$(json_kv target "$TARGET_FILE")"
echo "[OK] Apache 설정이 적용되었습니다. 대상 파일: ${TARGET_FILE}"
