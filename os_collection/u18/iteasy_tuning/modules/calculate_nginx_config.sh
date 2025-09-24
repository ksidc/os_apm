#!/bin/bash

# calculate_nginx_config.sh
# Nginx 설정 계산 및 nginx_config.conf 생성
# worker_processes는 auto로 고정, worker_rlimit_nofile은 65536으로 고정
# worker_connections는 시스템 자원과 서비스 조합에 따라 계산

# 공통 함수 로드
BASE_DIR="/usr/local/src/iteasy_tuning"
SCRIPTS_DIR="$BASE_DIR/scripts"
if [ ! -f "$SCRIPTS_DIR/common.sh" ]; then
    echo "오류: 공통 스크립트($SCRIPTS_DIR/common.sh)가 존재하지 않습니다." >&2
    exit 1
fi
source "$SCRIPTS_DIR/common.sh"

# 로깅 설정
log_debug "calculate_nginx_config.sh 시작"

# 환경 변수 로드 (Nginx 관련만)
if [ -f "$BASE_DIR/logs/service_paths.log" ]; then
    grep -E '^NGINX_RUNNING=|^NGINX_BINARY=' "$BASE_DIR/logs/service_paths.log" > /tmp/nginx_service_paths.log
    source /tmp/nginx_service_paths.log 2>/dev/null || {
        log_debug "service_paths.log에서 Nginx 관련 변수 로드 실패"
        rm -f /tmp/nginx_service_paths.log
        echo "오류: Nginx 상태 로드 실패" >&2
        exit 1
    }
    rm -f /tmp/nginx_service_paths.log
    if [ -z "$NGINX_RUNNING" ] || [ "$NGINX_RUNNING" -ne 1 ]; then
        log_debug "NGINX_RUNNING 변수가 유효하지 않음"
        echo "오류: Nginx 상태 확인 실패" >&2
        exit 1
    fi
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

# Nginx 버전 로드 (추출 강화)
if [ -f "$BASE_DIR/logs/service_versions.log" ]; then
    grep '^NGINX_VERSION=' "$BASE_DIR/logs/service_versions.log" > /tmp/nginx_versions.log
    # sed로 버전 숫자만 추출 (e.g., "nginx version: nginx/1.14.1" → "1.14.1")
    sed -i -E 's/^NGINX_VERSION=.*nginx\/([0-9]+\.[0-9]+\.[0-9]+).*/NGINX_VERSION=\1/' /tmp/nginx_versions.log
    source /tmp/nginx_versions.log 2>/dev/null || {
        log_debug "service_versions.log에서 Nginx 버전 로드 실패, 기본값 사용"
        NGINX_VERSION="1.10.0"
    }
    rm -f /tmp/nginx_versions.log
    if [ -z "$NGINX_VERSION" ] || ! echo "$NGINX_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
        log_debug "NGINX_VERSION이 유효하지 않음, 기본값 사용"
        NGINX_VERSION="1.10.0"
    fi
else
    log_debug "service_versions.log 파일 없음, 기본값 사용"
    NGINX_VERSION="1.10.0"
fi

# 변수 정수 변환
TOTAL_MEMORY=$(echo "$TOTAL_MEMORY" | grep -o '[0-9]\+' || echo "1024")
CPU_CORES=$(echo "$CPU_CORES" | grep -o '[0-9]\+' || echo "1")
log_debug "TOTAL_MEMORY=$TOTAL_MEMORY MB, CPU_CORES=$CPU_CORES"

# 서비스 상태 확인 (Nginx만 확인)
NGINX_RUNNING=${NGINX_RUNNING:-0}
log_debug "NGINX_RUNNING=$NGINX_RUNNING"

# Nginx 실행 여부 확인
if [ "$NGINX_RUNNING" -ne 1 ]; then
    log_debug "Nginx가 실행 중이 아니므로 설정 생성 생략"
    echo "오류: Nginx가 실행 중이 아니므로 설정을 생성할 수 없습니다." >&2
    echo "NGINX_CONFIG=skipped" >> "$BASE_DIR/logs/tuning_status.log"
    exit 1
fi

# Nginx 버전 확인
NGINX_MAJOR=$(echo "$NGINX_VERSION" | cut -d'.' -f1)
NGINX_MINOR=$(echo "$NGINX_VERSION" | cut -d'.' -f2)
log_debug "NGINX_VERSION=$NGINX_VERSION, MAJOR=$NGINX_MAJOR, MINOR=$NGINX_MINOR"

# 서비스 조합 확인 (로그 파일에서 관련 서비스 정보 가져오기)
ACTIVE_SERVICES=0
MYSQL_RUNNING=0
MARIADB_RUNNING=0
TOMCAT_COUNT=0
PHP_RUNNING=0
PHP_FPM_RUNNING=0
if [ -f "$BASE_DIR/logs/service_paths.log" ]; then
    [ "$(grep -E 'MYSQL_RUNNING=1|MARIADB_RUNNING=1' "$BASE_DIR/logs/service_paths.log")" ] && ACTIVE_SERVICES=$((ACTIVE_SERVICES + 1))
    TOMCAT_COUNT=$(grep -o 'TOMCAT_RUNNING_[0-9]=1' "$BASE_DIR/logs/service_paths.log" | wc -l)
    ACTIVE_SERVICES=$((ACTIVE_SERVICES + TOMCAT_COUNT))
    [ "$(grep -E 'PHP_RUNNING=1' "$BASE_DIR/logs/service_paths.log")" ] && ACTIVE_SERVICES=$((ACTIVE_SERVICES + 1))
    [ "$(grep -E 'PHP_FPM_RUNNING=1' "$BASE_DIR/logs/service_paths.log")" ] && ACTIVE_SERVICES=$((ACTIVE_SERVICES + 1))
    [ "$NGINX_RUNNING" -eq 1 ] && ACTIVE_SERVICES=$((ACTIVE_SERVICES + 1))
fi
log_debug "ACTIVE_SERVICES=$ACTIVE_SERVICES, TOMCAT_COUNT=$TOMCAT_COUNT"

# 메모리 할당 (서비스별 비율)
NGINX_MEMORY_PERCENT=0
RESERVE_MEMORY_PERCENT=10
if [ "$ACTIVE_SERVICES" -eq 1 ]; then
    NGINX_MEMORY_PERCENT=90  # 단일 서비스
elif [ "$TOMCAT_COUNT" -eq 0 ] && [ "$ACTIVE_SERVICES" -eq 2 ]; then
    NGINX_MEMORY_PERCENT=45  # Nginx + DB
elif [ "$TOMCAT_COUNT" -eq 2 ] && [ "$ACTIVE_SERVICES" -eq 4 ]; then
    NGINX_MEMORY_PERCENT=18  # Nginx + WAS(2) + DB
elif [ "$TOMCAT_COUNT" -eq 3 ] && [ "$ACTIVE_SERVICES" -eq 5 ]; then
    NGINX_MEMORY_PERCENT=13.5  # Nginx + WAS(3) + DB
elif [ "$TOMCAT_COUNT" -ge 4 ] && [ "$ACTIVE_SERVICES" -ge 6 ]; then
    NGINX_MEMORY_PERCENT=11.25  # Nginx + WAS(4+) + DB
else
    NGINX_MEMORY_PERCENT=27  # Nginx + WAS(n), DB 없음
fi

NGINX_MEMORY=$((TOTAL_MEMORY * NGINX_MEMORY_PERCENT / 100))
[ "$NGINX_MEMORY" -lt 512 ] && NGINX_MEMORY=512  # 최소 메모리 보장
log_debug "NGINX_MEMORY=$NGINX_MEMORY MB, NGINX_MEMORY_PERCENT=$NGINX_MEMORY_PERCENT%"

# worker_connections 계산
CONNECTION_MEMORY=0.2  # 연결당 0.2MB (실무 기준 보수적 값)
MAX_CONNECTIONS=$((NGINX_MEMORY / CONNECTION_MEMORY))
[ "$MAX_CONNECTIONS" -lt 1024 ] && MAX_CONNECTIONS=1024  # 최소 연결 수
WORKER_CONNECTIONS=$((MAX_CONNECTIONS / CPU_CORES))
[ "$WORKER_CONNECTIONS" -lt 1024 ] && WORKER_CONNECTIONS=1024  # 프로세스당 최소 연결
WORKER_CONNECTIONS=$((WORKER_CONNECTIONS * 50 / 100))  # 50% 안전 마진
if [ "$NGINX_MAJOR" -eq 1 ] && [ "$NGINX_MINOR" -ge 10 ]; then
    # Nginx 1.10+는 epoll 사용, 권장 범위(4096~8192) 내 조정
    [ "$WORKER_CONNECTIONS" -gt 8192 ] && WORKER_CONNECTIONS=8192
    [ "$WORKER_CONNECTIONS" -lt 4096 ] && WORKER_CONNECTIONS=4096
else
    # Nginx 1.10 미만은 보수적 설정
    [ "$WORKER_CONNECTIONS" -gt 4096 ] && WORKER_CONNECTIONS=4096
    [ "$WORKER_CONNECTIONS" -lt 1024 ] && WORKER_CONNECTIONS=1024
fi
log_debug "WORKER_CONNECTIONS=$WORKER_CONNECTIONS, MAX_CONNECTIONS=$MAX_CONNECTIONS"

# 설정 파일 생성
OUTPUT_DIR="$BASE_DIR/tmp_conf"
mkdir -p "$OUTPUT_DIR" || {
    log_debug "tmp_conf 디렉터리 생성 실패"
    echo "오류: 출력 디렉터리($OUTPUT_DIR) 생성 실패" >&2
    exit 1
}
cat > "$OUTPUT_DIR/nginx_config.conf" << EOF
worker_rlimit_nofile 65536;
worker_processes auto;
events {
    worker_connections $WORKER_CONNECTIONS;
}
EOF

log_debug "nginx_config.conf 생성 완료: $OUTPUT_DIR/nginx_config.conf"
log_debug "nginx_config.conf 내용: $(cat "$OUTPUT_DIR/nginx_config.conf" 2>/dev/null || echo '읽기 실패')"
echo "NGINX_CONFIG=success" >> "$BASE_DIR/logs/tuning_status.log"
echo "Nginx 설정이 $OUTPUT_DIR/nginx_config.conf에 저장되었습니다."