#!/bin/bash
# modules/find_services.sh (fixed)
# - MySQL/MariaDB는 통합 스크립트(find_mysql_mariadb.sh)를 한 번만 실행
# - 기존 apache/nginx/tomcat/php/php_fpm 탐지는 그대로 유지
# - 결과는 service_paths.log에 저장

BASE_DIR="/usr/local/src/iteasy_tuning"
LOG_DIR="$BASE_DIR/logs"
SERVICE_LOG="$LOG_DIR/service_paths.log"
FALLBACK_LOG_DIR="/tmp/iteasy_tuning_logs"
FALLBACK_SERVICE_LOG="$FALLBACK_LOG_DIR/service_paths.log"
SCRIPTS_DIR="$BASE_DIR/scripts"
DETECT_DIR="$SCRIPTS_DIR/detect"

# 공통 함수
if [ ! -f "$SCRIPTS_DIR/common.sh" ]; then
    echo "오류: 공통 스크립트($SCRIPTS_DIR/common.sh)가 존재하지 않습니다." >&2
    exit 1
fi
source "$SCRIPTS_DIR/common.sh"

setup_logging
if ! mkdir -p "$LOG_DIR" 2>/dev/null; then
    log_debug "오류: 로그 디렉터리($LOG_DIR) 생성 실패, 대체 경로($FALLBACK_LOG_DIR) 사용"
    mkdir -p "$FALLBACK_LOG_DIR" || {
        FALLBACK_LOG_DIR="/var/log/iteasy_tuning"
        mkdir -p "$FALLBACK_LOG_DIR" || { log_debug "오류: 최종 대체 로그 디렉터리($FALLBACK_LOG_DIR) 생성 실패"; exit 1; }
    }
    SERVICE_LOG="$FALLBACK_SERVICE_LOG"
fi
if ! touch "$SERVICE_LOG" 2>/dev/null; then
    log_debug "오류: 로그 파일($SERVICE_LOG) 생성 실패, 대체 경로($FALLBACK_SERVICE_LOG) 사용"
    SERVICE_LOG="$FALLBACK_SERVICE_LOG"
    touch "$SERVICE_LOG" || {
        SERVICE_LOG="/var/log/iteasy_tuning/service_paths.log"
        touch "$SERVICE_LOG" || { log_debug "오류: 최종 대체 로그 파일($SERVICE_LOG) 생성 실패"; exit 1; }
    }
fi
chmod 600 "$SERVICE_LOG" 2>/dev/null || log_debug "경고: $SERVICE_LOG 권한 설정 실패"
log_debug "find_services.sh 시작(fixed): SERVICE_LOG=$SERVICE_LOG"

OUTPUT=""

# 1) Apache / Nginx / Tomcat / PHP / PHP-FPM : 기존 방식
for service in apache nginx tomcat php php_fpm; do
    script="$DETECT_DIR/find_${service}.sh"
    if [ ! -f "$script" ]; then
        log_debug "경고: $service 스크립트($script) 누락, 스킵"
        continue
    fi
    chmod +x "$script" 2>/dev/null || { log_debug "오류: $script 실행 권한 설정 실패, 스킵"; continue; }
    log_debug "$service 탐지 스크립트 실행: $script"
    result=$("$script" 2>>"$DEBUG_LOG")
    if [ -n "$result" ]; then
        OUTPUT+="$result\n"
        log_debug "$service 탐지 결과: $result"
    else
        log_debug "경고: $service 탐지 결과 없음"
    fi
done

# 2) MySQL + MariaDB : 통합 스크립트를 '한 번만' 실행
mm_script="$DETECT_DIR/find_mysql_mariadb.sh"
if [ -f "$mm_script" ]; then
    chmod +x "$mm_script" 2>/dev/null || log_debug "경고: $mm_script 실행 권한 설정 실패"
    log_debug "mysql/mariadb 통합 탐지 스크립트 실행: $mm_script"
    mm_result=$("$mm_script" 2>>"$DEBUG_LOG")
    if [ -n "$mm_result" ]; then
        OUTPUT+="$mm_result\n"
        log_debug "mysql/mariadb 탐지 결과: $mm_result"
    else
        log_debug "경고: mysql/mariadb 탐지 결과 없음"
    fi
else
    # 구형 레이아웃 대비: 개별 스크립트가 있으면 각각 실행
    for svc in mysql mariadb; do
        leg_script="$DETECT_DIR/find_${svc}.sh"
        if [ -f "$leg_script" ]; then
            chmod +x "$leg_script" 2>/dev/null || { log_debug "오류: $leg_script 실행 권한 설정 실패, 스킵"; continue; }
            log_debug "$svc 탐지 스크립트 실행(레거시): $leg_script"
            res=$("$leg_script" 2>>"$DEBUG_LOG")
            [ -n "$res" ] && OUTPUT+="$res\n"
        else
            log_debug "오류: $svc 탐지 스크립트($leg_script) 없음"
        fi
    done
fi

# 3) 저장
if [ -n "$OUTPUT" ]; then
    echo -e "$OUTPUT" | grep -v '^$' > "$SERVICE_LOG" || { log_debug "오류: $SERVICE_LOG 쓰기 실패"; exit 1; }
    chmod 600 "$SERVICE_LOG" 2>/dev/null || log_debug "경고: $SERVICE_LOG 권한 설정 실패"
    log_debug "결과 저장 완료: $SERVICE_LOG, 내용: $(cat "$SERVICE_LOG" 2>/dev/null || echo '읽기 실패')"
else
    log_debug "경고: 탐지된 서비스 없음, 빈 로그 파일 생성"
    : > "$SERVICE_LOG"
fi