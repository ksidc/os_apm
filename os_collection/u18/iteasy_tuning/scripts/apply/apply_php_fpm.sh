#!/bin/bash

# apply_php-fpm.sh
# PHP-FPM 설정 파일을 적용
# 수정: 문법 검사 및 재시작 로직 강화, diff 생성 오류 처리 개선, PHP-FPM 8.0.30 호환성 보장
# 환경: Rocky Linux 9, PHP-FPM 8.0.30

BASE_DIR="/usr/local/src/iteasy_tuning"
LOG_DIR="$BASE_DIR/logs"
TMP_CONF_DIR="$BASE_DIR/tmp_conf"
BACKUP_DIR="$BASE_DIR/backups"
ERR_CONF_DIR="$BASE_DIR/err_conf"
SERVICE_PATHS="$LOG_DIR/service_paths.log"
SCRIPTS_DIR="$BASE_DIR/scripts"

# 공통 함수 로드
if [ ! -f "$SCRIPTS_DIR/common.sh" ]; then
    echo "[ERROR] 공통 스크립트($SCRIPTS_DIR/common.sh)가 존재하지 않습니다." >&2
    exit 1
fi
source "$SCRIPTS_DIR/common.sh" || { echo "[ERROR] 공통 스크립트($SCRIPTS_DIR/common.sh) 소싱 실패" >&2; exit 1; }

setup_logging
log_debug "apply_php-fpm.sh 시작"

# 루트 권한 확인
check_root

# service_paths.log 로드
if [ ! -f "$SERVICE_PATHS" ]; then
    log_debug "오류: service_paths.log($SERVICE_PATHS)가 존재하지 않습니다."
    echo "[ERROR] service_paths.log가 없습니다." >&2
    exit 1
fi
source "$SERVICE_PATHS" 2>/dev/null || { log_debug "service_paths.log 로드 실패"; exit 1; }

# PHP-FPM 설정 파일 및 바이너리 확인
CONF_FILE="$PHP_FPM_CONF"
APPLY_SRC="$TMP_CONF_DIR/php_fpm_config.conf"
PHPFPM_BIN="$PHP_FPM_BINARY"

if [ -z "$CONF_FILE" ] || [ ! -f "$CONF_FILE" ]; then
    log_debug "오류: PHP-FPM 설정 파일($CONF_FILE)이 없거나 정의되지 않았습니다."
    echo "[ERROR] PHP-FPM 설정 파일($CONF_FILE)이 없습니다." >&2
    exit 1
fi

if [ ! -f "$APPLY_SRC" ]; then
    log_debug "오류: 추천 설정 파일($APPLY_SRC)이 없습니다."
    echo "[SKIP] 추천 설정 파일($APPLY_SRC)이 없습니다." >&2
    exit 1
fi

if [ ! -x "$PHPFPM_BIN" ]; then
    log_debug "오류: PHP-FPM 바이너리($PHPFPM_BIN)가 실행 가능하지 않습니다."
    echo "[ERROR] PHP-FPM 바이너리($PHPFPM_BIN)가 실행 가능하지 않습니다." >&2
    exit 1
fi

# [www] 섹션 확인
if ! grep -q '^\[www\]' "$CONF_FILE"; then
    log_debug "오류: $CONF_FILE에 [www] 섹션이 없습니다."
    echo "[ERROR] $CONF_FILE에 [www] 섹션이 없습니다." >&2
    exit 1
fi

# 추천값 파싱
declare -A RECOMM
while IFS='=' read -r key val; do
    key=$(echo "$key" | tr -d ' ')
    val=$(echo "$val" | sed 's/^ //')
    [[ -z "$key" ]] && continue
    [[ "$key" =~ ^# ]] && continue
    RECOMM["$key"]="$val"
done < <(grep -vE '^\[.*\]|^$' "$APPLY_SRC")

# 미리보기
echo "---- PHP_FPM_CONF: $CONF_FILE 미리보기(추천값 적용 항목 요약) ----"
CHANGE_COUNT=0
declare -A PATCH_TYPE
declare -A PATCH_VAL
EXIST_KEYS=()
while IFS='=' read -r key val; do
    key=$(echo "$key" | tr -d ' ')
    val=$(echo "$val" | sed 's/^ //')
    [[ -z "$key" ]] && continue
    [[ "$key" =~ ^# ]] && continue
    [[ "$key" =~ ^\[.*\] ]] && continue
    if [[ -n "${RECOMM[$key]}" ]]; then
        if [ "${RECOMM[$key]}" = "$val" ]; then
            echo "[SAME]  $key = $val  (이미 적용됨)"
        else
            echo "[DIFF]  $key = $val  → $key = ${RECOMM[$key]}  (값 변경)"
            PATCH_TYPE["$key"]="mod"
            PATCH_VAL["$key"]="${RECOMM[$key]}"
            CHANGE_COUNT=$((CHANGE_COUNT+1))
        fi
    fi
    EXIST_KEYS+=("$key")
done < <(grep -vE '^\[.*\]|^$' "$CONF_FILE")
# 없는 추천값 추가
for key in "${!RECOMM[@]}"; do
    FOUND=0
    for ekey in "${EXIST_KEYS[@]}"; do
        [ "$key" = "$ekey" ] && FOUND=1
    done
    if [ $FOUND -eq 0 ]; then
        echo "[NEW]   $key = ${RECOMM[$key]}  (신규 추가)"
        PATCH_TYPE["$key"]="add"
        PATCH_VAL["$key"]="${RECOMM[$key]}"
        CHANGE_COUNT=$((CHANGE_COUNT+1))
    fi
done

if [ "$CHANGE_COUNT" -eq 0 ]; then
    echo "(모든 항목이 이미 적용되어 있습니다.)"
    log_debug "PHP-FPM: 변경 사항 없음, 문법 검사 진행"
    echo "[DRY-RUN] php-fpm 문법 검사"
    "$PHPFPM_BIN" -t -c "$CONF_FILE" 2> "$LOG_DIR/apply_php_fpm_error.log"
    if [ $? -eq 0 ]; then
        echo "[dry-run] 특이사항 없음."
        # 서비스 재시작
        SERVICE_NAME=$(systemctl list-units --type=service --state=running | grep -E 'php-fpm\.service' | awk '{print $1}' | cut -d'.' -f1 | head -1)
        if [ -n "$SERVICE_NAME" ]; then
            systemctl reload "$SERVICE_NAME" >/dev/null 2>> "$LOG_DIR/apply_php_fpm_error.log"
            if [ $? -eq 0 ]; then
                log_debug "PHP-FPM: 서비스 $SERVICE_NAME reload 성공"
                echo "[OK] PHP_FPM_CONF: 설정 적용 및 재시작 완료"
            else
                log_debug "오류: PHP-FPM 서비스 $SERVICE_NAME reload 실패"
                echo "[WARN] PHP-FPM: 재시작 실패, 로그 확인: $LOG_DIR/apply_php_fpm_error.log" >&2
            fi
        else
            log_debug "오류: PHP-FPM 서비스 이름 탐지 실패"
            echo "[WARN] PHP-FPM: 서비스 이름 탐지 실패" >&2
        fi
    else
        echo "[dry-run] ★문법 에러 발생★" >&2
        cat "$LOG_DIR/apply_php_fpm_error.log"
        echo "[ERROR] 문법 에러가 있어 재시작이 불가합니다. 반드시 파일을 확인하세요." >&2
        exit 1
    fi
    exit 0
fi

# 백업
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BASE_NAME=$(basename "$CONF_FILE")
BACKUP_FILE="$BACKUP_DIR/${BASE_NAME}.bak.$TIMESTAMP"
cp -a "$CONF_FILE" "$BACKUP_FILE"
log_debug "백업 완료: $CONF_FILE → $BACKUP_FILE"
echo "[INFO] 백업 완료: $CONF_FILE → $BACKUP_FILE"

# 설정 적용
TMP_PATCH="$TMP_CONF_DIR/.php_fpm_apply_patch.$$"
cp "$CONF_FILE" "$TMP_PATCH"
for key in "${!PATCH_TYPE[@]}"; do
    val="${PATCH_VAL[$key]}"
    if [ "${PATCH_TYPE[$key]}" = "mod" ]; then
        sed -i "s|^[[:space:]]*${key}[[:space:]]*=[[:space:]]*.*|$key = $val|" "$TMP_PATCH"
    elif [ "${PATCH_TYPE[$key]}" = "add" ]; then
        echo "$key = $val" >> "$TMP_PATCH"
    fi
done

# TMP_PATCH 파일 검증
if [ ! -s "$TMP_PATCH" ]; then
    log_debug "오류: $TMP_PATCH 파일이 비어 있습니다."
    echo "[ERROR] $TMP_PATCH 파일이 비어 있습니다. 적용을 중단합니다." >&2
    rm -f "$TMP_PATCH"
    exit 1
fi

# diff 파일 저장
DIFF_FILE="$LOG_DIR/diff_php_fpm_1_$TIMESTAMP.diff"
diff -u "$CONF_FILE" "$TMP_PATCH" > "$DIFF_FILE" 2>> "$LOG_DIR/apply_php_fpm_error.log"
if [ $? -eq 0 ] && [ -s "$DIFF_FILE" ]; then
    log_debug "diff 파일 생성: $DIFF_FILE"
    echo "[INFO] 변경 내역 저장: $DIFF_FILE"
else
    log_debug "diff 생성 실패: $CONF_FILE → $TMP_PATCH, 오류 로그: $LOG_DIR/apply_php_fpm_error.log"
    echo "[WARN] diff 생성 실패, 로그 확인: $LOG_DIR/apply_php_fpm_error.log" >&2
fi

# 적용
cp -a "$TMP_PATCH" "$CONF_FILE"
rm -f "$TMP_PATCH"
log_debug "적용 완료: PHP_FPM_CONF → $CONF_FILE"
echo "[적용 완료] PHP_FPM_CONF → $CONF_FILE"

# 문법 검사
echo "[DRY-RUN] php-fpm 문법 검사"
"$PHPFPM_BIN" -t -c "$CONF_FILE" 2> "$LOG_DIR/apply_php_fpm_error.log"
if [ $? -eq 0 ]; then
    echo "[dry-run] 특이사항 없음."
    # 서비스 재시작
    SERVICE_NAME=$(systemctl list-units --type=service --state=running | grep -E 'php-fpm\.service' | awk '{print $1}' | cut -d'.' -f1 | head -1)
    if [ -n "$SERVICE_NAME" ]; then
        systemctl reload "$SERVICE_NAME" >/dev/null 2>> "$LOG_DIR/apply_php_fpm_error.log"
        if [ $? -eq 0 ]; then
            log_debug "PHP-FPM: 서비스 $SERVICE_NAME reload 성공"
            echo "[OK] PHP_FPM_CONF: 설정 적용 및 재시작 완료"
        else
            log_debug "오류: PHP-FPM 서비스 $SERVICE_NAME reload 실패"
            echo "[ERROR] PHP-FPM: 재시작 실패, 롤백" >&2
            cp -a "$BACKUP_FILE" "$CONF_FILE"
            log_debug "복구: $CONF_FILE ← $BACKUP_FILE"
            echo "[복구] $CONF_FILE ← $BACKUP_FILE"
            exit 1
        fi
    else
        log_debug "오류: PHP-FPM 서비스 이름 탐지 실패"
        echo "[ERROR] PHP-FPM: 서비스 이름 탐지 실패, 롤백" >&2
        cp -a "$BACKUP_FILE" "$CONF_FILE"
        log_debug "복구: $CONF_FILE ← $BACKUP_FILE"
        echo "[복구] $CONF_FILE ← $BACKUP_FILE"
        exit 1
    fi
else
    log_debug "오류: PHP-FPM 문법 검사 실패 ($PHPFPM_BIN -t -c $CONF_FILE)"
    echo "[dry-run] ★문법 에러 발생★" >&2
    cat "$LOG_DIR/apply_php_fpm_error.log"
    ERR_CONF_FILE="$ERR_CONF_DIR/${BASE_NAME}.err.$TIMESTAMP"
    cp -a "$CONF_FILE" "$ERR_CONF_FILE"
    log_debug "에러 적용 conf 저장: $ERR_CONF_FILE"
    echo "[ERR_CONF] 에러 적용 conf를 $ERR_CONF_FILE 에 저장했습니다."
    cp -a "$BACKUP_FILE" "$CONF_FILE"
    log_debug "복구: $CONF_FILE ← $BACKUP_FILE"
    echo "[복구] $CONF_FILE ← $BACKUP_FILE"
    echo "[ERROR] 문법 에러가 있어 재시작이 불가합니다. 반드시 파일을 확인하세요." >&2
    exit 1
fi

echo "==== 적용 및 테스트 완료 ===="
exit 0
