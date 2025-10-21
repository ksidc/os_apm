#!/usr/bin/env bash
# gen_mysql_conf_myisam_auto.sh
# MyISAM 중심 자동 튜닝 (메모리 기반 항목만 재계산, 코어 기반/환경 항목은 유지)
# 주석: # MyISAM 성능 최적화 (메모리 기반)

set -euo pipefail

BASE_DIR="/usr/local/src/iteasy_tuning"
SRC_CONF="${BASE_DIR}/tmp_conf/mysql_config.conf"
DST_CONF="${BASE_DIR}/tmp_conf/mysql_config_myisam.conf"
SERVICE_PATHS="${BASE_DIR}/logs/service_paths.log"
MYSQL_MEM="${BASE_DIR}/logs/mysql_mem.log"

err(){ echo "[ERROR] $*" >&2; exit 1; }
now(){ date +%Y%m%d_%H%M%S; }

[[ -f "$SRC_CONF" ]] || err "$SRC_CONF not found"
[[ -f "$SERVICE_PATHS" ]] || err "$SERVICE_PATHS not found"
[[ -f "$MYSQL_MEM" ]] || err "$MYSQL_MEM not found"

# --- 1. 실제 conf 경로 가져오기 ---
MYSQL_CONF=$(grep -E '^MYSQL_CONF=' "$SERVICE_PATHS" | cut -d= -f2- | tr -d '"' | xargs || true)
MARIADB_CONF=$(grep -E '^MARIADB_CONF=' "$SERVICE_PATHS" | cut -d= -f2- | tr -d '"' | xargs || true)

if [[ -n "$MYSQL_CONF" ]]; then
  TARGET_CONF="$MYSQL_CONF"
elif [[ -n "$MARIADB_CONF" ]]; then
  TARGET_CONF="$MARIADB_CONF"
else
  err "MYSQL_CONF or MARIADB_CONF not found in $SERVICE_PATHS"
fi

mkdir -p "$(dirname "$DST_CONF")"
mkdir -p "$(dirname "$TARGET_CONF")"

# --- 2. 메모리 정보 읽기 ---
DB_TOTAL_MEM_MB=$(grep -E '^DB_TOTAL_MEM_MB=' "$MYSQL_MEM" | cut -d= -f2 | tr -d '[:space:]')
DB_MEM_PCT=$(grep -E '^DB_MEM_PCT=' "$MYSQL_MEM" | cut -d= -f2 | tr -d '[:space:]')
[[ -n "$DB_TOTAL_MEM_MB" && -n "$DB_MEM_PCT" ]] || err "Invalid mysql_mem.log"
AVAIL_MB=$(( DB_TOTAL_MEM_MB * DB_MEM_PCT / 100 ))
(( AVAIL_MB > 0 )) || err "Computed available memory = 0MB"

# --- 3. 메모리 기반 값 계산 ---
KEYBUF_MB=$(( AVAIL_MB * 30 / 100 ))
(( KEYBUF_MB < 256 ))  && KEYBUF_MB=256
(( KEYBUF_MB > 4096 )) && KEYBUF_MB=4096

if   (( AVAIL_MB < 2048 )); then MYISAM_SORT_MB=256; BULK_INS_MB=64
elif (( AVAIL_MB < 8192 )); then MYISAM_SORT_MB=512; BULK_INS_MB=128
else                            MYISAM_SORT_MB=1024; BULK_INS_MB=256
fi

TMP_MB=$(( AVAIL_MB / 10 ))
(( TMP_MB < 128 )) && TMP_MB=128
(( TMP_MB > 256 )) && TMP_MB=256

INNODB_BP_MB=$(( AVAIL_MB / 10 ))
(( INNODB_BP_MB < 128 )) && INNODB_BP_MB=128
(( INNODB_BP_MB > 512 )) && INNODB_BP_MB=512

INNODB_LOG_MB=$(( INNODB_BP_MB / 2 ))
(( INNODB_LOG_MB < 64 )) && INNODB_LOG_MB=64
(( INNODB_LOG_MB > 256 )) && INNODB_LOG_MB=256
INNODB_LOG_FILES=2

# --- 5. 새로운 conf 생성 ---
awk -v keybuf="${KEYBUF_MB}" \
    -v myisamsort="${MYISAM_SORT_MB}" \
    -v bulkins="${BULK_INS_MB}" \
    -v tmpm="${TMP_MB}" \
    -v innodb_bp="${INNODB_BP_MB}" \
    -v innodb_log="${INNODB_LOG_MB}" \
    -v innodb_logs="${INNODB_LOG_FILES}" '
BEGIN { IGNORECASE=1 }

/^#/ {
  if ($0 ~ /MyISAM 최소화/) next;  # 기존 MyISAM 최소화 주석은 삭제
  print; next
}
/skip-innodb/ || /^innodb=off/ { next }

# --- 메모리 기반 항목 재계산 ---
/key_buffer_size/ {
  print "# MyISAM 성능 최적화 (메모리 기반)"
  print "key_buffer_size=" keybuf "M"; next
}
/myisam_sort_buffer_size/     { print "myisam_sort_buffer_size=" myisamsort "M"; next }
/bulk_insert_buffer_size/     { print "bulk_insert_buffer_size=" bulkins "M"; next }
/tmp_table_size/              { print "tmp_table_size=" tmpm "M"; next }
/max_heap_table_size/         { print "max_heap_table_size=" tmpm "M"; next }
/innodb_buffer_pool_size/     { print "innodb_buffer_pool_size=" innodb_bp "M"; next }
/innodb_log_file_size/        { print "innodb_log_file_size=" innodb_log "M"; next }
/innodb_log_files_in_group/   { print "innodb_log_files_in_group=" innodb_logs; next }

# --- 나머지는 그대로 유지 ---
{ print }
' "$SRC_CONF" > "$DST_CONF"

# --- 6. 실제 설정 파일로 반영 ---
cp -f "$DST_CONF" "$TARGET_CONF"

echo "[OK] MyISAM conf 생성 완료: $DST_CONF"
echo "[OK] 실제 적용: $TARGET_CONF"
echo "     key_buffer_size=${KEYBUF_MB}M, myisam_sort_buffer_size=${MYISAM_SORT_MB}M, tmp_table_size=${TMP_MB}M, innodb_buffer_pool_size=${INNODB_BP_MB}M"

