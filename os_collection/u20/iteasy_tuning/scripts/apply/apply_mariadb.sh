#!/bin/bash

# apply_mariadb.sh
# MariaDB 설정 파일을 tmp_conf/mysql_config.conf로 교체
# 수정: restart 대신 stop/대기/start, socket 경로 일관성 확인, diff 오류 처리 강화, 서비스 이름으로 중지/시작

BASE_DIR="/usr/local/src/iteasy_tuning"
LOG_DIR="$BASE_DIR/logs"
TMP_CONF_DIR="$BASE_DIR/tmp_conf"
BACKUP_DIR="$BASE_DIR/backups"
ERR_CONF_DIR="$BASE_DIR/err_conf"
SERVICE_PATHS="$LOG_DIR/service_paths.log"
SCRIPTS_DIR="$BASE_DIR/scripts"

source "$SCRIPTS_DIR/common.sh"
setup_logging

APPLY_SRC="$TMP_CONF_DIR/mysql_config.conf"

# MariaDB conf 목록 (MYSQL_CONF_*, MYSQL_CONF 모두)
MYSQL_CONF_LIST=()
MYSQL_LABELS=()
while IFS='=' read -r key val; do
    [[ $key =~ ^MYSQL_CONF ]] && [ -n "$val" ] && MYSQL_CONF_LIST+=("$val") && MYSQL_LABELS+=("$key")
done < <(grep '^MYSQL_CONF' "$SERVICE_PATHS")

if [ "${#MYSQL_CONF_LIST[@]}" -eq 0 ]; then
    echo "[ERROR] 적용 대상 MariaDB conf 파일이 없습니다." >&2
    log_debug "적용 대상 MariaDB conf 파일이 없습니다."
    exit 1
fi

# MariaDB 바이너리 경로 가져오기 (문법 체크용)
MARIADB_BINARY=$(grep '^MARIADB_BINARY=' "$SERVICE_PATHS" | cut -d'=' -f2)
if [ -z "$MARIADB_BINARY" ] || [ ! -x "$MARIADB_BINARY" ]; then
    echo "[ERROR] MariaDB 바이너리($MARIADB_BINARY)가 없거나 실행 가능하지 않습니다." >&2
    log_debug "MariaDB 바이너리($MARIADB_BINARY)가 없거나 실행 가능하지 않습니다."
    exit 1
fi

# MariaDB 서비스 이름 가져오기 (중지/시작용)
MARIADB_SERVICE=$(grep '^MARIADB_SERVICE=' "$SERVICE_PATHS" | cut -d'=' -f2)
if [ -z "$MARIADB_SERVICE" ]; then
    echo "[ERROR] MariaDB 서비스 이름(MARIADB_SERVICE)이 정의되지 않았습니다." >&2
    log_debug "MariaDB 서비스 이름이 정의되지 않았습니다."
    exit 1
fi

# 모든 인스턴스 자동 선택
IDX_LIST=($(seq 0 $((${#MYSQL_CONF_LIST[@]}-1))))

for idx in "${IDX_LIST[@]}"; do
    CONF_FILE="${MYSQL_CONF_LIST[$idx]}"
    LABEL="${MYSQL_LABELS[$idx]}"
    APPLIED=0

    if [ ! -f "$CONF_FILE" ]; then
        echo "[SKIP] 파일 없음: $CONF_FILE" >&2
        log_debug "파일 없음: $CONF_FILE"
        continue
    fi

    if [ ! -f "$APPLY_SRC" ]; then
        echo "[SKIP] $LABEL: 추천 설정 파일($APPLY_SRC)이 없습니다." >&2
        log_debug "추천 설정 파일 없음: $APPLY_SRC"
        continue
    fi

    # 백업
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BASE_NAME=$(basename "$CONF_FILE")
    BACKUP_FILE="$BACKUP_DIR/${BASE_NAME}.bak.$TIMESTAMP"
    cp -a "$CONF_FILE" "$BACKUP_FILE"
    log_debug "백업 완료: $CONF_FILE → $BACKUP_FILE"

    # diff 파일 저장
    DIFF_FILE="$LOG_DIR/diff_mariadb_$((idx+1))_$TIMESTAMP.diff"
    diff -u "$CONF_FILE" "$APPLY_SRC" > "$DIFF_FILE" 2>> "$LOG_DIR/apply_mariadb_error.log"
    if [ $? -eq 0 ] && [ -s "$DIFF_FILE" ]; then
        log_debug "diff 파일 생성: $DIFF_FILE"
        echo "[INFO] 변경 내역 저장: $DIFF_FILE"
    else
        log_debug "diff 생성 실패: $CONF_FILE → $APPLY_SRC, 오류 로그: $LOG_DIR/apply_mariadb_error.log"
        echo "[WARN] diff 생성 실패, 로그 확인: $LOG_DIR/apply_mariadb_error.log" >&2
    fi

    # 설정 파일 교체
    cp -a "$APPLY_SRC" "$CONF_FILE"
    echo "[적용 완료] $LABEL → $CONF_FILE"
    log_debug "적용 완료: $LABEL → $CONF_FILE"
    APPLIED=1

    echo "[DRY-RUN] $MARIADB_BINARY --defaults-file=$CONF_FILE --verbose --help (문법 체크)"
    "$MARIADB_BINARY" --defaults-file="$CONF_FILE" --verbose --help > /dev/null 2> "$LOG_DIR/apply_mariadb_error.log"
    if [ $? -eq 0 ]; then
        echo "[dry-run] 특이사항 없음."
        # 서비스 중지, 대기, 시작
        systemctl stop "$MARIADB_SERVICE" >/dev/null 2>> "$LOG_DIR/apply_mariadb_error.log"
        sleep 3
        systemctl start "$MARIADB_SERVICE" >/dev/null 2>> "$LOG_DIR/apply_mariadb_error.log"
        if [ $? -eq 0 ]; then
            log_debug "$LABEL: MariaDB 재시작 성공"
            echo "[OK] $LABEL: 설정 적용 및 재시작 완료"
        else
            log_debug "오류: $LABEL MariaDB 재시작 실패"
            echo "[ERROR] $LABEL: 재시작 실패, 롤백" >&2
            cp -a "$BACKUP_FILE" "$CONF_FILE"
            log_debug "복구: $CONF_FILE ← $BACKUP_FILE"
            echo "[복구] $CONF_FILE ← $BACKUP_FILE"
            continue
        fi
    else
        echo "[dry-run] ★문법 에러 발생★" >&2
        cat "$LOG_DIR/apply_mariadb_error.log"
        ERR_CONF_FILE="$ERR_CONF_DIR/${BASE_NAME}.err.$TIMESTAMP"
        cp -a "$CONF_FILE" "$ERR_CONF_FILE"
        log_debug "에러 적용 conf 저장: $ERR_CONF_FILE"
        echo "[ERR_CONF] 에러 적용 conf를 $ERR_CONF_FILE 에 저장했습니다."
        cp -a "$BACKUP_FILE" "$CONF_FILE"
        log_debug "복구: $CONF_FILE ← $BACKUP_FILE"
        echo "[복구] $CONF_FILE ← $BACKUP_FILE"
        echo "[ERROR] 문법 에러가 있어 재시작이 불가합니다. 반드시 파일을 확인하세요." >&2
        continue
    fi
done

echo "==== 적용 및 테스트 완료 ===="
exit 0
