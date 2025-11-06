#!/bin/bash

# apply_mariadb.sh
# 추천된 MariaDB 설정을 /etc/my.cnf.d에 배포합니다.

BASE_DIR="${BASE_DIR:-/usr/local/src/iteasy_tuning}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$BASE_DIR/scripts}"
source "$SCRIPTS_DIR/common.sh"
source "$SCRIPTS_DIR/lib/kv_parser.sh"

RECOMM_FILE="$TMP_CONF_DIR/mysql_tuning.cnf"
TARGET_DIR="/etc/my.cnf.d"
TARGET_FILE="$TARGET_DIR/zz-iteasy_tuning.cnf"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

check_root || exit 1
setup_logging || exit 1

if [ ! -f "$RECOMM_FILE" ]; then
    echo "[오류] 추천 설정 파일(${RECOMM_FILE})이 존재하지 않습니다. 먼저 calculate_mysql_config.sh를 실행하세요." >&2
    log_error "추천 설정 파일이 없습니다" "apply_mariadb" "$(json_kv file "$RECOMM_FILE")"
    exit 1
fi

mkdir -p "$TARGET_DIR" 2>/dev/null || {
    echo "[오류] ${TARGET_DIR} 디렉터리를 생성할 수 없습니다." >&2
    log_error "my.cnf.d 디렉터리를 생성하지 못했습니다" "apply_mariadb" "$(json_kv dir "$TARGET_DIR")"
    exit 1
}

if [ -f "$TARGET_FILE" ]; then
    cp -a "$TARGET_FILE" "${TARGET_FILE}.backup.${TIMESTAMP}"
    log_info "기존 MariaDB 튜닝 파일을 백업했습니다" "apply_mariadb" "$(json_kv backup "${TARGET_FILE}.backup.${TIMESTAMP}")"
fi

cp -a "$RECOMM_FILE" "$TARGET_FILE" || {
    echo "[오류] ${TARGET_FILE} 파일을 생성하지 못했습니다." >&2
    log_error "추천 설정을 복사하는 데 실패했습니다" "apply_mariadb"
    exit 1
}
chmod 644 "$TARGET_FILE" 2>/dev/null || true

# innodb_log_file_size 변경 시 기존 로그 파일 제거 필요 (MariaDB 5.5 등 구버전)
if grep -q "innodb_log_file_size" "$TARGET_FILE" 2>/dev/null; then
    DATADIR=$(grep "^datadir" /etc/my.cnf /etc/my.cnf.d/*.cnf 2>/dev/null | head -1 | cut -d'=' -f2 | tr -d ' ' || echo "/var/lib/mysql")
    if [ -z "$DATADIR" ]; then
        DATADIR="/var/lib/mysql"
    fi

    if [ -f "$DATADIR/ib_logfile0" ]; then
        log_info "InnoDB 로그 파일 크기 변경을 위해 기존 로그 파일을 삭제합니다" "apply_mariadb" "$(json_kv datadir "$DATADIR")"
        # 서비스 중지
        if systemctl --quiet is-active mariadb.service 2>/dev/null; then
            systemctl stop mariadb >/dev/null 2>&1
        elif systemctl --quiet is-active mysqld.service 2>/dev/null; then
            systemctl stop mysqld >/dev/null 2>&1
        fi

        # 기존 로그 파일 백업 후 삭제
        if [ -f "$DATADIR/ib_logfile0" ]; then
            mv "$DATADIR/ib_logfile0" "$DATADIR/ib_logfile0.backup.${TIMESTAMP}" 2>/dev/null || true
        fi
        if [ -f "$DATADIR/ib_logfile1" ]; then
            mv "$DATADIR/ib_logfile1" "$DATADIR/ib_logfile1.backup.${TIMESTAMP}" 2>/dev/null || true
        fi
        log_info "InnoDB 로그 파일을 백업했습니다" "apply_mariadb"
    fi
fi

if systemctl --quiet is-active mariadb.service 2>/dev/null; then
    systemctl restart mariadb >/dev/null 2>&1
elif systemctl --quiet is-active mysqld.service 2>/dev/null; then
    systemctl restart mysqld >/dev/null 2>&1
elif systemctl --quiet is-enabled mariadb.service 2>/dev/null; then
    systemctl start mariadb >/dev/null 2>&1
elif systemctl --quiet is-enabled mysqld.service 2>/dev/null; then
    systemctl start mysqld >/dev/null 2>&1
fi

log_info "MariaDB 설정 적용을 완료했습니다" "apply_mariadb" "$(json_kv target "$TARGET_FILE")"
