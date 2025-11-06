#!/bin/bash

# common.sh
# Shared helpers: logging, permission checks, prompt handling.

BASE_DIR="${BASE_DIR:-/usr/local/src/iteasy_tuning}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$BASE_DIR/scripts}"

LOG_ROOT="${LOG_ROOT:-$BASE_DIR/logs}"
RUNTIME_LOG_DIR="${RUNTIME_LOG_DIR:-$LOG_ROOT/runtime}"
DEBUG_LOG_DIR="${DEBUG_LOG_DIR:-$LOG_ROOT/debug}"
ARTIFACT_LOG_DIR="${ARTIFACT_LOG_DIR:-$LOG_ROOT/artifacts}"

BACKUP_DIR="${BACKUP_DIR:-$BASE_DIR/backups}"
ERR_CONF_DIR="${ERR_CONF_DIR:-$BASE_DIR/err_conf}"
TMP_CONF_DIR="${TMP_CONF_DIR:-$BASE_DIR/tmp_conf}"

DEBUG_LOG="${DEBUG_LOG:-$DEBUG_LOG_DIR/pipeline-debug.log}"
TUNING_STATUS_LOG="${TUNING_STATUS_LOG:-$RUNTIME_LOG_DIR/tuning_status.log}"
APPLY_LOG="${APPLY_LOG:-$RUNTIME_LOG_DIR/apply.log}"
SERVICE_LOG="${SERVICE_LOG:-$ARTIFACT_LOG_DIR/service_paths.log}"
SYSTEM_LOG="${SYSTEM_LOG:-$ARTIFACT_LOG_DIR/system_specs.log}"
VERSION_LOG="${VERSION_LOG:-$ARTIFACT_LOG_DIR/service_versions.log}"
CONTEXT_LOG="${CONTEXT_LOG:-$ARTIFACT_LOG_DIR/tuning_context.log}"
REPORT_FILE="${REPORT_FILE:-$RUNTIME_LOG_DIR/tuning_report.html}"

FALLBACK_ROOT="/tmp/iteasy_tuning_logs"
FALLBACK_DEBUG_LOG="$FALLBACK_ROOT/debug.log"

json_kv() {
    local key="$1" value="$2"
    printf '{"%s":"%s"}' "$key" "${value//"/\\"}"
}

json_two() {
    local k1="$1" v1="$2" k2="$3" v2="$4"
    printf '{"%s":"%s","%s":"%s"}' \
        "$k1" "${v1//"/\\"}" "$k2" "${v2//"/\\"}"
}

runtime_log() {
    mkdir -p "$(dirname "$TUNING_STATUS_LOG")" 2>/dev/null || true
    printf '%s\n' "$1" >> "$TUNING_STATUS_LOG"
}

log_json() {
    local level="$1" module="$2" message="$3" detail="$4"
    local ts
    ts=$(date '+%Y-%m-%dT%H:%M:%S%z')
    mkdir -p "$(dirname "$DEBUG_LOG")" 2>/dev/null || true
    printf '{"ts":"%s","level":"%s","module":"%s","msg":"%s"%s}\n' \
        "$ts" "$level" "${module:-general}" "${message//"/\\"}" \
        "${detail:+,"detail":${detail}}" >> "$DEBUG_LOG"
}

log_info()  { log_json "INFO"  "$2" "$1" "$3"; }
log_warn()  { log_json "WARN"  "$2" "$1" "$3"; }
log_error() { log_json "ERROR" "$2" "$1" "$3"; }

trim_value() {
    local value="$1"
    echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

log_section_start() {
    local title="$1"
    runtime_log ""
    runtime_log "=== [$title] ==="
    runtime_log "time = $(date '+%Y-%m-%d %H:%M:%S')"
}

log_section_end() {
    local result="$1"
    runtime_log "result = ${result}"
}

_setup_dir() {
    local dir="$1" perms="$2"
    mkdir -p "$dir" 2>/dev/null || return 1
    if [ -n "$perms" ]; then
        chmod "$perms" "$dir" 2>/dev/null || true
    fi
    return 0
}

setup_logging() {
    local root="$LOG_ROOT"

    if ! mkdir -p "$root" 2>/dev/null; then
        root="$FALLBACK_ROOT"
        if ! mkdir -p "$root" 2>/dev/null; then
            root="/var/log/iteasy_tuning"
            mkdir -p "$root" 2>/dev/null || { echo "[오류] 로그 디렉터리를 생성하지 못했습니다." >&2; return 1; }
        fi
    fi

    LOG_ROOT="$root"
    RUNTIME_LOG_DIR="$LOG_ROOT/runtime"
    DEBUG_LOG_DIR="$LOG_ROOT/debug"
    ARTIFACT_LOG_DIR="$LOG_ROOT/artifacts"

    _setup_dir "$RUNTIME_LOG_DIR" 700 || return 1
    _setup_dir "$DEBUG_LOG_DIR" 700 || return 1
    _setup_dir "$ARTIFACT_LOG_DIR" 700 || return 1
    _setup_dir "$BACKUP_DIR" 700 || return 1
    _setup_dir "$ERR_CONF_DIR" 700 || return 1
    _setup_dir "$TMP_CONF_DIR" 700 || true

    DEBUG_LOG="$DEBUG_LOG_DIR/pipeline-debug.log"
    TUNING_STATUS_LOG="$RUNTIME_LOG_DIR/tuning_status.log"
    APPLY_LOG="$RUNTIME_LOG_DIR/apply.log"
    SERVICE_LOG="$ARTIFACT_LOG_DIR/service_paths.log"
    SYSTEM_LOG="$ARTIFACT_LOG_DIR/system_specs.log"
    VERSION_LOG="$ARTIFACT_LOG_DIR/service_versions.log"
    CONTEXT_LOG="$ARTIFACT_LOG_DIR/tuning_context.log"

    for logfile in \
        "$DEBUG_LOG" \
        "$TUNING_STATUS_LOG" \
        "$APPLY_LOG" \
        "$SERVICE_LOG" \
        "$SYSTEM_LOG" \
        "$VERSION_LOG" \
        "$CONTEXT_LOG"; do
        touch "$logfile" 2>/dev/null || { echo "[오류] 로그 파일(${logfile})을 생성하지 못했습니다." >&2; return 1; }
        chmod 600 "$logfile" 2>/dev/null || true
    done
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "[오류] 루트 권한으로 실행해야 합니다." >&2
        log_error "루트 권한 필요" "auth"
        return 1
    fi
    return 0
}

tty_echo() {
    local message="$1"
    if [ -t 1 ]; then
        printf "%s\n" "$message"
    elif [ -w /dev/tty ]; then
        printf "%s\n" "$message" > /dev/tty
    fi
}

gather_running_services() {
    local log_file="$SERVICE_LOG"
    local result=()
    [ -f "$log_file" ] || { printf "%s\n" "${result[@]}"; return 0; }

    if grep -q '^APACHE_RUNNING=1' "$log_file" 2>/dev/null; then
        result+=("apache")
    fi
    if grep -q '^MYSQL_RUNNING=1' "$log_file" 2>/dev/null; then
        result+=("mysql")
    fi

    printf "%s\n" "${result[@]}"
}

print_apply_summary() {
    local svc="$1"
    echo ""
    echo "=========================================="
    case "$svc" in
        apache)
            local target
            target=$(awk -F'=' '/^APACHE_MPM_CONF=/{print $2}' "$SERVICE_LOG" 2>/dev/null | head -1)
            target=$(trim_value "$target")
            target=${target:-/etc/apache2/mods-available/mpm_event.conf}
            local latest_backup
            latest_backup=$(ls -t "${target}".backup.* 2>/dev/null | head -1)

            echo "Apache 튜닝 완료"
            echo "=========================================="
            echo "튜닝 파일: $target"
            if [ -n "$latest_backup" ] && [ -f "$latest_backup" ]; then
                echo "백업 위치: $latest_backup"
                echo ""
                echo "[롤백 방법]"
                echo "  cp $latest_backup $target"
                echo "  systemctl restart apache2"
            else
                echo "백업 위치: 없음"
                echo ""
                echo "[경고] 백업본이 없어 즉시 롤백이 어렵습니다."
            fi
            echo ""
            echo "[검증 명령]"
            echo "  apache2ctl -M | grep mpm"
            echo "  apache2ctl -t"
            ;;
        mysql)
            local target="/etc/mysql/mysql.conf.d/zz-iteasy_tuning.cnf"
            local unit
            unit=$(awk -F'=' '/^MYSQL_SYSTEMD_UNIT=/{print $2}' "$SERVICE_LOG" 2>/dev/null | head -1)
            unit=$(trim_value "$unit")
            unit=${unit:-mysql}
            local latest_backup
            latest_backup=$(ls -t "${target}".backup.* 2>/dev/null | head -1)

            echo "MySQL/MariaDB 튜닝 완료"
            echo "=========================================="
            echo "튜닝 파일: $target"
            if [ -n "$latest_backup" ] && [ -f "$latest_backup" ]; then
                echo "백업 위치: $latest_backup"
                echo ""
                echo "[롤백 방법]"
                echo "  cp $latest_backup $target"
                echo "  systemctl restart $unit"
            else
                echo "백업 위치: 없음 (최초 적용일 가능)"
                echo ""
                echo "[롤백 방법]"
                echo "  rm -f $target"
                echo "  systemctl restart $unit"
            fi
            echo ""
            echo "[검증 명령]"
            echo "  mysql -e \"SHOW VARIABLES LIKE 'innodb_buffer_pool_size';\""
            echo "  mysql -e \"SHOW VARIABLES LIKE 'max_connections';\""
            ;;
    esac
    echo "=========================================="
    echo ""
}

prompt_for_apply() {
    mapfile -t running_services < <(gather_running_services)
    if [ ${#running_services[@]} -eq 0 ]; then
        tty_echo "적용할 서비스가 없어 작업을 종료합니다."
        log_info "적용 가능한 서비스 없음" "apply"
        exit 0
    fi

    tty_echo ""
    tty_echo "탐지된 서비스: ${running_services[*]}"
    tty_echo "튜닝 설정을 적용하시겠습니까? (A: 전체, S: 선택, N: 취소)"
    read -r choice

    local apply_services=()
    case "${choice,,}" in
        a|"" )
            apply_services=("${running_services[@]}")
            ;;
        s)
            tty_echo "적용할 서비스를 공백으로 구분해 입력하세요 (예: apache mysql)."
            read -r line
            for token in $line; do
                if printf '%s' " ${running_services[*]} " | grep -q " ${token} "; then
                    apply_services+=("$token")
                else
                    tty_echo "경고: ${token} 은(는) 적용 대상이 아닙니다."
                fi
            done
            ;;
        n)
            tty_echo "적용을 취소합니다."
            log_info "사용자가 적용을 취소했습니다" "apply"
            exit 0
            ;;
        *)
            tty_echo "A, S, N 중 하나를 입력하세요."
            log_warn "적용 여부 프롬프트 잘못된 입력" "apply"
            prompt_for_apply
            return
            ;;
    esac

    if [ ${#apply_services[@]} -eq 0 ]; then
        tty_echo "선택된 서비스가 없어 종료합니다."
        log_info "선택된 서비스 없음" "apply"
        exit 0
    fi

    log_section_start "설정 적용"
    for svc in "${apply_services[@]}"; do
        local conf_file=""
        case "$svc" in
            apache) conf_file="$TMP_CONF_DIR/apache_tuning.conf" ;;
            mysql)  conf_file="$TMP_CONF_DIR/mysql_tuning.cnf" ;;
            *) tty_echo "[건너뜀] 지원하지 않는 서비스: $svc"; continue ;;
        esac
        local apply_script="$SCRIPTS_DIR/apply/apply_${svc}.sh"

        if [ ! -f "$conf_file" ] || [ ! -s "$conf_file" ]; then
            tty_echo "[건너뜀] $svc: 적용할 설정 파일(${conf_file})이 없습니다."
            log_warn "적용 파일 없음" "apply" "$(json_two service "$svc" file "$conf_file")"
            continue
        fi
        if [ ! -x "$apply_script" ]; then
            tty_echo "[건너뜀] $svc: 적용 스크립트(${apply_script})를 실행할 수 없습니다."
            log_warn "적용 스크립트 실행 불가" "apply" "$(json_two service "$svc" script "$apply_script")"
            continue
        fi

        tty_echo "[적용] $svc 설정을 적용합니다..."
        log_info "설정 적용 시작" "apply" "$(json_kv service "$svc")"
        if "$apply_script" >>"$DEBUG_LOG" 2>&1; then
            tty_echo "[완료] $svc 설정 적용이 끝났습니다."
            log_info "설정 적용 완료" "apply" "$(json_kv service "$svc")"
            print_apply_summary "$svc"
        else
            tty_echo "[오류] $svc 설정 적용에 실패했습니다. (로그: $DEBUG_LOG)"
            log_error "설정 적용 실패" "apply" "$(json_kv service "$svc")"
        fi
    done
    log_section_end "완료"
}
