#!/bin/bash

# calculate_tomcat_config.sh
# Tomcat 설정 계산 및 tomcat_config.conf 생성 (Tomcat 7~11, JVM 옵션 버전별 분리)
# 작성: 아이티이지 (2025-07-23, 최신 정책 반영)

BASE_DIR="/usr/local/src/iteasy_tuning"
SCRIPTS_DIR="$BASE_DIR/scripts"
if [ ! -f "$SCRIPTS_DIR/common.sh" ]; then
    echo "오류: 공통 스크립트($SCRIPTS_DIR/common.sh)가 존재하지 않습니다." >&2
    exit 1
fi
source "$SCRIPTS_DIR/common.sh"

log_debug "calculate_tomcat_config.sh 시작"

# Tomcat 관련 환경 변수 로드
if [ -f "$BASE_DIR/logs/service_paths.log" ]; then
    grep -E '^TOMCAT_RUNNING_[0-9]=|^TOMCAT_BINARY_[0-9]=' "$BASE_DIR/logs/service_paths.log" > /tmp/tomcat_service_paths.log
    source /tmp/tomcat_service_paths.log 2>/dev/null || {
        log_debug "service_paths.log에서 Tomcat 관련 변수 로드 실패"
        rm -f /tmp/tomcat_service_paths.log
        echo "오류: Tomcat 상태 로드 실패" >&2
        exit 1
    }
    rm -f /tmp/tomcat_service_paths.log
else
    log_debug "service_paths.log 파일 없음"
    exit 1
fi

# Tomcat 인스턴스 카운트
TOMCAT_COUNT=$(grep -Eo 'TOMCAT_RUNNING=1|TOMCAT_RUNNING_[0-9]=1' "$BASE_DIR/logs/service_paths.log" | wc -l)
if [ "$TOMCAT_COUNT" -eq 0 ]; then
    log_debug "Tomcat가 실행 중이 아니므로 설정 생성 생략"
    echo "오류: Tomcat가 실행 중이 아니므로 설정을 생성할 수 없습니다." >&2
    echo "TOMCAT_CONFIG=skipped" >> "$BASE_DIR/logs/tuning_status.log"
    exit 1
fi
log_debug "TOMCAT_COUNT=$TOMCAT_COUNT"

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

# Tomcat 버전 로드 (첫 번째 인스턴스 기준)
if [ -f "$BASE_DIR/logs/service_versions.log" ]; then
    grep '^TOMCAT_VERSION_1=' "$BASE_DIR/logs/service_versions.log" > /tmp/tomcat_versions.log
    sed -i -E 's/^TOMCAT_VERSION_1=.*Tomcat\/([0-9]+\.[0-9]+\.[0-9]+).*/TOMCAT_VERSION=\1/' /tmp/tomcat_versions.log
    source /tmp/tomcat_versions.log 2>/dev/null || {
        log_debug "service_versions.log에서 Tomcat 버전 로드 실패, 기본값 사용"
        TOMCAT_VERSION="7.0.0"
    }
    rm -f /tmp/tomcat_versions.log
    if [ -z "$TOMCAT_VERSION" ] || ! echo "$TOMCAT_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
        log_debug "TOMCAT_VERSION이 유효하지 않음, 기본값 사용"
        TOMCAT_VERSION="7.0.0"
    fi
else
    log_debug "service_versions.log 파일 없음, 기본값 사용"
    TOMCAT_VERSION="7.0.0"
fi

# 변수 정수 변환
TOTAL_MEMORY=$(echo "$TOTAL_MEMORY" | grep -o '[0-9]\+' || echo "1024")
CPU_CORES=$(echo "$CPU_CORES" | grep -o '[0-9]\+' || echo "1")
log_debug "TOTAL_MEMORY=$TOTAL_MEMORY MB, CPU_CORES=$CPU_CORES"

# Tomcat 버전 확인
TOMCAT_MAJOR=$(echo "$TOMCAT_VERSION" | cut -d'.' -f1)
TOMCAT_MINOR=$(echo "$TOMCAT_VERSION" | cut -d'.' -f2)
log_debug "TOMCAT_VERSION=$TOMCAT_VERSION, MAJOR=$TOMCAT_MAJOR, MINOR=$TOMCAT_MINOR"

# 서비스 조합 확인 (다중 서비스 환경 고려)
ACTIVE_SERVICES=0
if [ -f "$BASE_DIR/logs/service_paths.log" ]; then
    [ "$(grep -E 'MYSQL_RUNNING=1|MARIADB_RUNNING=1' "$BASE_DIR/logs/service_paths.log")" ] && ACTIVE_SERVICES=$((ACTIVE_SERVICES + 1))
    TOMCAT_COUNT=$(grep -o 'TOMCAT_RUNNING_[0-9]=1' "$BASE_DIR/logs/service_paths.log" | wc -l)
    ACTIVE_SERVICES=$((ACTIVE_SERVICES + TOMCAT_COUNT))
    [ "$(grep -E 'NGINX_RUNNING=1' "$BASE_DIR/logs/service_paths.log")" ] && ACTIVE_SERVICES=$((ACTIVE_SERVICES + 1))
    [ "$(grep -E 'PHP_RUNNING=1' "$BASE_DIR/logs/service_paths.log")" ] && ACTIVE_SERVICES=$((ACTIVE_SERVICES + 1))
    [ "$(grep -E 'PHP_FPM_RUNNING=1' "$BASE_DIR/logs/service_paths.log")" ] && ACTIVE_SERVICES=$((ACTIVE_SERVICES + 1))
fi
log_debug "ACTIVE_SERVICES=$ACTIVE_SERVICES, TOMCAT_COUNT=$TOMCAT_COUNT"

# 메모리 할당 (기존 공식)
TOMCAT_MEMORY_PERCENT=0
RESERVE_MEMORY_PERCENT=10
if [ "$ACTIVE_SERVICES" -eq 1 ]; then
    TOMCAT_MEMORY_PERCENT=90  # 단일 서비스
elif [ "$TOMCAT_COUNT" -eq 0 ] && [ "$ACTIVE_SERVICES" -eq 2 ]; then
    TOMCAT_MEMORY_PERCENT=45  # WAS 없음 + DB 등
elif [ "$TOMCAT_COUNT" -eq 2 ] && [ "$ACTIVE_SERVICES" -eq 4 ]; then
    TOMCAT_MEMORY_PERCENT=18  # Nginx + WAS(2) + DB
elif [ "$TOMCAT_COUNT" -eq 3 ] && [ "$ACTIVE_SERVICES" -eq 5 ]; then
    TOMCAT_MEMORY_PERCENT=13.5  # Nginx + WAS(3) + DB
elif [ "$TOMCAT_COUNT" -ge 4 ] && [ "$ACTIVE_SERVICES" -ge 6 ]; then
    TOMCAT_MEMORY_PERCENT=11.25  # Nginx + WAS(4+) + DB
else
    TOMCAT_MEMORY_PERCENT=27  # Nginx + WAS(n), DB 없음
fi

TOMCAT_MEMORY_PERCENT=$((TOMCAT_MEMORY_PERCENT / TOMCAT_COUNT))  # 인스턴스별 분배
TOMCAT_MEMORY=$((TOTAL_MEMORY * TOMCAT_MEMORY_PERCENT / 100))
[ "$TOMCAT_MEMORY" -lt 512 ] && TOMCAT_MEMORY=512
log_debug "TOMCAT_MEMORY=$TOMCAT_MEMORY MB (per instance), TOMCAT_MEMORY_PERCENT=$TOMCAT_MEMORY_PERCENT%"

# Xms, Xmx 기본 계산
XMS=$((TOMCAT_MEMORY / 4))
XMX=$((TOMCAT_MEMORY * 3 / 4))

# Tomcat 버전별 JVM 옵션 세팅

JAVA_MAJOR=$(java -version 2>&1 | awk -F[\".] '/version/ {if ($2 >= 9) print $2; else print $3}' | head -n1)
log_debug "JAVA_MAJOR=$JAVA_MAJOR"

case "$TOMCAT_MAJOR" in
    1|2|3|4|5|6|7)
        if [ "$JAVA_MAJOR" -lt 8 ]; then
            JVM_OPTS="-Xms${XMS}M -Xmx${XMX}M -XX:PermSize=$((TOMCAT_MEMORY / 16))M -XX:MaxPermSize=$((TOMCAT_MEMORY / 8))M -XX:+UseConcMarkSweepGC"
            JVM_COMMENT="# Tomcat 7 이하 + Java 7 이하: PermGen 영역 및 CMS GC"
        else
            JVM_OPTS="-Xms${XMS}M -Xmx${XMX}M -XX:MetaspaceSize=$((TOMCAT_MEMORY / 16))M -XX:MaxMetaspaceSize=$((TOMCAT_MEMORY / 8))M -XX:+UseG1GC"
            JVM_COMMENT="# Tomcat 7 이하 + Java 8 이상: Metaspace 사용"
        fi
        ;;
    8)
        JVM_OPTS="-Xms${XMS}M -Xmx${XMX}M -XX:MetaspaceSize=$((TOMCAT_MEMORY / 16))M -XX:MaxMetaspaceSize=$((TOMCAT_MEMORY / 8))M -XX:+UseG1GC"
        JVM_COMMENT="# Tomcat 8.x: Metaspace, G1GC 권장"
        ;;
    9|10|11)
        JVM_OPTS="-Xms${XMS}M -Xmx${XMX}M -XX:MetaspaceSize=$((TOMCAT_MEMORY / 16))M -XX:MaxMetaspaceSize=$((TOMCAT_MEMORY / 8))M -XX:+UseG1GC"
        JVM_COMMENT="# Tomcat 9~11.x: Metaspace, G1GC"
        ;;
    *)
        if [ "$JAVA_MAJOR" -ge 8 ]; then
            JVM_OPTS="-Xms${XMS}M -Xmx${XMX}M -XX:MetaspaceSize=$((TOMCAT_MEMORY / 16))M -XX:MaxMetaspaceSize=$((TOMCAT_MEMORY / 8))M -XX:+UseG1GC"
            JVM_COMMENT="# 기본값: Java 8 이상 감지되어 Metaspace 사용"
        else
            JVM_OPTS="-Xms${XMS}M -Xmx${XMX}M -XX:PermSize=$((TOMCAT_MEMORY / 16))M -XX:MaxPermSize=$((TOMCAT_MEMORY / 8))M -XX:+UseConcMarkSweepGC"
            JVM_COMMENT="# 기본값: Java 7 이하 감지되어 PermSize 사용"
        fi
        ;;
esac

log_debug "JVM_OPTS=$JVM_OPTS"

# Connector 설정
MAX_THREADS=$((CPU_CORES * 50)); [ "$MAX_THREADS" -gt 200 ] && MAX_THREADS=200
MIN_SPARE_THREADS=$((CPU_CORES * 5))
MAX_SPARE_THREADS=$((CPU_CORES * 20))
ACCEPT_COUNT=100
CONNECTION_TIMEOUT=20000
KEEP_ALIVE_TIMEOUT=15000
if [ "$TOMCAT_MAJOR" -ge 9 ]; then
    PROTOCOL="org.apache.coyote.http11.Http11Nio2Protocol"
else
    PROTOCOL="org.apache.coyote.http11.Http11NioProtocol"
fi
log_debug "MAX_THREADS=$MAX_THREADS, MIN_SPARE_THREADS=$MIN_SPARE_THREADS, MAX_SPARE_THREADS=$MAX_SPARE_THREADS"

# 설정 파일 생성
OUTPUT_DIR="$BASE_DIR/tmp_conf"
mkdir -p "$OUTPUT_DIR" || {
    log_debug "tmp_conf 디렉터리 생성 실패"
    echo "오류: 출력 디렉터리($OUTPUT_DIR) 생성 실패" >&2
    exit 1
}
cat > "$OUTPUT_DIR/tomcat_config.conf" << EOF
$JVM_COMMENT
# JVM 옵션 (setenv.sh 또는 catalina.sh에 추가)
JAVA_OPTS="${JVM_OPTS}"
EOF

# 포트별 Connector 반복 출력
for i in $(seq 1 "$TOMCAT_COUNT"); do
    port=$(grep "^TOMCAT_PORT_${i}=" "$BASE_DIR/logs/service_paths.log" | cut -d= -f2)
    [ -z "$port" ] && port=$((8080 + i - 1))  # fallback

    cat >> "$OUTPUT_DIR/tomcat_config.conf" << EOF

# server.xml Connector 설정 예시
<Connector port="$port" protocol="$PROTOCOL"
           maxThreads="$MAX_THREADS"
           minSpareThreads="$MIN_SPARE_THREADS"
           maxSpareThreads="$MAX_SPARE_THREADS"
           acceptCount="$ACCEPT_COUNT"
           connectionTimeout="$CONNECTION_TIMEOUT"
           keepAliveTimeout="$KEEP_ALIVE_TIMEOUT"
           compression="on"
           compressableMimeType="text/html,text/xml,text/plain,text/css,text/javascript,application/javascript,application/json"
           enableLookups="false"
           URIEncoding="UTF-8" />
EOF
done

log_debug "tomcat_config.conf 생성 완료: $OUTPUT_DIR/tomcat_config.conf"
log_debug "tomcat_config.conf 내용: $(cat "$OUTPUT_DIR/tomcat_config.conf" 2>/dev/null || echo '읽기 실패')"
echo "TOMCAT_CONFIG=success" >> "$BASE_DIR/logs/tuning_status.log"
echo "Tomcat 설정이 $OUTPUT_DIR/tomcat_config.conf에 저장되었습니다."
