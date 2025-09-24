#!/bin/bash
# find_php_fpm.sh (patched, Ubuntu/Debian & RHEL 계열 호환)
# - 서비스명: php<주>.<부>-fpm → 없으면 php-fpm 로 폴백
# - 설정 경로: /etc/php/<주>.<부>/fpm/{pool.d/www.conf, php-fpm.conf, php.ini} 우선
#              없으면 RHEL 계열 /etc/php-fpm.{conf,d}/… 로 폴백
# - 출력 변수: 호환성 유지를 위해 PHP_FPM_CONF 는 풀 conf(www.conf)를 가리킴
#              추가로 PHP_FPM_POOL_CONF, PHP_FPM_MAIN_CONF, PHP_FPM_INI 도 함께 출력
# - 다중 인스턴스 대응: 최초 유효 인스턴스를 대표로 선택, 목록은 PHP_FPM_BINARY_LIST 로 제공

# ---- 공통 로드 --------------------------------------------------------------
SCRIPTS_DIR="/usr/local/src/iteasy_tuning/scripts"
if [ ! -f "$SCRIPTS_DIR/common.sh" ]; then
  echo "오류: 공통 스크립트($SCRIPTS_DIR/common.sh)가 존재하지 않습니다." >&2
  exit 1
fi
source "$SCRIPTS_DIR/common.sh"

log_debug "find_php_fpm.sh 시작"

# ---- 초기값 ----------------------------------------------------------------
PHP_FPM_BINARY=""
PHP_FPM_CONF=""         # backward-compat: 풀 conf(www.conf) 경로
PHP_FPM_POOL_CONF=""
PHP_FPM_MAIN_CONF=""
PHP_FPM_INI=""
PHP_FPM_RUNNING=0
PHP_FPM_SERVICE=""
MULTIPLE_PHP_FPM_FOUND=0
PHP_FPM_BINARY_LIST=""

# ---- 유틸리티 ---------------------------------------------------------------
trim() { sed 's/^[[:space:]]*//;s/[[:space:]]*$//' ; }

pick_existing() {
  # 인자들 중 존재하는 첫 파일 경로 반환
  for p in "$@"; do
    [ -n "$p" ] && [ -f "$p" ] && { echo "$p"; return 0; }
  done
  echo ""
}

detect_ver_mm() {
  # 입력: php-fpm 바이너리 경로
  local bin="$1" ver full
  # 버전 문자열: 8.3.6 → 8.3
  full="$("$bin" -v 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  if [ -n "$full" ]; then
    ver="$(echo "$full" | awk -F. '{print $1"."$2}')"
    printf "%s\n" "$ver"
    return 0
  fi
  # 실패 시 빈 문자열
  printf "%s\n" ""
  return 0
}

guess_service_from_systemd() {
  # 우선순위:
  # 1) 정확히 php<주>.<부>-fpm(.service) 존재
  # 2) 실행 중인 php*-fpm.service 중 하나
  # 3) php-fpm(.service)
  local ver_mm="$1" svc=""
  if systemctl list-unit-files --type=service 2>/dev/null | grep -q "php${ver_mm}-fpm\.service"; then
    svc="php${ver_mm}-fpm"
  else
    svc="$(systemctl list-units --type=service --state=running 2>/dev/null \
            | awk '{print $1}' | sed 's/\.service$//' \
            | grep -E '^php[0-9\.]*-fpm$' | head -1)"
    if [ -z "$svc" ] && systemctl list-unit-files --type=service 2>/dev/null | grep -q '^php-fpm\.service'; then
      svc="php-fpm"
    fi
  fi
  printf "%s\n" "$svc"
}

detect_ini_with_bin() {
  # php-fpm -i 에서 Loaded Configuration File 추출
  local bin="$1" ini=""
  ini="$("$bin" -i 2>/dev/null | awk -F': ' '/Loaded Configuration File/{print $2}' | tail -1 | trim)"
  [ -f "$ini" ] || ini=""
  printf "%s\n" "$ini"
}

# ---- 바이너리 탐지 ----------------------------------------------------------
# 우선 순위: (1) PATH 상의 php-fpm 계열 (2) /usr/sbin, /usr/local/sbin 스캔
readarray -t FOUND_BINS < <(
  (command -v php-fpm 2>/dev/null; command -v php-fpm* 2>/dev/null) 2>/dev/null \
  | sed '/not found/d' | sort -u
)
if [ ${#FOUND_BINS[@]} -eq 0 ]; then
  readarray -t FOUND_BINS < <(find /usr/sbin /usr/local/sbin -type f -name 'php-fpm*' 2>/dev/null | sort -u)
fi

if [ ${#FOUND_BINS[@]} -gt 0 ]; then
  MULTIPLE_PHP_FPM_FOUND=${#FOUND_BINS[@]}
  PHP_FPM_BINARY_LIST="$(printf "%s;" "${FOUND_BINS[@]}" | sed 's/;$//')"
  # 대표 바이너리 선택(첫 항목의 실제 경로)
  PHP_FPM_BINARY="$(realpath "${FOUND_BINS[0]}" 2>/dev/null || echo "${FOUND_BINS[0]}")"
  log_debug "php-fpm 바이너리 후보(${MULTIPLE_PHP_FPM_FOUND}): $PHP_FPM_BINARY_LIST"
else
  log_debug "php-fpm 바이너리 탐지 실패"
fi

# ---- 버전/서비스/설정 경로 추정 ---------------------------------------------
if [ -n "$PHP_FPM_BINARY" ]; then
  VER_MM="$(detect_ver_mm "$PHP_FPM_BINARY")"
  log_debug "php-fpm 버전(주.부): ${VER_MM:-<unknown>}"

  # 서비스명 추정
  PHP_FPM_SERVICE="$(guess_service_from_systemd "$VER_MM")"
  if [ -n "$PHP_FPM_SERVICE" ] && systemctl is-active "$PHP_FPM_SERVICE" >/dev/null 2>&1; then
    PHP_FPM_RUNNING=1
  else
    # 실행 중이 아니면 마지막 시도: php-fpm
    [ -z "$PHP_FPM_SERVICE" ] && PHP_FPM_SERVICE="php-fpm"
    systemctl is-active "$PHP_FPM_SERVICE" >/dev/null 2>&1 && PHP_FPM_RUNNING=1
  fi
  log_debug "서비스명: ${PHP_FPM_SERVICE:-<empty>}, 실행중: $PHP_FPM_RUNNING"

  # 경로(우선: Debian/Ubuntu)
  UB_POOL="/etc/php/${VER_MM}/fpm/pool.d/www.conf"
  UB_MAIN="/etc/php/${VER_MM}/fpm/php-fpm.conf"
  UB_INI="/etc/php/${VER_MM}/fpm/php.ini"

  # RHEL 계열 폴백
  RH_POOL="/etc/php-fpm.d/www.conf"
  RH_MAIN="/etc/php-fpm.conf"
  RH_INI="/etc/php.ini"

  # 실제 존재하는 경로 선택
  PHP_FPM_POOL_CONF="$(pick_existing "$UB_POOL" "$RH_POOL")"
  PHP_FPM_MAIN_CONF="$(pick_existing "$UB_MAIN" "$RH_MAIN")"
  PHP_FPM_INI="$(pick_existing "$UB_INI" "$RH_INI")"

  # 바이너리에서 직접 INI 확인(있으면 우선)
  INI_FROM_BIN="$(detect_ini_with_bin "$PHP_FPM_BINARY")"
  [ -n "$INI_FROM_BIN" ] && PHP_FPM_INI="$INI_FROM_BIN"

  # 호환성: PHP_FPM_CONF = 풀 conf
  PHP_FPM_CONF="$PHP_FPM_POOL_CONF"

  log_debug "POOL_CONF=$PHP_FPM_POOL_CONF, MAIN_CONF=$PHP_FPM_MAIN_CONF, INI=$PHP_FPM_INI"
fi

# ---- 출력 -------------------------------------------------------------------
# (다중 설치를 전부 Keyed 로 내보내던 기존 포맷과 호환 필요 시 확장 가능)
cat <<EOF
PHP_FPM_BINARY=$PHP_FPM_BINARY
PHP_FPM_CONF=$PHP_FPM_CONF
PHP_FPM_POOL_CONF=$PHP_FPM_POOL_CONF
PHP_FPM_MAIN_CONF=$PHP_FPM_MAIN_CONF
PHP_FPM_INI=$PHP_FPM_INI
PHP_FPM_RUNNING=$PHP_FPM_RUNNING
PHP_FPM_SERVICE=$PHP_FPM_SERVICE
MULTIPLE_PHP_FPM_FOUND=$MULTIPLE_PHP_FPM_FOUND
PHP_FPM_BINARY_LIST=$PHP_FPM_BINARY_LIST
EOF

log_debug "find_php_fpm.sh 종료"