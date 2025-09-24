#!/bin/bash

# find_nginx.sh
# Nginx 실행 경로, 설정 파일, 동작 여부 탐지
# common.sh의 공통 함수 사용, 결과는 find_services.sh에서 통합 저장
# 수정: echo를 log_debug로 대체, get_user_input 호출 제거

# 공통 함수 로드
SCRIPTS_DIR="/usr/local/src/iteasy_tuning/scripts"
if [ ! -f "$SCRIPTS_DIR/common.sh" ]; then
    log_debug "오류: 공통 스크립트($SCRIPTS_DIR/common.sh)가 존재하지 않습니다."
    exit 1
fi
source "$SCRIPTS_DIR/common.sh"

# 로깅 설정
log_debug "find_nginx.sh 시작"

# 변수 초기화
NGINX_BINARY=""
NGINX_CONF=""
NGINX_RUNNING=0
NGINX_SERVICE=""
MULTIPLE_NGINX_FOUND=0
NGINX_BINARY_LIST=""
declare -A NGINX_RUNNING_STATUS

# Nginx 탐지
log_debug "Nginx 탐지 시작"
NGINX_BINS=($(find_binaries "Nginx" "nginx" "" "[n]ginx: master"))
if [ ${#NGINX_BINS[@]} -gt 1 ]; then
    MULTIPLE_NGINX_FOUND=${#NGINX_BINS[@]}
    log_debug "Nginx: 다중 설치 발견 (${MULTIPLE_NGINX_FOUND}개)"
    NGINX_BINARY_LIST=$(printf "%s\n" "${NGINX_BINS[@]}" | tr '\n' ';')
    for i in "${!NGINX_BINS[@]}"; do
        bin=$(realpath "${NGINX_BINS[$i]}" 2>/dev/null)
        NGINX_RUNNING_STATUS[$i]=0
        for pid in "${NGINX_PIDS[@]}"; do
            proc_bin=$(realpath "/proc/$pid/exe" 2>/dev/null)
            log_debug "Nginx PID $pid, proc_bin=$proc_bin, 비교 대상=$bin"
            if [ "$proc_bin" = "$bin" ]; then
                NGINX_RUNNING_STATUS[$i]=1
                NGINX_RUNNING=1
                log_debug "Nginx 인스턴스 $((i+1)) 실행 중 (PID: $pid)"
                break
            fi
        done
    done
    NGINX_BINARY="${NGINX_BINS[0]}"
    log_debug "첫 번째 Nginx 바이너리 선택: ${NGINX_BINS[0]}"
elif [ ${#NGINX_BINS[@]} -eq 1 ]; then
    NGINX_BINARY="${NGINX_BINS[0]}"
    NGINX_RUNNING_STATUS[0]=0
    bin=$(realpath "${NGINX_BINS[0]}" 2>/dev/null)
    for pid in "${NGINX_PIDS[@]}"; do
        proc_bin=$(realpath "/proc/$pid/exe" 2>/dev/null)
        log_debug "Nginx PID $pid, proc_bin=$proc_bin, 비교 대상=$bin"
        if [ "$proc_bin" = "$bin" ]; then
            NGINX_RUNNING_STATUS[0]=1
            NGINX_RUNNING=1
            log_debug "Nginx 단일 인스턴스 실행 중 (PID: $pid)"
            break
        fi
    done
    log_debug "단일 Nginx 바이너리 선택: ${NGINX_BINS[0]}"
fi
if [ -n "$NGINX_BINARY" ]; then
    NGINX_CONF=$(find_config "Nginx" "$NGINX_BINARY" "nginx.conf" "\"$NGINX_BINARY\" -t | grep 'configuration file' | awk '{print \$NF}'")
    if [ -d "$NGINX_CONF" ]; then
        NGINX_CONF=$(find "$NGINX_CONF" -type f -name "nginx.conf" | head -1)
        [ -z "$NGINX_CONF" ] && NGINX_CONF=""
        log_debug "Nginx: 유효한 설정 파일 탐지 실패, NGINX_CONF 비움"
    fi
    NGINX_PIDS=($(find_pids "Nginx" "[n]ginx: master"))
    NGINX_SERVICE=$(check_service_status "Nginx" "nginx" "$NGINX_BINARY" NGINX_PIDS[@] "[n]ginx: master")
    if [ -n "$NGINX_SERVICE" ] || [ ${#NGINX_PIDS[@]} -gt 0 ]; then
        NGINX_RUNNING=1
        NGINX_RUNNING_STATUS[0]=1
    fi
    log_debug "Nginx 서비스: $NGINX_SERVICE, 실행 여부: $NGINX_RUNNING"
fi

# 결과 출력
OUTPUT="# Nginx\n"
if [ $MULTIPLE_NGINX_FOUND -gt 1 ]; then
    for i in "${!NGINX_BINS[@]}"; do
        bin=${NGINX_BINS[$i]}
        conf=$(find_config "Nginx" "$bin" "nginx.conf" "\"$bin\" -t | grep 'configuration file' | awk '{print \$NF}'")
        if [ -d "$conf" ]; then
            conf=$(find "$conf" -type f -name "nginx.conf" | head -1)
            [ -z "$conf" ] && conf=""
        fi
        OUTPUT+="NGINX_BINARY_$((i+1))=$bin\n"
        OUTPUT+="NGINX_CONF_$((i+1))=$conf\n"
        OUTPUT+="NGINX_RUNNING_$((i+1))=${NGINX_RUNNING_STATUS[$i]}\n"
    done
else
    OUTPUT+="NGINX_BINARY=$NGINX_BINARY\n"
    OUTPUT+="NGINX_CONF=$NGINX_CONF\n"
    OUTPUT+="NGINX_RUNNING=$NGINX_RUNNING\n"
fi
OUTPUT+="NGINX_SERVICE=$NGINX_SERVICE\n"
OUTPUT+="MULTIPLE_NGINX_FOUND=$MULTIPLE_NGINX_FOUND\n"
OUTPUT+="NGINX_BINARY_LIST=$NGINX_BINARY_LIST\n"
echo -e "$OUTPUT"