#!/bin/bash
# apply_php-fpm.sh (patched)
# PHP-FPM 풀 설정(www.conf) 및 php.ini에 추천치 적용, 문법검사 후 서비스 reload/restart

set -o pipefail

BASE_DIR="/usr/local/src/iteasy_tuning"
LOG_DIR="$BASE_DIR/logs"
TMP_CONF_DIR="$BASE_DIR/tmp_conf"
BACKUP_DIR="$BASE_DIR/backups"
ERR_CONF_DIR="$BASE_DIR/err_conf"
SERVICE_PATHS="$LOG_DIR/service_paths.log"
SCRIPTS_DIR="$BASE_DIR/scripts"

# --- 공통 로드 ---
unset CATALINA_BASE CATALINA_HOME CATALINA_TMPDIR CATALINA_OPTS
if [ ! -f "$SCRIPTS_DIR/common.sh" ]; then
  echo "[ERROR] 공통 스크립트($SCRIPTS_DIR/common.sh)가 존재하지 않습니다." >&2
  exit 1
fi
source "$SCRIPTS_DIR/common.sh" || { echo "[ERROR] 공통 스크립트 로드 실패"; exit 1; }

setup_logging
log_debug "apply_php-fpm.sh 시작"
check_root

# --- 입력/환경 확인 ---
if [ ! -f "$SERVICE_PATHS" ]; then
  log_debug "오류: $SERVICE_PATHS 없음"
  echo "[ERROR] service_paths.log가 없습니다." >&2
  exit 1
fi
source "$SERVICE_PATHS" 2>/dev/null || { log_debug "service_paths.log 로드 실패"; exit 1; }

CONF_FILE="$PHP_FPM_CONF"           # 호환(풀 conf를 가리킴)
POOL_CONF_FILE="$PHP_FPM_POOL_CONF" # 실제 풀 conf
MAIN_CONF_FILE="$PHP_FPM_MAIN_CONF" # 메인 conf (php-fpm.conf)
INI_FILE="$PHP_FPM_INI"
APPLY_SRC="$TMP_CONF_DIR/php_fpm_config.conf"
APPLY_INI_SRC="$TMP_CONF_DIR/php_fpm_ini.conf"
PHPFPM_BIN="${PHP_FPM_BINARY:-$(command -v php-fpm || true)}"

# 경로 보정
[ -z "$POOL_CONF_FILE" ] && POOL_CONF_FILE="$CONF_FILE"
if [ -z "$MAIN_CONF_FILE" ]; then
  # Debian/Ubuntu 우선, RHEL 폴백
  MAIN_CONF_FILE="$(\
    { ls /etc/php/*/fpm/php-fpm.conf 2>/dev/null || true; echo /etc/php-fpm.conf; } \
    | while read -r f; do [ -f "$f" ] && echo "$f" && break; done)"
fi

# --- 유효성 검사 ---
if [ -z "$POOL_CONF_FILE" ] || [ ! -f "$POOL_CONF_FILE" ]; then
  log_debug "오류: 풀 설정 파일 없음: $POOL_CONF_FILE"
  echo "[ERROR] PHP-FPM 풀 설정 파일이 없습니다." >&2
  exit 1
fi
if [ -z "$MAIN_CONF_FILE" ] || [ ! -f "$MAIN_CONF_FILE" ]; then
  log_debug "경고: 메인 설정 파일 발견 실패: $MAIN_CONF_FILE"
  echo "[WARN] php-fpm 메인 설정 파일을 찾지 못했습니다. 일반 위치로 시도합니다."
  # 마지막 폴백
  if [ -f /etc/php-fpm.conf ]; then
    MAIN_CONF_FILE="/etc/php-fpm.conf"
  else
    MAIN_CONF_FILE="$(ls /etc/php/*/fpm/php-fpm.conf 2>/dev/null | head -1)"
  fi
  [ -z "$MAIN_CONF_FILE" ] && { echo "[ERROR] 메인 설정 파일을 찾을 수 없습니다."; exit 1; }
fi
if [ -z "$PHPFPM_BIN" ] || [ ! -x "$PHPFPM_BIN" ]; then
  log_debug "오류: php-fpm 바이너리 실행 불가: $PHPFPM_BIN"
  echo "[ERROR] php-fpm 바이너리를 찾을 수 없거나 실행할 수 없습니다." >&2
  exit 1
fi
if [ ! -f "$APPLY_SRC" ]; then
  log_debug "오류: 추천 설정 파일 없음: $APPLY_SRC"
  echo "[SKIP] 추천 설정 파일($APPLY_SRC)이 없습니다." >&2
  exit 1
fi
if [ -n "$INI_FILE" ] && [ ! -f "$APPLY_INI_SRC" ]; then
  log_debug "경고: 추천 php.ini 설정 파일 없음: $APPLY_INI_SRC"
  echo "[WARN] 추천 php.ini 설정 파일이 없어 php.ini 적용을 생략합니다."
  INI_FILE=""
fi

# --- 백업 파일 경로를 초기에 확정 (어떤 분기에서도 참조 가능) ---
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_DIR" "$ERR_CONF_DIR" || true
BASE_NAME=$(basename "$POOL_CONF_FILE")
BACKUP_FILE="$BACKUP_DIR/${BASE_NAME}.bak.$TIMESTAMP"
if [ -n "$INI_FILE" ]; then
  BASE_NAME_INI=$(basename "$INI_FILE")
  BACKUP_FILE_INI="$BACKUP_DIR/${BASE_NAME_INI}.bak.$TIMESTAMP"
fi

# --- 추천값 파싱(풀 conf) ---
declare -A RECOMM
while IFS='=' read -r key val; do
  key=$(echo "$key" | tr -d ' ')
  val=$(echo "$val" | sed 's/^ //')
  [[ -z "$key" || "$key" =~ ^# || "$key" =~ ^\[.*\] ]] && continue
  RECOMM["$key"]="$val"
done < <(grep -vE '^\[.*\]|^$' "$APPLY_SRC")

# 제약 검증
if [ "${RECOMM[pm]}" = "dynamic" ]; then
  MAX_CHILDREN=${RECOMM[pm.max_children]:-0}
  START_SERVERS=${RECOMM[pm.start_servers]:-0}
  MIN_SPARE=${RECOMM[pm.min_spare_servers]:-0}
  MAX_SPARE=${RECOMM[pm.max_spare_servers]:-0}
  if [ "$MIN_SPARE" -gt "$MAX_CHILDREN" ] || [ "$MAX_SPARE" -gt "$MAX_CHILDREN" ]; then
    echo "[ERROR] pm.min/max_spare_servers ≤ pm.max_children 이어야 합니다." >&2
    exit 1
  fi
  if [ "$START_SERVERS" -lt "$MIN_SPARE" ] || [ "$START_SERVERS" -gt "$MAX_SPARE" ]; then
    echo "[ERROR] pm.start_servers는 [min_spare, max_spare] 범위여야 합니다." >&2
    exit 1
  fi
fi

# --- 추천값 파싱(php.ini) ---
declare -A RECOMM_INI
if [ -n "$INI_FILE" ] && [ -f "$APPLY_INI_SRC" ]; then
  while IFS='=' read -r key val; do
    key=$(echo "$key" | tr -d ' ')
    val=$(echo "$val" | sed 's/^ //')
    [[ -z "$key" || "$key" =~ ^# || "$key" =~ ^\[.*\] ]] && continue
    RECOMM_INI["$key"]="$val"
  done < <(grep -vE '^\[.*\]|^$' "$APPLY_INI_SRC")
fi

# --- 변경 미리보기 & 패치 계획 산출(풀 conf) ---
echo "---- PHP_FPM_POOL_CONF: $POOL_CONF_FILE 미리보기 ----"
CHANGE_COUNT=0
declare -A PATCH_TYPE PATCH_VAL
mapfile -t EXIST_LINES < <(grep -vE '^\[.*\]|^$' "$POOL_CONF_FILE")
declare -a EXIST_KEYS=()

for line in "${EXIST_LINES[@]}"; do
  key=$(echo "$line" | cut -d'=' -f1 | tr -d ' ')
  val=$(echo "$line" | cut -d'=' -f2- | sed 's/^ //')
  [[ -z "$key" || "$key" =~ ^# ]] && continue
  EXIST_KEYS+=("$key")
  if [[ -n "${RECOMM[$key]}" ]]; then
    if [ "${RECOMM[$key]}" = "$val" ]; then
      echo "[SAME] $key = $val"
    else
      echo "[DIFF] $key: $val  →  ${RECOMM[$key]}"
      PATCH_TYPE["$key"]="mod"
      PATCH_VAL["$key"]="${RECOMM[$key]}"
      CHANGE_COUNT=$((CHANGE_COUNT+1))
    fi
  fi
done

for key in "${!RECOMM[@]}"; do
  FOUND=0
  for e in "${EXIST_KEYS[@]}"; do [ "$e" = "$key" ] && FOUND=1; done
  if [ $FOUND -eq 0 ]; then
    echo "[NEW]  $key = ${RECOMM[$key]}"
    PATCH_TYPE["$key"]="add"
    PATCH_VAL["$key"]="${RECOMM[$key]}"
    CHANGE_COUNT=$((CHANGE_COUNT+1))
  fi
done

# --- 변경 미리보기(php.ini) ---
CHANGE_COUNT_INI=0
declare -A PATCH_TYPE_INI PATCH_VAL_INI
if [ -n "$INI_FILE" ] && [ -f "$APPLY_INI_SRC" ]; then
  echo "---- PHP_FPM_INI: $INI_FILE 미리보기 ----"
  mapfile -t EXIST_LINES_INI < <(grep -vE '^\[.*\]|^$' "$INI_FILE")
  declare -a EXIST_KEYS_INI=()
  for line in "${EXIST_LINES_INI[@]}"; do
    key=$(echo "$line" | cut -d'=' -f1 | tr -d ' ')
    val=$(echo "$line" | cut -d'=' -f2- | sed 's/^ //')
    [[ -z "$key" || "$key" =~ ^# ]] && continue
    EXIST_KEYS_INI+=("$key")
    if [[ -n "${RECOMM_INI[$key]}" ]]; then
      if [ "${RECOMM_INI[$key]}" = "$val" ]; then
        echo "[SAME] $key = $val"
      else
        echo "[DIFF] $key: $val  →  ${RECOMM_INI[$key]}"
        PATCH_TYPE_INI["$key"]="mod"
        PATCH_VAL_INI["$key"]="${RECOMM_INI[$key]}"
        CHANGE_COUNT_INI=$((CHANGE_COUNT_INI+1))
      fi
    fi
  done
  for key in "${!RECOMM_INI[@]}"; do
    FOUND=0
    for e in "${EXIST_KEYS_INI[@]}"; do [ "$e" = "$key" ] && FOUND=1; done
    if [ $FOUND -eq 0 ]; then
      echo "[NEW]  $key = ${RECOMM_INI[$key]}"
      PATCH_TYPE_INI["$key"]="add"
      PATCH_VAL_INI["$key"]="${RECOMM_INI[$key]}"
      CHANGE_COUNT_INI=$((CHANGE_COUNT_INI+1))
    fi
  done
fi

# --- 변경 없음: configtest + reload만 수행(롤백 없음) ---
do_configtest_and_reload() {
  local svc="$1"
  echo "[DRY-RUN] php-fpm 문법 검사"
  # 중요: 메인 conf는 -y, php.ini는 -c 로 지정
  if [ -n "$INI_FILE" ]; then
    "$PHPFPM_BIN" -t -y "$MAIN_CONF_FILE" -c "$INI_FILE" 2> "$LOG_DIR/apply_php_fpm_error.log"
  else
    "$PHPFPM_BIN" -t -y "$MAIN_CONF_FILE" 2> "$LOG_DIR/apply_php_fpm_error.log"
  fi
  if [ $? -ne 0 ]; then
    echo "[ERROR] php-fpm 문법 검사 실패" >&2
    cat "$LOG_DIR/apply_php_fpm_error.log"
    return 1
  fi
  echo "[dry-run] 문법 이상 없음."
  systemctl reload "$svc" >/dev/null 2>>"$LOG_DIR/apply_php_fpm_error.log" || \
  systemctl restart "$svc" >/dev/null 2>>"$LOG_DIR/apply_php_fpm_error.log"
}

if [ "$CHANGE_COUNT" -eq 0 ] && [ "$CHANGE_COUNT_INI" -eq 0 ]; then
  # 서비스명 탐지
  SERVICE_NAME="$PHP_FPM_SERVICE"
  if [ -z "$SERVICE_NAME" ]; then
    SERVICE_NAME=$(systemctl list-units --type=service --state=running \
      | awk '{print $1}' | sed 's/\.service$//' \
      | grep -E '^php[0-9\.]*-fpm$' | head -1)
  fi
  if [ -z "$SERVICE_NAME" ]; then
    PHP_VER=$("$PHPFPM_BIN" -v 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
    [ -n "$PHP_VER" ] && SERVICE_NAME="php${PHP_VER}-fpm"
  fi
  [ -z "$SERVICE_NAME" ] && SERVICE_NAME="php-fpm"

  log_debug "변경 없음: 서비스=$SERVICE_NAME, 메인=$MAIN_CONF_FILE, ini=${INI_FILE:-<none>}"
  do_configtest_and_reload "$SERVICE_NAME" || exit 1
  echo "[OK] 변경사항 없음: 서비스 재적용 완료"
  exit 0
fi

# --- 백업 ---
cp -a "$POOL_CONF_FILE" "$BACKUP_FILE" 2>>"$LOG_DIR/apply_php_fpm_error.log" || {
  echo "[ERROR] 백업 실패: $POOL_CONF_FILE → $BACKUP_FILE" >&2
  exit 1
}
echo "[INFO] 백업 완료: $POOL_CONF_FILE → $BACKUP_FILE"
if [ -n "$INI_FILE" ]; then
  cp -a "$INI_FILE" "$BACKUP_FILE_INI" 2>>"$LOG_DIR/apply_php_fpm_error.log" || {
    echo "[ERROR] 백업 실패: $INI_FILE → $BACKUP_FILE_INI" >&2
    exit 1
  }
  echo "[INFO] 백업 완료: $INI_FILE → $BACKUP_FILE_INI"
fi

# --- 패치 파일 작성(풀 conf) ---
TMP_PATCH="$TMP_CONF_DIR/.php_fpm_apply_patch.$$"
cp "$POOL_CONF_FILE" "$TMP_PATCH" 2>>"$LOG_DIR/apply_php_fpm_error.log" || {
  echo "[ERROR] 임시 패치 파일 생성 실패: $TMP_PATCH" >&2
  exit 1
}
for key in "${!PATCH_TYPE[@]}"; do
  val="${PATCH_VAL[$key]}"
  if [ "${PATCH_TYPE[$key]}" = "mod" ]; then
    sed -i "s|^[[:space:]]*${key}[[:space:]]*=[[:space:]]*.*|$key = $val|" "$TMP_PATCH" 2>>"$LOG_DIR/apply_php_fpm_error.log"
  else
    echo "$key = $val" >> "$TMP_PATCH"
  fi
done

# diff 저장
DIFF_FILE="$LOG_DIR/diff_php_fpm_1_$TIMESTAMP.diff"
if ! diff -u "$POOL_CONF_FILE" "$TMP_PATCH" > "$DIFF_FILE" 2>>"$LOG_DIR/apply_php_fpm_error.log"; then
  # diff가 1을 반환할 수도 있으므로 파일 존재만 안내
  [ -s "$DIFF_FILE" ] && echo "[INFO] 변경 내역 저장: $DIFF_FILE"
fi

# 적용(풀 conf)
cp -a "$TMP_PATCH" "$POOL_CONF_FILE" 2>>"$LOG_DIR/apply_php_fpm_error.log" || {
  rm -f "$TMP_PATCH"
  echo "[ERROR] 풀 설정 적용 실패: $POOL_CONF_FILE" >&2
  exit 1
}
rm -f "$TMP_PATCH"
echo "[적용 완료] PHP_FPM_POOL_CONF → $POOL_CONF_FILE"

# --- php.ini 적용 ---
if [ -n "$INI_FILE" ] && [ -f "$APPLY_INI_SRC" ]; then
  TMP_PATCH_INI="$TMP_CONF_DIR/.php_fpm_ini_apply_patch.$$"
  cp "$INI_FILE" "$TMP_PATCH_INI" 2>>"$LOG_DIR/apply_php_fpm_error.log" || {
    echo "[ERROR] 임시 ini 패치 파일 생성 실패: $TMP_PATCH_INI" >&2
    exit 1
  }
  for key in "${!PATCH_TYPE_INI[@]}"; do
    val="${PATCH_VAL_INI[$key]}"
    if [ "${PATCH_TYPE_INI[$key]}" = "mod" ]; then
      sed -i "s|^[[:space:]]*${key}[[:space:]]*=[[:space:]]*.*|$key = $val|" "$TMP_PATCH_INI" 2>>"$LOG_DIR/apply_php_fpm_error.log"
    else
      echo "$key = $val" >> "$TMP_PATCH_INI"
    fi
  done
  DIFF_FILE_INI="$LOG_DIR/diff_php_fpm_ini_1_$TIMESTAMP.diff"
  if ! diff -u "$INI_FILE" "$TMP_PATCH_INI" > "$DIFF_FILE_INI" 2>>"$LOG_DIR/apply_php_fpm_error.log"; then
    [ -s "$DIFF_FILE_INI" ] && echo "[INFO] 변경 내역 저장: $DIFF_FILE_INI"
  fi
  cp -a "$TMP_PATCH_INI" "$INI_FILE" 2>>"$LOG_DIR/apply_php_fpm_error.log" || {
    rm -f "$TMP_PATCH_INI"
    echo "[ERROR] php.ini 적용 실패: $INI_FILE" >&2
    exit 1
  }
  rm -f "$TMP_PATCH_INI"
  echo "[적용 완료] PHP_FPM_INI → $INI_FILE"
fi

# --- 최종 문법 검사 ---
echo "[DRY-RUN] php-fpm 최종 문법 검사"
if [ -n "$INI_FILE" ]; then
  "$PHPFPM_BIN" -t -y "$MAIN_CONF_FILE" -c "$INI_FILE" 2> "$LOG_DIR/apply_php_fpm_error.log"
else
  "$PHPFPM_BIN" -t -y "$MAIN_CONF_FILE" 2> "$LOG_DIR/apply_php_fpm_error.log"
fi
if [ $? -ne 0 ]; then
  echo "[ERROR] 최종 문법 검사 실패 — 롤백합니다." >&2
  cat "$LOG_DIR/apply_php_fpm_error.log"
  cp -a "$BACKUP_FILE" "$POOL_CONF_FILE" 2>>"$LOG_DIR/apply_php_fpm_error.log"
  [ -n "$INI_FILE" ] && cp -a "$BACKUP_FILE_INI" "$INI_FILE" 2>>"$LOG_DIR/apply_php_fpm_error.log"
  exit 1
fi
echo "[dry-run] 문법 이상 없음."

# --- 서비스명 탐지 & 재적용 ---
SERVICE_NAME="$PHP_FPM_SERVICE"
if [ -z "$SERVICE_NAME" ]; then
  SERVICE_NAME=$(systemctl list-units --type=service --state=running \
    | awk '{print $1}' | sed 's/\.service$//' \
    | grep -E '^php[0-9\.]*-fpm$' | head -1)
fi
if [ -z "$SERVICE_NAME" ]; then
  PHP_VER=$("$PHPFPM_BIN" -v 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
  [ -n "$PHP_VER" ] && SERVICE_NAME="php${PHP_VER}-fpm"
fi
[ -z "$SERVICE_NAME" ] && SERVICE_NAME="php-fpm"

log_debug "서비스 재적용 대상: $SERVICE_NAME"
if ! systemctl reload "$SERVICE_NAME" >/dev/null 2>>"$LOG_DIR/apply_php_fpm_error.log"; then
  log_debug "reload 실패, restart 시도"
  if ! systemctl restart "$SERVICE_NAME" >/dev/null 2>>"$LOG_DIR/apply_php_fpm_error.log"; then
    echo "[ERROR] 서비스 재적용 실패 — 롤백합니다. ($SERVICE_NAME)" >&2
    cp -a "$BACKUP_FILE" "$POOL_CONF_FILE" 2>>"$LOG_DIR/apply_php_fpm_error.log"
    [ -n "$INI_FILE" ] && cp -a "$BACKUP_FILE_INI" "$INI_FILE" 2>>"$LOG_DIR/apply_php_fpm_error.log"
    exit 1
  fi
fi

echo "==== 적용 및 서비스 재적용 완료 ===="
exit 0