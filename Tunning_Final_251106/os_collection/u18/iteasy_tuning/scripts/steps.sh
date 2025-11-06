#!/bin/bash

# steps.sh
# 튜닝 파이프라인 단계를 실행하고 로그를 기록합니다.

profile_requires_db() {
    case "$1" in
        web_db|web_was_db|was_db|db) return 0 ;;
        *) return 1 ;;
    esac
}

record_tuning_context() {
    mkdir -p "$(dirname "$CONTEXT_LOG")" 2>/dev/null || true
    {
        echo "timestamp=$(date '+%Y-%m-%d %H:%M:%S')"
        echo "service_profile=${SERVICE_PROFILE}"
        echo "db_engine=${DB_ENGINE}"
    } > "$CONTEXT_LOG"
    chmod 600 "$CONTEXT_LOG" 2>/dev/null || true
    log_info "튜닝 컨텍스트를 기록했습니다" "context" "$(json_two profile "$SERVICE_PROFILE" db_engine "$DB_ENGINE")"
}

run_background_step() {
    local step_name="$1"
    local script="$2"
    local step_number="$3"
    log_section_start "단계 ${step_number} - ${step_name}"
    log_info "단계를 시작합니다" "step" "$(json_two step "$step_number" script "$script")"

    if [ -f "$script" ]; then
        local runner=()
        if [ -x "$script" ]; then
            runner=("$script")
        elif command -v bash >/dev/null 2>&1; then
            runner=("bash" "$script")
        else
            runtime_log "단계 ${step_number} (${step_name}) = 건너뜀"
            log_warn "실행 권한이 없어 단계를 건너뜁니다" "step" "$(json_two step "$step_number" script "$script")"
            log_section_end "건너뜀"
            return
        fi

        "${runner[@]}" >> "$DEBUG_LOG" 2>&1 &
        local pid=$!
        wait "$pid"
        if [ $? -eq 0 ]; then
            runtime_log "단계 ${step_number} (${step_name}) = 성공"
            log_info "단계가 성공적으로 종료되었습니다" "step" "$(json_two step "$step_number" pid "$pid")"
            log_section_end "성공"
        else
            runtime_log "단계 ${step_number} (${step_name}) = 실패"
            log_error "단계 실행 중 오류가 발생했습니다" "step" "$(json_two step "$step_number" pid "$pid")"
            log_section_end "실패"
        fi
    else
        runtime_log "단계 ${step_number} (${step_name}) = 건너뜀"
        log_warn "단계 스크립트를 찾지 못해 건너뜁니다" "step" "$(json_two step "$step_number" script "$script")"
        log_section_end "건너뜀"
    fi
}

run_backup_step() {
    local label="환경 설정 백업"
    log_section_start "$label"
    log_info "백업 단계를 시작합니다" "backup"
    backup_all_services >> "$DEBUG_LOG" 2>&1 &
    local pid=$!
    wait "$pid"
    if [ $? -eq 0 ]; then
        runtime_log "백업 단계 = 성공"
        log_info "환경 설정을 백업했습니다" "backup" "$(json_kv pid "$pid")"
        log_section_end "성공"
    else
        runtime_log "백업 단계 = 실패"
        log_error "환경 설정 백업이 실패했습니다" "backup" "$(json_kv pid "$pid")"
        echo "[경고] 백업 단계가 실패했습니다. 상세 내용은 $DEBUG_LOG 를 참고하세요." >&2
        log_section_end "실패"
    fi
}

## 서비스 탐지 보조 ##

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

determine_target_services() {
    TARGET_SERVICES=()
    DB_SERVICE_TARGET=""

    mapfile -t running_services < <(gather_running_services)
    log_info "감지된 서비스 목록" "detection" "$(json_kv services "${running_services[*]:-없음}")"

    if profile_requires_db "$SERVICE_PROFILE"; then
        if printf '%s' " ${running_services[*]} " | grep -q ' mysql '; then
            DB_SERVICE_TARGET="mysql"
        else
            log_warn "DB 프로파일이지만 실행 중인 DB 서비스가 없습니다" "detection" "$(json_kv profile "$SERVICE_PROFILE")"
        fi
    fi

    case "$SERVICE_PROFILE" in
        web|web_was)
            printf '%s' " ${running_services[*]} " | grep -q ' apache ' && TARGET_SERVICES+=("apache")
            ;;
        web_db|web_was_db)
            printf '%s' " ${running_services[*]} " | grep -q ' apache ' && TARGET_SERVICES+=("apache")
            [ -n "$DB_SERVICE_TARGET" ] && TARGET_SERVICES+=("$DB_SERVICE_TARGET")
            ;;
        was_db|db)
            [ -n "$DB_SERVICE_TARGET" ] && TARGET_SERVICES+=("$DB_SERVICE_TARGET")
            ;;
        *)
            log_warn "알 수 없는 서비스 프로파일입니다" "detection" "$(json_kv profile "$SERVICE_PROFILE")"
            ;;
    esac

    log_info "튜닝 대상 서비스 결정" "detection" "$(json_two services "${TARGET_SERVICES[*]:-없음}" db "$DB_SERVICE_TARGET")"
}

run_calculation_steps() {
    local step=5
    local seen_db=false

    for svc in "${TARGET_SERVICES[@]}"; do
        case "$svc" in
            apache)
                run_background_step "Apache 설정 계산" "$MODULES_DIR/calculate_mpm_config.sh" "$step"
                step=$((step + 1))
                ;;
            mysql)
                if [ "$seen_db" = false ]; then
                    run_background_step "데이터베이스 설정 계산" "$MODULES_DIR/calculate_mysql_config.sh" "$step"
                    step=$((step + 1))
                    seen_db=true
                fi
                ;;
        esac
    done
}

run_report_step() {
    local report_script="$BASE_DIR/scripts/report/generate_tuning_report.sh"
    if [ ! -f "$report_script" ]; then
        log_warn "보고서 생성 스크립트를 찾지 못했습니다" "report" "$(json_kv path "$report_script")"
        return 0
    fi

    tty_echo ""
    tty_echo "=========================================="
    tty_echo "보고서를 생성합니다..."
    tty_echo "=========================================="
    log_info "보고서 생성을 시작합니다" "report" "$(json_kv output "$REPORT_FILE")"

    if bash "$report_script" >> "$DEBUG_LOG" 2>&1; then
        if [ -f "$REPORT_FILE" ]; then
            tty_echo "보고서가 생성되었습니다: $REPORT_FILE"
            log_info "보고서 생성이 완료되었습니다" "report" "$(json_kv path "$REPORT_FILE")"
        else
            log_warn "보고서 스크립트가 성공했지만 파일을 찾지 못했습니다" "report"
        fi
    else
        log_error "보고서 생성 중 오류가 발생했습니다" "report"
    fi
}
