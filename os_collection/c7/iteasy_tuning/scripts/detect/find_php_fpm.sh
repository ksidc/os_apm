#!/bin/bash

# find_php_fpm.sh
# PHP-FPM 실행 경로, 설정 파일, 동작 여부 탐지
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
log_debug "find_php_fpm.sh 시작"

# 변수 초기화
PHP_FPM_BINARY=""
PHP_FPM_CONF=""
PHP_FPM_RUNNING=0
PHP_FPM_SERVICE=""
MULTIPLE_PHP_FPM_FOUND=0
PHP_FPM_BINARY_LIST=""
declare -A PHP_FPM_RUNNING_STATUS

# PHP-FPM 탐지
log_debug "PHP-FPM 탐지 시작"
PHP_FPM_BINS=($(find_binaries "PHP-FPM" "php-fpm" "PHP" "[p]hp-fpm: master"))
if [ ${#PHP_FPM_BINS[@]} -gt 1 ]; then
    MULTIPLE_PHP_FPM_FOUND=${#PHP_FPM_BINS[@]}
    log_debug "PHP-FPM: 다중 설치 발견 (${MULTIPLE_PHP_FPM_FOUND}개)"
    PHP_FPM_BINARY_LIST=$(printf "%s\n" "${PHP_FPM_BINS[@]}" | tr '\n' ';')
    for i in "${!PHP_FPM_BINS[@]}"; do
        bin=$(realpath "${PHP_FPM_BINS[$i]}" 2>/dev/null)
        PHP_FPM_RUNNING_STATUS[$i]=0
        for pid in "${PHP_FPM_PIDS[@]}"; do
            proc_bin=$(realpath "/proc/$pid/exe" 2>/dev/null)
            log_debug "PHP-FPM PID $pid, proc_bin=$proc_bin, 비교 대상=$bin"
            if [ "$proc_bin" = "$bin" ]; then
                PHP_FPM_RUNNING_STATUS[$i]=1
                PHP_FPM_RUNNING=1
                log_debug "PHP-FPM 인스턴스 $((i+1)) 실행 중 (PID: $pid)"
                break
            fi
        done
    done
    PHP_FPM_BINARY="${PHP_FPM_BINS[0]}"
    log_debug "첫 번째 PHP-FPM 바이너리 선택: ${PHP_FPM_BINS[0]}"
elif [ ${#PHP_FPM_BINS[@]} -eq 1 ]; then
    PHP_FPM_BINARY="${PHP_FPM_BINS[0]}"
    PHP_FPM_RUNNING_STATUS[0]=0
    bin=$(realpath "${PHP_FPM_BINS[0]}" 2>/dev/null)
    for pid in "${PHP_FPM_PIDS[@]}"; do
        proc_bin=$(realpath "/proc/$pid/exe" 2>/dev/null)
        log_debug "PHP-FPM PID $pid, proc_bin=$proc_bin, 비교 대상=$bin"
        if [ "$proc_bin" = "$bin" ]; then
            PHP_FPM_RUNNING_STATUS[0]=1
            PHP_FPM_RUNNING=1
            log_debug "PHP-FPM 단일 인스턴스 실행 중 (PID: $pid)"
            break
        fi
    done
    log_debug "단일 PHP-FPM 바이너리 선택: ${PHP_FPM_BINS[0]}"
fi
if [ -n "$PHP_FPM_BINARY" ]; then
    PHP_FPM_CONF=$("$PHP_FPM_BINARY" -t 2>&1 | grep 'configuration file' | awk '{print $NF}' || echo "")
    if [ -z "$PHP_FPM_CONF" ] || [ ! -f "$PHP_FPM_CONF" ]; then
        PHP_FPM_CONF=$(find /etc/php-fpm.d /etc/php /usr/local/etc/php-fpm.d -type f -name "www.conf" -o -name "php-fpm.conf" 2>/dev/null | head -1)
        log_debug "PHP-FPM conf fallback 검색: $PHP_FPM_CONF"
    fi
    if [ -d "$PHP_FPM_CONF" ]; then
        PHP_FPM_CONF=$(find "$PHP_FPM_CONF" -type f -name "php-fpm.conf" | head -1)
        [ -z "$PHP_FPM_CONF" ] && PHP_FPM_CONF=""
        log_debug "PHP-FPM: 유효한 설정 파일 탐지 실패, PHP_FPM_CONF 비움"
    fi
    PHP_FPM_PIDS=($(find_pids "PHP-FPM" "[p]hp-fpm: master"))
    PHP_FPM_SERVICE=$(check_service_status "PHP-FPM" "php-fpm" "$PHP_FPM_BINARY" PHP_FPM_PIDS[@] "[p]hp-fpm: master")
    if [ -n "$PHP_FPM_SERVICE" ] || [ ${#PHP_FPM_PIDS[@]} -gt 0 ]; then
        PHP_FPM_RUNNING=1
        PHP_FPM_RUNNING_STATUS[0]=1
        SERVICE_RUNNING["PHP_FPM_RUNNING"]=1
    fi
    log_debug "PHP-FPM 서비스: $PHP_FPM_SERVICE, 실행 여부: $PHP_FPM_RUNNING"
fi

# 결과 출력
OUTPUT="# PHP-FPM\n"
if [ $MULTIPLE_PHP_FPM_FOUND -gt 1 ]; then
    for i in "${!PHP_FPM_BINS[@]}"; do
        bin=${PHP_FPM_BINS[$i]}
        conf=$("$bin" -t 2>&1 | grep 'configuration file' | awk '{print $NF}' || echo "")
        if [ -z "$conf" ] || [ ! -f "$conf" ]; then
            conf=$(find /etc/php-fpm.d /etc/php /usr/local/etc/php-fpm.d -type f -name "www.conf" -o -name "php-fpm.conf" 2>/dev/null | head -1)
        fi
        if [ -d "$conf" ]; then
            conf=$(find "$conf" -type f -name "php-fpm.conf" | head -1)
            [ -z "$conf" ] && conf=""
        fi
        OUTPUT+="PHP_FPM_BINARY_$((i+1))=$bin\n"
        OUTPUT+="PHP_FPM_CONF_$((i+1))=$conf\n"
        OUTPUT+="PHP_FPM_RUNNING_$((i+1))=${PHP_FPM_RUNNING_STATUS[$i]}\n"
    done
else
    OUTPUT+="PHP_FPM_BINARY=$PHP_FPM_BINARY\n"
    OUTPUT+="PHP_FPM_CONF=$PHP_FPM_CONF\n"
    OUTPUT+="PHP_FPM_RUNNING=$PHP_FPM_RUNNING\n"
fi
OUTPUT+="PHP_FPM_SERVICE=$PHP_FPM_SERVICE\n"
OUTPUT+="MULTIPLE_PHP_FPM_FOUND=$MULTIPLE_PHP_FPM_FOUND\n"
OUTPUT+="PHP_FPM_BINARY_LIST=$PHP_FPM_BINARY_LIST\n"
echo -e "$OUTPUT"