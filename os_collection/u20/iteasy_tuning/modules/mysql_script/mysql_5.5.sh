#!/bin/bash
# mysql_5.5.sh (개선: 세션 버퍼 K단위 floor 적용, 0M 방지, net_buffer_length 기본값 복원, key_buffer_size cap 완화)

BASE_DIR="/usr/local/src/iteasy_tuning"
COMMON="$BASE_DIR/scripts/common.sh"
[ -f "$COMMON" ] || { echo "오류: 공통 스크립트($COMMON) 없음" >&2; exit 1; }
source "$COMMON"

LOG_DIR="$BASE_DIR/logs"

function parse_cnf_files() {
    local files=("$@")
    local datadir="" socket="" pid_file="" log_error=""
    for conf_file in "${files[@]}"; do
        if [ -f "$conf_file" ]; then
            while IFS= read -r line; do
                [[ "$line" =~ ^\s*# ]] && continue
                [[ "$line" =~ ^\s*$ ]] && continue
                if [[ "$line" =~ ^datadir[[:space:]]*=[[:space:]]*(.+) ]]; then datadir="${BASH_REMATCH[1]}"; fi
                if [[ "$line" =~ ^socket[[:space:]]*=[[:space:]]*(.+) ]]; then socket="${BASH_REMATCH[1]}"; fi
                if [[ "$line" =~ ^pid-file[[:space:]]*=[[:space:]]*(.+) ]]; then pid_file="${BASH_REMATCH[1]}"; fi
                if [[ "$line" =~ ^log-error[[:space:]]*=[[:space:]]*(.+) ]]; then log_error="${BASH_REMATCH[1]}"; fi
            done < "$conf_file"
            if [ -n "$datadir" ] || [ -n "$socket" ] || [ -n "$pid_file" ] || [ -n "$log_error" ]; then break; fi
        fi
    done
    if [ -z "$datadir" ]; then datadir="/var/lib/mysql"; fi
    if [ -z "$socket" ]; then socket="/var/lib/mysql/mysql.sock"; fi
    if [ -z "$pid_file" ]; then
        if [ ! -d "/var/run/mysqld/" ]; then
            mkdir -p "/var/run/mysqld/"
            if id mysql >/dev/null 2>&1; then chown mysql:mysql "/var/run/mysqld/"; chmod 755 "/var/run/mysqld/"; fi
        fi
        pid_file="/var/run/mysqld/mysql.pid"
    fi
    if [ -z "$log_error" ]; then
        if [ ! -d "/var/log/mysql" ]; then
            mkdir -p "/var/log/mysql"
            if id mysql >/dev/null 2>&1; then chown mysql:mysql "/var/log/mysql"; chmod 755 "/var/log/mysql"; fi
        fi
        log_error="/var/log/mysql/mysql.log"
    fi
    echo "$datadir $socket $pid_file $log_error"
}

SP="$LOG_DIR/service_paths.log"
[ -f "$SP" ] || { echo "오류: service_paths.log 없음" >&2; exit 1; }
MYSQL_CONF_FILES=($(grep '^MYSQL_CONF=' "$SP" | cut -d= -f2- | tr '\n' ' '))

read DATADIR SOCKET PID_FILE LOG_ERROR < <(parse_cnf_files "${MYSQL_CONF_FILES[@]}")

MEM_LOG="$LOG_DIR/mysql_mem.log"
[ -f "$MEM_LOG" ] || { echo "ERROR: $MEM_LOG not found." >&2; exit 1; }
DB_TOTAL_MEM_MB=$(grep '^DB_TOTAL_MEM_MB=' "$MEM_LOG" | cut -d'=' -f2)
[[ "$DB_TOTAL_MEM_MB" =~ ^[0-9]+$ ]] || { echo "ERROR: Invalid DB_TOTAL_MEM_MB: $DB_TOTAL_MEM_MB" >&2; exit 1; }

if   [ "$DB_TOTAL_MEM_MB" -le 4096 ]; then MAX_CONN=256
elif [ "$DB_TOTAL_MEM_MB" -le 8192 ]; then MAX_CONN=512
else MAX_CONN=1024
fi

INNODB_BUFFER_POOL_SIZE=$(( DB_TOTAL_MEM_MB * 60 / 100 ))M
[ "${INNODB_BUFFER_POOL_SIZE%M}" -lt 1024 ] && INNODB_BUFFER_POOL_SIZE=1024M

INNODB_BUFFER_POOL_INSTANCES=$(( DB_TOTAL_MEM_MB / 4096 ))
[ "$INNODB_BUFFER_POOL_INSTANCES" -lt 1 ] && INNODB_BUFFER_POOL_INSTANCES=1
[ "$INNODB_BUFFER_POOL_INSTANCES" -gt 8 ] && INNODB_BUFFER_POOL_INSTANCES=8

INNODB_LOG_BUFFER_SIZE=$(( DB_TOTAL_MEM_MB / 100 ))M
[ "${INNODB_LOG_BUFFER_SIZE%M}" -lt 8 ] && INNODB_LOG_BUFFER_SIZE=8M
[ "${INNODB_LOG_BUFFER_SIZE%M}" -gt 64 ] && INNODB_LOG_BUFFER_SIZE=64M

QUERY_CACHE_SIZE=$(( DB_TOTAL_MEM_MB * 2 / 100 ))M
[ "${QUERY_CACHE_SIZE%M}" -gt 128 ] && QUERY_CACHE_SIZE=128M
QUERY_CACHE_LIMIT=$(( DB_TOTAL_MEM_MB / 1024 ))M
[ "${QUERY_CACHE_LIMIT%M}" -lt 1 ] && QUERY_CACHE_LIMIT=1M
[ "${QUERY_CACHE_LIMIT%M}" -gt 8 ] && QUERY_CACHE_LIMIT=8M

TMP_TABLE_SIZE=$(( DB_TOTAL_MEM_MB * 5 / 100 ))M
[ "${TMP_TABLE_SIZE%M}" -lt 32 ] && TMP_TABLE_SIZE=32M
[ "${TMP_TABLE_SIZE%M}" -gt 256 ] && TMP_TABLE_SIZE=256M
MAX_HEAP_TABLE_SIZE=$TMP_TABLE_SIZE

KEY_BUFFER_SIZE=$(( DB_TOTAL_MEM_MB * 5 / 100 ))M
[ "${KEY_BUFFER_SIZE%M}" -lt 8 ] && KEY_BUFFER_SIZE=8M
[ "${KEY_BUFFER_SIZE%M}" -gt 64 ] && KEY_BUFFER_SIZE=64M   # cap 완화(미사용 가정)

# ---- 세션 버퍼 계산: floor 및 K단위 지원 ----
calc_session_buf() {
  local baseMB="$1" scale="$2" floorKiB="$3"
  local mb=$(awk "BEGIN {x=$baseMB * $scale; print int(x)}")
  local kib=$(( mb * 1024 ))
  [ "$kib" -lt "$floorKiB" ] && kib="$floorKiB"
  if [ $((kib % 1024)) -eq 0 ]; then echo "$((kib/1024))M"; else echo "${kib}K"; fi
}

SCALE_FACTOR=$(awk "BEGIN {print 256 / $MAX_CONN}")
awk "BEGIN {exit !( $SCALE_FACTOR < 0.5 ) }" && SCALE_FACTOR=0.5

FLOOR_SORT_KIB=256   # 256K
FLOOR_JOIN_KIB=256   # 256K
FLOOR_READ_KIB=128   # 128K
FLOOR_RND_KIB=256    # 256K

BASE_SORT_MB=2; BASE_JOIN_MB=2; BASE_READ_MB=1; BASE_RND_MB=1

SORT_BUFFER_SIZE=$(calc_session_buf "$BASE_SORT_MB" "$SCALE_FACTOR" "$FLOOR_SORT_KIB")
JOIN_BUFFER_SIZE=$(calc_session_buf "$BASE_JOIN_MB" "$SCALE_FACTOR" "$FLOOR_JOIN_KIB")
READ_BUFFER_SIZE=$(calc_session_buf "$BASE_READ_MB" "$SCALE_FACTOR" "$FLOOR_READ_KIB")
READ_RND_BUFFER_SIZE=$(calc_session_buf "$BASE_RND_MB" "$SCALE_FACTOR" "$FLOOR_RND_KIB")

cat <<EOF
[mysqld]
port = 3306
datadir = $DATADIR
socket = $SOCKET
pid-file = $PID_FILE
log-error = $LOG_ERROR

default-storage-engine = innodb
character-set-server = utf8
skip-name-resolve = 1

max_connections = ${MAX_CONN}
max_connect_errors = 1000
connect_timeout = 10
wait_timeout = 28800
interactive_timeout = 28800

innodb_buffer_pool_size = ${INNODB_BUFFER_POOL_SIZE}
innodb_buffer_pool_instances = ${INNODB_BUFFER_POOL_INSTANCES}
innodb_log_file_size = 256M
innodb_log_buffer_size = ${INNODB_LOG_BUFFER_SIZE}
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
innodb_file_per_table = 1
innodb_io_capacity = 1000
innodb_lock_wait_timeout = 50
innodb_open_files = 1024
innodb_autoextend_increment = 64

key_buffer_size = ${KEY_BUFFER_SIZE}
myisam_sort_buffer_size = 8M
myisam_max_sort_file_size = 2G

# 세션별 버퍼 (floor 적용: 0M 방지)
sort_buffer_size = ${SORT_BUFFER_SIZE}
join_buffer_size = ${JOIN_BUFFER_SIZE}
read_buffer_size = ${READ_BUFFER_SIZE}
read_rnd_buffer_size = ${READ_RND_BUFFER_SIZE}
tmp_table_size = ${MAX_HEAP_TABLE_SIZE}
max_heap_table_size = ${MAX_HEAP_TABLE_SIZE}

thread_stack = 256K

max_allowed_packet = 64M
net_buffer_length = 16K
net_read_timeout = 30
net_write_timeout = 60

slow-query-log = 1
slow-query-log-file = /var/log/mysql/slow.log
long_query_time = 3
log-queries-not-using-indexes = 1

local-infile = 0

EOF

