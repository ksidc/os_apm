#!/bin/bash

# calculate_mysql_config.sh
# 시스템 자원과 선택한 엔진을 바탕으로 MySQL/MariaDB 설정을 제안합니다.

BASE_DIR="${BASE_DIR:-/usr/local/src/iteasy_tuning}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$BASE_DIR/scripts}"
source "$SCRIPTS_DIR/common.sh"
source "$SCRIPTS_DIR/lib/kv_parser.sh"

SERVICE_LOG_PATH="$SERVICE_LOG"
SYSTEM_LOG_PATH="$SYSTEM_LOG"
OUTPUT_FILE="$TMP_CONF_DIR/mysql_tuning.cnf"

mkdir -p "$TMP_CONF_DIR" 2>/dev/null || {
    log_error "TMP_CONF_DIR를 생성하지 못했습니다" "mysql" "$(json_kv path "$TMP_CONF_DIR")"
    exit 1
}

if [ ! -f "$SERVICE_LOG_PATH" ] || [ ! -f "$SYSTEM_LOG_PATH" ]; then
    log_warn "필수 로그 파일이 없어 MySQL 설정 계산을 건너뜁니다" "mysql"
    runtime_log "MySQL 설정 = 건너뜀"
    exit 0
fi

MYSQL_RUNNING=$(kv_get_value "$SERVICE_LOG_PATH" "MYSQL_RUNNING")
MARIADB_RUNNING=$(kv_get_value "$SERVICE_LOG_PATH" "MARIADB_RUNNING")
if [ "$MYSQL_RUNNING" != "1" ] && [ "$MARIADB_RUNNING" != "1" ]; then
    log_info "실행 중인 MySQL/MariaDB 서비스가 없어 설정 계산을 건너뜁니다" "mysql"
    runtime_log "MySQL 설정 = 건너뜀"
    exit 0
fi

TOTAL_MEMORY=$(kv_get_value "$SYSTEM_LOG_PATH" "TOTAL_MEMORY")
TOTAL_MEMORY=${TOTAL_MEMORY:-4096}
CPU_CORES=$(kv_get_value "$SYSTEM_LOG_PATH" "CPU_CORES")
CPU_CORES=${CPU_CORES:-4}

get_db_ratio() {
    case "$1" in
        web) echo 0 ;;
        web_was) echo 0 ;;
        web_db) echo 55 ;;
        web_was_db) echo 50 ;;
        was_db) echo 65 ;;
        db) echo 80 ;;
        *) echo 50 ;;
    esac
}

ratio=$(get_db_ratio "${ITEASY_SERVICE_PROFILE:-web_db}")
target_memory=$(( TOTAL_MEMORY * ratio / 100 ))
if [ "$target_memory" -gt $((TOTAL_MEMORY - 512)) ]; then
    target_memory=$((TOTAL_MEMORY - 512))
fi
[ "$target_memory" -lt 512 ] && target_memory=512

max_connections=$(( CPU_CORES * 60 ))
[ "$max_connections" -lt 200 ] && max_connections=200
[ "$max_connections" -gt 1200 ] && max_connections=1200

thread_cache_size=$(( CPU_CORES * 8 ))
[ "$thread_cache_size" -lt 32 ] && thread_cache_size=32
[ "$thread_cache_size" -gt 256 ] && thread_cache_size=256

table_open_cache=$(( CPU_CORES * 200 ))
[ "$table_open_cache" -lt 800 ] && table_open_cache=800
[ "$table_open_cache" -gt 4000 ] && table_open_cache=4000

tmp_table_size=64
[ "$target_memory" -gt 8192 ] && tmp_table_size=128

case "${ITEASY_DB_ENGINE:-innodb}" in
    myisam)
        innodb_buffer=$(( target_memory * 30 / 100 ))
        key_buffer=$(( target_memory * 50 / 100 ))
        ;;
    mixed)
        innodb_buffer=$(( target_memory * 60 / 100 ))
        key_buffer=$(( target_memory * 20 / 100 ))
        ;;
    *) # innodb
        innodb_buffer=$(( target_memory * 70 / 100 ))
        key_buffer=64
        ;;
esac

[ "$innodb_buffer" -lt 256 ] && innodb_buffer=256
[ "$innodb_buffer" -gt $(( target_memory - 256 )) ] && innodb_buffer=$(( target_memory - 256 ))
[ "$key_buffer" -lt 32 ] && key_buffer=32
[ "$key_buffer" -gt 1024 ] && key_buffer=1024

innodb_log_file=$(( innodb_buffer / 4 ))
[ "$innodb_log_file" -lt 256 ] && innodb_log_file=256
[ "$innodb_log_file" -gt 2048 ] && innodb_log_file=2048

innodb_instances=$(( innodb_buffer / 1024 ))
[ "$innodb_instances" -lt 1 ] && innodb_instances=1
[ "$innodb_instances" -gt 8 ] && innodb_instances=8

cat > "$OUTPUT_FILE" <<EOF
[mysqld]
max_connections         = ${max_connections}
thread_cache_size       = ${thread_cache_size}
table_open_cache        = ${table_open_cache}
tmp_table_size          = ${tmp_table_size}M
max_heap_table_size     = ${tmp_table_size}M
wait_timeout            = 300
innodb_buffer_pool_size = ${innodb_buffer}M
innodb_buffer_pool_instances = ${innodb_instances}
innodb_log_file_size    = ${innodb_log_file}M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method     = O_DIRECT
innodb_file_per_table   = 1
key_buffer_size         = ${key_buffer}M
EOF

chmod 600 "$OUTPUT_FILE" 2>/dev/null || true
log_info "MySQL/MariaDB 튜닝 설정을 생성했습니다" "mysql" "$(json_two memory_mb "$target_memory" output "$OUTPUT_FILE")"
runtime_log "MySQL 설정 = 성공 ($OUTPUT_FILE)"
