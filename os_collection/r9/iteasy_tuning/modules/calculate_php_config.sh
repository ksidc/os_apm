#!/bin/bash
# calculate_php_config.sh
# PHP 설정 계산 및 단일 php_config.ini 생성 (다중 설치 지원)
# 수정: mod_php 실행 여부 확인 제거, service_paths.log에서 PHP_CONF_N으로 다중 인스턴스 감지
# 단일 출력 파일: php_config.ini
# 고정 설정: short_open_tag=On, date.timezone=Asia/Seoul, upload_max_filesize=100M, post_max_size=100M
BASE_DIR="/usr/local/src/iteasy_tuning"
SCRIPTS_DIR="$BASE_DIR/scripts"
if [ ! -f "$SCRIPTS_DIR/common.sh" ]; then
    echo "오류: 공통 스크립트($SCRIPTS_DIR/common.sh)가 존재하지 않습니다." >&2
    exit 1
fi
source "$SCRIPTS_DIR/common.sh"
setup_logging
log_debug "calculate_php_config.sh 시작"
if [ -f "$BASE_DIR/logs/service_paths.log" ]; then
    source "$BASE_DIR/logs/service_paths.log" 2>/dev/null || {
        log_debug "service_paths.log 로드 실패"
        echo "오류: service_paths.log 로드 실패" >&2
        exit 1
    }
else
    log_debug "service_paths.log 파일 없음"
    echo "오류: service_paths.log 파일 없음" >&2
    exit 1
fi
PHP_CONF_LIST=()
if grep -q '^PHP_CONF_' "$BASE_DIR/logs/service_paths.log"; then
    while IFS='=' read -r key val; do
        if [[ $key =~ ^PHP_CONF_([0-9]+)$ ]]; then
            [ -n "$val" ] && PHP_CONF_LIST+=("$val")
        fi
    done < <(grep '^PHP_CONF_' "$BASE_DIR/logs/service_paths.log")
fi
if [ "${#PHP_CONF_LIST[@]}" -eq 0 ]; then
    log_debug "PHP 인스턴스 감지되지 않음"
    echo "오류: PHP 인스턴스가 감지되지 않아 설정을 생성할 수 없습니다." >&2
    exit 1
fi
log_debug "감지된 PHP 설정 파일: ${PHP_CONF_LIST[*]}"
OUTPUT_DIR="$BASE_DIR/tmp_conf"
mkdir -p "$OUTPUT_DIR" || {
    log_debug "tmp_conf 디렉터리 생성 실패"
    echo "오류: 출력 디렉터리($OUTPUT_DIR) 생성 실패" >&2
    exit 1
}
OUTPUT_FILE="$OUTPUT_DIR/php_config.ini"
cat > "$OUTPUT_FILE" << EOF
short_open_tag = On
date.timezone = Asia/Seoul
upload_max_filesize = 100M
post_max_size = 100M
EOF
if [ $? -ne 0 ]; then
    log_debug "php_config.ini 생성 실패"
    echo "오류: php_config.ini 생성 실패" >&2
    exit 1
fi
log_debug "php_config.ini 생성 완료: $OUTPUT_FILE"
log_debug "php_config.ini 내용: $(cat "$OUTPUT_FILE" 2>/dev/null || echo '읽기 실패')"
echo "PHP_CONFIG=success" >> "$BASE_DIR/logs/tuning_status.log"
echo "PHP 설정이 $OUTPUT_FILE에 저장되었습니다."
exit 0
