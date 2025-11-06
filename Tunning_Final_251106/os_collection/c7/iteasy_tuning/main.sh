#!/bin/bash

# main.sh
# Apache/MySQL 환경에서 튜닝 파이프라인을 실행합니다.

BASE_DIR="/usr/local/src/iteasy_tuning"
LOG_ROOT="$BASE_DIR/logs"
RUNTIME_LOG_DIR="$LOG_ROOT/runtime"
DEBUG_LOG_DIR="$LOG_ROOT/debug"
ARTIFACT_LOG_DIR="$LOG_ROOT/artifacts"

LOG_DIR="$ARTIFACT_LOG_DIR"
DEBUG_LOG="$DEBUG_LOG_DIR/pipeline-debug.log"
TUNING_STATUS_LOG="$RUNTIME_LOG_DIR/tuning_status.log"
APPLY_LOG="$RUNTIME_LOG_DIR/apply.log"
SERVICE_LOG="$ARTIFACT_LOG_DIR/service_paths.log"
SYSTEM_LOG="$ARTIFACT_LOG_DIR/system_specs.log"
VERSION_LOG="$ARTIFACT_LOG_DIR/service_versions.log"
CONTEXT_LOG="$ARTIFACT_LOG_DIR/tuning_context.log"
REPORT_FILE="$RUNTIME_LOG_DIR/tuning_report.html"
export LOG_ROOT RUNTIME_LOG_DIR DEBUG_LOG_DIR ARTIFACT_LOG_DIR
export LOG_DIR DEBUG_LOG TUNING_STATUS_LOG APPLY_LOG SERVICE_LOG SYSTEM_LOG VERSION_LOG CONTEXT_LOG REPORT_FILE

MODULES_DIR="$BASE_DIR/modules"
SCRIPTS_DIR="$BASE_DIR/scripts"
TMP_CONF_DIR="$BASE_DIR/tmp_conf"

SERVICE_PROFILE=""
DB_ENGINE="none"
declare -a TARGET_SERVICES=()
DB_SERVICE_TARGET=""

require_script() {
    local script_path="$1"
    local description="$2"
    if [ ! -f "$script_path" ]; then
        echo "오류: ${description} (${script_path}) 파일을 찾을 수 없습니다." >&2
        exit 1
    fi
}

require_script "$SCRIPTS_DIR/common.sh" "common.sh"
source "$SCRIPTS_DIR/common.sh"

require_script "$SCRIPTS_DIR/backup.sh" "backup.sh"
source "$SCRIPTS_DIR/backup.sh" || {
    echo "오류: 백업 스크립트를 불러오지 못했습니다: ${SCRIPTS_DIR}/backup.sh" >&2
    exit 1
}

require_script "$SCRIPTS_DIR/steps.sh" "steps.sh"
source "$SCRIPTS_DIR/steps.sh"

require_script "$SCRIPTS_DIR/ui.sh" "ui.sh"
source "$SCRIPTS_DIR/ui.sh"

check_root || exit 1
setup_logging || exit 1
> "$TUNING_STATUS_LOG"
log_section_start "튜닝 파이프라인 시작"

SERVICE_PROFILE=$(prompt_service_profile)
if [ -z "$SERVICE_PROFILE" ]; then
    tty_echo "서비스 구성을 선택하지 않아 작업을 종료합니다."
    log_section_end "취소"
    exit 0
fi
export ITEASY_SERVICE_PROFILE="$SERVICE_PROFILE"
log_info "서비스 프로필 선택" "main" "$(json_kv profile "$SERVICE_PROFILE")"

if profile_requires_db "$SERVICE_PROFILE"; then
    DB_ENGINE=$(prompt_db_engine)
    if [ "$DB_ENGINE" = "none" ]; then
        tty_echo "데이터베이스 엔진 선택이 취소되어 작업을 종료합니다."
        log_section_end "취소"
        exit 0
    fi
else
    DB_ENGINE="none"
fi
export ITEASY_DB_ENGINE="$DB_ENGINE"
log_info "데이터베이스 엔진 선택" "main" "$(json_kv engine "$DB_ENGINE")"

record_tuning_context

run_background_step "시스템 정보 수집" "$MODULES_DIR/get_server_specs.sh" "1"
run_background_step "서비스 탐지" "$MODULES_DIR/find_services.sh" "2"
run_background_step "서비스 버전 확인" "$MODULES_DIR/check_service_versions.sh" "3"

determine_target_services
run_backup_step
run_calculation_steps
prompt_for_apply
run_report_step

log_section_end "완료"
tty_echo ""
tty_echo "=========================================="
tty_echo "모든 작업이 완료되었습니다"
tty_echo "=========================================="
tty_echo ""
tty_echo "[결과 확인]"
tty_echo "  튜닝 보고서: ${REPORT_FILE}"
tty_echo "  상태 로그: ${TUNING_STATUS_LOG}"
tty_echo "  디버그 로그: ${DEBUG_LOG}"
tty_echo "  백업 위치: ${BACKUP_DIR}"
tty_echo ""
tty_echo "=========================================="
