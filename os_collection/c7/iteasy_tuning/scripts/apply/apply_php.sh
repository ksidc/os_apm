#!/bin/bash

# apply_php.sh
# PHP 설정 파일을 적용 (다중 설치 지원, 단일 php_config.ini 사용)
# 수정: php_config.ini 사용, 문법 검사 제거
# 추가 수정: PHP 실행 테스트 제거

BASE_DIR="/usr/local/src/iteasy_tuning"
LOG_DIR="$BASE_DIR/logs"
TMP_CONF_DIR="$BASE_DIR/tmp_conf"
BACKUP_DIR="$BASE_DIR/backups"
ERR_CONF_DIR="$BASE_DIR/err_conf"
SERVICE_PATHS="$LOG_DIR/service_paths.log"
SCRIPTS_DIR="$BASE_DIR/scripts"

source "$SCRIPTS_DIR/common.sh"
setup_logging

APPLY_SRC="$TMP_CONF_DIR/php_config.ini"

PHP_CONF_LIST=()
PHP_LABELS=()
if grep -q '^PHP_CONF_' "$SERVICE_PATHS"; then
    while IFS='=' read -r key val; do
        if [[ $key =~ ^PHP_CONF_([0-9]+)$ ]]; then
            [ -n "$val" ] && PHP_CONF_LIST+=("$val") && PHP_LABELS+=("$key")
        fi
    done < <(grep '^PHP_CONF_' "$SERVICE_PATHS")
fi

if [ "${#PHP_CONF_LIST[@]}" -eq 0 ]; then
    echo "[ERROR] 적용 대상 PHP conf 파일이 없습니다." >&2
    log_debug "적용 대상 PHP conf 파일이 없습니다."
    exit 1
fi

for idx in "${!PHP_CONF_LIST[@]}"; do
    CONF_FILE="${PHP_CONF_LIST[$idx]}"
    LABEL="${PHP_LABELS[$idx]}"
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

    echo "---- $LABEL: $CONF_FILE 미리보기(추천값 적용 항목 요약) ----"
    CHANGE_COUNT=0
    declare -A RECOMM
    declare -A PATCH_TYPE
    declare -A PATCH_VAL
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        key=$(echo "$line" | awk -F'=' '{print $1}' | xargs)
        val=$(echo "$line" | awk -F'=' '{print $2}' | xargs)
        [[ -z "$key" ]] && continue
        RECOMM["$key"]="$val"
    done < "$APPLY_SRC"

    EXIST_KEYS=()
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        key=$(echo "$line" | awk -F'=' '{print $1}' | xargs)
        val=$(echo "$line" | awk -F'=' '{print $2}' | xargs)
        [[ -z "$key" ]] && continue
        if [[ -n "${RECOMM[$key]}" ]]; then
            if [ "${RECOMM[$key]}" = "$val" ]; then
                echo "[SAME] $key = $val (이미 적용됨)"
            else
                echo "[DIFF] $key = $val → ${RECOMM[$key]} (값 변경)"
                PATCH_TYPE["$key"]="mod"
                PATCH_VAL["$key"]="${RECOMM[$key]}"
                CHANGE_COUNT=$((CHANGE_COUNT+1))
            fi
        fi
        EXIST_KEYS+=("$key")
    done < "$CONF_FILE"

    for key in "${!RECOMM[@]}"; do
        FOUND=0
        for ekey in "${EXIST_KEYS[@]}"; do
            [ "$key" = "$ekey" ] && FOUND=1
        done
        if [ $FOUND -eq 0 ]; then
            echo "[NEW] $key = ${RECOMM[$key]} (신규 추가)"
            PATCH_TYPE["$key"]="add"
            PATCH_VAL["$key"]="${RECOMM[$key]}"
            CHANGE_COUNT=$((CHANGE_COUNT+1))
        fi
    done

    if [ "$CHANGE_COUNT" -eq 0 ]; then
        echo "(모든 항목이 이미 적용되어 있습니다.)"
        log_debug "$LABEL: 변경 사항 없음, 적용 생략"
        continue
    fi

    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BASE_NAME=$(basename "$CONF_FILE")
    BACKUP_FILE="$BACKUP_DIR/${BASE_NAME}.bak.$TIMESTAMP"
    cp -a "$CONF_FILE" "$BACKUP_FILE"
    log_debug "백업 완료: $CONF_FILE → $BACKUP_FILE"
    echo "[INFO] 백업 완료: $CONF_FILE → $BACKUP_FILE"

    TMP_PATCH="$TMP_CONF_DIR/.php_apply_patch.$$"
    cp -a "$CONF_FILE" "$TMP_PATCH"
    for key in "${!PATCH_TYPE[@]}"; do
        val="${PATCH_VAL[$key]}"
        escaped_key=$(echo "$key" | sed 's/[]\/$*.^|[]/\\&/g')
        escaped_val=$(echo "$val" | sed 's/[]\/$*.^|[]/\\&/g')
        if [ "${PATCH_TYPE[$key]}" = "mod" ]; then
            sed -i "s|^\([[:space:]]*${escaped_key}[[:space:]]*=\).*|\1 ${escaped_val}|" "$TMP_PATCH" 2>> "$LOG_DIR/apply_php_error.log"
            if [ $? -ne 0 ]; then
                log_debug "sed 오류: 키 $key 수정 실패"
                echo "[ERROR] $key 수정 중 오류 발생, 로그 확인: $LOG_DIR/apply_php_error.log" >&2
                rm -f "$TMP_PATCH"
                continue 2
            fi
            log_debug "sed 적용: $key = $val"
        elif [ "${PATCH_TYPE[$key]}" = "add" ]; then
            echo "$key = $val" >> "$TMP_PATCH"
            log_debug "추가: $key = $val"
        fi
    done

    DIFF_FILE="$LOG_DIR/diff_php_$((idx+1))_$TIMESTAMP.diff"
    diff -u "$CONF_FILE" "$TMP_PATCH" > "$DIFF_FILE" 2>> "$LOG_DIR/apply_php_error.log"
    if [ $? -eq 0 ] && [ -s "$DIFF_FILE" ]; then
        log_debug "diff 파일 생성: $DIFF_FILE"
        echo "[INFO] 변경 내역 저장: $DIFF_FILE"
    else
        log_debug "diff 생성 실패: $CONF_FILE → $TMP_PATCH, 오류 로그: $LOG_DIR/apply_php_error.log"
        echo "[WARN] diff 생성 실패, 로그 확인: $LOG_DIR/apply_php_error.log" >&2
    fi

    cp -a "$TMP_PATCH" "$CONF_FILE"
    if [ $? -ne 0 ]; then
        log_debug "오류: $TMP_PATCH → $CONF_FILE 복사 실패"
        echo "[ERROR] $CONF_FILE 적용 실패, 로그 확인: $LOG_DIR/apply_php_error.log" >&2
        rm -f "$TMP_PATCH"
        continue
    fi
    rm -f "$TMP_PATCH"
    echo "[적용 완료] $LABEL → $CONF_FILE"
    log_debug "적용 완료: $LABEL → $CONF_FILE"
    APPLIED=1
done

echo "==== 적용 완료 ===="
exit 0
