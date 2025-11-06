#!/bin/bash

# calculate_mpm_config.sh
# 시스템 자원과 서비스 프로필을 기반으로 Apache MPM 설정을 계산합니다.

BASE_DIR="${BASE_DIR:-/usr/local/src/iteasy_tuning}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$BASE_DIR/scripts}"
source "$SCRIPTS_DIR/common.sh"
source "$SCRIPTS_DIR/lib/kv_parser.sh"

SERVICE_LOG_PATH="$SERVICE_LOG"
SYSTEM_LOG_PATH="$SYSTEM_LOG"
OUTPUT_FILE="$TMP_CONF_DIR/apache_tuning.conf"

mkdir -p "$TMP_CONF_DIR" 2>/dev/null || {
    log_error "TMP_CONF_DIR를 생성하지 못했습니다" "apache" "$(json_kv path "$TMP_CONF_DIR")"
    exit 1
}

if [ ! -f "$SERVICE_LOG_PATH" ] || [ ! -f "$SYSTEM_LOG_PATH" ]; then
    log_warn "필수 로그 파일이 없어 Apache 설정 계산을 건너뜁니다" "apache"
    runtime_log "Apache 설정 = 건너뜀"
    exit 0
fi

APACHE_RUNNING=$(kv_get_value "$SERVICE_LOG_PATH" "APACHE_RUNNING")
if [ "$APACHE_RUNNING" != "1" ]; then
    log_info "Apache 서비스가 실행 중이 아니어서 설정 계산을 건너뜁니다" "apache"
    runtime_log "Apache 설정 = 건너뜀"
    exit 0
fi

APACHE_MPM=$(kv_get_value "$SERVICE_LOG_PATH" "APACHE_MPM")
APACHE_MPM=${APACHE_MPM:-prefork}
APACHE_CONFIG=$(kv_get_value "$SERVICE_LOG_PATH" "APACHE_CONFIG")
APACHE_CONFIG=${APACHE_CONFIG:-/etc/httpd/conf/httpd.conf}

TOTAL_MEMORY=$(kv_get_value "$SYSTEM_LOG_PATH" "TOTAL_MEMORY")
TOTAL_MEMORY=${TOTAL_MEMORY:-2048}
CPU_CORES=$(kv_get_value "$SYSTEM_LOG_PATH" "CPU_CORES")
CPU_CORES=${CPU_CORES:-2}

get_ratio() {
    case "$1" in
        web) echo 70 ;;
        web_was) echo 55 ;;
        web_db) echo 35 ;;
        web_was_db) echo 25 ;;
        was_db) echo 15 ;;
        db) echo 0 ;;
        *) echo 30 ;;
    esac
}

ratio=$(get_ratio "${ITEASY_SERVICE_PROFILE:-web_db}")
target_memory=$(( TOTAL_MEMORY * ratio / 100 ))
[ "$target_memory" -lt 512 ] && target_memory=512

prefork_config() {
    local memory_mb="$1" cores="$2"
    local max_workers=$(( memory_mb / 60 ))
    [ "$max_workers" -lt 50 ] && max_workers=50
    [ "$max_workers" -gt 8000 ] && max_workers=8000

    local start_servers=$(( cores * 2 ))
    [ "$start_servers" -lt 5 ] && start_servers=5
    [ "$start_servers" -gt 20 ] && start_servers=20

    local min_spare=$(( cores * 2 ))
    [ "$min_spare" -lt 5 ] && min_spare=5
    [ "$min_spare" -gt 50 ] && min_spare=50

    local max_spare=$(( min_spare * 2 ))
    [ "$max_spare" -lt 10 ] && max_spare=10
    [ "$max_spare" -gt 200 ] && max_spare=200

    cat > "$OUTPUT_FILE" <<EOF
<IfModule mpm_prefork_module>
    StartServers          $start_servers
    MinSpareServers       $min_spare
    MaxSpareServers       $max_spare
    MaxRequestWorkers     $max_workers
    MaxConnectionsPerChild 10000
</IfModule>
EOF
}

worker_config() {
    local memory_mb="$1" cores="$2"
    local max_workers=$(( memory_mb / 4 ))
    [ "$max_workers" -lt 300 ] && max_workers=300
    [ "$max_workers" -gt 10000 ] && max_workers=10000

    local threads_per_child=$(( cores * 4 ))
    [ "$threads_per_child" -lt 16 ] && threads_per_child=16
    [ "$threads_per_child" -gt 64 ] && threads_per_child=64

    local server_limit=$(( (max_workers + threads_per_child - 1) / threads_per_child ))
    [ "$server_limit" -lt 2 ] && server_limit=2

    local min_spare_threads=$(( threads_per_child / 2 ))
    [ "$min_spare_threads" -lt 16 ] && min_spare_threads=16
    local max_spare_threads=$(( min_spare_threads * 2 ))
    [ "$max_spare_threads" -gt 256 ] && max_spare_threads=256

    cat > "$OUTPUT_FILE" <<EOF
<IfModule mpm_${APACHE_MPM}_module>
    StartServers             4
    MinSpareThreads          $min_spare_threads
    MaxSpareThreads          $max_spare_threads
    ThreadsPerChild          $threads_per_child
    ServerLimit              $server_limit
    MaxRequestWorkers        $max_workers
    MaxConnectionsPerChild   10000
</IfModule>
EOF
}

case "$APACHE_MPM" in
    prefork|event_prefork)
        prefork_config "$target_memory" "$CPU_CORES"
        ;;
    worker|event)
        worker_config "$target_memory" "$CPU_CORES"
        ;;
    *)
        prefork_config "$target_memory" "$CPU_CORES"
        ;;
esac

chmod 600 "$OUTPUT_FILE" 2>/dev/null || true
log_info "Apache 튜닝 설정을 생성했습니다" "apache" "$(json_two mpm "$APACHE_MPM" output "$OUTPUT_FILE")"
runtime_log "Apache 설정 = 성공 ($OUTPUT_FILE)"
