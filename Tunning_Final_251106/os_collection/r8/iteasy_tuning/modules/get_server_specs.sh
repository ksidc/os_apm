#!/bin/bash

# get_server_specs.sh
# 서버 자원(메모리, CPU 코어, 디스크 여유 공간)을 수집합니다.

BASE_DIR="${BASE_DIR:-/usr/local/src/iteasy_tuning}"
source "$BASE_DIR/scripts/common.sh"

TOTAL_MEMORY=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null)
CPU_CORES=$(nproc 2>/dev/null)
DISK_SPACE=$(df -Pk / 2>/dev/null | awk 'NR==2 {printf "%d", $4/1024}')

TOTAL_MEMORY=${TOTAL_MEMORY:-0}
CPU_CORES=${CPU_CORES:-0}
DISK_SPACE=${DISK_SPACE:-0}

cat <<EOF > "$SYSTEM_LOG"
TOTAL_MEMORY=$TOTAL_MEMORY
CPU_CORES=$CPU_CORES
DISK_SPACE=$DISK_SPACE
EOF
chmod 600 "$SYSTEM_LOG" 2>/dev/null || true

log_info "시스템 자원을 수집했습니다" "specs" "$(json_two memory_mb "$TOTAL_MEMORY" cpu "$CPU_CORES")"
log_info "디스크 여유 공간" "specs" "$(json_kv disk_mb "$DISK_SPACE")"
