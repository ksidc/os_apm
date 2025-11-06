#!/bin/bash

# common.sh
# 공통 함수: 로깅, 권한 확인, 사용자 상호작용을 담당합니다.

# --- 기본 경로 설정 ---
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
FALLBACK_APPLY_LOG="$FALLBACK_ROOT/apply.log"

# --- JSON 보조 함수 ---
json_kv() {
    local key="$1" value="$2"
    printf '{"%s":"%s"}' "$key" "${value//"/\\"}"
}

json_two() {
    local k1="$1" v1="$2" k2="$3" v2="$4"
    printf '{"%s":"%s","%s":"%s"}' \
        "$k1" "${v1//"/\\"}" "$k2" "${v2//"/\\"}"
}

# --- 공통 로깅 도우미 ---
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

log_section_start() {
    local title="$1"
    runtime_log ""
    runtime_log "=== [$title] ==="
    runtime_log "시간 = $(date '+%Y-%m-%d %H:%M:%S')"
}

log_section_end() {
    local result="$1"
    runtime_log "결과 = ${result}"
}

# --- 디렉터리/파일 생성 ---
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
            mkdir -p "$root" 2>/dev/null || { echo "오류: 로그 디렉터리를 생성할 수 없습니다." >&2; return 1; }
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
        touch "$logfile" 2>/dev/null || { echo "오류: 로그 파일(${logfile})을 생성하지 못했습니다." >&2; return 1; }
        chmod 600 "$logfile" 2>/dev/null || true
    done

    log_info "로그 환경이 준비되었습니다" "bootstrap" "$(json_kv root "$LOG_ROOT")"
    return 0
}

check_root() {
    if [ "${EUID}" -ne 0 ]; then
        log_error "루트 권한으로 실행해야 합니다" "permission"
        echo "[오류] 루트 권한으로 실행해야 합니다." >&2
        return 1
    fi
    return 0
}

display_service_list() {
    local services=("apache" "mysql" "mariadb")
    local log_file="$SERVICE_LOG"
    local found=false

    echo ""
    echo "=========================================="
    echo "감지된 서비스 및 설정 정보"
    echo "=========================================="

    for svc in "${services[@]}"; do
        local upper
        upper=$(echo "$svc" | tr 'a-z' 'A-Z')
        local conf_key
        if [ "$svc" = "apache" ]; then
            conf_key="${upper}_MPM_CONF"
        else
            conf_key="${upper}_CONF"
        fi

        if grep -qE "^${upper}_RUNNING(_[0-9]+)?=1" "$log_file" 2>/dev/null; then
            local confs
            confs=$(grep -E "^${conf_key}(_[0-9]+)?=" "$log_file" 2>/dev/null | cut -d'=' -f2-)
            if [ -n "$confs" ]; then
                found=true
                while IFS= read -r path; do
                    path=$(echo "$path" | xargs)
                    if [ -n "$path" ] && [ -f "$path" ]; then
                        echo "- $svc"
                        echo "  원본 설정: $path"
                        if [ "$svc" = "apache" ]; then
                            echo "  튜닝 저장: /etc/httpd/conf.modules.d/00-mpm.conf"
                        else
                            echo "  튜닝 저장: /etc/my.cnf.d/zz-iteasy_tuning.cnf"
                        fi
                    else
                        log_warn "설정 파일 경로가 유효하지 않습니다" "service" "$(json_kv service "$svc")"
                    fi
                done <<< "$confs"
            fi
        fi
    done

    $found || echo "실행 중인 서비스가 없습니다."
    echo "=========================================="
    echo ""
}

prompt_for_apply() {
    local services=("apache" "mysql" "mariadb")
    local log_file="$SERVICE_LOG"

    display_service_list

    local running_services=()
    for svc in "${services[@]}"; do
        local upper
        upper=$(echo "$svc" | tr 'a-z' 'A-Z')
        if grep -qE "^${upper}_RUNNING(_[0-9]+)?=1" "$log_file" 2>/dev/null; then
            running_services+=("$svc")
        fi
    done

    if [ ${#running_services[@]} -eq 0 ]; then
        echo "적용 가능한 서비스가 없어 작업을 종료합니다."
        log_info "적용 대상 서비스 없음" "apply"
        exit 0
    fi

    echo "설정을 적용하시겠습니까? (A: 전체 적용, S: 선택 적용, N: 취소)"
    read -r choice

    local apply_services=()
    case "$choice" in
        [Aa])
            apply_services=("${running_services[@]}")
            log_info "사용자가 전체 적용을 선택했습니다" "apply"
            ;;
        [Ss])
            echo "현재 실행 중인 서비스: ${running_services[*]}"
            echo "적용할 서비스를 입력하세요 (예: apache mysql, 종료하려면 Enter):"
            read -a selected
            for svc in "${selected[@]}"; do
                if [[ " ${services[*]} " =~ " $svc " ]]; then
                    local upper
                    upper=$(echo "$svc" | tr 'a-z' 'A-Z')
                    if grep -qE "^${upper}_RUNNING(_[0-9]+)?=1" "$log_file" 2>/dev/null; then
                        apply_services+=("$svc")
                    else
                        echo "경고: $svc 서비스가 실행 중이 아닙니다." >&2
                        log_warn "서비스가 실행 중이 아님" "apply" "$(json_kv service "$svc")"
                    fi
                else
                    echo "경고: 알 수 없는 서비스 $svc 입니다." >&2
                    log_warn "알 수 없는 서비스가 입력되었습니다" "apply" "$(json_kv service "$svc")"
                fi
            done
            ;;
        [Nn])
            echo "사용자가 적용을 취소했습니다."
            log_info "사용자가 적용을 취소했습니다" "apply"
            exit 0
            ;;
        *)
            echo "오류: A, S, N 중 하나를 입력하세요." >&2
            log_warn "잘못된 입력으로 다시 요청" "apply"
            prompt_for_apply
            return
            ;;
    esac

    if [ ${#apply_services[@]} -eq 0 ]; then
        tty_echo "선택된 서비스가 없어 종료합니다."
        log_info "적용할 서비스가 없어 종료합니다" "apply"
        exit 0
    fi

    if [ ${#apply_services[@]} -gt 0 ]; then
        log_section_start "설정 적용"
    fi

    for svc in "${apply_services[@]}"; do
        local conf_file=""
        case "$svc" in
            apache) conf_file="$TMP_CONF_DIR/apache_tuning.conf" ;;
            mysql|mariadb) conf_file="$TMP_CONF_DIR/mysql_tuning.cnf" ;;
        esac
        local apply_script="$SCRIPTS_DIR/apply/apply_${svc}.sh"

        if [ ! -f "$conf_file" ] || [ ! -s "$conf_file" ]; then
            echo "[건너뜀] $svc: 적용할 설정 파일(${conf_file})이 없습니다." >&2
            log_warn "적용 파일을 찾지 못해 건너뜁니다" "apply" "$(json_two service "$svc" file "$conf_file")"
            continue
        fi
        if [ ! -x "$apply_script" ]; then
            echo "[건너뜀] $svc: 적용 스크립트(${apply_script})를 실행할 수 없습니다." >&2
            log_warn "적용 스크립트를 실행할 수 없어 건너뜁니다" "apply" "$(json_two service "$svc" script "$apply_script")"
            continue
        fi

        echo "[적용] $svc 설정을 적용합니다..."
        log_info "설정 적용 시작" "apply" "$(json_kv service "$svc")"
        "$apply_script" >> "$DEBUG_LOG" 2>&1
        if [ $? -eq 0 ]; then
            echo "[완료] $svc 설정 적용이 끝났습니다."
            log_info "설정 적용 성공" "apply" "$(json_kv service "$svc")"

            # 서비스별 백업 정보 및 롤백 방법 출력
            echo ""
            echo "=========================================="
            case "$svc" in
                apache)
                    echo "Apache 튜닝 완료"
                    echo "=========================================="
                    echo "튜닝 파일: /etc/httpd/conf.modules.d/00-mpm.conf"

                    # 백업 파일 찾기
                    local latest_backup
                    latest_backup=$(ls -t "$BACKUP_DIR"/*00-mpm.conf 2>/dev/null | head -1)

                    if [ -n "$latest_backup" ] && [ -f "$latest_backup" ]; then
                        echo "백업 위치: $latest_backup"
                        echo ""
                        echo "[롤백 방법]"
                        echo "백업본으로 복원하려면:"
                        echo "  cp $latest_backup /etc/httpd/conf.modules.d/00-mpm.conf"
                        echo "  systemctl restart httpd"
                    else
                        echo "백업 위치: 없음"
                        echo ""
                        echo "[경고] 백업이 없어 롤백할 수 없습니다."
                    fi

                    echo ""
                    echo "[설정 확인 명령어]"
                    echo "  httpd -V | grep MPM"
                    echo "  httpd -M | grep mpm"
                    echo "  apachectl -t -D DUMP_MODULES | grep mpm"
                    ;;
                mysql|mariadb)
                    local db_service
                    [ "$svc" = "mysql" ] && db_service="mysqld" || db_service="mariadb"
                    echo "$(echo $svc | tr 'a-z' 'A-Z') 튜닝 완료"
                    echo "=========================================="
                    echo "튜닝 파일: /etc/my.cnf.d/zz-iteasy_tuning.cnf"

                    # 백업 파일 찾기
                    local latest_backup
                    latest_backup=$(ls -t "$BACKUP_DIR"/*zz-iteasy_tuning.cnf 2>/dev/null | head -1)

                    if [ -n "$latest_backup" ] && [ -f "$latest_backup" ]; then
                        echo "백업 위치: $latest_backup"
                        echo ""
                        echo "[롤백 방법]"
                        echo "백업본으로 복원하려면:"
                        echo "  cp $latest_backup /etc/my.cnf.d/zz-iteasy_tuning.cnf"
                        echo "  systemctl restart $db_service"
                    else
                        echo "백업 위치: 없음 (최초 튜닝)"
                        echo ""
                        echo "[롤백 방법]"
                        echo "원본 설정으로 되돌리려면 (튜닝 파일 삭제):"
                        echo "  rm -f /etc/my.cnf.d/zz-iteasy_tuning.cnf"
                        echo "  systemctl restart $db_service"
                    fi
                    echo ""
                    echo "[설정 확인 명령어]"
                    echo "  $db_service --verbose --help | grep -A 1 'Default options'"
                    echo "  mysql -e \"SHOW VARIABLES LIKE 'innodb_buffer_pool_size';\""
                    echo "  mysql -e \"SHOW VARIABLES LIKE 'max_connections';\""
                    ;;
            esac
            echo "=========================================="
            echo ""
        else
            echo "[오류] $svc 설정 적용에 실패했습니다. (로그: $DEBUG_LOG)" >&2
            log_error "설정 적용 실패" "apply" "$(json_kv service "$svc")"
        fi
    done

    if [ ${#apply_services[@]} -gt 0 ]; then
        log_section_end "완료"
    fi
}
