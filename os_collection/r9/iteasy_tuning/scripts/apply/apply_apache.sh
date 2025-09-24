#!/bin/bash

# apply_apache.sh
# Apache MPM 설정 파일을 적용
# 수정: 컴파일 설치 Apache의 설정 파일 경로 명시, 모듈 경로 충돌 방지, 문법 검사 및 재시작 로직 강화, diff 생성 오류 처리 개선
# 환경: Rocky Linux 9, Apache 2.4 (패키지 및 컴파일 설치)

BASE_DIR="/usr/local/src/iteasy_tuning"
LOG_DIR="$BASE_DIR/logs"
TMP_CONF_DIR="$BASE_DIR/tmp_conf"
BACKUP_DIR="$BASE_DIR/backups"
ERR_CONF_DIR="$BASE_DIR/err_conf"
SERVICE_PATHS="$LOG_DIR/service_paths.log"
SCRIPTS_DIR="$BASE_DIR/scripts"

source "$SCRIPTS_DIR/common.sh"
setup_logging

# 루트 권한 확인
check_root

# service_paths.log 로드
if [ ! -f "$SERVICE_PATHS" ]; then
    log_debug "오류: service_paths.log($SERVICE_PATHS)가 존재하지 않습니다."
    echo "[ERROR] service_paths.log가 없습니다." >&2
    exit 1
fi
source "$SERVICE_PATHS" 2>/dev/null || { log_debug "service_paths.log 로드 실패"; exit 1; }

# 대상 conf 리스트 수집
MPM_CONF_LIST=()
MPM_LABELS=()
MPM_BINARY_LIST=()
MPM_TYPE_LIST=()
MPM_CONFIG_FILE=()
if grep -q '^APACHE_MPM_CONF_' "$SERVICE_PATHS"; then
    for i in $(seq 1 "$MULTIPLE_APACHE_FOUND"); do
        eval "conf=\$APACHE_MPM_CONF_$i"
        eval "binary=\$APACHE_BINARY_$i"
        eval "mpm=\$APACHE_MPM_$i"
        eval "running=\$APACHE_RUNNING_$i"
        if [ -n "$conf" ] && [ "$conf" != "NOT_FOUND" ] && [ -f "$conf" ] && [ "$running" = "1" ]; then
            MPM_CONF_LIST+=("$conf")
            MPM_LABELS+=("APACHE_MPM_CONF_$i")
            MPM_BINARY_LIST+=("$binary")
            MPM_TYPE_LIST+=("$mpm")
            # 컴파일 설치 여부에 따라 설정 파일 경로 지정
            if [[ "$binary" == *"/usr/local/"* ]]; then
                MPM_CONFIG_FILE+=("/usr/local/apache/conf/httpd.conf")
            else
                MPM_CONFIG_FILE+=("/etc/httpd/conf/httpd.conf")
            fi
        fi
    done
else
    MPM_CONF=$(grep '^APACHE_MPM_CONF=' "$SERVICE_PATHS" | cut -d= -f2-)
    MPM_BINARY=$(grep '^APACHE_BINARY=' "$SERVICE_PATHS" | cut -d= -f2-)
    MPM_TYPE=$(grep '^APACHE_MPM=' "$SERVICE_PATHS" | cut -d= -f2-)
    if [ -n "$MPM_CONF" ] && [ "$MPM_CONF" != "NOT_FOUND" ] && [ -f "$MPM_CONF" ] && [ "$APACHE_RUNNING" = "1" ]; then
        MPM_CONF_LIST+=("$MPM_CONF")
        MPM_LABELS+=("APACHE_MPM_CONF")
        MPM_BINARY_LIST+=("$MPM_BINARY")
        MPM_TYPE_LIST+=("$MPM_TYPE")
        if [[ "$MPM_BINARY" == *"/usr/local/"* ]]; then
            MPM_CONFIG_FILE+=("/usr/local/apache/conf/httpd.conf")
        else
            MPM_CONFIG_FILE+=("/etc/httpd/conf/httpd.conf")
        fi
    fi
fi

if [ "${#MPM_CONF_LIST[@]}" -eq 0 ]; then
    log_debug "적용 대상 Apache MPM conf 파일이 없습니다."
    echo "[ERROR] 적용 대상 Apache MPM conf 파일이 없습니다." >&2
    exit 1
fi

# 인스턴스별 적용
for idx in "${!MPM_CONF_LIST[@]}"; do
    CONF_FILE="${MPM_CONF_LIST[$idx]}"
    LABEL="${MPM_LABELS[$idx]}"
    BINARY="${MPM_BINARY_LIST[$idx]}"
    MPM_TYPE="${MPM_TYPE_LIST[$idx]}"
    CONFIG_FILE="${MPM_CONFIG_FILE[$idx]}"
    APPLY_SRC="$TMP_CONF_DIR/mpm_config_$((idx+1)).conf"

    if [ ! -f "$CONF_FILE" ]; then
        log_debug "파일 없음: $CONF_FILE"
        echo "[SKIP] 파일 없음: $CONF_FILE" >&2
        continue
    fi

    if [ ! -f "$APPLY_SRC" ]; then
        log_debug "추천 설정 파일 없음: $APPLY_SRC"
        echo "[SKIP] $LABEL: 추천 설정 파일($APPLY_SRC)이 없습니다." >&2
        continue
    fi

    # 추천값에서 MPM 타입 확인
    RECOMM_MPM_TYPE=$(grep -oP '<IfModule mpm_\K[^_]*' "$APPLY_SRC" | head -1)
    if [ -z "$RECOMM_MPM_TYPE" ]; then
        RECOMM_MPM_TYPE="$MPM_TYPE"
        log_debug "$LABEL: 추천 MPM 타입 미지정, 기본값 $MPM_TYPE 사용"
    fi

    # --- 추천값 파싱 ---
    declare -A RECOMM
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        key=$(echo "$line" | awk '{print $1}')
        val=$(echo "$line" | sed -e "s|^$key[[:space:]]*||")
        [[ -z "$key" ]] && continue
        RECOMM["$key"]="$val"
    done < <(grep -vE '^<IfModule|^</IfModule' "$APPLY_SRC")

    # --- 적용 대상 블록 탐지 ---
    BLOCK_START=$(grep -n "<IfModule mpm_${MPM_TYPE}_module>" "$CONF_FILE" | cut -d: -f1 | head -1)
    BLOCK_END=""
    if [ -n "$BLOCK_START" ]; then
        BLOCK_END=$(awk "NR>$BLOCK_START && /<\/IfModule>/" "$CONF_FILE" | head -1 | awk -v s=$BLOCK_START 'NR==1{print NR+s}')
    fi

    if [ -z "$BLOCK_START" ] || [ -z "$BLOCK_END" ]; then
        log_debug "$CONF_FILE에서 <IfModule mpm_${MPM_TYPE}_module> 블록이 없어 신규로 추가합니다."
        echo "[WARN] $CONF_FILE에서 <IfModule mpm_${MPM_TYPE}_module> 블록이 없어 신규로 추가합니다." >&2
        # 기존 MPM 블록 제거
        sed -i "/<IfModule mpm_.*_module>/,/<\/IfModule>/d" "$CONF_FILE"
        cat "$APPLY_SRC" >> "$CONF_FILE"
        echo "[INFO] $CONF_FILE에 <IfModule mpm_${MPM_TYPE}_module> 블록을 추가했습니다."
        BLOCK_START=$(grep -n "<IfModule mpm_${MPM_TYPE}_module>" "$CONF_FILE" | cut -d: -f1 | head -1)
        if [ -n "$BLOCK_START" ]; then
            BLOCK_END=$(awk "NR>$BLOCK_START && /<\/IfModule>/" "$CONF_FILE" | head -1 | awk -v s=$BLOCK_START 'NR==1{print NR+s}')
        fi
        if [ -z "$BLOCK_END" ]; then
            log_debug "$CONF_FILE에 블록을 추가했으나, 다시 찾기에 실패했습니다."
            echo "[ERROR] $CONF_FILE에 블록을 추가했으나, 다시 찾기에 실패했습니다. 파일을 확인하세요." >&2
            continue
        fi
    fi

    # --- 미리보기 ---
    echo "---- $LABEL: $CONF_FILE ($MPM_TYPE) 미리보기(추천값 적용 항목 요약) ----"
    CHANGE_COUNT=0
    declare -A PATCH_TYPE
    declare -A PATCH_VAL
    EXIST_KEYS=()
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        key=$(echo "$line" | awk '{print $1}')
        val=$(echo "$line" | sed -e "s|^$key[[:space:]]*||")
        [[ -z "$key" ]] && continue
        if [[ -n "${RECOMM[$key]}" ]]; then
            if [ "${RECOMM[$key]}" = "$val" ]; then
                echo "[SAME]  $key $val  (이미 적용됨)"
            else
                echo "[DIFF]  $key $val  → $key ${RECOMM[$key]}  (값 변경)"
                PATCH_TYPE["$key"]="mod"
                PATCH_VAL["$key"]="${RECOMM[$key]}"
                CHANGE_COUNT=$((CHANGE_COUNT+1))
            fi
        fi
        EXIST_KEYS+=("$key")
    done < <(sed -n "${BLOCK_START},${BLOCK_END}p" "$CONF_FILE")
    # 없는 추천값 추가
    for key in "${!RECOMM[@]}"; do
        FOUND=0
        for ekey in "${EXIST_KEYS[@]}"; do
            [ "$key" = "$ekey" ] && FOUND=1
        done
        if [ $FOUND -eq 0 ]; then
            echo "[NEW]   $key ${RECOMM[$key]}  (신규 추가)"
            PATCH_TYPE["$key"]="add"
            PATCH_VAL["$key"]="${RECOMM[$key]}"
            CHANGE_COUNT=$((CHANGE_COUNT+1))
        fi
    done

    if [ "$CHANGE_COUNT" -eq 0 ]; then
        echo "(모든 항목이 이미 적용되어 있습니다.)"
        log_debug "$LABEL: 변경 사항 없음, 문법 검사 진행"
        echo "[DRY-RUN] $BINARY -t -f $CONFIG_FILE (문법 검사)"
        "$BINARY" -t -f "$CONFIG_FILE" 2> "$LOG_DIR/apply_apache_error.log"
        if [ $? -eq 0 ]; then
            echo "[dry-run] 특이사항 없음."
        else
            echo "[dry-run] ★문법 에러 발생★" >&2
            cat "$LOG_DIR/apply_apache_error.log"
            echo "[ERROR] 문법 에러가 있어 재시작이 불가합니다. 반드시 파일을 확인하세요." >&2
            continue
        fi
        continue
    fi

    # 백업
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BASE_NAME=$(basename "$CONF_FILE")
    BACKUP_FILE="$BACKUP_DIR/${BASE_NAME}.bak.$TIMESTAMP"
    cp -a "$CONF_FILE" "$BACKUP_FILE"
    log_debug "백업 완료: $CONF_FILE → $BACKUP_FILE"
    echo "[INFO] 백업 완료: $CONF_FILE → $BACKUP_FILE"

    # --- prefork/worker/event 블록 내에서만 값 변경/추가 적용 ---
    TMP_PATCH="$TMP_CONF_DIR/.apache_apply_patch.$$"
    cp "$CONF_FILE" "$TMP_PATCH"
    # 기존 MPM 블록 제거
    sed -i "/<IfModule mpm_.*_module>/,/<\/IfModule>/d" "$TMP_PATCH"
    # 새로운 설정 추가
    cat "$APPLY_SRC" >> "$TMP_PATCH"

    # TMP_PATCH 파일 검증
    if [ ! -s "$TMP_PATCH" ]; then
        log_debug "오류: $TMP_PATCH 파일이 비어 있습니다."
        echo "[ERROR] $TMP_PATCH 파일이 비어 있습니다. 적용을 중단합니다." >&2
        rm -f "$TMP_PATCH"
        continue
    fi

    # diff 파일 저장
    DIFF_FILE="$LOG_DIR/diff_apache_$((idx+1))_$TIMESTAMP.diff"
    diff -u "$CONF_FILE" "$TMP_PATCH" > "$DIFF_FILE" 2>> "$LOG_DIR/apply_apache_error.log"
    if [ $? -eq 0 ] && [ -s "$DIFF_FILE" ]; then
        log_debug "diff 파일 생성: $DIFF_FILE"
        echo "[INFO] 변경 내역 저장: $DIFF_FILE"
    else
        log_debug "diff 생성 실패: $CONF_FILE → $TMP_PATCH, 오류 로그: $LOG_DIR/apply_apache_error.log"
        echo "[WARN] diff 생성 실패, 로그 확인: $LOG_DIR/apply_apache_error.log" >&2
    fi

    # 적용
    cp -a "$TMP_PATCH" "$CONF_FILE"
    rm -f "$TMP_PATCH"
    log_debug "적용 완료: $LABEL → $CONF_FILE"
    echo "[적용 완료] $LABEL → $CONF_FILE"

    # 문법 검사
    echo "[DRY-RUN] $BINARY -t -f $CONFIG_FILE (문법 검사)"
    "$BINARY" -t -f "$CONFIG_FILE" 2> "$LOG_DIR/apply_apache_error.log"
    if [ $? -eq 0 ]; then
        echo "[dry-run] 특이사항 없음."
        # 서비스 재시작
        SERVICE_NAME=$(systemctl list-units --type=service --state=running | grep -E 'httpd\.service|apache2\.service' | awk '{print $1}' | cut -d'.' -f1 | head -1)
        if [ -n "$SERVICE_NAME" ] && [[ "$BINARY" != *"/usr/local/"* ]]; then
            systemctl restart "$SERVICE_NAME" >/dev/null 2>> "$LOG_DIR/apply_apache_error.log"
            if [ $? -eq 0 ]; then
                log_debug "$LABEL: 서비스 $SERVICE_NAME 재시작 성공"
                echo "[OK] $LABEL: 설정 적용 및 재시작 완료"
            else
                log_debug "오류: $LABEL 서비스 $SERVICE_NAME 재시작 실패, 바이너리 재시작 시도"
                "$BINARY" -k stop -f "$CONFIG_FILE" >/dev/null 2>> "$LOG_DIR/apply_apache_error.log" && "$BINARY" -k start -f "$CONFIG_FILE" >/dev/null 2>> "$LOG_DIR/apply_apache_error.log"
                if [ $? -eq 0 ]; then
                    log_debug "$LABEL: 바이너리 stop/start 성공"
                    echo "[OK] $LABEL: 설정 적용 및 재시작 완료"
                else
                    log_debug "오류: $LABEL 바이너리 재시작 실패"
                    echo "[ERROR] $LABEL: 서비스 재시작 실패, 롤백" >&2
                    cp -a "$BACKUP_FILE" "$CONF_FILE"
                    log_debug "복구: $CONF_FILE ← $BACKUP_FILE"
                    echo "[복구] $CONF_FILE ← $BACKUP_FILE"
                    continue
                fi
            fi
        else
            "$BINARY" -k graceful -f "$CONFIG_FILE" >/dev/null 2>> "$LOG_DIR/apply_apache_error.log"
            if [ $? -eq 0 ]; then
                log_debug "$LABEL: 서비스 graceful 재시작 성공"
                echo "[OK] $LABEL: 설정 적용 및 재시작 완료"
            else
                log_debug "오류: $LABEL 서비스 graceful 재시작 실패, 바이너리 재시작 시도"
                "$BINARY" -k stop -f "$CONFIG_FILE" >/dev/null 2>> "$LOG_DIR/apply_apache_error.log" && "$BINARY" -k start -f "$CONFIG_FILE" >/dev/null 2>> "$LOG_DIR/apply_apache_error.log"
                if [ $? -eq 0 ]; then
                    log_debug "$LABEL: 바이너리 stop/start 성공"
                    echo "[OK] $LABEL: 설정 적용 및 재시작 완료"
                else
                    log_debug "오류: $LABEL 바이너리 재시작 실패"
                    echo "[ERROR] $LABEL: 서비스 재시작 실패, 롤백" >&2
                    cp -a "$BACKUP_FILE" "$CONF_FILE"
                    log_debug "복구: $CONF_FILE ← $BACKUP_FILE"
                    echo "[복구] $CONF_FILE ← $BACKUP_FILE"
                    continue
                fi
            fi
        fi
    else
        log_debug "오류: $LABEL 문법 검사 실패 ($BINARY -t -f $CONFIG_FILE)"
        echo "[dry-run] ★문법 에러 발생★" >&2
        cat "$LOG_DIR/apply_apache_error.log"
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
