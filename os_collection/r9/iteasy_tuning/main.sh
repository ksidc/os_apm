#!/bin/bash

# main.sh
# 서버 튜닝 프로세스를 백그라운드에서 실행하고, 서비스 리스트 출력 후 사용자 선택에 따라 설정 적용
# 단계: 1. 자원 확인, 2. 서비스 탐지, 3. 버전 확인, 4. 백업, 5. 설정 계산, 6. 사용자 선택 후 적용
# 모든 단계는 백그라운드에서 실행, 로그에 기록
# 사용자 출력: 실행 중인 서비스 리스트와 설정 파일 경로, 적용 옵션(A/S/N)
# 수정: prompt_for_apply에서 conf_file 확인 제거, apply 스크립트에 설정 파일 처리 위임
# 추가 수정: 설정 계산 단계를 run_background_step으로 이동, 백업 단계 함수화, calculate_mpm_config.sh 사용, 디버깅 강화
# 최신 수정: 실행 중이지 않은 서비스 경고 메시지 제거, PHP(mod_php) 처리 개선, Apache 전용 계산 로직 강화

# 기본 디렉터리 설정
BASE_DIR="/usr/local/src/iteasy_tuning"
LOG_DIR="$BASE_DIR/logs"
DEBUG_LOG="$LOG_DIR/debug.log"
TUNING_STATUS_LOG="$LOG_DIR/tuning_status.log"
SERVICE_LOG="$LOG_DIR/service_paths.log"
MODULES_DIR="$BASE_DIR/modules"
SCRIPTS_DIR="$BASE_DIR/scripts"
TMP_CONF_DIR="$BASE_DIR/tmp_conf"

# 공통 함수 로드
if [ ! -f "$SCRIPTS_DIR/common.sh" ]; then
    echo "오류: 공통 스크립트($SCRIPTS_DIR/common.sh)가 존재하지 않습니다." >&2
    exit 1
fi
source "$SCRIPTS_DIR/common.sh"

# 백업 스크립트 로드
if [ ! -f "$SCRIPTS_DIR/backup.sh" ]; then
    echo "오류: 백업 스크립트($SCRIPTS_DIR/backup.sh)가 존재하지 않습니다." >&2
    exit 1
fi
source "$SCRIPTS_DIR/backup.sh" || { echo "백업 스크립트 로드 실패: $SCRIPTS_DIR/backup.sh" >&2; exit 1; }
log_debug "백업 스크립트 로드 완료"

# 로그 디렉터리 및 파일 생성
setup_logging
log_debug "main.sh 시작: BASE_DIR=$BASE_DIR, SERVICE_LOG=$SERVICE_LOG"

# 백그라운드 단계 실행 함수
run_background_step() {
    local step_name="$1"
    local script="$2"
    local step_number="$3"
    log_debug "단계 $step_number: $step_name 실행 중, 스크립트: $script"
    if [ -f "$script" ] && [ -x "$script" ]; then
        "$script" >> "$DEBUG_LOG" 2>&1 &
        local pid=$!
        log_debug "단계 $step_number: 프로세스 시작, PID=$pid"
        wait "$pid"
        if [ $? -eq 0 ]; then
            echo "$step_name=success" >> "$TUNING_STATUS_LOG"
            log_debug "단계 $step_number: $step_name 완료"
        else
            echo "$step_name=failed" >> "$TUNING_STATUS_LOG"
            log_debug "단계 $step_number: $step_name 실패"
        fi
    else
        echo "$step_name=skipped" >> "$TUNING_STATUS_LOG"
        log_debug "오류: $script 스크립트가 존재하지 않거나 실행 가능하지 않습니다. (존재: $([ -f "$script" ] && echo '있음' || echo '없음'), 실행 가능: $([ -x "$script" ] && echo '가능' || echo '불가'))"
    fi
}

# 백업 단계 함수
run_backup_step() {
    local step_name="설정 파일 백업"
    local step_number="4"
    log_debug "단계 $step_number: $step_name 실행 중..."
    backup_all_services >> "$DEBUG_LOG" 2>&1 &
    local backup_pid=$!
    log_debug "단계 $step_number: 백업 프로세스 시작, PID=$backup_pid"
    wait "$backup_pid"
    if [ $? -eq 0 ]; then
        echo "$step_name=success" >> "$TUNING_STATUS_LOG"
        log_debug "단계 $step_number: $step_name 완료"
    else
        echo "$step_name=failed" >> "$TUNING_STATUS_LOG"
        log_debug "단계 $step_number: $step_name 실패"
        echo "[WARN] $step_name 실패, 계속 진행 (자세한 내용은 $DEBUG_LOG 확인)" >&2
    fi
}

# 단계 실행 (백그라운드)
run_background_step "시스템 자원 확인" "$MODULES_DIR/get_server_specs.sh" "1"
run_background_step "서비스 탐지" "$MODULES_DIR/find_services.sh" "2"
run_background_step "서비스 버전 확인" "$MODULES_DIR/check_service_versions.sh" "3"

# 백업 단계
run_backup_step

# 설정 계산 단계
services=("apache" "mysql" "nginx" "php" "php_fpm" "tomcat")
i=0
for svc in "${services[@]}"; do
    svc_upper=$(echo "$svc" | tr 'a-z' 'A-Z' | tr '-' '_')
    conf_key=$([ "$svc" = "apache" ] && echo "${svc_upper}_MPM_CONF" || echo "${svc_upper}_CONF")
    # PHP는 mod_php로 실행될 수 있으므로 설정 파일 존재 여부로 확인
    if [ "$svc" = "php" ]; then
        if grep -qE "^${conf_key}(_[0-9]+)?=" "$SERVICE_LOG" 2>/dev/null; then
            calc_script_name="calculate_${svc}_config.sh"
            calc_script="$MODULES_DIR/$calc_script_name"
            if [ -f "$calc_script" ] && [ -x "$calc_script" ]; then
                run_background_step "${svc_upper}_CONFIG" "$calc_script" "$((i+5))"
            else
                echo "${svc_upper}_CONFIG=skipped" >> "$TUNING_STATUS_LOG"
                log_debug "경고: $svc 설정 계산 스크립트($calc_script) 없음, 스킵"
            fi
        else
            log_debug "서비스 $svc: 설정 파일 없음, 계산 스킵"
        fi
    else
        # 다른 서비스는 RUNNING 상태로 확인
        if grep -qE "^${svc_upper}_RUNNING(_[0-9]+)?=1" "$SERVICE_LOG" 2>/dev/null; then
            calc_script_name=$([ "$svc" = "apache" ] && echo "calculate_mpm_config.sh" || echo "calculate_${svc}_config.sh")
            calc_script="$MODULES_DIR/$calc_script_name"
            if [ -f "$calc_script" ] && [ -x "$calc_script" ]; then
                run_background_step "${svc_upper}_CONFIG" "$calc_script" "$((i+5))"
            else
                echo "${svc_upper}_CONFIG=skipped" >> "$TUNING_STATUS_LOG"
                log_debug "경고: $svc 설정 계산 스크립트($calc_script) 없음, 스킵"
            fi
        else
            log_debug "서비스 $svc: 실행 중 아님, 계산 스킵"
        fi
    fi
    i=$((i+1))
done

# 서비스 리스트 출력
display_service_list() {
    local log_file="$SERVICE_LOG"
    if [ ! -f "$log_file" ]; then
        echo "오류: service_paths.log 파일($log_file)이 없습니다." >&2
        log_debug "service_paths.log 파일($log_file) 없음"
        return 1
    fi
    echo "실행 중인 서비스 및 수정될 설정 파일:"
    local found_running=false
    services=("apache" "nginx" "mysql" "mariadb" "php" "php_fpm" "tomcat")
    for svc in "${services[@]}"; do
        svc_upper=$(echo "$svc" | tr 'a-z' 'A-Z' | tr '-' '_')
        conf_key=$([ "$svc" = "apache" ] && echo "${svc_upper}_MPM_CONF" || echo "${svc_upper}_CONF")
        # PHP는 mod_php로 실행될 수 있으므로 설정 파일 존재 여부로 확인
        if [ "$svc" = "php" ]; then
            if grep -qE "^${conf_key}(_[0-9]+)?=" "$log_file" 2>/dev/null; then
                found_running=true
                conf_files=$(grep -E "^${conf_key}(_[0-9]+)?=" "$log_file" 2>/dev/null | cut -d'=' -f2)
                if [ -n "$conf_files" ]; then
                    while IFS= read -r conf_file; do
                        if [ -n "$conf_file" ] && [ -f "$conf_file" ]; then
                            echo "- $svc: $conf_file"
                        else
                            log_debug "서비스 $svc: 설정 파일($conf_file) 존재하지 않음"
                        fi
                    done <<< "$conf_files"
                else
                    log_debug "서비스 $svc: 설정 파일 없음"
                fi
            else
                log_debug "서비스 $svc: 설정 파일 없음, 출력 스킵"
            fi
        else
            # 다른 서비스는 RUNNING 상태로 확인
            running_instances=$(grep -E "^${svc_upper}_RUNNING(_[0-9]+)?=1" "$log_file" 2>/dev/null | wc -l)
            log_debug "서비스 $svc: grep 패턴=^${svc_upper}_RUNNING(_[0-9]+)?=1, 실행 중인 인스턴스=$running_instances"
            if [ "$running_instances" -gt 0 ]; then
                found_running=true
                conf_files=$(grep -E "^${conf_key}(_[0-9]+)?=" "$log_file" 2>/dev/null | cut -d'=' -f2)
                if [ -n "$conf_files" ]; then
                    while IFS= read -r conf_file; do
                        if [ -n "$conf_file" ] && [ -f "$conf_file" ]; then
                            echo "- $svc: $conf_file"
                        else
                            log_debug "서비스 $svc: 설정 파일($conf_file) 존재하지 않음"
                        fi
                    done <<< "$conf_files"
                else
                    log_debug "서비스 $svc: 설정 파일 없음"
                fi
            else
                log_debug "서비스 $svc: 실행 중 아님, 출력 스킵"
            fi
        fi
    done
    if [ "$found_running" = false ]; then
        echo "실행 중인 서비스가 없습니다."
    fi
    echo ""
}

# 설정 적용 여부 확인
prompt_for_apply() {
    display_service_list
    local running_services=()
    services=("apache" "nginx" "mysql" "mariadb" "php" "php_fpm" "tomcat")
    for svc in "${services[@]}"; do
        svc_upper=$(echo "$svc" | tr 'a-z' 'A-Z' | tr '-' '_')
        if [ "$svc" = "php" ]; then
            if grep -qE "^${svc_upper}_CONF(_[0-9]+)?=" "$SERVICE_LOG" 2>/dev/null; then
                running_services+=("$svc")
            fi
        elif grep -qE "^${svc_upper}_RUNNING(_[0-9]+)?=1" "$SERVICE_LOG" 2>/dev/null; then
            running_services+=("$svc")
        fi
    done

    if [ ${#running_services[@]} -eq 0 ]; then
        echo "적용 가능한 서비스가 없습니다. 프로세스 종료."
        log_debug "적용 가능한 서비스 없음, 종료"
        exit 0
    fi

    echo "설정을 적용하시겠습니까? (A: 모두 적용, S: 선택 적용, N: 종료)"
    read -r choice
    apply_services=()
    case $choice in
        [Aa])
            apply_services=("${running_services[@]}")
            ;;
        [Ss])
            echo "현재 실행 중인 서비스: ${running_services[*]}"
            echo "적용할 서비스를 선택하세요 (예: apache nginx mysql, 공백으로 구분, 종료하려면 Enter):"
            read -a selected
            for svc in "${selected[@]}"; do
                if [[ " ${services[*]} " =~ " $svc " ]]; then
                    svc_upper=$(echo "$svc" | tr 'a-z' 'A-Z' | tr '-' '_')
                    if [ "$svc" = "php" ]; then
                        if grep -qE "^${svc_upper}_CONF(_[0-9]+)?=" "$SERVICE_LOG" 2>/dev/null; then
                            apply_services+=("$svc")
                        else
                            echo "경고: $svc 설정 파일이 없습니다." >&2
                            log_debug "선택된 서비스 $svc 설정 파일 없음"
                        fi
                    elif grep -qE "^${svc_upper}_RUNNING(_[0-9]+)?=1" "$SERVICE_LOG" 2>/dev/null; then
                        apply_services+=("$svc")
                    else
                        echo "경고: $svc 서비스가 실행 중이 아닙니다." >&2
                        log_debug "선택된 서비스 $svc 실행 중 아님"
                    fi
                else
                    echo "경고: $svc는 유효한 서비스가 아닙니다." >&2
                    log_debug "유효하지 않은 서비스 선택: $svc"
                fi
            done
            ;;
        [Nn])
            echo "프로세스 종료"
            log_debug "사용자 선택: 종료"
            exit 0
            ;;
        *)
            echo "오류: A, S, N 중 하나를 입력하세요." >&2
            prompt_for_apply
            return
            ;;
    esac

    # 설정 적용
    for svc in "${apply_services[@]}"; do
        local apply_script="$SCRIPTS_DIR/apply/apply_${svc}.sh"
        if [ ! -x "$apply_script" ]; then
            echo "[SKIP] $svc: 적용 스크립트($apply_script)가 없습니다." >&2
            log_debug "$svc: 적용 스크립트($apply_script) 없음"
            continue
        fi

        echo "[적용] $svc 설정 적용 중..."
        "$apply_script" >> "$DEBUG_LOG" 2>&1
        if [ $? -eq 0 ]; then
            echo "[OK] $svc 설정 적용 완료"
            log_debug "$svc 설정 적용 성공"
        else
            echo "[ERROR] $svc 설정 적용 실패 (자세한 내용은 $DEBUG_LOG 확인)" >&2
            log_debug "$svc 설정 적용 실패"
        fi
    done
}

# 메인 실행
check_root
prompt_for_apply

echo "모든 프로세스 완료. 로그: $TUNING_STATUS_LOG, $DEBUG_LOG"