#!/bin/bash

# generate_tuning_report.sh
# 주요 로그와 추천 설정을 간단한 HTML 보고서로 정리합니다.

BASE_DIR="${BASE_DIR:-/usr/local/src/iteasy_tuning}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$BASE_DIR/scripts}"
source "$SCRIPTS_DIR/common.sh"
source "$SCRIPTS_DIR/lib/kv_parser.sh"

REPORT_FILE="$RUNTIME_LOG_DIR/tuning_report.html"
SERVICE_LOG_PATH="$SERVICE_LOG"
STATUS_LOG_PATH="$TUNING_STATUS_LOG"
APACHE_CONF="$TMP_CONF_DIR/apache_tuning.conf"
MYSQL_CONF="$TMP_CONF_DIR/mysql_tuning.cnf"

html_escape() {
    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

section_file() {
    local title="$1" file="$2"
    printf '<h2>%s</h2>\n' "$title"
    if [ -f "$file" ] && [ -s "$file" ]; then
        printf '<pre>%s</pre>\n' "$(html_escape < "$file")"
    else
        printf '<p><em>파일을 찾을 수 없습니다: %s</em></p>\n' "$file"
    fi
}

{
    printf '<!DOCTYPE html>\n<html lang="ko">\n<head><meta charset="utf-8"><title>ITEasy Tuning Report</title></head><body>'
    printf '<h1>튜닝 실행 보고서</h1>'
    printf '<p>생성 시각: %s</p>' "$(date '+%Y-%m-%d %H:%M:%S')"

    section_file "서비스 탐지 결과" "$SERVICE_LOG_PATH"
    section_file "단계 실행 로그" "$STATUS_LOG_PATH"
    section_file "Apache 추천 설정" "$APACHE_CONF"
    section_file "MySQL/MariaDB 추천 설정" "$MYSQL_CONF"

    printf '</body></html>'
} > "$REPORT_FILE"

log_info "튜닝 보고서를 생성했습니다" "report" "$(json_kv path "$REPORT_FILE")"
