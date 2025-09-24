#!/bin/bash
# calculate_mpm_config.sh
# - Apache MPM 설정 자동 계산 후 tmp_conf/mpm_config_<index>.conf 생성
# - running=1(실행 중)인 인스턴스만 대상으로 계산
# - 인스턴스가 1개여도(>=1) 반드시 생성
# - 비교식/산술 안정화(기본값 보정, 0 나누기 방지)

set -u

BASE_DIR="/usr/local/src/iteasy_tuning"
SCRIPTS_DIR="$BASE_DIR/scripts"

# 공용 함수 로드
if [ -f "$SCRIPTS_DIR/common.sh" ]; then
  # shellcheck disable=SC1090
  source "$SCRIPTS_DIR/common.sh"
else
  # fallback logger
  log_debug() { echo "[DEBUG] $*"; }
fi

log_debug "calculate_mpm_config.sh 시작"

# 로그 경로
SERVICE_LOG="$BASE_DIR/logs/service_paths.log"
SPECS_LOG="$BASE_DIR/logs/system_specs.log"
VERSIONS_LOG="$BASE_DIR/logs/service_versions.log"

# 필수 로그 확인
[ -f "$SERVICE_LOG" ] || { echo "오류: $SERVICE_LOG 없음"; exit 1; }
[ -f "$SPECS_LOG" ]   || { echo "오류: $SPECS_LOG 없음"; exit 1; }

# 환경 변수 로드(키=값) — 존재해도 일부 키가 비어 있을 수 있음
# shellcheck disable=SC1090
source "$SERVICE_LOG" 2>/dev/null || true
# shellcheck disable=SC1090
source "$SPECS_LOG"   2>/dev/null || true
[ -f "$VERSIONS_LOG" ] && source "$VERSIONS_LOG" 2>/dev/null || true

# 숫자 기본값/정수화
to_int() { echo "$1" | grep -oE '^[0-9]+' || echo "0"; }

TOTAL_MEMORY="$(to_int "${TOTAL_MEMORY:-0}")"
CPU_CORES="$(to_int "${CPU_CORES:-0}")"
DISK_SPACE="$(to_int "${DISK_SPACE:-0}")"

[ "$TOTAL_MEMORY" -gt 0 ] || TOTAL_MEMORY=1024
[ "$CPU_CORES"   -gt 0 ] || CPU_CORES=1

# 서비스 러닝 기본값
: "${MYSQL_RUNNING:=0}"
: "${NGINX_RUNNING:=0}"
: "${PHP_FPM_RUNNING:=0}"
: "${APACHE_RUNNING:=0}"
: "${MULTIPLE_APACHE_FOUND:=0}"

MYSQL_RUNNING="$(to_int "$MYSQL_RUNNING")"
NGINX_RUNNING="$(to_int "$NGINX_RUNNING")"
PHP_FPM_RUNNING="$(to_int "$PHP_FPM_RUNNING")"
APACHE_RUNNING="$(to_int "$APACHE_RUNNING")"
MULTIPLE_APACHE_FOUND="$(to_int "$MULTIPLE_APACHE_FOUND")"

log_debug "시스템 스펙: MEM=${TOTAL_MEMORY}MB, CPU=${CPU_CORES}, DISK=${DISK_SPACE}GB"
log_debug "서비스 러닝 플래그: MYSQL=${MYSQL_RUNNING}, NGINX=${NGINX_RUNNING}, PHP_FPM=${PHP_FPM_RUNNING}, APACHE=${APACHE_RUNNING}, MULTI_APACHE=${MULTIPLE_APACHE_FOUND}"

# ===== Apache 인스턴스 수집 (index 기반, running=1만 집계) =====
declare -A APACHE_INSTANCE_RUNNING
declare -A APACHE_INSTANCE_MPM
declare -A APACHE_INSTANCE_BINARY
declare -A APACHE_INSTANCE_MPM_CONF
declare -A APACHE_INSTANCE_MAJOR
declare -A APACHE_INSTANCE_MINOR

APACHE_INSTANCE_COUNT=0

# helper: MPM 재탐지
detect_mpm_from_conf() {
  local conf="$1"
  [ -f "$conf" ] || return 0
  local m
  m="$(grep -E 'LoadModule.*mpm_(prefork|worker|event)_module' "$conf" \
      | awk '{print $2}' | cut -d'_' -f2 | tr '[:upper:]' '[:lower:]' | head -n1)"
  [ -n "$m" ] && echo "$m"
}

detect_mpm_fallback() {
  # apache2ctl 및 a2query가 있을 경우 모듈 확인
  local m=""
  if command -v apache2ctl >/dev/null 2>&1; then
    m="$(apache2ctl -M 2>/dev/null | grep -Eo 'mpm_(prefork|worker|event)_module' \
        | sed 's/^mpm_\|_module$//g' | head -n1)"
  fi
  if [ -z "$m" ] && command -v a2query >/dev/null 2>&1; then
    m="$(a2query -m 2>/dev/null | grep -Eo 'mpm_(prefork|worker|event)' \
        | sed 's/^mpm_//g' | head -n1)"
  fi
  echo "$m"
}

# 1) 인덱스 키가 1개 이상 존재하면(= MULTIPLE_APACHE_FOUND >= 1) 무조건 인덱스 기반 처리
if [ "$MULTIPLE_APACHE_FOUND" -ge 1 ]; then
  for i in $(seq 1 "$MULTIPLE_APACHE_FOUND"); do
    eval "R=\${APACHE_RUNNING_${i}:-0}"
    eval "BIN=\${APACHE_BINARY_${i}:-}"
    eval "MPM=\${APACHE_MPM_${i}:-}"
    eval "CONF=\${APACHE_MPM_CONF_${i}:-}"

    R="$(to_int "$R")"
    # htcacheclean 제외
    if [ -n "$BIN" ] && [[ "$BIN" == */htcacheclean ]]; then
      log_debug "Apache idx $i: htcacheclean 바이너리 스킵"
      continue
    fi

    if [ "$R" -eq 1 ]; then
      APACHE_INSTANCE_COUNT=$((APACHE_INSTANCE_COUNT + 1))
      APACHE_INSTANCE_RUNNING["$APACHE_INSTANCE_COUNT"]="$i"
      APACHE_INSTANCE_MPM["$APACHE_INSTANCE_COUNT"]="$MPM"
      APACHE_INSTANCE_BINARY["$APACHE_INSTANCE_COUNT"]="$BIN"
      APACHE_INSTANCE_MPM_CONF["$APACHE_INSTANCE_COUNT"]="$CONF"

      # MPM 미지정이면 conf/ctl에서 재탐지
      if [ -z "$MPM" ] || [ "$MPM" = "NOT_FOUND" ]; then
        m="$(detect_mpm_from_conf "$CONF")"
        [ -z "$m" ] && m="$(detect_mpm_fallback)"
        [ -n "$m" ] && APACHE_INSTANCE_MPM["$APACHE_INSTANCE_COUNT"]="$m"
      fi

      # 버전 파싱
      if [ -n "$BIN" ] && [ -x "$BIN" ]; then
        raw="$("$BIN" -V 2>/dev/null | grep -i 'Server version' || true)"
        ver="$(echo "$raw" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
        maj="$(echo "$ver" | cut -d. -f1)"
        min="$(echo "$ver" | cut -d. -f2)"
        APACHE_INSTANCE_MAJOR["$APACHE_INSTANCE_COUNT"]="$(to_int "$maj")"
        APACHE_INSTANCE_MINOR["$APACHE_INSTANCE_COUNT"]="$(to_int "$min")"
      else
        APACHE_INSTANCE_MAJOR["$APACHE_INSTANCE_COUNT"]=2
        APACHE_INSTANCE_MINOR["$APACHE_INSTANCE_COUNT"]=4
      fi

      log_debug "실행 Apache#${APACHE_INSTANCE_COUNT}(원본 idx=$i): MPM=${APACHE_INSTANCE_MPM[$APACHE_INSTANCE_COUNT]}, BIN=${APACHE_INSTANCE_BINARY[$APACHE_INSTANCE_COUNT]}, CONF=${APACHE_INSTANCE_MPM_CONF[$APACHE_INSTANCE_COUNT]}, VER=${APACHE_INSTANCE_MAJOR[$APACHE_INSTANCE_COUNT]}.${APACHE_INSTANCE_MINOR[$APACHE_INSTANCE_COUNT]}"
    fi
  done

# 2) 인덱스가 전혀 없는 경우(옛 포맷): APACHE_RUNNING만 마지막 보조로 사용
else
  if [ "$APACHE_RUNNING" -eq 1 ]; then
    APACHE_INSTANCE_COUNT=1
    APACHE_INSTANCE_RUNNING[1]=1
    APACHE_INSTANCE_MPM[1]="${APACHE_MPM:-}"
    APACHE_INSTANCE_BINARY[1]="${APACHE_BINARY:-}"
    APACHE_INSTANCE_MPM_CONF[1]="${APACHE_MPM_CONF:-}"

    if [ -z "${APACHE_INSTANCE_MPM[1]}" ] || [ "${APACHE_INSTANCE_MPM[1]}" = "NOT_FOUND" ]; then
      m="$(detect_mpm_from_conf "${APACHE_INSTANCE_MPM_CONF[1]}")"
      [ -z "$m" ] && m="$(detect_mpm_fallback)"
      [ -n "$m" ] && APACHE_INSTANCE_MPM[1]="$m"
    fi

    if [ -n "${APACHE_INSTANCE_BINARY[1]}" ] && [ -x "${APACHE_INSTANCE_BINARY[1]}" ]; then
      raw="$("${APACHE_INSTANCE_BINARY[1]}" -V 2>/dev/null | grep -i 'Server version' || true)"
      ver="$(echo "$raw" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
      APACHE_INSTANCE_MAJOR[1]="$(to_int "$(echo "$ver" | cut -d. -f1)")"
      APACHE_INSTANCE_MINOR[1]="$(to_int "$(echo "$ver" | cut -d. -f2)")"
    else
      APACHE_INSTANCE_MAJOR[1]=2
      APACHE_INSTANCE_MINOR[1]=4
    fi
  else
    APACHE_INSTANCE_COUNT=0
    log_debug "Apache 단일 포맷: 실행 중 아님(APACHE_RUNNING=0)"
  fi
fi

log_debug "APACHE_INSTANCE_COUNT(실행 중) = $APACHE_INSTANCE_COUNT"

# ===== 기타 서비스 실행 수 =====
PHP_COUNT="$(grep -o 'PHP_RUNNING_[0-9]=1' "$SERVICE_LOG" | wc -l | tr -d ' ')"
PHP_COUNT="$(to_int "$PHP_COUNT")"
PHP_RUNNING=0
[ "$PHP_COUNT" -ge 1 ] && PHP_RUNNING=1

TOMCAT_COUNT="$(grep -o 'TOMCAT_RUNNING_[0-9]=1' "$SERVICE_LOG" | wc -l | tr -d ' ')"
TOMCAT_COUNT="$(to_int "$TOMCAT_COUNT")"

log_debug "기타 실행 수: PHP_COUNT=${PHP_COUNT} (PHP_RUNNING=${PHP_RUNNING}), TOMCAT_COUNT=${TOMCAT_COUNT}, MYSQL_RUNNING=${MYSQL_RUNNING}, NGINX_RUNNING=${NGINX_RUNNING}, PHP_FPM_RUNNING=${PHP_FPM_RUNNING}"

# ===== ACTIVE_SERVICES (실행 중만 합산) =====
ACTIVE_SERVICES=0
[ "$APACHE_INSTANCE_COUNT" -ge 1 ] && ACTIVE_SERVICES=$((ACTIVE_SERVICES + APACHE_INSTANCE_COUNT))
[ "$TOMCAT_COUNT"        -ge 1 ] && ACTIVE_SERVICES=$((ACTIVE_SERVICES + TOMCAT_COUNT))
[ "$MYSQL_RUNNING"       -ge 1 ] && ACTIVE_SERVICES=$((ACTIVE_SERVICES + 1))
[ "$NGINX_RUNNING"       -ge 1 ] && ACTIVE_SERVICES=$((ACTIVE_SERVICES + 1))
[ "$PHP_RUNNING"         -ge 1 ] && ACTIVE_SERVICES=$((ACTIVE_SERVICES + PHP_COUNT))
[ "$PHP_FPM_RUNNING"     -ge 1 ] && ACTIVE_SERVICES=$((ACTIVE_SERVICES + 1))

log_debug "ACTIVE_SERVICES=${ACTIVE_SERVICES}"
if [ "$ACTIVE_SERVICES" -le 0 ]; then
  echo "오류: 실행 중인 서비스가 없습니다." >&2
  exit 1
fi

# ===== 메모리 배분 =====
# 정책(예시): MYSQL 30%, RESERVE 10%, TOMCAT 256MB/인스턴스 고정, 나머지를 Apache에 분배
MYSQL_MEMORY_PERCENT=30
RESERVE_MEMORY_PERCENT=10
TOMCAT_MEMORY_PER_INSTANCE=256

MYSQL_MEMORY=0
if [ "$MYSQL_RUNNING" -ge 1 ]; then
  MYSQL_MEMORY=$(( TOTAL_MEMORY * MYSQL_MEMORY_PERCENT / 100 ))
  [ "$MYSQL_MEMORY" -lt 256 ] && MYSQL_MEMORY=256
fi

TOMCAT_MEMORY=$(( TOMCAT_COUNT * TOMCAT_MEMORY_PER_INSTANCE ))
RESERVE_MEMORY=$(( TOTAL_MEMORY * RESERVE_MEMORY_PERCENT / 100 ))

REMAIN=$(( TOTAL_MEMORY - MYSQL_MEMORY - TOMCAT_MEMORY - RESERVE_MEMORY ))
[ "$REMAIN" -lt 0 ] && REMAIN=0

if [ "$APACHE_INSTANCE_COUNT" -ge 1 ]; then
  DIV="$APACHE_INSTANCE_COUNT"
  [ "$DIV" -lt 1 ] && DIV=1
  APACHE_MEMORY=$(( REMAIN / DIV ))
  [ "$APACHE_MEMORY" -lt 512 ] && APACHE_MEMORY=512
else
  APACHE_MEMORY=0
fi

log_debug "메모리 배분: MYSQL=${MYSQL_MEMORY}MB, TOMCAT=${TOMCAT_MEMORY}MB, RESERVE=${RESERVE_MEMORY}MB, APACHE(per instance)=${APACHE_MEMORY}MB"

# ===== MPM 설정 생성 (실행 중 인스턴스만, >=1) =====
OUTPUT_DIR="$BASE_DIR/tmp_conf"
mkdir -p "$OUTPUT_DIR"

if [ "$APACHE_INSTANCE_COUNT" -ge 1 ]; then
  for idx in "${!APACHE_INSTANCE_RUNNING[@]}"; do
    orig="${APACHE_INSTANCE_RUNNING[$idx]}"
    MPM="${APACHE_INSTANCE_MPM[$idx]:-}"
    CONF="${APACHE_INSTANCE_MPM_CONF[$idx]:-}"
    MAJOR="${APACHE_INSTANCE_MAJOR[$idx]:-2}"
    MINOR="${APACHE_INSTANCE_MINOR[$idx]:-4}"

    [ -z "$MPM" ] && { log_debug "Apache#$idx: MPM 미탐지 → 스킵"; continue; }
    [ "$CONF" = "NOT_FOUND" ] && { log_debug "Apache#$idx: MPM_CONF 없음 → 스킵"; continue; }

    # 분모 보호: 인스턴스 수
    DIV="$APACHE_INSTANCE_COUNT"; [ "$DIV" -lt 1 ] && DIV=1

    # 공통 튜닝값
    MAX_CONNECTIONS_PER_CHILD=10000
    MAX_REQUESTS_PER_CHILD=10000

    # 시작/여유 파라미터
    START_SERVERS=$(( CPU_CORES * 2 / DIV ))
    [ "$START_SERVERS" -lt 1 ] && START_SERVERS=1

    if [ "$MPM" = "prefork" ]; then
      MIN_SPARE_SERVERS=$(( CPU_CORES * 5 / DIV ))
      MAX_SPARE_SERVERS=$(( CPU_CORES * 10 / DIV ))
      [ "$MIN_SPARE_SERVERS" -lt 1 ] && MIN_SPARE_SERVERS=1
      [ "$MAX_SPARE_SERVERS" -lt "$MIN_SPARE_SERVERS" ] && MAX_SPARE_SERVERS=$((MIN_SPARE_SERVERS+1))

      if   [ "$APACHE_MEMORY" -lt 1024 ]; then MAX_REQUEST_WORKERS=$(( APACHE_MEMORY / 25 ))
      elif [ "$APACHE_MEMORY" -lt 2048 ]; then MAX_REQUEST_WORKERS=$(( APACHE_MEMORY / 20 ))
      else                                    MAX_REQUEST_WORKERS=$(( APACHE_MEMORY / 15 ))
      fi
      [ "$MAX_REQUEST_WORKERS" -lt 10 ] && MAX_REQUEST_WORKERS=10

      SERVER_LIMIT="$MAX_REQUEST_WORKERS"
      [ "$SERVER_LIMIT" -lt 1 ] && SERVER_LIMIT=1

      if [ "$MAJOR" -eq 2 ] && [ "$MINOR" -lt 4 ]; then
        # Apache 2.2 계열
        cat > "$OUTPUT_DIR/mpm_config_${idx}.conf" <<EOF
<IfModule mpm_prefork_module>
    StartServers          $START_SERVERS
    MinSpareServers       $MIN_SPARE_SERVERS
    MaxSpareServers       $MAX_SPARE_SERVERS
    MaxClients            $MAX_REQUEST_WORKERS
    MaxRequestsPerChild   $MAX_REQUESTS_PER_CHILD
</IfModule>
EOF
      else
        # Apache 2.4+
        cat > "$OUTPUT_DIR/mpm_config_${idx}.conf" <<EOF
<IfModule mpm_prefork_module>
    StartServers             $START_SERVERS
    MinSpareServers          $MIN_SPARE_SERVERS
    MaxSpareServers          $MAX_SPARE_SERVERS
    ServerLimit              $SERVER_LIMIT
    MaxRequestWorkers        $MAX_REQUEST_WORKERS
    MaxConnectionsPerChild   $MAX_CONNECTIONS_PER_CHILD
</IfModule>
EOF
      fi

    elif [ "$MPM" = "worker" ] || [ "$MPM" = "event" ]; then
      MIN_SPARE_THREADS=$(( CPU_CORES * 10 / DIV ))
      MAX_SPARE_THREADS=$(( CPU_CORES * 20 / DIV ))
      [ "$MIN_SPARE_THREADS" -lt 5 ] && MIN_SPARE_THREADS=5
      [ "$MAX_SPARE_THREADS" -lt "$MIN_SPARE_THREADS" ] && MAX_SPARE_THREADS=$((MIN_SPARE_THREADS+5))

      THREADS_PER_CHILD=25
      THREAD_LIMIT=64

      if   [ "$APACHE_MEMORY" -lt 1024 ]; then MAX_REQUEST_WORKERS=$(( APACHE_MEMORY / 20 ))
      elif [ "$APACHE_MEMORY" -lt 2048 ]; then MAX_REQUEST_WORKERS=$(( APACHE_MEMORY / 15 ))
      else                                    MAX_REQUEST_WORKERS=$(( APACHE_MEMORY / 10 ))
      fi
      [ "$MAX_REQUEST_WORKERS" -lt 25 ] && MAX_REQUEST_WORKERS=25
      # THREADS_PER_CHILD의 배수로 정렬
      MAX_REQUEST_WORKERS=$(( (MAX_REQUEST_WORKERS / THREADS_PER_CHILD) * THREADS_PER_CHILD ))
      [ "$MAX_REQUEST_WORKERS" -lt 25 ] && MAX_REQUEST_WORKERS=25

      SERVER_LIMIT=$(( MAX_REQUEST_WORKERS / THREADS_PER_CHILD ))
      [ "$SERVER_LIMIT" -lt 1 ] && SERVER_LIMIT=1

      # Apache 2.2에서 event 미지원 → worker로 태그만 교체
      if [ "$MPM" = "event" ] && [ "$MAJOR" -eq 2 ] && [ "$MINOR" -lt 4 ]; then
        MPM_TAG="mpm_worker_module"
      else
        MPM_TAG="mpm_${MPM}_module"
      fi

      if [ "$MAJOR" -eq 2 ] && [ "$MINOR" -lt 4 ]; then
        # Apache 2.2
        cat > "$OUTPUT_DIR/mpm_config_${idx}.conf" <<EOF
<IfModule ${MPM_TAG}>
    StartServers          $START_SERVERS
    MinSpareThreads       $MIN_SPARE_THREADS
    MaxSpareThreads       $MAX_SPARE_THREADS
    ThreadsPerChild       $THREADS_PER_CHILD
    MaxClients            $MAX_REQUEST_WORKERS
    MaxRequestsPerChild   $MAX_REQUESTS_PER_CHILD
</IfModule>
EOF
      else
        # Apache 2.4+
        cat > "$OUTPUT_DIR/mpm_config_${idx}.conf" <<EOF
<IfModule ${MPM_TAG}>
    StartServers             $START_SERVERS
    MinSpareThreads          $MIN_SPARE_THREADS
    MaxSpareThreads          $MAX_SPARE_THREADS
    ThreadsPerChild          $THREADS_PER_CHILD
    ServerLimit              $SERVER_LIMIT
    MaxRequestWorkers        $MAX_REQUEST_WORKERS
    ThreadLimit              $THREAD_LIMIT
    MaxConnectionsPerChild   $MAX_CONNECTIONS_PER_CHILD
</IfModule>
EOF
      fi

    else
      log_debug "Apache#$idx: 알 수 없는 MPM(${MPM}) → 스킵"
      continue
    fi

    log_debug "Apache#$idx: $OUTPUT_DIR/mpm_config_${idx}.conf 생성 완료"
  done

  echo "MPM 설정이 인스턴스별로 저장되었습니다."
else
  log_debug "Apache가 실행 중이 아니므로 MPM 설정 생성 생략(APACHE_INSTANCE_COUNT=0)"
fi

exit 0