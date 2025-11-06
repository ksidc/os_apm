#!/bin/bash


#


# apply_apache.sh


# calculate_mpm_config.shÃÂ¬ÃÂÃÂÃÂ¬ÃÂÃÂ ÃÂ¬ÃÂÃÂÃÂ¬ÃÂÃÂ±ÃÂ­ÃÂÃÂ apache_tuning.confÃÂ«ÃÂ¥ÃÂ¼ ÃÂ¬ÃÂ ÃÂÃÂ¬ÃÂÃÂ©ÃÂ­ÃÂÃÂÃÂ«ÃÂÃÂ¤.





BASE_DIR="/usr/local/src/iteasy_tuning"


ARTIFACT_LOG_DIR="${ARTIFACT_LOG_DIR:-$BASE_DIR/logs}"


LOG_DIR="$ARTIFACT_LOG_DIR"


TMP_CONF_DIR="$BASE_DIR/tmp_conf"


SERVICE_LOG="${SERVICE_LOG:-$ARTIFACT_LOG_DIR/service_paths.log}"


SCRIPTS_DIR="$BASE_DIR/scripts"


ERR_CONF_DIR="$BASE_DIR/err_conf"





COMMON_SH="$SCRIPTS_DIR/common.sh"


PARSER_SH="$SCRIPTS_DIR/lib/kv_parser.sh"





if [ ! -f "$COMMON_SH" ]; then


    echo "[ERROR] ÃÂªÃÂ³ÃÂµÃÂ­ÃÂÃÂµ ÃÂ¬ÃÂÃÂ¤ÃÂ­ÃÂÃÂ¬ÃÂ«ÃÂ¦ÃÂ½ÃÂ­ÃÂÃÂ¸(${COMMON_SH})ÃÂªÃÂ°ÃÂ ÃÂ¬ÃÂÃÂÃÂ¬ÃÂÃÂµÃÂ«ÃÂÃÂÃÂ«ÃÂÃÂ¤." >&2


    exit 1


fi


source "$COMMON_SH"





if [ ! -f "$PARSER_SH" ]; then


    echo "[ERROR] ÃÂ­ÃÂÃÂ¤-ÃÂªÃÂ°ÃÂ ÃÂ­ÃÂÃÂÃÂ¬ÃÂÃÂ(${PARSER_SH})ÃÂªÃÂ°ÃÂ ÃÂ¬ÃÂÃÂÃÂ¬ÃÂÃÂµÃÂ«ÃÂÃÂÃÂ«ÃÂÃÂ¤." >&2


    exit 1


fi


source "$PARSER_SH"





check_root


setup_logging


mkdir -p "$ERR_CONF_DIR" 2>/dev/null





RECOMM_FILE="$TMP_CONF_DIR/apache_tuning.conf"


[ -f "$RECOMM_FILE" ] || {


    log_debug "ÃÂ¬ÃÂ¶ÃÂÃÂ¬ÃÂ²ÃÂ ÃÂ¬ÃÂÃÂ¤ÃÂ¬ÃÂ ÃÂ ÃÂ­ÃÂÃÂÃÂ¬ÃÂÃÂ¼(${RECOMM_FILE})ÃÂ¬ÃÂÃÂ´ ÃÂ¬ÃÂÃÂÃÂ¬ÃÂÃÂµÃÂ«ÃÂÃÂÃÂ«ÃÂÃÂ¤."


    echo "[ERROR] ÃÂ¬ÃÂ¶ÃÂÃÂ¬ÃÂ²ÃÂ ÃÂ¬ÃÂÃÂ¤ÃÂ¬ÃÂ ÃÂ ÃÂ­ÃÂÃÂÃÂ¬ÃÂÃÂ¼ÃÂ¬ÃÂÃÂ´ ÃÂ¬ÃÂÃÂÃÂ¬ÃÂÃÂµÃÂ«ÃÂÃÂÃÂ«ÃÂÃÂ¤. ÃÂ«ÃÂ¨ÃÂ¼ÃÂ¬ÃÂ ÃÂ calculate_mpm_config.shÃÂ«ÃÂ¥ÃÂ¼ ÃÂ¬ÃÂÃÂ¤ÃÂ­ÃÂÃÂÃÂ­ÃÂÃÂÃÂ¬ÃÂÃÂ¸ÃÂ¬ÃÂÃÂ." >&2


    exit 1


}





[ -f "$SERVICE_LOG" ] || {


    log_debug "service_paths.log(${SERVICE_LOG})ÃÂªÃÂ°ÃÂ ÃÂ¬ÃÂÃÂÃÂ¬ÃÂÃÂµÃÂ«ÃÂÃÂÃÂ«ÃÂÃÂ¤."


    echo "[ERROR] service_paths.logÃÂ«ÃÂ¥ÃÂ¼ ÃÂ¬ÃÂ°ÃÂ¾ÃÂ¬ÃÂÃÂ ÃÂ¬ÃÂÃÂ ÃÂ¬ÃÂÃÂÃÂ¬ÃÂÃÂµÃÂ«ÃÂÃÂÃÂ«ÃÂÃÂ¤." >&2


    exit 1


}





APACHE_RUNNING=$(kv_get_value "$SERVICE_LOG" "APACHE_RUNNING")


[ "$APACHE_RUNNING" = "1" ] || {


    log_debug "ApacheÃÂªÃÂ°ÃÂ ÃÂ¬ÃÂÃÂ¤ÃÂ­ÃÂÃÂ ÃÂ¬ÃÂ¤ÃÂÃÂ¬ÃÂÃÂ´ ÃÂ¬ÃÂÃÂÃÂ«ÃÂÃÂÃÂ«ÃÂ¯ÃÂÃÂ«ÃÂ¡ÃÂ ÃÂ¬ÃÂ ÃÂÃÂ¬ÃÂÃÂ©ÃÂ¬ÃÂÃÂ ÃÂªÃÂ±ÃÂ´ÃÂ«ÃÂÃÂÃÂ«ÃÂÃÂÃÂ«ÃÂÃÂÃÂ«ÃÂÃÂ¤."


    echo "[SKIP] ApacheÃÂªÃÂ°ÃÂ ÃÂ¬ÃÂÃÂ¤ÃÂ­ÃÂÃÂ ÃÂ¬ÃÂ¤ÃÂÃÂ¬ÃÂÃÂ´ ÃÂ¬ÃÂÃÂÃÂ«ÃÂÃÂÃÂ«ÃÂÃÂÃÂ«ÃÂÃÂ¤."


    exit 0


}





APACHE_MPM_CONF=$(kv_get_value "$SERVICE_LOG" "APACHE_MPM_CONF")


APACHE_CONFIG=$(kv_get_value "$SERVICE_LOG" "APACHE_CONFIG")


APACHE_BINARY=$(kv_get_value "$SERVICE_LOG" "APACHE_BINARY")


APACHE_MPM=$(kv_get_value "$SERVICE_LOG" "APACHE_MPM")





APACHE_BINARY=${APACHE_BINARY:-/usr/sbin/httpd}


APACHE_MPM=${APACHE_MPM:-prefork}





TARGET_FILE="$APACHE_MPM_CONF"


if [ -z "$TARGET_FILE" ] || [ "$TARGET_FILE" = "NOT_FOUND" ] || [ ! -f "$TARGET_FILE" ]; then


    TARGET_FILE="$APACHE_CONFIG"


fi





if [ -z "$TARGET_FILE" ] || [ ! -f "$TARGET_FILE" ]; then


    log_debug "ÃÂ¬ÃÂ ÃÂÃÂ¬ÃÂÃÂ© ÃÂ«ÃÂÃÂÃÂ¬ÃÂÃÂ ÃÂ­ÃÂÃÂÃÂ¬ÃÂÃÂ¼ÃÂ¬ÃÂÃÂ ÃÂ¬ÃÂ°ÃÂ¾ÃÂ¬ÃÂÃÂ ÃÂ¬ÃÂÃÂ ÃÂ¬ÃÂÃÂÃÂ¬ÃÂÃÂµÃÂ«ÃÂÃÂÃÂ«ÃÂÃÂ¤. TARGET=${TARGET_FILE}"


    echo "[ERROR] ÃÂ¬ÃÂ ÃÂÃÂ¬ÃÂÃÂ© ÃÂ«ÃÂÃÂÃÂ¬ÃÂÃÂ Apache ÃÂ¬ÃÂÃÂ¤ÃÂ¬ÃÂ ÃÂ ÃÂ­ÃÂÃÂÃÂ¬ÃÂÃÂ¼ÃÂ¬ÃÂÃÂ ÃÂ¬ÃÂ°ÃÂ¾ÃÂ¬ÃÂÃÂ ÃÂ¬ÃÂÃÂ ÃÂ¬ÃÂÃÂÃÂ¬ÃÂÃÂµÃÂ«ÃÂÃÂÃÂ«ÃÂÃÂ¤." >&2


    exit 1


fi





TIMESTAMP=$(date +%Y%m%d_%H%M%S)


WORK_FILE="${TARGET_FILE}.tuning.${TIMESTAMP}"


cp -a "$TARGET_FILE" "$WORK_FILE" || {


    log_debug "ÃÂ¬ÃÂÃÂ¤ÃÂ«ÃÂ¥ÃÂ: ${TARGET_FILE} ÃÂ«ÃÂ³ÃÂµÃÂ¬ÃÂÃÂ¬ ÃÂ¬ÃÂÃÂ¤ÃÂ­ÃÂÃÂ¨"


    echo "[ERROR] ÃÂªÃÂ¸ÃÂ°ÃÂ¬ÃÂ¡ÃÂ´ ÃÂ¬ÃÂÃÂ¤ÃÂ¬ÃÂ ÃÂ ÃÂ­ÃÂÃÂÃÂ¬ÃÂÃÂ¼ ÃÂ«ÃÂ³ÃÂµÃÂ¬ÃÂ ÃÂÃÂ¬ÃÂÃÂ ÃÂ¬ÃÂÃÂ¤ÃÂ­ÃÂÃÂ¨ÃÂ­ÃÂÃÂÃÂ¬ÃÂÃÂµÃÂ«ÃÂÃÂÃÂ«ÃÂÃÂ¤." >&2


    exit 1


}





log_debug "Apache ÃÂ¬ÃÂ ÃÂÃÂ¬ÃÂÃÂ© ÃÂ«ÃÂÃÂÃÂ¬ÃÂÃÂ: ${TARGET_FILE}, ÃÂ¬ÃÂÃÂÃÂ¬ÃÂÃÂ ÃÂ¬ÃÂÃÂÃÂ¬ÃÂÃÂ ÃÂ­ÃÂÃÂÃÂ¬ÃÂÃÂ¼: ${WORK_FILE}"





sed -i "/<IfModule mpm_.*_module>/,/<\/IfModule>/d" "$WORK_FILE"


cat "$RECOMM_FILE" >> "$WORK_FILE"





if ! [ -s "$WORK_FILE" ]; then


    log_debug "ÃÂ¬ÃÂÃÂ¤ÃÂ«ÃÂ¥ÃÂ: ÃÂ¬ÃÂÃÂÃÂ¬ÃÂÃÂ ÃÂ­ÃÂÃÂÃÂ¬ÃÂÃÂ¼(${WORK_FILE})ÃÂ¬ÃÂÃÂ´ ÃÂ«ÃÂ¹ÃÂÃÂ¬ÃÂÃÂ´ ÃÂ¬ÃÂÃÂÃÂ¬ÃÂÃÂµÃÂ«ÃÂÃÂÃÂ«ÃÂÃÂ¤."


    echo "[ERROR] ÃÂ¬ÃÂÃÂÃÂ¬ÃÂÃÂ ÃÂ­ÃÂÃÂÃÂ¬ÃÂÃÂ¼ÃÂ¬ÃÂÃÂ´ ÃÂ«ÃÂ¹ÃÂÃÂ¬ÃÂÃÂ´ ÃÂ¬ÃÂÃÂÃÂ¬ÃÂÃÂµÃÂ«ÃÂÃÂÃÂ«ÃÂÃÂ¤. ÃÂ¬ÃÂ ÃÂÃÂ¬ÃÂÃÂ©ÃÂ¬ÃÂÃÂ ÃÂ¬ÃÂ¤ÃÂÃÂ«ÃÂÃÂ¨ÃÂ­ÃÂÃÂ©ÃÂ«ÃÂÃÂÃÂ«ÃÂÃÂ¤." >&2


    rm -f "$WORK_FILE"


    exit 1


fi





if ! "$APACHE_BINARY" -t -f "$WORK_FILE" >/dev/null 2>&1; then


    ERR_FILE="$ERR_CONF_DIR/apache_${TIMESTAMP}.err.conf"


    cp -a "$WORK_FILE" "$ERR_FILE"


    log_debug "ÃÂ¬ÃÂÃÂ¤ÃÂ«ÃÂ¥ÃÂ: ÃÂ«ÃÂ¬ÃÂ¸ÃÂ«ÃÂ²ÃÂ ÃÂªÃÂ²ÃÂÃÂ¬ÃÂ¦ÃÂ ÃÂ¬ÃÂÃÂ¤ÃÂ­ÃÂÃÂ¨. ERR_FILE=${ERR_FILE}"


    echo "[ERROR] Apache ÃÂ¬ÃÂÃÂ¤ÃÂ¬ÃÂ ÃÂ ÃÂªÃÂ²ÃÂÃÂ¬ÃÂ¦ÃÂÃÂ¬ÃÂÃÂ ÃÂ¬ÃÂÃÂ¤ÃÂ­ÃÂÃÂ¨ÃÂ­ÃÂÃÂÃÂ¬ÃÂÃÂµÃÂ«ÃÂÃÂÃÂ«ÃÂÃÂ¤. ${ERR_FILE}ÃÂ«ÃÂ¥ÃÂ¼ ÃÂ­ÃÂÃÂÃÂ¬ÃÂÃÂ¸ÃÂ­ÃÂÃÂÃÂ¬ÃÂÃÂ¸ÃÂ¬ÃÂÃÂ." >&2


    rm -f "$WORK_FILE"


    exit 1


fi





cp -a "$TARGET_FILE" "${TARGET_FILE}.backup.${TIMESTAMP}"


cp -a "$WORK_FILE" "$TARGET_FILE"


rm -f "$WORK_FILE"





if systemctl --quiet is-active httpd.service 2>/dev/null; then


    systemctl reload httpd >/dev/null 2>&1 || systemctl restart httpd >/dev/null 2>&1


elif systemctl --quiet is-active apache2.service 2>/dev/null; then


    systemctl reload apache2 >/dev/null 2>&1 || systemctl restart apache2 >/dev/null 2>&1


else


    "$APACHE_BINARY" -k graceful >/dev/null 2>&1


fi





log_debug "Apache ÃÂ¬ÃÂÃÂ¤ÃÂ¬ÃÂ ÃÂ ÃÂ¬ÃÂ ÃÂÃÂ¬ÃÂÃÂ© ÃÂ¬ÃÂÃÂÃÂ«ÃÂ£ÃÂ: ${TARGET_FILE}"


echo "[OK] Apache ÃÂ¬ÃÂÃÂ¤ÃÂ¬ÃÂ ÃÂÃÂ¬ÃÂÃÂ´ ÃÂ¬ÃÂ ÃÂÃÂ¬ÃÂÃÂ©ÃÂ«ÃÂÃÂÃÂ¬ÃÂÃÂÃÂ¬ÃÂÃÂµÃÂ«ÃÂÃÂÃÂ«ÃÂÃÂ¤. ÃÂ«ÃÂÃÂÃÂ¬ÃÂÃÂ ÃÂ­ÃÂÃÂÃÂ¬ÃÂÃÂ¼: ${TARGET_FILE}"


exit 0


