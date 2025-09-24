#!/bin/bash

# 개선된 apply_tomcat.sh - 다중 포트 Connector 적용 가능 버전
# 각 Tomcat 인스턴스별 포트에 맞는 Connector 설정 자동 적용
# 수정: port와 protocol 속성이 포함된 기존 Connector 블록을 주석 처리하고 새로운 설정 적용 (2025-08-01)

BASE_DIR="/usr/local/src/iteasy_tuning"
LOG_DIR="$BASE_DIR/logs"
TMP_CONF_DIR="$BASE_DIR/tmp_conf"
BACKUP_DIR="$BASE_DIR/backups"
ERR_CONF_DIR="$BASE_DIR/err_conf"
SERVICE_PATHS="$LOG_DIR/service_paths.log"
SCRIPTS_DIR="$BASE_DIR/scripts"

source "$SCRIPTS_DIR/common.sh"
setup_logging

APPLY_SRC="$TMP_CONF_DIR/tomcat_config.conf"
[ ! -f "$APPLY_SRC" ] && echo "[ERROR] tomcat_config.conf가 없습니다." >&2 && log_debug "tomcat_config.conf가 없습니다." && exit 1

TOMCAT_PATHS=()
TOMCAT_LABELS=()
TOMCAT_PORTS=()

while IFS='=' read -r key path; do
    if [[ "$key" =~ ^TOMCAT_BASE_DIR_([0-9]+)$ ]]; then
        idx="${BASH_REMATCH[1]}"
        if grep -q "^TOMCAT_RUNNING_${idx}=1" "$SERVICE_PATHS"; then
            if [ -d "$path" ] && [ -f "$path/conf/server.xml" ]; then
                port=$(grep "^TOMCAT_PORT_${idx}=" "$SERVICE_PATHS" | cut -d= -f2)
                TOMCAT_PATHS+=("$path")
                TOMCAT_LABELS+=("TOMCAT_$idx")
                TOMCAT_PORTS+=("$port")
            fi
        fi
    fi
done < "$SERVICE_PATHS"

if [ ${#TOMCAT_PATHS[@]} -eq 0 ]; then
    echo "[ERROR] 적용 가능한 Tomcat 인스턴스가 없습니다." >&2
    log_debug "적용 가능한 Tomcat 인스턴스가 없습니다."
    exit 1
fi

APPLY_JVM=$(grep '^JAVA_OPTS=' "$APPLY_SRC" | cut -d= -f2- | tr -d '"')

for idx in "${!TOMCAT_PATHS[@]}"; do
    T_PATH="${TOMCAT_PATHS[$idx]}"
    LABEL="${TOMCAT_LABELS[$idx]}"
    PORT="${TOMCAT_PORTS[$idx]}"
    CONF_FILE="$T_PATH/conf/server.xml"
    CATALINA_SH="$T_PATH/bin/catalina.sh"
    SETENV_SH="$T_PATH/bin/setenv.sh"
    TS=$(date +%Y%m%d_%H%M%S)

    echo "---- $LABEL ($T_PATH) 포트 $PORT 적용 미리보기 ----"
    log_debug "$LABEL 포트 $PORT 적용 시작"

    CURR_JVM=""
    [ -f "$SETENV_SH" ] && CURR_JVM=$(grep 'JAVA_OPTS=' "$SETENV_SH" | grep -v '^#' | tail -1 | cut -d= -f2- | tr -d '"')
    [ "$APPLY_JVM" != "$CURR_JVM" ] && JVM_CHANGE=1 || JVM_CHANGE=0

    SNIPPET=$(awk -v port="$PORT" 'BEGIN{RS="<Connector"; ORS=""} $0 ~ "port=\""port"\"" {print "<Connector"$0}' "$APPLY_SRC")
    if [ -z "$SNIPPET" ]; then
        echo "[WARN] $PORT 포트에 대한 Connector 설정이 없습니다."
        log_debug "$LABEL 포트 $PORT 에 대한 Connector 블록 없음"
        continue
    fi

    RECOMM_LINE=$(echo "$SNIPPET" | grep '<Connector ' | sed 's/^[[:space:]]*//')
    RECOMM_PROTO=$(echo "$RECOMM_LINE" | grep -o 'protocol="[^\"]*"' | head -1 | cut -d'"' -f2)
    EXIST_LINENO=$(grep -n '<Connector ' "$CONF_FILE" | grep "port=\"$PORT\"" | grep "protocol=" | head -1 | cut -d: -f1)

    if [ -z "$EXIST_LINENO" ]; then
        CONNECTOR_DIFF=2
    else
        EXIST_BLOCK=$(awk "NR>=$EXIST_LINENO" "$CONF_FILE" | awk '/<Connector /,/>/')
        [ "$EXIST_BLOCK" != "$SNIPPET" ] && CONNECTOR_DIFF=1 || CONNECTOR_DIFF=0
    fi

    [ $JVM_CHANGE -eq 0 ] && [ $CONNECTOR_DIFF -eq 0 ] && echo "(변경 사항 없음)" && log_debug "$LABEL 변경 없음" && continue

    cp -a "$CONF_FILE" "$BACKUP_DIR/server.xml.bak.$TS"
    BACKUP_FILE="$BACKUP_DIR/server.xml.bak.$TS"
    [ -f "$CATALINA_SH" ] && cp -a "$CATALINA_SH" "$BACKUP_DIR/catalina.sh.bak.$TS" 2>/dev/null
    log_debug "$LABEL server.xml 백업 완료 → $BACKUP_FILE"

    TMP_PATCH="$CONF_FILE.tmp"
    cp "$CONF_FILE" "$TMP_PATCH"

    if [ $JVM_CHANGE -eq 1 ]; then
        if [ -z "$CURR_JVM" ]; then
            echo -e "\n# added\nexport JAVA_OPTS=\"$APPLY_JVM\"" >> "$SETENV_SH"
            chmod +x "$SETENV_SH"
            log_debug "$LABEL setenv.sh 에 JAVA_OPTS 추가"
        else
            sed -i "s|^.*JAVA_OPTS=.*|export JAVA_OPTS=\"$APPLY_JVM\"|g" "$SETENV_SH"
            log_debug "$LABEL setenv.sh 의 JAVA_OPTS 변경"
        fi
        echo "[APPLIED] JAVA_OPTS"
    fi

    SNIPPET_FILE="$TMP_CONF_DIR/.connector_$PORT.$$"
    echo "$SNIPPET" > "$SNIPPET_FILE"

    if [ $CONNECTOR_DIFF -eq 1 ]; then
        # port와 protocol 속성이 포함된 기존 Connector 블록을 주석 처리하고 새로운 설정 추가
        awk -v lineno="$EXIST_LINENO" -v f="$SNIPPET_FILE" -v port="$PORT" '
        BEGIN { in_block=0; block=""; }
        /<Connector / && $0 ~ "port=\""port"\"" && $0 ~ "protocol=" {
            in_block=1; block="<!--\n"; next
        }
        in_block {
            block=block $0 "\n"
            if (/>/) {
                in_block=0
                block=block "-->\n"
                while ((getline line < f) > 0) block=block line "\n"
                close(f)
                print block
                next
            }
            next
        }
        { print }
        ' "$CONF_FILE" > "$TMP_PATCH"
        echo "[APPLIED] Connector 포트 $PORT 설정 교체 (기존 설정 주석 처리)"
        log_debug "$LABEL 포트 $PORT Connector 설정 교체 및 기존 블록 주석 처리: $EXIST_BLOCK"
    elif [ $CONNECTOR_DIFF -eq 2 ]; then
        # 새로운 Connector 추가
        awk -v f="$SNIPPET_FILE" '/<\/Service>/ {
            while ((getline line < f) > 0) print line
            close(f)
        }
        { print }' "$CONF_FILE" > "$TMP_PATCH"
        echo "[APPLIED] Connector 포트 $PORT 설정 추가"
        log_debug "$LABEL 포트 $PORT Connector 설정 추가"
    fi

    DIFF_FILE="$LOG_DIR/diff_tomcat_$PORT_$TS.diff"
    diff -u "$CONF_FILE" "$TMP_PATCH" > "$DIFF_FILE" 2>> "$LOG_DIR/apply_tomcat_error.log"
    if [ $? -ne 0 ] || [ ! -s "$DIFF_FILE" ]; then
        echo "[WARN] diff 생성 실패, 로그 확인: $LOG_DIR/apply_tomcat_error.log" >&2
        log_debug "$LABEL diff 생성 실패"
    else
        echo "[INFO] 변경 내역 저장: $DIFF_FILE"
        log_debug "$LABEL diff 저장 완료 → $DIFF_FILE"
    fi

    cp -a "$TMP_PATCH" "$CONF_FILE"
    rm -f "$TMP_PATCH" "$SNIPPET_FILE"
    echo "[적용 완료] $LABEL → $CONF_FILE"
    log_debug "$LABEL server.xml 반영 완료"

    "$CATALINA_SH" configtest >/dev/null 2>> "$LOG_DIR/apply_tomcat_error.log"
    if [ $? -eq 0 ]; then
        "$CATALINA_SH" stop >/dev/null 2>> "$LOG_DIR/apply_tomcat_error.log"
        sleep 2
        "$CATALINA_SH" start >/dev/null 2>> "$LOG_DIR/apply_tomcat_error.log"
        if [ $? -eq 0 ]; then
            echo "[OK] $LABEL (포트 $PORT) 적용 및 재시작 완료"
            log_debug "$LABEL 재시작 완료"
        else
            echo "[ERROR] $LABEL: 재시작 실패, 롤백" >&2
            cp -a "$BACKUP_FILE" "$CONF_FILE"
            log_debug "$LABEL 재시작 실패 → 복구 수행"
            echo "[복구] $CONF_FILE ← $BACKUP_FILE"
            continue
        fi
    else
        echo "[ERROR] $LABEL 문법 오류 발생" >&2
        cat "$LOG_DIR/apply_tomcat_error.log"
        ERR_CONF_FILE="$ERR_CONF_DIR/server.xml.err.$TS"
        cp -a "$CONF_FILE" "$ERR_CONF_FILE"
        log_debug "$LABEL 문법 에러 → $ERR_CONF_FILE 저장"
        echo "[ERR_CONF] 에러 적용 conf를 $ERR_CONF_FILE 에 저장했습니다."
        cp -a "$BACKUP_FILE" "$CONF_FILE"
        log_debug "$LABEL 에러 발생 → 설정 복구 수행"
        echo "[복구] $CONF_FILE ← $BACKUP_FILE"
        continue
    fi

done

echo "==== 모든 Tomcat 인스턴스에 대한 설정 적용 완료 ===="
exit 0
