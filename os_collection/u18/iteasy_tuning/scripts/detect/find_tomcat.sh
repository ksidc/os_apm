#!/bin/bash

# find_tomcat.sh
# Tomcat 실행 경로, 설정 파일, 포트, 동작 여부 탐지
# common.sh 사용, 결과는 service_paths.log에 저장
# 수정: PID 기반으로 catalina.base와 server.xml에서 포트 감지, TOMCAT_PORT_<idx> 추가

SCRIPTS_DIR="/usr/local/src/iteasy_tuning/scripts"
if [ ! -f "$SCRIPTS_DIR/common.sh" ]; then
    log_debug "오류: 공통 스크립트($SCRIPTS_DIR/common.sh)가 존재하지 않습니다."
    exit 1
fi
source "$SCRIPTS_DIR/common.sh"

log_debug "find_tomcat.sh 시작"

# 변수 초기화
TOMCAT_BINARY=""
TOMCAT_CONF=""
TOMCAT_RUNNING=0
TOMCAT_SERVICE=""
MULTIPLE_TOMCAT_FOUND=0
TOMCAT_BINARY_LIST=""
declare -A TOMCAT_RUNNING_STATUS TOMCAT_BASE_DIRS TOMCAT_PORTS

# 에러 핸들링 및 출력 저장
trap 'echo -e "$OUTPUT" >> /usr/local/src/iteasy_tuning/logs/service_paths.log; log_debug "find_tomcat.sh 비정상 종료, 출력 저장: $OUTPUT"; exit 1' ERR

# server.xml에서 포트 추출 함수
get_tomcat_port() {
    local server_xml="$1"
    if [ -f "$server_xml" ] && [ -r "$server_xml" ]; then
        port=$(grep -A 10 '<Connector ' "$server_xml" | grep -o 'port="[0-9]*"' | head -1 | cut -d'"' -f2)
        echo "${port:-8080}"
    else
        echo "8080"
    fi
}

# Tomcat 탐지
log_debug "Tomcat 탐지 시작"
TOMCAT_BINS=()
TOMCAT_BINS+=($(find -L /usr /var /opt /usr/local /usr/local/src /var/www -type f -name "catalina.sh" -executable 2>/dev/null | while read -r bin; do realpath "$bin" 2>/dev/null || echo "$bin"; done))
log_debug "find 명령 출력: $(find -L /usr /var /opt /usr/local /usr/local/src /var/www -type f -name 'catalina.sh' -executable 2>/dev/null)"
for bin in "${TOMCAT_BINS[@]}"; do
    log_debug "바이너리 권한 확인: $(ls -l "$bin" 2>/dev/null || echo '권한 확인 실패')"
done
TOMCAT_PIDS=($(ps aux | grep "[o]rg\.apache\.catalina" | grep -v grep | awk '{print $2}'))
log_debug "탐지된 Tomcat PID: ${TOMCAT_PIDS[*]}"

# PID 기반으로 catalina.base와 포트 감지
declare -A UNIQUE_CATALINA_BASES
for pid in "${TOMCAT_PIDS[@]}"; do
    cmdline=$(tr '\0' ' ' < /proc/"$pid"/cmdline 2>/dev/null)
    catalina_base=$(echo "$cmdline" | grep -oP '(?<=-Dcatalina\.base=)[^\s]+')
    log_debug "Tomcat PID $pid, cmdline=$cmdline, catalina.base=$catalina_base"
    if [ -n "$catalina_base" ] && [ -d "$catalina_base" ]; then
        catalina_sh="$catalina_base/bin/catalina.sh"
        server_xml="$catalina_base/conf/server.xml"
        log_debug "catalina.sh 경로 확인: $catalina_sh, 존재 여부: $([ -f "$catalina_sh" ] && echo '있음' || echo '없음'), 실행 가능 여부: $([ -x "$catalina_sh" ] && echo '가능' || echo '불가')"
        if [ -f "$catalina_sh" ] && [ -x "$catalina_sh" ] && [ -z "${UNIQUE_CATALINA_BASES[$catalina_base]}" ]; then
            catalina_sh_real=$(realpath "$catalina_sh" 2>/dev/null || echo "$catalina_sh")
            UNIQUE_CATALINA_BASES["$catalina_base"]="$catalina_sh_real"
            log_debug "Tomcat 인스턴스 추가: $catalina_sh_real (catalina.base=$catalina_base)"
            TOMCAT_PORTS["$catalina_base"]=$(get_tomcat_port "$server_xml")
            log_debug "Tomcat 포트 감지: $catalina_base -> port=${TOMCAT_PORTS[$catalina_base]}"
        else
            log_debug "catalina.sh 접근 실패: $catalina_sh"
        fi
    else
        log_debug "catalina.base 비어 있거나 디렉터리 아님: $catalina_base"
    fi
done
TOMCAT_BINS=("${UNIQUE_CATALINA_BASES[@]}")
TOMCAT_BINS=($(printf "%s\n" "${TOMCAT_BINS[@]}" | sort -u))
log_debug "최종 탐지된 Tomcat 바이너리: ${TOMCAT_BINS[*]}"

if [ ${#TOMCAT_BINS[@]} -gt 1 ]; then
    MULTIPLE_TOMCAT_FOUND=${#TOMCAT_BINS[@]}
    log_debug "Tomcat: 다중 설치 발견 (${MULTIPLE_TOMCAT_FOUND}개)"
    TOMCAT_BINARY_LIST=$(printf "%s\n" "${TOMCAT_BINS[@]}" | tr '\n' ';')
    for i in "${!TOMCAT_BINS[@]}"; do
        bin="${TOMCAT_BINS[$i]}"
        TOMCAT_RUNNING_STATUS[$i]=0
        base_dir=$(dirname "$(dirname "$bin")")
        base_dir=$(realpath "$base_dir" 2>/dev/null || echo "$base_dir")
        TOMCAT_BASE_DIRS[$i]="$base_dir"
        TOMCAT_PORTS[$i]=${TOMCAT_PORTS[$base_dir]:-8080}
        for pid in "${TOMCAT_PIDS[@]}"; do
            cmdline=$(tr '\0' ' ' < /proc/"$pid"/cmdline 2>/dev/null)
            proc_base=$(echo "$cmdline" | grep -oP '(?<=-Dcatalina\.base=)[^\s]+')
            log_debug "Tomcat PID $pid, proc_base=$proc_base, 비교 대상=$base_dir"
            if [ -n "$proc_base" ] && [ "$proc_base" = "$base_dir" ]; then
                TOMCAT_RUNNING_STATUS[$i]=1
                TOMCAT_RUNNING=1
                log_debug "Tomcat 인스턴스 $((i+1)) 실행 중 (PID: $pid, catalina.base=$base_dir, port=${TOMCAT_PORTS[$i]})"
                break
            fi
        done
    done
    TOMCAT_BINARY="${TOMCAT_BINS[0]}"
    TOMCAT_CONF=$(dirname "${TOMCAT_BINS[0]}")/../conf/server.xml
    TOMCAT_CONF=$(realpath "$TOMCAT_CONF" 2>/dev/null || echo "")
    TOMCAT_PORT="${TOMCAT_PORTS[0]}"
    log_debug "첫 번째 Tomcat 바이너리 선택: $TOMCAT_BINARY, conf=$TOMCAT_CONF, port=$TOMCAT_PORT"
elif [ ${#TOMCAT_BINS[@]} -eq 1 ]; then
    TOMCAT_BINARY="${TOMCAT_BINS[0]}"
    TOMCAT_RUNNING_STATUS[0]=0
    base_dir=$(dirname "$(dirname "${TOMCAT_BINS[0]}")")
    base_dir=$(realpath "$base_dir" 2>/dev/null || echo "$base_dir")
    TOMCAT_BASE_DIRS[0]="$base_dir"
    TOMCAT_CONF="$base_dir/conf/server.xml"
    TOMCAT_PORT=$(get_tomcat_port "$TOMCAT_CONF")
    TOMCAT_PORTS[0]="$TOMCAT_PORT"
    for pid in "${TOMCAT_PIDS[@]}"; do
        cmdline=$(tr '\0' ' ' < /proc/"$pid"/cmdline 2>/dev/null)
        proc_base=$(echo "$cmdline" | grep -oP '(?<=-Dcatalina\.base=)[^\s]+')
        log_debug "Tomcat PID $pid, proc_base=$proc_base, 비교 대상=$base_dir"
        if [ -n "$proc_base" ] && [ "$proc_base" = "$base_dir" ]; then
            TOMCAT_RUNNING_STATUS[0]=1
            TOMCAT_RUNNING=1
            log_debug "Tomcat 단일 인스턴스 실행 중 (PID: $pid, catalina.base=$base_dir, port=$TOMCAT_PORT)"
            break
        fi
    done
    log_debug "단일 Tomcat 바이너리 선택: $TOMCAT_BINARY, conf=$TOMCAT_CONF, port=$TOMCAT_PORT"
fi

# 서비스 상태 확인
if [ -n "$TOMCAT_BINARY" ]; then
    TOMCAT_PIDS=($(ps aux | grep "[o]rg\.apache\.catalina" | grep -v grep | awk '{print $2}'))
    TOMCAT_SERVICE=$(check_service_status "Tomcat" "tomcat tomcat7 tomcat8 tomcat9" "$TOMCAT_BINARY" "${TOMCAT_PIDS[@]}" "[o]rg\.apache\.catalina")
    if [ -n "$TOMCAT_SERVICE" ] || [ ${#TOMCAT_PIDS[@]} -gt 0 ]; then
        TOMCAT_RUNNING=1
    fi
    log_debug "Tomcat 서비스: $TOMCAT_SERVICE, 실행 여부: $TOMCAT_RUNNING"
fi

# 버전 확인
if [ -n "$TOMCAT_BINARY" ]; then
    TOMCAT_VERSION_RAW=$("$TOMCAT_BINARY" version 2>/dev/null | grep -i "Server version" || echo "")
    TOMCAT_VERSION=$(echo "$TOMCAT_VERSION_RAW" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "")
    log_debug "Tomcat 버전 원본: $TOMCAT_VERSION_RAW, 파싱된 버전: $TOMCAT_VERSION"
fi

# 결과 출력
OUTPUT="# Tomcat\n"
if [ $MULTIPLE_TOMCAT_FOUND -gt 1 ]; then
    for i in "${!TOMCAT_BINS[@]}"; do
        bin="${TOMCAT_BINS[$i]}"
        base_dir="${TOMCAT_BASE_DIRS[$i]}"
        conf=$(find -L "$base_dir" -type f -name "server.xml" -path "*/conf/*" 2>/dev/null | head -1)
        port="${TOMCAT_PORTS[$i]}"
        log_debug "Tomcat 인스턴스 $((i+1)): conf=$conf, port=$port"
        if [ -z "$conf" ]; then
            conf=""
            log_debug "Tomcat 인스턴스 $((i+1)): 유효한 설정 파일 탐지 실패, conf 비움"
        fi
        OUTPUT+="TOMCAT_BINARY_$((i+1))=$bin\n"
        OUTPUT+="TOMCAT_CONF_$((i+1))=$conf\n"
        OUTPUT+="TOMCAT_PORT_$((i+1))=$port\n"
        OUTPUT+="TOMCAT_RUNNING_$((i+1))=${TOMCAT_RUNNING_STATUS[$i]}\n"
        OUTPUT+="TOMCAT_BASE_DIR_$((i+1))=$base_dir\n"
    done
else
#########0806 start
    OUTPUT+="TOMCAT_BINARY_1=$TOMCAT_BINARY\n"
    OUTPUT+="TOMCAT_CONF_1=$TOMCAT_CONF\n"
    OUTPUT+="TOMCAT_PORT_1=$TOMCAT_PORT\n"
    OUTPUT+="TOMCAT_RUNNING_1=$TOMCAT_RUNNING\n"
    OUTPUT+="TOMCAT_BASE_DIR_1=${TOMCAT_BASE_DIRS[0]}\n"
#########end
fi
OUTPUT+="TOMCAT_SERVICE=$TOMCAT_SERVICE\n"
OUTPUT+="MULTIPLE_TOMCAT_FOUND=$MULTIPLE_TOMCAT_FOUND\n"
OUTPUT+="TOMCAT_BINARY_LIST=$TOMCAT_BINARY_LIST\n"
echo -e "$OUTPUT"
