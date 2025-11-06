#!/bin/bash

# apply_mysql.sh
# Copy mysql_tuning.cnf into MariaDB config directory and restart the service.

BASE_DIR="${BASE_DIR:-/usr/local/src/iteasy_tuning}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$BASE_DIR/scripts}"
TMP_CONF_DIR="${TMP_CONF_DIR:-$BASE_DIR/tmp_conf}"
source "$SCRIPTS_DIR/common.sh"
source "$SCRIPTS_DIR/lib/kv_parser.sh"

check_root || exit 1
setup_logging || exit 1

RECOMM_FILE="$TMP_CONF_DIR/mysql_tuning.cnf"
SERVICE_LOG_PATH="$SERVICE_LOG"
TARGET_DIR="/etc/mysql/mariadb.conf.d"
TARGET_FILE="$TARGET_DIR/zz-iteasy_tuning.cnf"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

if [ ! -f "$RECOMM_FILE" ]; then
    echo "[ERROR] 적용 대상 MySQL conf 파일이 없습니다. (경로: $RECOMM_FILE)" >&2
    log_error "추천 설정 파일 없음" "apply_mysql" "$(json_kv file "$RECOMM_FILE")"
    exit 1
fi

SERVICE_UNIT=$(kv_get_value "$SERVICE_LOG_PATH" "MYSQL_SYSTEMD_UNIT")
SERVICE_UNIT=${SERVICE_UNIT:-mariadb}

mkdir -p "$TARGET_DIR" 2>/dev/null || {
    echo "[ERROR] ${TARGET_DIR} 디렉터리를 생성하지 못했습니다." >&2
    log_error "mariadb.conf.d 생성 실패" "apply_mysql" "$(json_kv dir "$TARGET_DIR")"
    exit 1
}

BACKUP_FILE=""
if [ -f "$TARGET_FILE" ]; then
    BACKUP_FILE="$TARGET_FILE.backup.$TIMESTAMP"
    cp -a "$TARGET_FILE" "$BACKUP_FILE"
    log_info "기존 DB 튜닝 파일을 백업했습니다" "apply_mysql" "$(json_kv backup "$BACKUP_FILE")"
fi

cp -a "$RECOMM_FILE" "$TARGET_FILE" || {
    echo "[ERROR] ${TARGET_FILE} 파일을 생성하지 못했습니다." >&2
    log_error "추천 설정 복사 실패" "apply_mysql" "$(json_kv target "$TARGET_FILE")"
    exit 1
}
chmod 644 "$TARGET_FILE" 2>/dev/null || true

if ! systemctl restart "${SERVICE_UNIT}.service" >/dev/null 2>&1; then
    if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
        cp -a "$BACKUP_FILE" "$TARGET_FILE"
    else
        rm -f "$TARGET_FILE"
    fi
    systemctl restart "${SERVICE_UNIT}.service" >/dev/null 2>&1 || true
    log_error "MySQL/MariaDB 재시작 실패" "apply_mysql"
    echo "[ERROR] DB 서비스(${SERVICE_UNIT}) 재시작이 실패했습니다. 복원 후 로그를 확인하세요." >&2
    exit 1
fi

log_info "MySQL/MariaDB 설정을 적용했습니다" "apply_mysql" "$(json_kv target "$TARGET_FILE")"
echo "[OK] MySQL/MariaDB 설정이 적용되었습니다. 대상 파일: ${TARGET_FILE}"
