#!/bin/bash

# calculate_mysql_config.sh
# MySQL 메모리 및 설정 계산
# → logs/mysql_mem.log 생성
# → tmp_conf/mysql_config.conf 생성
#   1) 버전별 헤더 (mysql_5.5.sh 등에서 수집)
#   2) innodb_buffer_pool_size (메모리 분배)
#   3) CPU 코어별 설정

set -euo pipefail

# 0) 환경 설정
BASE_DIR="/usr/local/src/iteasy_tuning"
COMMON="$BASE_DIR/scripts/common.sh"
LOG_DIR="$BASE_DIR/logs"
TMP_CONF_DIR="$BASE_DIR/tmp_conf"
MODULE_DIR="$BASE_DIR/modules"
MYSQL_SCRIPT_DIR="$MODULE_DIR/mysql_script"

# 1) 공통 함수 로드
if [ ! -f "$COMMON" ]; then
  echo "오류: 공통 스크립트($COMMON) 없음" >&2
  exit 1
fi
source "$COMMON"
log_debug "calculate_mysql_config.sh 시작"

# 2) 시스템 스펙 로드
SYS_SPEC="$LOG_DIR/system_specs.log"
if [ ! -f "$SYS_SPEC" ]; then
  log_debug "system_specs.log 없음"
  exit 1
fi
source <(grep -E '^(CPU_CORES|MEM_TOTAL_MB|TOTAL_MEMORY)=' "$SYS_SPEC")
if [ -z "${MEM_TOTAL_MB:-}" ] && [ -n "${TOTAL_MEMORY:-}" ]; then
  MEM_TOTAL_MB="$TOTAL_MEMORY"
fi
log_debug "SYSTEM_SPECS: CPU_CORES=${CPU_CORES}, MEM_TOTAL_MB=${MEM_TOTAL_MB}MB"

# 3) 서비스 상태 로드 (source 대신 grep으로 변수 추출 - 오류 우회)
SP="$LOG_DIR/service_paths.log"
if [ ! -f "$SP" ]; then
  log_debug "service_paths.log 없음"
  exit 1
fi
APACHE_RUNNING=$(grep '^APACHE_RUNNING=' "$SP" | cut -d= -f2 || echo 0)
NGINX_RUNNING=$(grep '^NGINX_RUNNING=' "$SP" | cut -d= -f2 || echo 0)
MYSQL_RUNNING=$(grep '^MYSQL_RUNNING=' "$SP" | cut -d= -f2 || echo 0)
MARIADB_RUNNING=$(grep '^MARIADB_RUNNING=' "$SP" | cut -d= -f2 || echo 0)
log_debug "서비스 상태: APACHE=$APACHE_RUNNING, NGINX=$NGINX_RUNNING, MYSQL=$MYSQL_RUNNING, MARIADB=$MARIADB_RUNNING"

WEB_PRESENT=0
[ "${APACHE_RUNNING:-0}" -eq 1 ] && WEB_PRESENT=1
[ "${NGINX_RUNNING:-0}" -eq 1 ] && WEB_PRESENT=1

WAS_COUNT=0
for i in 1 2 3 4; do
  TOMCAT_VAR="TOMCAT_RUNNING_${i}"
  TOMCAT_RUN=$(grep "^${TOMCAT_VAR}=" "$SP" | cut -d= -f2 || echo 0)
  [ "$TOMCAT_RUN" -eq 1 ] && WAS_COUNT=$((WAS_COUNT+1))
done

DB_PRESENT=0
[ "${MYSQL_RUNNING:-0}" -eq 1 ] && DB_PRESENT=1
[ "${MARIADB_RUNNING:-0}" -eq 1 ] && DB_PRESENT=1

log_debug "서비스 감지 → WEB_PRESENT=${WEB_PRESENT}, WAS_COUNT=${WAS_COUNT}, DB_PRESENT=${DB_PRESENT}"

# 4) DB 메모리 분배
DB_MEM=""
DB_PCT=""
if [ "$DB_PRESENT" -eq 1 ]; then
  TOTAL=$MEM_TOTAL_MB
  # 기준 비율 (≥31GB→90%, 그 외→80%)
  if [ "$TOTAL" -ge 31744 ]; then BASE_PCT=90; else BASE_PCT=80; fi
  ALLOC=$(( TOTAL * BASE_PCT / 100 ))

  # 분배 비율 결정
  if [ "$WEB_PRESENT" -eq 0 ] && [ "$WAS_COUNT" -eq 0 ]; then
    DB_PCT=90
  else
    case "${WEB_PRESENT}_${WAS_COUNT}_1" in
      1_0_1) DB_PCT=45    ;;
      1_2_1) DB_PCT=36    ;;
      1_3_1) DB_PCT=50    ;;
      1_4_1) DB_PCT=56    ;;
      *)     DB_PCT=0     ;;
    esac
  fi
  DB_MEM=$(( ALLOC * DB_PCT / 100 ))
  [ "$DB_MEM" -lt 256 ] && DB_MEM=256

  # mysql_mem.log 초기화 및 기록
  if [ -f "$LOG_DIR/mysql_mem.log" ]; then
    mv "$LOG_DIR/mysql_mem.log" "$LOG_DIR/mysql_mem.log.bak" 2>/dev/null
  fi
  {
    echo "DB_TOTAL_MEM_MB=${DB_MEM}"
    echo "DB_MEM_PCT=${DB_PCT}"
  } > "$LOG_DIR/mysql_mem.log"
  chmod 600 "$LOG_DIR/mysql_mem.log" 2>/dev/null
  log_debug "mysql_mem.log 작성: DB_TOTAL_MEM_MB=${DB_MEM}, DB_MEM_PCT=${DB_PCT}%"
else
  log_debug "DB 미감지 — mysql_mem.log 생성 생략"
fi

# 5) 버전별 스크립트 실행 및 헤더 수집
SV="$LOG_DIR/service_versions.log"
VERSION_HEADER=""
if [ -f "$SV" ]; then
  MYSQL_VERSION=$(grep -E '^MYSQL_VERSION=' "$SV" | cut -d= -f2)
  log_debug "Detected MYSQL_VERSION: $MYSQL_VERSION"
  MYSQL_MAJOR_MINOR=$(echo "$MYSQL_VERSION" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')
  case "$MYSQL_MAJOR_MINOR" in
    5.5) SCRIPT="$MYSQL_SCRIPT_DIR/mysql_5.5.sh" ;;
    5.6|5.7) SCRIPT="$MYSQL_SCRIPT_DIR/mysql_5.6.sh" ;;
    5.8) SCRIPT="$MYSQL_SCRIPT_DIR/mysql_5.8.sh" ;;
    8.*)   SCRIPT="$MYSQL_SCRIPT_DIR/mysql_8.sh"   ;;
    10.*|11.*|12.*) SCRIPT="$MYSQL_SCRIPT_DIR/mariadb.sh" ;;  # MariaDB 10.x, 11.x, 12.x 추가
    *)     SCRIPT="" ;;
  esac
  log_debug "Selected SCRIPT: $SCRIPT"
  if [ -n "$SCRIPT" ] && [ -x "$SCRIPT" ]; then
    # 버전별 스크립트 실행 후 출력 수집 (헤더로 사용)
    VERSION_HEADER="$("$SCRIPT" 2>/dev/null)"
    log_debug "버전별 스크립트 출력: $VERSION_HEADER"
  else
    log_debug "버전별 스크립트 없음 또는 실행 불가: $SCRIPT"
  fi
else
  log_debug "service_versions.log 없음 — 버전별 헤더 생략"
fi

# 6) tmp_conf/mysql_config.conf 생성
mkdir -p "$TMP_CONF_DIR" || { echo "오류: $TMP_CONF_DIR 생성 실패" >&2; log_debug "디렉터리 생성 실패"; exit 1; }
chmod 700 "$TMP_CONF_DIR" 2>/dev/null

# CPU 코어별 설정 값 계산
thread_cache_size=$(( CPU_CORES * 8 ));        [ $thread_cache_size -lt 64 ] && thread_cache_size=64
table_open_cache=$(( CPU_CORES * 256 ));       [ $table_open_cache -lt 2048 ] && table_open_cache=2048
table_definition_cache=$(( CPU_CORES * 128 )); [ $table_definition_cache -lt 1024 ] && table_definition_cache=1024
open_files_limit=$(( CPU_CORES * 1024 ));      [ $open_files_limit -lt 8192 ] && open_files_limit=8192
io_threads=$CPU_CORES;                         [ $CPU_CORES -gt 64 ] && io_threads=64

# my.cnf 대체 로직
OUT_FILE="$TMP_CONF_DIR/mysql_config.conf"
{
  # 1) 기본 [mysqld] 헤더 (VERSION_HEADER가 비어있을 경우 대체)
  if [ -z "$VERSION_HEADER" ]; then
    echo "[mysqld]"
    echo
  else
    echo "$VERSION_HEADER"
  fi

  # 3) CPU 코어별 설정 블록
  cat <<EOF
# CPU 코어별 설정 (${CPU_CORES}코어) ===================
# 스레드 및 테이블 캐시 
thread_cache_size           = ${thread_cache_size}
table_open_cache            = ${table_open_cache}
table_definition_cache      = ${table_definition_cache}
open_files_limit            = ${open_files_limit}

# InnoDB ${CPU_CORES}코어 CPU 최적화
innodb_read_io_threads      = ${io_threads}
innodb_write_io_threads     = ${io_threads}
innodb_thread_concurrency   = 0
# =====================================================
EOF
} > "$OUT_FILE"

log_debug "mysql_config.conf 생성: $TMP_CONF_DIR/mysql_config.conf"
log_debug "calculate_mysql_config.sh 완료"
