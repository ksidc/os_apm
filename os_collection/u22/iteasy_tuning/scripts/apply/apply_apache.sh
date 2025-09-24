#!/bin/bash
# apply_apache.sh — no-autostart when previously stopped (2025-08-22)
# 목적: Apache(패키지 apache2 / 컴파일 httpd) 모두에 대해 MPM 추천값을 적용하되,
#       "탐지 시 정지되어 있던 인스턴스는 절대 자동 기동하지 않도록" 보호.
# 핵심:
#  - 패키지형: APACHE_CONFDIR=/etc/apache2 apache2ctl -f /etc/apache2/apache2.conf -t 로 문법검사 고정
#  - 패키지형 재적용: systemctl reload → apache2ctl -k graceful → systemctl restart → apache2ctl restart (폴백)
#  - 컴파일형: httpd -t -f <MAIN> / -k graceful → 실패 시 -k restart
#  - 기존 MPM 블록/맨바닥 지시어 제거 → 추천 블록 1개만 삽입(중복 방지)
#  - 적용 후 실제 키 존재 검증(없으면 즉시 롤백)
#  - 새 가드: 탐지 당시 RUNNING=0 이면 재시작 단계 "스킵" (환경변수 ALLOW_START_DEAD=1 로 강제 기동 가능)

set -o pipefail

BASE_DIR="/usr/local/src/iteasy_tuning"
LOG_DIR="$BASE_DIR/logs"
TMP_CONF_DIR="$BASE_DIR/tmp_conf"
BACKUP_DIR="$BASE_DIR/backups"
ERR_CONF_DIR="$BASE_DIR/err_conf"
SERVICE_PATHS="$LOG_DIR/service_paths.log"
SCRIPTS_DIR="$BASE_DIR/scripts"

# 실행 파일 경로 로깅(섀도 카피 이슈 탐지용)
echo "[RUNNING] $(date +%F_%T) apply_apache.sh path=$(readlink -f "$0")" | tee -a "$LOG_DIR/apply.log" 2>/dev/null || true

unset CATALINA_BASE CATALINA_HOME CATALINA_TMPDIR CATALINA_OPTS

# 공통 함수 로드
if [ ! -f "$SCRIPTS_DIR/common.sh" ]; then
  echo "[ERROR] 공통 스크립트가 없습니다: $SCRIPTS_DIR/common.sh" >&2
  exit 1
fi
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/common.sh"
setup_logging
check_root

mkdir -p "$BACKUP_DIR" "$ERR_CONF_DIR" || true

# service_paths 로드
if [ ! -f "$SERVICE_PATHS" ]; then
  echo "[ERROR] service_paths.log가 없습니다: $SERVICE_PATHS" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$SERVICE_PATHS" 2>/dev/null || { echo "[ERROR] service_paths.log 로드 실패" >&2; exit 1; }

# ---------- 유틸 ----------
is_package_binary() { [[ "$1" == *"/usr/sbin/apache2"* ]]; }

apache2ctl_bin() {
  if command -v apache2ctl >/dev/null 2>&1; then command -v apache2ctl; 
  elif [ -x /usr/sbin/apache2ctl ]; then echo /usr/sbin/apache2ctl; 
  else echo apache2ctl; fi
}

main_conf_for() {
  # $1: binary, $2: raw main conf from service_paths
  if is_package_binary "$1"; then
    echo "/etc/apache2/apache2.conf"
  else
    [ -n "$2" ] && echo "$2" || echo "/usr/local/apache/conf/httpd.conf"
  fi
}

strip_mpm_blocks_and_bare() {
  # $1: 파일 경로 — 모든 MPM 블록(prefork/worker/event) 및 맨바닥 MPM 지시어 제거
  local f="$1"
  sed -i '/^[[:space:]]*<IfModule mpm_prefork_module>/,^[[:space:]]*<\/IfModule>[[:space:]]*$/d' "$f"
  sed -i '/^[[:space:]]*<IfModule mpm_worker_module>/,^[[:space:]]*<\/IfModule>[[:space:]]*$/d' "$f"
  sed -i '/^[[:space:]]*<IfModule mpm_event_module>/,^[[:space:]]*<\/IfModule>[[:space:]]*$/d' "$f"
  sed -i -E '/^[[:space:]]*(StartServers|MinSpareServers|MaxSpareServers|ServerLimit|MaxRequestWorkers|MaxClients|MaxConnectionsPerChild)\b/d' "$f"
}

append_recommend_block() {
  # $1: 대상 파일, $2: 추천 블록(conf fragment)
  echo "" >> "$1"
  cat "$2" >> "$1"
}

extract_keys_from_block() {
  # $1: conf fragment → 키 목록(공백 구분) 반환
  awk 'BEGIN{inblk=0}
       /<IfModule mpm_.*_module>/ {inblk=1; next}
       /<\/IfModule>/ {inblk=0; next}
       { if(inblk){ if($1 ~ /^(StartServers|MinSpareServers|MaxSpareServers|ServerLimit|MaxRequestWorkers|MaxClients|MaxConnectionsPerChild)$/) print $1 } }' "$1" | sort -u | xargs
}

ensure_keys_present() {
  # $1: 대상 conf, $2..: 키 리스트 → 모든 키가 존재하면 0
  local file="$1"; shift; local keys=("$@")
  for k in "${keys[@]}"; do
    if ! grep -q -E "^[[:space:]]*${k}[[:space:]]+" "$file"; then
      echo "[VERIFY-FAIL] ${k} not found in $(basename "$file")" >> "$LOG_DIR/apply_apache_error.log"
      return 1
    fi
  done
  return 0
}

run_configtest() {
  # $1: binary, $2: main_conf(컴파일형 전용)
  if is_package_binary "$1"; then
    local APCTL; APCTL="$(apache2ctl_bin)"
    echo "[DRY-RUN] APACHE_CONFDIR=/etc/apache2 $APCTL -f /etc/apache2/apache2.conf -t"
    APACHE_CONFDIR=/etc/apache2 "$APCTL" -f /etc/apache2/apache2.conf -t 2> "$LOG_DIR/apply_apache_error.log"
  else
    echo "[DRY-RUN] $1 -t -f $2"
    "$1" -t -f "$2" 2> "$LOG_DIR/apply_apache_error.log"
  fi
}

restart_instance() {
  # $1: binary, $2: main_conf
  if is_package_binary "$1"; then
    local APCTL; APCTL="$(apache2ctl_bin)"
    # 순차 폴백(실패해도 다음 단계 시도)
    systemctl reload apache2 >/dev/null 2>>"$LOG_DIR/apply_apache_error.log" || true
    APACHE_CONFDIR=/etc/apache2 "$APCTL" -k graceful 2>>"$LOG_DIR/apply_apache_error.log" || true
    systemctl restart apache2 >/dev/null 2>>"$LOG_DIR/apply_apache_error.log" || true
    APACHE_CONFDIR=/etc/apache2 "$APCTL" restart 2>>"$LOG_DIR/apply_apache_error.log" || true
  else
    "$1" -k graceful -f "$2" >/dev/null 2>>"$LOG_DIR/apply_apache_error.log" || \
    "$1" -k restart  -f "$2" >/dev/null 2>>"$LOG_DIR/apply_apache_error.log"
  fi
}

post_check() {
  # $1: binary
  sleep 2
  if is_package_binary "$1"; then
    if command -v systemctl >/dev/null 2>&1; then
      systemctl is-active --quiet apache2 && return 0
    fi
  fi
  pgrep -f "$1" >/dev/null
}

pick_apply_src_for_idx() {
  # $1: ORIG_IDX, $2: CURR_IDX
  local a b
  a="$TMP_CONF_DIR/mpm_config_${1}.conf"
  b="$TMP_CONF_DIR/mpm_config_$(( $2 + 1 )).conf"
  if [ -s "$a" ]; then echo "$a"; return; fi
  if [ -s "$b" ]; then echo "$b"; return; fi
  local cand
  cand=$(ls -1t "$TMP_CONF_DIR"/mpm_config_*.conf 2>/dev/null | head -1)
  [ -s "$cand" ] && echo "$cand" || echo ""
}

# ---------- 대상 수집 ----------
MPM_CONF_LIST=(); MPM_BINARY_LIST=(); MPM_CONFIG_FILE=(); MPM_ORIG_IDX=(); MPM_PREV_RUNNING=()

if grep -q '^APACHE_MPM_CONF_' "$SERVICE_PATHS"; then
  for i in $(seq 1 ${MULTIPLE_APACHE_FOUND:-0}); do
    eval "conf=\$APACHE_MPM_CONF_$i"
    eval "binary=\$APACHE_BINARY_$i"
    eval "running=\$APACHE_RUNNING_$i"
    eval "config_file=\$APACHE_CONFIG_$i"
    # 정지 상태여도 적용은 허용(재기동만 스킵하기 위해)
    if [ -n "$conf" ] && [ -f "$conf" ]; then
      MPM_CONF_LIST+=("$conf"); MPM_BINARY_LIST+=("$binary"); MPM_CONFIG_FILE+=("$config_file"); MPM_ORIG_IDX+=("$i"); MPM_PREV_RUNNING+=("${running:-0}")
    fi
  done
else
  if [ -n "$APACHE_MPM_CONF" ] && [ -f "$APACHE_MPM_CONF" ]; then
    MPM_CONF_LIST+=("$APACHE_MPM_CONF"); MPM_BINARY_LIST+=("$APACHE_BINARY"); MPM_CONFIG_FILE+=("$APACHE_CONFIG"); MPM_ORIG_IDX+=("1"); MPM_PREV_RUNNING+=("${APACHE_RUNNING:-0}")
  fi
fi

[ "${#MPM_CONF_LIST[@]}" -eq 0 ] && { echo "[ERROR] 적용 대상 Apache MPM conf 파일이 없습니다." >&2; exit 1; }

# ---------- 인스턴스별 적용 ----------
ALLOW_START_DEAD=${ALLOW_START_DEAD:-0}

for idx in "${!MPM_CONF_LIST[@]}"; do
  CONF_FILE="${MPM_CONF_LIST[$idx]}"; BINARY="${MPM_BINARY_LIST[$idx]}"; CONFIG_FILE_RAW="${MPM_CONFIG_FILE[$idx]}"; ORIG_IDX="${MPM_ORIG_IDX[$idx]}"; PREV_RUN="${MPM_PREV_RUNNING[$idx]}"

  APPLY_SRC="$(pick_apply_src_for_idx "$ORIG_IDX" "$idx")"
  log_debug "[MAP] idx=$idx ORIG_IDX=$ORIG_IDX prev_running=${PREV_RUN} CONF_FILE=$CONF_FILE APPLY_SRC=$APPLY_SRC"
  if [ -z "$APPLY_SRC" ] || [ ! -s "$APPLY_SRC" ]; then
    echo "[SKIP] 추천 설정 파일이 없어 건너뜁니다. (orig=$ORIG_IDX)" >&2
    continue
  fi

  if [ ! -w "$CONF_FILE" ]; then
    echo "[ERROR] 쓰기 권한 없음: $CONF_FILE" >&2
    continue
  fi

  TS=$(date +%Y%m%d_%H%M%S)
  BACKUP_FILE="$BACKUP_DIR/$(basename "$CONF_FILE").bak.$TS"
  cp -a "$CONF_FILE" "$BACKUP_FILE" 2>>"$LOG_DIR/apply_apache_error.log" || { echo "[ERROR] 백업 실패: $CONF_FILE" >&2; continue; }
  echo "[INFO] 백업 완료: $CONF_FILE → $BACKUP_FILE"

  TMP_PATCH="$TMP_CONF_DIR/.apache_apply_patch.$$.$idx"
  cp "$CONF_FILE" "$TMP_PATCH" || { echo "[ERROR] 임시 패치 생성 실패" >&2; continue; }

  # 기존 블록/맨바닥 제거 후 추천 블록 삽입
  strip_mpm_blocks_and_bare "$TMP_PATCH"
  append_recommend_block "$TMP_PATCH" "$APPLY_SRC"

  DIFF_FILE="$LOG_DIR/diff_apache_${ORIG_IDX}_$TS.diff"
  diff -u "$CONF_FILE" "$TMP_PATCH" > "$DIFF_FILE" 2>>"$LOG_DIR/apply_apache_error.log" || true
  [ -s "$DIFF_FILE" ] && echo "[INFO] 변경 내역: $DIFF_FILE"

  # 즉시 적용
  cp -a "$TMP_PATCH" "$CONF_FILE" 2>>"$LOG_DIR/apply_apache_error.log" || { echo "[ERROR] 적용 실패: $CONF_FILE" >&2; rm -f "$TMP_PATCH"; continue; }
  rm -f "$TMP_PATCH"
  echo "[적용 완료] $CONF_FILE"

  # 적용 내용 키 검증
  KEYS_STR="$(extract_keys_from_block "$APPLY_SRC")"; read -r -a KEYS <<<"$KEYS_STR"
  if ! ensure_keys_present "$CONF_FILE" "${KEYS[@]}"; then
    echo "[ERROR] 적용 키 검증 실패 — 롤백합니다." >&2
    cp -a "$BACKUP_FILE" "$CONF_FILE" 2>>"$LOG_DIR/apply_apache_error.log" || true
    echo "[복구] $CONF_FILE ← $BACKUP_FILE"
    continue
  fi

  MAIN_CONF=$(main_conf_for "$BINARY" "$CONFIG_FILE_RAW")
  if ! run_configtest "$BINARY" "$MAIN_CONF"; then
    echo "[ERROR] 문법 검사 실패 — 롤백합니다." >&2
    cat "$LOG_DIR/apply_apache_error.log" >&2 || true
    ERR_SAVE="$ERR_CONF_DIR/$(basename "$CONF_FILE").err.$TS"; cp -a "$CONF_FILE" "$ERR_SAVE" 2>>"$LOG_DIR/apply_apache_error.log" || true
    echo "[ERR_CONF] 에러 conf 저장: $ERR_SAVE"
    cp -a "$BACKUP_FILE" "$CONF_FILE" 2>>"$LOG_DIR/apply_apache_error.log" || true
    echo "[복구] $CONF_FILE ← $BACKUP_FILE"
    continue
  fi
  echo "[dry-run] 특이사항 없음."

  # ==== 재시작 판단 가드 ====
  if [ "$PREV_RUN" != "1" ] && [ "$ALLOW_START_DEAD" != "1" ]; then
    echo "[SKIP-RESTART] 탐지 시 정지 상태(orig=$ORIG_IDX) → 자동 기동 금지 (ALLOW_START_DEAD=1 로 무시 가능)" | tee -a "$LOG_DIR/apply.log"
    continue
  fi

  if ! restart_instance "$BINARY" "$MAIN_CONF"; then
    echo "[WARN] graceful/restart 실패 — 재시도 또는 롤백" >&2
  fi

  if ! post_check "$BINARY"; then
    echo "[ERROR] 재시작 확인 실패 — 롤백합니다." >&2
    cp -a "$BACKUP_FILE" "$CONF_FILE" 2>>"$LOG_DIR/apply_apache_error.log" || true
    echo "[복구] $CONF_FILE ← $BACKUP_FILE"
    continue
  fi

  echo "[OK] 설정 적용 및 재시작 완료 (인스턴스 $ORIG_IDX)"

done

echo "==== 적용 및 테스트 완료 ===="
exit 0