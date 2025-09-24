#!/bin/bash
# calculate_php_fpm_config.sh (fixed)
# PHP-FPM 설정 계산 및 php_fpm_config.conf 생성
# - pm 모드 dynamic 기본
# - 접미사/비접미사 변수 폴백 지원
# - 소수 퍼센트 산술은 awk로 처리

set -euo pipefail

# 공통 함수 로드
BASE_DIR="/usr/local/src/iteasy_tuning"
SCRIPTS_DIR="$BASE_DIR/scripts"
LOG_DIR="$BASE_DIR/logs"
OUT_DIR="$BASE_DIR/tmp_conf"

if [ ! -f "$SCRIPTS_DIR/common.sh" ]; then
  echo "오류: 공통 스크립트($SCRIPTS_DIR/common.sh)가 존재하지 않습니다." >&2
  exit 1
fi
source "$SCRIPTS_DIR/common.sh"

log_debug "calculate_php_fpm_config.sh 시작 (fixed)"

# ----- system_specs 로드 -----
SYS_SPEC="$LOG_DIR/system_specs.log"
if [ ! -f "$SYS_SPEC" ]; then
  log_debug "system_specs.log 파일 없음"
  exit 1
fi
# TOTAL_MEMORY, CPU_CORES만 안전 추출
source <(grep -E '^(TOTAL_MEMORY|CPU_CORES)=' "$SYS_SPEC") 2>/dev/null || true
TOTAL_MEMORY=$(echo "${TOTAL_MEMORY:-1024}" | grep -o '[0-9]\+' || echo "1024")
CPU_CORES=$(echo "${CPU_CORES:-1}" | grep -o '[0-9]\+' || echo "1")
[ -z "$TOTAL_MEMORY" ] && TOTAL_MEMORY=1024
[ -z "$CPU_CORES" ] && CPU_CORES=1
log_debug "시스템 스펙: TOTAL_MEMORY=${TOTAL_MEMORY}MB, CPU_CORES=${CPU_CORES}"

# ----- service_paths 로드(접미사/비접미사 폴백) -----
SP="$LOG_DIR/service_paths.log"
if [ ! -f "$SP" ]; then
  log_debug "service_paths.log 파일 없음"
  exit 1
fi

# 비접미사 우선
PHP_FPM_RUNNING=$(grep -E '^PHP_FPM_RUNNING=' "$SP" | cut -d= -f2 | head -1 || echo "")
MYSQL_RUNNING=$(grep -E '^MYSQL_RUNNING=' "$SP" | cut -d= -f2 | head -1 || echo "")
MARIADB_RUNNING=$(grep -E '^MARIADB_RUNNING=' "$SP" | cut -d= -f2 | head -1 || echo "")
TOMCAT_RUNNING_BARE=$(grep -E '^TOMCAT_RUNNING=' "$SP" | cut -d= -f2 | head -1 || echo "")

# 접미사 폴백
if [ "${PHP_FPM_RUNNING:-}" != "1" ]; then
  grep -q '^PHP_FPM_RUNNING_1=1' "$SP" 2>/dev/null && PHP_FPM_RUNNING=1
fi
if [ -z "${MYSQL_RUNNING:-}" ] || [ "$MYSQL_RUNNING" != "1" ]; then
  grep -q '^MYSQL_RUNNING_1=1' "$SP" 2>/dev/null && MYSQL_RUNNING=1
fi
if [ -z "${MARIADB_RUNNING:-}" ] || [ "$MARIADB_RUNNING" != "1" ]; then
  grep -q '^MARIADB_RUNNING_1=1' "$SP" 2>/dev/null && MARIADB_RUNNING=1
fi

# Tomcat 개수 집계(비접미사 + 접미사)
TOMCAT_COUNT=0
[ "${TOMCAT_RUNNING_BARE:-0}" = "1" ] && TOMCAT_COUNT=$((TOMCAT_COUNT + 1))
TOMCAT_SUFFIX_COUNT=$(grep -oE '^TOMCAT_RUNNING_[0-9]+=1' "$SP" | wc -l | awk '{print $1}')
TOMCAT_COUNT=$((TOMCAT_COUNT + TOMCAT_SUFFIX_COUNT))

# PHP-FPM 실행 확인
if [ "${PHP_FPM_RUNNING:-0}" -ne 1 ]; then
  log_debug "PHP-FPM이 실행 중이 아니므로 설정 생성 생략"
  echo "오류: PHP-FPM이 실행 중이 아니므로 설정을 생성할 수 없습니다." >&2
  exit 1
fi
DB_PRESENT=0
[ "${MYSQL_RUNNING:-0}" = "1" ] && DB_PRESENT=1
[ "${MARIADB_RUNNING:-0}" = "1" ] && DB_PRESENT=1

log_debug "서비스 상태: PHP_FPM_RUNNING=${PHP_FPM_RUNNING}, DB_PRESENT=${DB_PRESENT}, TOMCAT_COUNT=${TOMCAT_COUNT}"

# ----- PHP 버전 로드 -----
SV="$LOG_DIR/service_versions.log"
PHP_VERSION="7.0.0"
if [ -f "$SV" ]; then
  PV=$(grep -E '^PHP_FPM_VERSION=' "$SV" | cut -d= -f2 | head -1 || true)
  [ -n "${PV:-}" ] && PHP_VERSION="$PV"
fi
log_debug "PHP_VERSION=$PHP_VERSION"

# ----- 메모리 배분 (소수 퍼센트는 awk 사용) -----
# 케이스 우선순위: (WAS 포함 + DB) > (WAS 포함) > (DB만) > 단일 서비스 > 기타
# 퍼센트 표준: 단일=90, Web+DB=45, Web+WAS만=27, Web+WAS(2)+DB=18, Web+WAS(3)+DB=13.5, Web+WAS(4+)+DB=11.25
WEB_MEMORY_PERCENT="0"
if [ "$TOMCAT_COUNT" -ge 4 ] && [ "$DB_PRESENT" -eq 1 ]; then
  WEB_MEMORY_PERCENT="11.25"
elif [ "$TOMCAT_COUNT" -eq 3 ] && [ "$DB_PRESENT" -eq 1 ]; then
  WEB_MEMORY_PERCENT="13.5"
elif [ "$TOMCAT_COUNT" -eq 2 ] && [ "$DB_PRESENT" -eq 1 ]; then
  WEB_MEMORY_PERCENT="18"
elif [ "$TOMCAT_COUNT" -ge 1 ] && [ "$DB_PRESENT" -eq 0 ]; then
  WEB_MEMORY_PERCENT="27"
elif [ "$DB_PRESENT" -eq 1 ] && [ "$TOMCAT_COUNT" -eq 0 ]; then
  WEB_MEMORY_PERCENT="45"
elif [ "$DB_PRESENT" -eq 0 ] && [ "$TOMCAT_COUNT" -eq 0 ]; then
  # 단일(Web만) 판단은 어려우므로 PHP-FPM 단독 서비스로 간주
  WEB_MEMORY_PERCENT="90"
fi
# 안전 기본값
[ "$WEB_MEMORY_PERCENT" = "0" ] && WEB_MEMORY_PERCENT="27"

# 퍼센트 -> MB (정수)
PHP_FPM_MEMORY=$(awk -v total="$TOTAL_MEMORY" -v pct="$WEB_MEMORY_PERCENT" 'BEGIN{printf "%d", total*pct/100}')
[ "$PHP_FPM_MEMORY" -lt 256 ] && PHP_FPM_MEMORY=256
log_debug "PHP_FPM_MEMORY=${PHP_FPM_MEMORY}MB (WEB_MEMORY_PERCENT=${WEB_MEMORY_PERCENT}%)"

# ----- pm(dyn) 파라미터 계산 -----
PM_MODE="dynamic"
PROCESS_MEMORY=100   # MB/child 추정
MAX_CHILDREN=$(( PHP_FPM_MEMORY / PROCESS_MEMORY ))
[ "$MAX_CHILDREN" -lt 5 ] && MAX_CHILDREN=5

# 코어 대비 메모리 비율
CORE_MEMORY_RATIO=$(( TOTAL_MEMORY / CPU_CORES ))
if [ "$CORE_MEMORY_RATIO" -lt 512 ]; then
  START_SERVERS=$(( CPU_CORES * 2 ))
  [ "$START_SERVERS" -gt "$MAX_CHILDREN" ] && START_SERVERS=$MAX_CHILDREN
else
  START_SERVERS=$(( MAX_CHILDREN / 2 ))
  [ "$START_SERVERS" -lt 2 ] && START_SERVERS=2
fi

MIN_SPARE_SERVERS=$(( START_SERVERS / 2 ))
[ "$MIN_SPARE_SERVERS" -lt 1 ] && MIN_SPARE_SERVERS=1
[ "$MIN_SPARE_SERVERS" -gt "$MAX_CHILDREN" ] && MIN_SPARE_SERVERS=$MAX_CHILDREN

MAX_SPARE_SERVERS=$START_SERVERS
[ "$MAX_SPARE_SERVERS" -gt "$MAX_CHILDREN" ] && MAX_SPARE_SERVERS=$MAX_CHILDREN

MAX_REQUESTS=500

log_debug "계산 결과: MAX_CHILDREN=$MAX_CHILDREN, START_SERVERS=$START_SERVERS, MIN_SPARE_SERVERS=$MIN_SPARE_SERVERS, MAX_SPARE_SERVERS=$MAX_SPARE_SERVERS, MAX_REQUESTS=$MAX_REQUESTS"

# 일관성 검증
if [ "$MIN_SPARE_SERVERS" -gt "$MAX_CHILDREN" ] || [ "$MAX_SPARE_SERVERS" -gt "$MAX_CHILDREN" ]; then
  log_debug "오류: pm.min/max_spare_servers가 pm.max_children보다 큼"
  echo "오류: PHP-FPM 설정 값이 잘못되었습니다." >&2
  exit 1
fi

# ----- 출력 -----
mkdir -p "$OUT_DIR" || { log_debug "tmp_conf 디렉터리 생성 실패"; echo "오류: 출력 디렉터리 생성 실패" >&2; exit 1; }
cat > "$OUT_DIR/php_fpm_config.conf" << EOF
pm = $PM_MODE
pm.max_children = $MAX_CHILDREN
pm.start_servers = $START_SERVERS
pm.min_spare_servers = $MIN_SPARE_SERVERS
pm.max_spare_servers = $MAX_SPARE_SERVERS
pm.max_requests = $MAX_REQUESTS

# static 모드 (주석 풀어 사용, dynamic 주석 처리)
# pm = static
# pm.max_children = $MAX_CHILDREN
# pm.max_requests = $MAX_REQUESTS

# on-demand 모드 (주석 풀어 사용, dynamic 주석 처리)
# pm = ondemand
# pm.max_children = $MAX_CHILDREN
# pm.process_idle_timeout = 10s
# pm.max_requests = $MAX_REQUESTS
EOF

log_debug "php_fpm_config.conf 생성 완료: $OUT_DIR/php_fpm_config.conf"
echo "PHP_FPM_CONFIG=success" >> "$LOG_DIR/tuning_status.log"
echo "PHP-FPM 설정이 $OUT_DIR/php_fpm_config.conf에 저장되었습니다."