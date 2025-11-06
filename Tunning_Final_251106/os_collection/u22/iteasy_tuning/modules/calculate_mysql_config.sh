#!/bin/bash

# calculate_mysql_config.sh
# Produce a conservative MySQL/MariaDB tuning snippet for Ubuntu 24.x.

BASE_DIR="${BASE_DIR:-/usr/local/src/iteasy_tuning}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$BASE_DIR/scripts}"
source "$SCRIPTS_DIR/common.sh"
source "$SCRIPTS_DIR/lib/kv_parser.sh"

SERVICE_LOG_PATH="$SERVICE_LOG"
SYSTEM_LOG_PATH="$SYSTEM_LOG"
OUTPUT_FILE="$TMP_CONF_DIR/mysql_tuning.cnf"

mkdir -p "$TMP_CONF_DIR" 2>/dev/null || {
    log_error "TMP_CONF_DIR 생성 실패" "mysql" "$(json_kv path "$TMP_CONF_DIR")"
    exit 1
}

if [ ! -f "$SYSTEM_LOG_PATH" ]; then
    log_warn "시스템 정보 로그가 없어 기본값으로 MySQL 설정을 계산합니다" "mysql"
fi

if [ ! -f "$SERVICE_LOG_PATH" ]; then
    log_warn "서비스 경로 로그가 없어 기본값으로 MySQL 설정을 계산합니다" "mysql"
fi

TOTAL_MEMORY=$(kv_get_value "$SYSTEM_LOG_PATH" "TOTAL_MEMORY")
TOTAL_MEMORY=${TOTAL_MEMORY:-4096}
CPU_CORES=$(kv_get_value "$SYSTEM_LOG_PATH" "CPU_CORES")
CPU_CORES=${CPU_CORES:-2}

TARGET_PROFILE=${ITEASY_SERVICE_PROFILE:-web_db}

get_db_ratio() {
    case "$1" in
        web) echo 0 ;;
        web_was) echo 0 ;;
        web_db) echo 40 ;;
        web_was_db) echo 35 ;;
        was_db) echo 50 ;;
        db) echo 60 ;;
        *) echo 30 ;;
    esac
}

ratio=$(get_db_ratio "$TARGET_PROFILE")
target_memory=$(( TOTAL_MEMORY * ratio / 100 ))
[ "$target_memory" -lt 384 ] && target_memory=384
[ "$target_memory" -gt $((TOTAL_MEMORY - 256)) ] && target_memory=$((TOTAL_MEMORY - 256))

max_connections=$(( CPU_CORES * 80 ))
[ "$max_connections" -lt 200 ] && max_connections=200
[ "$max_connections" -gt 800 ] && max_connections=800

thread_cache_size=$(( CPU_CORES * 8 ))
[ "$thread_cache_size" -lt 32 ] && thread_cache_size=32
[ "$thread_cache_size" -gt 256 ] && thread_cache_size=256

table_open_cache=$(( CPU_CORES * 200 ))
[ "$table_open_cache" -lt 800 ] && table_open_cache=800
[ "$table_open_cache" -gt 4000 ] && table_open_cache=4000

tmp_table_size=64
[ "$target_memory" -gt 6144 ] && tmp_table_size=96

innodb_buffer=$(( target_memory * 55 / 100 ))
[ "$innodb_buffer" -lt 256 ] && innodb_buffer=256
[ "$innodb_buffer" -gt 2048 ] && innodb_buffer=2048

innodb_instances=$(( innodb_buffer / 512 ))
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
innodb_flush_log_at_trx_commit = 2
innodb_flush_method     = O_DIRECT
innodb_file_per_table   = 1
key_buffer_size         = 64M
EOF

chmod 600 "$OUTPUT_FILE" 2>/dev/null || true
log_info "MySQL/MariaDB 튜닝 파일을 생성했습니다" "mysql" "$(json_two memory_mb "$target_memory" output "$OUTPUT_FILE")"
