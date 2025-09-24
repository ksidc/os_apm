#!/bin/bash

# calculate_mpm_config.sh
# Apache MPM 설정 계산 및 mpm_config_<index>.conf 생성 (prefork, event, worker 및 Apache 2.2, 2.4 모든 버전 지원)
# 수정: MaxRequestWorkers를 ThreadsPerChild의 배수로 조정, 다중 인스턴스별 설정 계산
# 추가 수정: check_version 호출 제거, service_versions.log에서 버전 읽기, Tomcat 호출 방지
# 추가 수정: prefork 모듈에 ThreadLimit, MinSpareThreads, MaxSpareThreads 제거, 로그 강화
# 2025-08-19 변경: 단일 인스턴스도 접미사 경로 루프로 처리(-ge 1), 접미사→비접미사 폴백 추가
# 2025-08-20 변경: PHP, PHP-FPM을 메모리 비율 계산에서 제외, service_paths.log 기반 서비스 상태 신뢰
# 2025-08-20 변경: 메모리 상한선 제거(단일 구성), ThreadsPerChild 동적 조정, MaxRequestWorkers 50 단위 조정
# 2025-08-20 변경: worker MPM에서 MaxClients를 MaxRequestWorkers로 수정, 고정값 공식 적용 (32GB=2048, 64GB=5012, >64GB=7000)
# 2025-08-20 변경: prefork MPM에서 MinSpareServers, MaxSpareServers 최소값 보장 (단일: 120/240, 다중: 50/100)
# 2025-08-20 변경: ServerLimit 계산 정정 (내림 후 조건부 +1)

# 공통 함수 로드
BASE_DIR="/usr/local/src/iteasy_tuning"
SCRIPTS_DIR="$BASE_DIR/scripts"
if [ ! -f "$SCRIPTS_DIR/common.sh" ]; then
    echo "오류: 공통 스크립트($SCRIPTS_DIR/common.sh)가 존재하지 않습니다." >&2
    exit 1
fi
source "$SCRIPTS_DIR/common.sh"

# 로깅 설정
log_debug "calculate_mpm_config.sh 시작"

# 환경 변수 로드
if [ -f "$BASE_DIR/logs/service_paths.log" ]; then
    source "$BASE_DIR/logs/service_paths.log" 2>/dev/null || {
        log_debug "service_paths.log 로드 실패"
        exit 1
    }
else
    log_debug "service_paths.log 파일 없음"
    exit 1
fi

# 시스템 스펙 로드
if [ -f "$BASE_DIR/logs/system_specs.log" ]; then
    source "$BASE_DIR/logs/system_specs.log" 2>/dev/null || {
        log_debug "system_specs.log 로드 실패"
        exit 1
    }
else
    log_debug "system_specs.log 파일 없음"
    exit 1
fi

# 서비스 버전 로드
if [ -f "$BASE_DIR/logs/service_versions.log" ]; then
    source "$BASE_DIR/logs/service_versions.log" 2>/dev/null || {
        log_debug "service_versions.log 로드 실패"
        exit 1
    }
else
    log_debug "service_versions.log 파일 없음"
    exit 1
fi

# 변수 정수 변환
TOTAL_MEMORY=$(echo "$TOTAL_MEMORY" | grep -o '[0-9]\+' || echo "1024")
CPU_CORES=$(echo "$CPU_CORES" | grep -o '[0-9]\+' || echo "1")
DISK_SPACE=$(echo "$DISK_SPACE" | grep -o '[0-9]\+' || echo "0")
log_debug "TOTAL_MEMORY=$TOTAL_MEMORY MB, CPU_CORES=$CPU_CORES, DISK_SPACE=$DISK_SPACE GB"

# 서비스 조합 확인 (PHP, PHP-FPM 제외)
ACTIVE_SERVICES=0
TOMCAT_COUNT=0
if [ -f "$BASE_DIR/logs/service_paths.log" ]; then
    [ "$(grep -E 'MYSQL_RUNNING=1|MARIADB_RUNNING=1' "$BASE_DIR/logs/service_paths.log")" ] && ACTIVE_SERVICES=$((ACTIVE_SERVICES + 1))
    TOMCAT_COUNT=$(grep -o 'TOMCAT_RUNNING_[0-9]=1' "$BASE_DIR/logs/service_paths.log" | wc -l)
    ACTIVE_SERVICES=$((ACTIVE_SERVICES + TOMCAT_COUNT))
    [ "$(grep -E 'NGINX_RUNNING=1' "$BASE_DIR/logs/service_paths.log")" ] && ACTIVE_SERVICES=$((ACTIVE_SERVICES + 1))
fi
log_debug "ACTIVE_SERVICES=$ACTIVE_SERVICES, TOMCAT_COUNT=$TOMCAT_COUNT"

# 서비스 상태 확인 (다중 Apache 지원)
APACHE_INSTANCE_COUNT=0
declare -A APACHE_INSTANCE_RUNNING
declare -A APACHE_INSTANCE_MPM
declare -A APACHE_INSTANCE_MAJOR
declare -A APACHE_INSTANCE_MINOR
declare -A APACHE_INSTANCE_BINARY

if [ "${MULTIPLE_APACHE_FOUND:-0}" -ge 1 ]; then
    for i in $(seq 1 "$MULTIPLE_APACHE_FOUND"); do
        eval "INSTANCE_RUNNING=\${APACHE_RUNNING_$i:-\$APACHE_RUNNING}"
        eval "INSTANCE_BINARY=\${APACHE_BINARY_$i:-\$APACHE_BINARY}"
        eval "INSTANCE_MPM=\${APACHE_MPM_$i:-\$APACHE_MPM}"
        eval "INSTANCE_VERSION=\${APACHE_VERSION_$i:-\$APACHE_VERSION}"

        if [ -z "$INSTANCE_VERSION" ]; then
            INSTANCE_VERSION="2.4.0"
            log_debug "인스턴스 $i: 버전 정보 비어 있어 기본값(2.4.0) 사용"
        fi

        if [ -n "$INSTANCE_RUNNING" ] && [ "$INSTANCE_RUNNING" -eq 1 ] && [ -n "$INSTANCE_BINARY" ]; then
            if [[ "$INSTANCE_BINARY" =~ httpd$ ]]; then
                APACHE_INSTANCE_COUNT=$((APACHE_INSTANCE_COUNT + 1))
                APACHE_INSTANCE_RUNNING[$APACHE_INSTANCE_COUNT]=$INSTANCE_RUNNING
                APACHE_INSTANCE_MPM[$APACHE_INSTANCE_COUNT]=$INSTANCE_MPM
                APACHE_INSTANCE_BINARY[$APACHE_INSTANCE_COUNT]=$INSTANCE_BINARY
                APACHE_MAJOR_VERSION=$(echo "$INSTANCE_VERSION" | cut -d'.' -f1)
                APACHE_MINOR_VERSION=$(echo "$INSTANCE_VERSION" | cut -d'.' -f2)
                APACHE_INSTANCE_MAJOR[$APACHE_INSTANCE_COUNT]=${APACHE_MAJOR_VERSION:-2}
                APACHE_INSTANCE_MINOR[$APACHE_INSTANCE_COUNT]=${APACHE_MINOR_VERSION:-4}
                log_debug "Apache 인스턴스 $APACHE_INSTANCE_COUNT: 바이너리=$INSTANCE_BINARY, MPM=$INSTANCE_MPM, 버전=$INSTANCE_VERSION"
            else
                log_debug "Apache 인스턴스 $i 스킵: 비-httpd 바이너리($INSTANCE_BINARY)"
            fi
        else
            log_debug "Apache 인스턴스 $i 스킵: RUNNING=$INSTANCE_RUNNING, BINARY=$INSTANCE_BINARY"
        fi
    done
else
    if [ -n "$APACHE_RUNNING" ] && [ "$APACHE_RUNNING" -eq 1 ] && [ -n "$APACHE_BINARY" ] && [[ "$APACHE_BINARY" =~ httpd$ ]]; then
        APACHE_INSTANCE_COUNT=1
        APACHE_INSTANCE_RUNNING[1]=$APACHE_RUNNING
        APACHE_INSTANCE_MPM[1]=$APACHE_MPM
        APACHE_INSTANCE_BINARY[1]=$APACHE_BINARY
        APACHE_MAJOR_VERSION=$(echo "${APACHE_VERSION:-2.4.0}" | cut -d'.' -f1)
        APACHE_MINOR_VERSION=$(echo "${APACHE_VERSION:-2.4.0}" | cut -d'.' -f2)
        APACHE_INSTANCE_MAJOR[1]=${APACHE_MAJOR_VERSION:-2}
        APACHE_INSTANCE_MINOR[1]=${APACHE_MINOR_VERSION:-4}
        log_debug "Apache 인스턴스 1: 바이너리=$APACHE_BINARY, MPM=$APACHE_MPM, 버전=${APACHE_VERSION:-2.4.0}"
    fi
fi

if [ "$APACHE_INSTANCE_COUNT" -eq 0 ]; then
    log_debug "Apache가 실행 중이 아니므로 MPM 설정 생성 생략"
    echo "MPM_CONFIG=skipped" >> "$BASE_DIR/logs/tuning_status.log"
    exit 0
fi

# 메모리 비율 계산 (PHP, PHP-FPM 제외)
RESERVE_MEMORY_PERCENT=10
AVAILABLE_MEMORY=$((TOTAL_MEMORY * (100 - RESERVE_MEMORY_PERCENT) / 100))
if [ "$ACTIVE_SERVICES" -eq 0 ]; then
    APACHE_MEMORY_PERCENT=90
else
    APACHE_MEMORY_PERCENT=$((90 / (ACTIVE_SERVICES + 1)))
fi
APACHE_MEMORY_PERCENT=$((APACHE_MEMORY_PERCENT / APACHE_INSTANCE_COUNT))
APACHE_MEMORY=$((AVAILABLE_MEMORY * APACHE_MEMORY_PERCENT / 100))
[ "$APACHE_MEMORY" -lt 256 ] && APACHE_MEMORY=256
# 단일 구성에서는 메모리 상한선 제거, 다중 서비스에서는 2048MB 제한
if [ "$ACTIVE_SERVICES" -eq 0 ]; then
    :
else
    [ "$APACHE_MEMORY" -gt 2048 ] && APACHE_MEMORY=2048
fi
log_debug "APACHE_MEMORY=$APACHE_MEMORY MB (per instance), APACHE_MEMORY_PERCENT=$APACHE_MEMORY_PERCENT%"

# 출력 디렉터리 생성
OUTPUT_DIR="$BASE_DIR/tmp_conf"
mkdir -p "$OUTPUT_DIR" || {
    log_debug "tmp_conf 디렉터리 생성 실패"
    echo "오류: 출력 디렉터리($OUTPUT_DIR) 생성 실패" >&2
    exit 1
}

# 메모리 및 스레드 설정 계산
idx=0
for i in $(seq 1 "$APACHE_INSTANCE_COUNT"); do
    if [ "${APACHE_INSTANCE_RUNNING[$i]}" -eq 1 ]; then
        ((idx++))
        MPM_MODULE="${APACHE_INSTANCE_MPM[$i]}"
        APACHE_MAJOR_VERSION="${APACHE_INSTANCE_MAJOR[$i]}"
        APACHE_MINOR_VERSION="${APACHE_INSTANCE_MINOR[$i]}"
        APACHE_BINARY="${APACHE_INSTANCE_BINARY[$i]}"

        # MaxClients/MaxRequestWorkers 고정값 공식
        GB=$((TOTAL_MEMORY / 1024))
        if [ "$GB" -le 32 ]; then
            MAX_WORKERS=$(( (TOTAL_MEMORY / 1024 * 6775 / 100) ))
        elif [ "$GB" -le 64 ]; then
            MAX_WORKERS=$(( 2048 + (TOTAL_MEMORY / 1024 - 32) * 92625 / 1000 ))
        else
            MAX_WORKERS=7000
        fi
        [ "$MAX_WORKERS" -lt 50 ] && MAX_WORKERS=50
        # 다중 인스턴스일 경우 균등 분배
        if [ "$APACHE_INSTANCE_COUNT" -gt 1 ]; then
            MAX_WORKERS=$((MAX_WORKERS / APACHE_INSTANCE_COUNT))
            [ "$MAX_WORKERS" -lt 50 ] && MAX_WORKERS=50
        fi
        # 50 단위로 조정
        remainder=$((MAX_WORKERS % 50))
        if [ $remainder -ne 0 ]; then
            MAX_WORKERS=$((MAX_WORKERS - remainder + 50))
        fi

        if [ "$MPM_MODULE" = "prefork" ]; then
            if [ "$ACTIVE_SERVICES" -eq 0 ]; then
                # 단일 구성: 고정값 적용
                MIN_SPARE_SERVERS=120
                MAX_SPARE_SERVERS=240
                START_SERVERS=$((CPU_CORES * 2))
                [ "$START_SERVERS" -lt 5 ] && START_SERVERS=5
            else
                # 다중 서비스: 메모리 비례 조정, 최소값 보장
                START_SERVERS=$((CPU_CORES * 2 * (APACHE_MEMORY / 1000)))
                [ "$START_SERVERS" -lt 5 ] && START_SERVERS=5
                MIN_SPARE_SERVERS=$((CPU_CORES * 5 * (APACHE_MEMORY / 1000)))
                [ "$MIN_SPARE_SERVERS" -lt 50 ] && MIN_SPARE_SERVERS=50
                MAX_SPARE_SERVERS=$((MIN_SPARE_SERVERS * 2))
                [ "$MAX_SPARE_SERVERS" -lt 100 ] && MAX_SPARE_SERVERS=100
            fi
            MAX_CLIENTS=$MAX_WORKERS
            MAX_REQUESTS_PER_CHILD=10000
            MIN_SPARE_THREADS=""
            MAX_SPARE_THREADS=""
            THREADS_PER_CHILD=""
            SERVER_LIMIT=""
            THREAD_LIMIT=""
            MAX_CONNECTIONS_PER_CHILD=""
        else
            # ThreadsPerChild 동적 조정
            if [ "$APACHE_MEMORY" -lt 1000 ]; then
                THREADS_PER_CHILD=$((CPU_CORES * 10))
            else
                THREADS_PER_CHILD=$((CPU_CORES * 25))
            fi
            [ "$THREADS_PER_CHILD" -gt 100 ] && THREADS_PER_CHILD=100
            START_SERVERS=$((CPU_CORES * 2))
            [ "$START_SERVERS" -lt 5 ] && START_SERVERS=5
            MIN_SPARE_THREADS=$((CPU_CORES * 10))
            MAX_SPARE_THREADS=$((MIN_SPARE_THREADS * 2))
            MAX_REQUEST_WORKERS=$MAX_WORKERS
            SERVER_LIMIT=$((MAX_REQUEST_WORKERS / THREADS_PER_CHILD))
            [ "$((MAX_REQUEST_WORKERS % THREADS_PER_CHILD))" -ne 0 ] && SERVER_LIMIT=$((SERVER_LIMIT + 1))
            THREAD_LIMIT=$((THREADS_PER_CHILD * 2))
            MAX_CONNECTIONS_PER_CHILD=10000
            MIN_SPARE_SERVERS=""
            MAX_SPARE_SERVERS=""
            MAX_CLIENTS=""
            MAX_REQUESTS_PER_CHILD=""
        fi

        log_debug "Apache 인스턴스 $idx: MPM=$MPM_MODULE, START_SERVERS=$START_SERVERS, MIN_SPARE_SERVERS=$MIN_SPARE_SERVERS, MAX_SPARE_SERVERS=$MAX_SPARE_SERVERS, MAX_CLIENTS=$MAX_CLIENTS, MAX_REQUEST_WORKERS=$MAX_REQUEST_WORKERS, SERVER_LIMIT=$SERVER_LIMIT, THREAD_LIMIT=$THREAD_LIMIT, MAX_REQUESTS_PER_CHILD=$MAX_REQUESTS_PER_CHILD, MAX_CONNECTIONS_PER_CHILD=$MAX_CONNECTIONS_PER_CHILD"

        if [ "$MPM_MODULE" = "prefork" ]; then
            cat > "$OUTPUT_DIR/mpm_config_$idx.conf" << EOF
<IfModule mpm_prefork_module>
    StartServers          $START_SERVERS
    MinSpareServers       $MIN_SPARE_SERVERS
    MaxSpareServers       $MAX_SPARE_SERVERS
    MaxClients            $MAX_CLIENTS
    MaxRequestsPerChild   $MAX_REQUESTS_PER_CHILD
</IfModule>
EOF
        elif [ "$APACHE_MAJOR_VERSION" -eq 2 ] && [ "$APACHE_MINOR_VERSION" -lt 4 ]; then
            log_debug "Apache 2.2는 event MPM을 지원하지 않음, worker로 대체"
            MPM_MODULE="worker"
            cat > "$OUTPUT_DIR/mpm_config_$idx.conf" << EOF
<IfModule mpm_worker_module>
    StartServers          $START_SERVERS
    MinSpareThreads       $MIN_SPARE_THREADS
    MaxSpareThreads       $MAX_SPARE_THREADS
    ThreadsPerChild       $THREADS_PER_CHILD
    MaxRequestWorkers     $MAX_REQUEST_WORKERS
    MaxRequestsPerChild   $MAX_CONNECTIONS_PER_CHILD
</IfModule>
EOF
        else
            cat > "$OUTPUT_DIR/mpm_config_$idx.conf" << EOF
<IfModule mpm_${MPM_MODULE}_module>
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
        log_debug "mpm_config_$idx.conf 생성 완료: $OUTPUT_DIR/mpm_config_$idx.conf"
        log_debug "mpm_config_$idx.conf 내용: $(cat "$OUTPUT_DIR/mpm_config_$idx.conf" 2>/dev/null || echo '읽기 실패')"
    fi
done
echo "MPM 설정이 인스턴스별로 저장되었습니다."
exit 0