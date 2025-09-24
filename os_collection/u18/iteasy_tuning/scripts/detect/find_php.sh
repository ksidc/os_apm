#!/bin/bash

# find_php.sh
# PHP 설정 파일 탐지
# 수정: php --ini 호출 제거, find로 다중 php.ini 탐지, PHP_BINARY_* 출력 제거, PHP_RUNNING_* 추가
# 출력: PHP_CONF_*, PHP_RUNNING_*만 service_paths.log에 기록
# 저장 경로: $LOG_DIR/service_paths.log

BASE_DIR="/usr/local/src/iteasy_tuning"
SCRIPTS_DIR="$BASE_DIR/scripts"
LOG_DIR="$BASE_DIR/logs"

source "$SCRIPTS_DIR/common.sh"
setup_logging

# 변수 초기화
PHP_CONF_LIST=()
log_debug "PHP 탐지 시작"

# php.ini 파일 탐지 (다중 파일 지원)
PHP_CONF_FILES=($(find /etc /usr/local /opt /usr/libexec -type f -name php.ini 2>/dev/null))

# 탐지 처리
OUTPUT="# PHP\n"
if [ ${#PHP_CONF_FILES[@]} -gt 0 ]; then
    for i in "${!PHP_CONF_FILES[@]}"; do
        conf=$(realpath "${PHP_CONF_FILES[$i]}" 2>/dev/null)
        if [ -f "$conf" ]; then
            PHP_CONF_LIST+=("$conf")
            OUTPUT+="PHP_CONF_$((i+1))=$conf\n"
            OUTPUT+="PHP_RUNNING_$((i+1))=1\n"
            log_debug "PHP 인스턴스 $((i+1)): 설정 파일=$conf, 실행 여부 강제 설정: PHP_RUNNING_$((i+1))=1"
        else
            log_debug "PHP 인스턴스 $((i+1)): 유효한 설정 파일 없음 - $conf"
        fi
    done
else
    log_debug "PHP 설정 파일 탐지 결과 없음"
    echo "오류: PHP 설정 파일이 감지되지 않았습니다." >&2
    exit 1
fi

if [ ${#PHP_CONF_LIST[@]} -eq 0 ]; then
    log_debug "PHP 인스턴스 감지되지 않음"
    echo "오류: PHP 설정 파일이 감지되지 않았습니다." >&2
    exit 1
fi

echo -e "$OUTPUT"
