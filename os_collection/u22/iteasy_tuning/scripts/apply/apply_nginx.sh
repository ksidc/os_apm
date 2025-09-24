#!/bin/bash

# apply_nginx.sh
# Nginx 설정 파일을 적용
# 단일 인스턴스 환경에서 자동 적용, 문법 검사, 사용자 입력 프롬프트 제거
# 수정: 자동 적용, 프롬프트 제거, 경로 정규화

BASE_DIR="/usr/local/src/iteasy_tuning"
LOG_DIR="$BASE_DIR/logs"
TMP_CONF_DIR="$BASE_DIR/tmp_conf"
BACKUP_DIR="$BASE_DIR/backups"
ERR_CONF_DIR="$BASE_DIR/err_conf"
SERVICE_PATHS="$LOG_DIR/service_paths.log"
SCRIPTS_DIR="$BASE_DIR/scripts"

source "$SCRIPTS_DIR/common.sh"
setup_logging

APPLY_SRC="$TMP_CONF_DIR/nginx_config.conf"

# 루트 권한 확인
check_root

# service_paths.log 로드
if [ ! -f "$SERVICE_PATHS" ]; then
    log_debug "오류: service_paths.log($SERVICE_PATHS)가 존재하지 않습니다."
    echo "[ERROR] service_paths.log가 없습니다." >&2
    exit 1
fi
source "$SERVICE_PATHS" 2>/dev/null || { log_debug "service_paths.log 로드 실패"; exit 1; }

# Nginx 설정 확인
if [ -z "$NGINX_BINARY" ] || [ -z "$NGINX_CONF" ] || [ ! -f "$NGINX_CONF" ]; then
    log_debug "Nginx: 유효한 바이너리($NGINX_BINARY) 또는 conf($NGINX_CONF)가 없습니다."
    echo "[SKIP] Nginx: 설정 파일($NGINX_CONF)이 유효하지 않습니다." >&2
    exit 1
fi

if [ "$NGINX_RUNNING" != "1" ]; then
    log_debug "Nginx: 실행 중이 아닙니다."
    echo "[SKIP] Nginx: 실행 중이 아닙니다." >&2
    exit 1
fi

if [ ! -f "$APPLY_SRC" ]; then
    log_debug "Nginx: 추천 설정 파일($APPLY_SRC)이 없습니다."
    echo "[SKIP] Nginx: 추천 설정 파일($APPLY_SRC)이 없습니다." >&2
    exit 1
fi

# 추천값 추출
WR_NOFILE=$(grep "^worker_rlimit_nofile" "$APPLY_SRC" | awk '{print $2}' | sed 's/;//')
WP_AUTO=$(grep "^worker_processes" "$APPLY_SRC" | awk '{print $2}' | sed 's/;//')
WC=$(awk '/events[[:space:]]*{/ {f=1;next} /\}/ {f=0} f && /worker_connections/ {print $2}' "$APPLY_SRC" | sed 's/;//')

# 단일 인스턴스 적용
CONF_FILE="$NGINX_CONF"
LABEL="NGINX_CONF"
TMP_PATCH="$TMP_CONF_DIR/.nginx_apply_patch.$$"
cp "$CONF_FILE" "$TMP_PATCH"

echo "---- $LABEL: $CONF_FILE 미리보기 (diff 요약) ----"
CHANGE=0

# 1. worker_rlimit_nofile
if grep -q "^[[:space:]]*worker_rlimit_nofile" "$TMP_PATCH"; then
    CUR=$(grep "^[[:space:]]*worker_rlimit_nofile" "$TMP_PATCH" | awk '{print $2}' | sed 's/;//')
    if [ "$CUR" != "$WR_NOFILE" ]; then
        echo "[DIFF] worker_rlimit_nofile $CUR → $WR_NOFILE"
        sed -i "s|^\([[:space:]]*worker_rlimit_nofile[[:space:]]\+\).*|\\1$WR_NOFILE;|" "$TMP_PATCH"
        CHANGE=1
    else
        echo "[SAME] worker_rlimit_nofile $WR_NOFILE"
    fi
else
    echo "[NEW] worker_rlimit_nofile $WR_NOFILE 추가"
    sed -i "/^[[:space:]]*events[[:space:]]*{/i worker_rlimit_nofile $WR_NOFILE;" "$TMP_PATCH"
    CHANGE=1
fi

# 2. worker_processes
if grep -q "^[[:space:]]*worker_processes" "$TMP_PATCH"; then
    CUR=$(grep "^[[:space:]]*worker_processes" "$TMP_PATCH" | awk '{print $2}' | sed 's/;//')
    if [ "$CUR" != "$WP_AUTO" ]; then
        echo "[DIFF] worker_processes $CUR → $WP_AUTO"
        sed -i "s|^\([[:space:]]*worker_processes[[:space:]]\+\).*|\\1$WP_AUTO;|" "$TMP_PATCH"
        CHANGE=1
    else
        echo "[SAME] worker_processes $WP_AUTO"
    fi
else
    echo "[NEW] worker_processes $WP_AUTO 추가"
    sed -i "/^[[:space:]]*events[[:space:]]*{/i worker_processes $WP_AUTO;" "$TMP_PATCH"
    CHANGE=1
fi

# 3. worker_connections (events 블록 내부)
EV_START=$(grep -n "^[[:space:]]*events[[:space:]]*{" "$TMP_PATCH" | cut -d: -f1 | head -1)
EV_END=$(awk "NR>$EV_START" "$TMP_PATCH" | grep -n "^[[:space:]]*}" | head -1 | cut -d: -f1)
EV_END=$((EV_START + EV_END))

FOUND=$(sed -n "${EV_START},${EV_END}p" "$TMP_PATCH" | grep "worker_connections" | awk '{print $2}' | sed 's/;//')
if [ -n "$FOUND" ]; then
    if [ "$FOUND" != "$WC" ]; then
        echo "[DIFF] worker_connections $FOUND → $WC"
        sed -i "${EV_START},${EV_END}s|^\([[:space:]]*worker_connections[[:space:]]\+\).*|\\1$WC;|" "$TMP_PATCH"
        CHANGE=1
    else
        echo "[SAME] worker_connections $WC"
    fi
else
    echo "[NEW] events 블록에 worker_connections $WC 추가"
    sed -i "$((EV_END-1)) i \    worker_connections $WC;" "$TMP_PATCH"
    CHANGE=1
fi

if [ "$CHANGE" -eq 0 ]; then
    echo "(모든 항목이 이미 적용되어 있습니다.)"
    rm -f "$TMP_PATCH"
    echo "[DRY-RUN] $NGINX_BINARY -t -c $CONF_FILE"
    "$NGINX_BINARY" -t -c "$CONF_FILE" 2> "$LOG_DIR/apply_nginx_error.log"
    if [ $? -eq 0 ]; then
        echo "[dry-run] 특이사항 없음."
    else
        echo "[dry-run] ★문법 에러 발생★" >&2
        cat "$LOG_DIR/apply_nginx_error.log"
        echo "[ERROR] 문법 에러가 있어 재시작이 불가합니다. 반드시 파일을 확인하세요." >&2
    fi
    exit 0
fi

# 백업
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BASE_NAME=$(basename "$CONF_FILE")
BACKUP_FILE="$BACKUP_DIR/${BASE_NAME}.bak.$TIMESTAMP"
cp -a "$CONF_FILE" "$BACKUP_FILE"
log_debug "백업 완료: $CONF_FILE → $BACKUP_FILE"

# 적용
CONF_FILE=$(realpath "$CONF_FILE" 2>/dev/null || echo "$CONF_FILE")
cp "$TMP_PATCH" "$CONF_FILE"
rm -f "$TMP_PATCH"
log_debug "적용 완료: $LABEL → $CONF_FILE"
echo "[적용 완료] $LABEL → $CONF_FILE"

# 문법 검사
echo "[DRY-RUN] $NGINX_BINARY -t -c $CONF_FILE"
"$NGINX_BINARY" -t -c "$CONF_FILE" 2> "$LOG_DIR/apply_nginx_error.log"
if [ $? -eq 0 ]; then
    echo "[OK] 문법 검사 통과"
    # 서비스 재시작
    if systemctl restart nginx >/dev/null 2>&1; then
        log_debug "$LABEL: 서비스 재시작 성공"
        echo "[OK] $LABEL: 설정 적용 및 재시작 완료"
    else
        log_debug "오류: $LABEL 서비스 재시작 실패"
        echo "[ERROR] $LABEL: 서비스 재시작 실패, 롤백" >&2
        cp -a "$BACKUP_FILE" "$CONF_FILE"
        log_debug "복구: $CONF_FILE ← $BACKUP_FILE"
        echo "[복구] $CONF_FILE ← $BACKUP_FILE"
        exit 1
    fi
else
    log_debug "오류: $LABEL 문법 검사 실패 ($NGINX_BINARY -t)"
    echo "[ERROR] 문법 오류 발생" >&2
    cat "$LOG_DIR/apply_nginx_error.log"
    ERR_CONF_FILE="$ERR_CONF_DIR/${BASE_NAME}.err.$TIMESTAMP"
    cp -a "$CONF_FILE" "$ERR_CONF_FILE"
    log_debug "에러 적용 conf 저장: $ERR_CONF_FILE"
    echo "[ERR_CONF] 에러 적용 conf를 $ERR_CONF_FILE 에 저장했습니다."
    cp -a "$BACKUP_FILE" "$CONF_FILE"
    log_debug "복구: $CONF_FILE ← $BACKUP_FILE"
    echo "[복구] $CONF_FILE ← $BACKUP_FILE"
    exit 1
fi

echo "==== 적용 및 테스트 완료 ===="
exit 0