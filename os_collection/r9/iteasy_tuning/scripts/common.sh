#!/bin/bash

# common.sh
# 공통 함수: 로깅, 디렉터리 설정, 서비스 탐지, 백업, 사용자 인터페이스
# 추가: display_service_list, prompt_for_apply 함수
# 보안: 로그 권한 600, 백업 디렉터리 700, 비밀번호 마스킹
# 수정: find_binaries 함수의 구문 오류 수정, 로그 메시지 개선
# 최신 수정: /var/log 폴백 추가, find_config 로그 강화, 단일/다중 서비스 환경 최적화, PHP(mod_php) 처리 개선

# 기본 디렉터리 설정
BASE_DIR="/usr/local/src/iteasy_tuning"
LOG_DIR="$BASE_DIR/logs"
DEBUG_LOG="$LOG_DIR/debug.log"
FALLBACK_LOG_DIR="/tmp/iteasy_tuning_logs"
FALLBACK_DEBUG_LOG="$FALLBACK_LOG_DIR/debug.log"
BACKUP_DIR="$BASE_DIR/backups"
APPLY_LOG="$LOG_DIR/apply.log"
ERR_CONF_DIR="$BASE_DIR/err_conf"

# 디버깅 로그 함수
log_debug() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp: $*" >> "$DEBUG_LOG" 2>/dev/null || \
    echo "$timestamp: $*" >> "$FALLBACK_DEBUG_LOG" 2>/dev/null
}

# 로그 및 디렉터리 설정
setup_logging() {
    [ -z "$BASE_DIR" ] && { echo "오류: BASE_DIR 환경변수가 정의되지 않았습니다." >&2; exit 1; }
    [ -z "$LOG_DIR" ] && LOG_DIR="$BASE_DIR/logs"
    [ -z "$BACKUP_DIR" ] && BACKUP_DIR="$BASE_DIR/backups"
    [ -z "$ERR_CONF_DIR" ] && ERR_CONF_DIR="$BASE_DIR/err_conf"
    [ -z "$DEBUG_LOG" ] && DEBUG_LOG="$LOG_DIR/debug.log"
    [ -z "$APPLY_LOG" ] && APPLY_LOG="$LOG_DIR/apply.log"

    FALLBACK_LOG_DIR="/tmp/iteasy_tuning_logs"
    FALLBACK_DEBUG_LOG="$FALLBACK_LOG_DIR/debug.log"
    FALLBACK_APPLY_LOG="$FALLBACK_LOG_DIR/apply.log"

    if ! mkdir -p "$LOG_DIR" 2>/dev/null; then
        echo "오류: 로그 디렉터리($LOG_DIR) 생성 실패, 대체 경로($FALLBACK_LOG_DIR) 사용" >&2
        mkdir -p "$FALLBACK_LOG_DIR" || {
            FALLBACK_LOG_DIR="/var/log/iteasy_tuning"
            mkdir -p "$FALLBACK_LOG_DIR" || { echo "오류: 최종 대체 로그 디렉터리($FALLBACK_LOG_DIR) 생성 실패" >&2; exit 1; }
            LOG_DIR="$FALLBACK_LOG_DIR"
            DEBUG_LOG="$FALLBACK_LOG_DIR/debug.log"
            APPLY_LOG="$FALLBACK_LOG_DIR/apply.log"
        }
        LOG_DIR="$FALLBACK_LOG_DIR"
        DEBUG_LOG="$FALLBACK_DEBUG_LOG"
        APPLY_LOG="$FALLBACK_APPLY_LOG"
    fi
    chmod 700 "$LOG_DIR" "$FALLBACK_LOG_DIR" 2>/dev/null || log_debug "경고: $LOG_DIR 또는 $FALLBACK_LOG_DIR 권한 설정 실패"

    if ! mkdir -p "$BACKUP_DIR" 2>/dev/null; then
        echo "오류: 백업 디렉터리($BACKUP_DIR) 생성 실패" >&2
        exit 1
    fi
    chmod 700 "$BACKUP_DIR" 2>/dev/null || log_debug "경고: $BACKUP_DIR 권한 설정 실패"

    if ! mkdir -p "$ERR_CONF_DIR" 2>/dev/null; then
        echo "오류: ERR_CONF_DIR($ERR_CONF_DIR) 생성 실패" >&2
        exit 1
    fi
    chmod 700 "$ERR_CONF_DIR" 2>/dev/null || log_debug "경고: $ERR_CONF_DIR 권한 설정 실패"

    for logf in "$DEBUG_LOG" "$APPLY_LOG" "$LOG_DIR/tuning_status.log" "$LOG_DIR/service_paths.log" \
                "$LOG_DIR/service_versions.log" "$LOG_DIR/system_specs.log"; do
        touch "$logf" || { echo "오류: 로그 파일($logf) 생성 실패" >&2; exit 1; }
        chmod 600 "$logf" 2>/dev/null || log_debug "경고: $logf 권한 설정 실패"
    done
    log_debug "공통 로깅/디렉터리 설정 완료: DEBUG_LOG=$DEBUG_LOG, APPLY_LOG=$APPLY_LOG, ERR_CONF_DIR=$ERR_CONF_DIR"
}

# 루트 권한 체크
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "오류: 루트 권한으로 실행하세요 (sudo $0)." >&2
        log_debug "루트 권한 부족: 스크립트 종료"
        exit 1
    fi
    log_debug "루트 권한 확인 완료"
}

# 서비스 리스트 출력 함수
display_service_list() {
    local log_file="$LOG_DIR/service_paths.log"
    local tmp_conf_dir="$BASE_DIR/tmp_conf"
    echo "실행 중인 서비스 및 수정될 설정 파일:"
    local services=("apache" "nginx" "mysql" "mariadb" "php" "php_fpm" "tomcat")
    local found_running=false
    for svc in "${services[@]}"; do
        local svc_upper=$(echo "$svc" | tr 'a-z' 'A-Z' | tr '-' '_')
        local conf_key=$([ "$svc" = "apache" ] && echo "${svc_upper}_MPM_CONF" || echo "${svc_upper}_CONF")
        # PHP는 mod_php로 실행될 수 있으므로 설정 파일 존재 여부로 확인
        if [ "$svc" = "php" ]; then
            if grep -qE "^${svc_upper}_CONF(_[0-9]+)?=" "$log_file" 2>/dev/null; then
                local conf_lines=$(grep -E "^${conf_key}(_[0-9]+)?=" "$log_file" 2>/dev/null | cut -d'=' -f2-)
                if [ -n "$conf_lines" ]; then
                    found_running=true
                    while IFS= read -r conf_file; do
                        conf_file=$(echo "$conf_file" | xargs)  # 공백 제거
                        if [ -n "$conf_file" ] && [ -f "$conf_file" ]; then
                            echo "- $svc: $conf_file"
                        else
                            log_debug "서비스 $svc: 설정 파일($conf_file) 존재하지 않음"
                        fi
                    done <<< "$conf_lines"
                else
                    log_debug "서비스 $svc: 설정 파일 없음"
                fi
            else
                log_debug "서비스 $svc: 설정 파일 없음, 출력 스킵"
            fi
        else
            # 다른 서비스는 RUNNING 상태로 확인
            local running=$(grep -E "^${svc_upper}_RUNNING(_[0-9]+)?=1" "$log_file" 2>/dev/null | wc -l)
            if [ "$running" -gt 0 ]; then
                found_running=true
                local conf_lines=$(grep -E "^${conf_key}(_[0-9]+)?=" "$log_file" 2>/dev/null | cut -d'=' -f2-)
                if [ -n "$conf_lines" ]; then
                    while IFS= read -r conf_file; do
                        conf_file=$(echo "$conf_file" | xargs)  # 공백 제거
                        if [ -n "$conf_file" ] && [ -f "$conf_file" ]; then
                            echo "- $svc: $conf_file"
                        else
                            log_debug "서비스 $svc: 설정 파일($conf_file) 존재하지 않음"
                        fi
                    done <<< "$conf_lines"
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
    log_debug "서비스 리스트 출력 완료"
}

# 적용 옵션 사용자 입력 함수
prompt_for_apply() {
    local services=("apache" "nginx" "mysql" "mariadb" "php" "php_fpm" "tomcat")
    local apply_services=()
    local log_file="$LOG_DIR/service_paths.log"
    local tmp_conf_dir="$BASE_DIR/tmp_conf"

    display_service_list
    local running_services=()
    for svc in "${services[@]}"; do
        local svc_upper=$(echo "$svc" | tr 'a-z' 'A-Z' | tr '-' '_')
        if [ "$svc" = "php" ]; then
            if grep -qE "^${svc_upper}_CONF(_[0-9]+)?=" "$log_file" 2>/dev/null; then
                running_services+=("$svc")
            fi
        elif grep -qE "^${svc_upper}_RUNNING(_[0-9]+)?=1" "$log_file" 2>/dev/null; then
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
    case "$choice" in
        [Aa])
            apply_services=("${running_services[@]}")
            ;;
        [Ss])
            echo "현재 실행 중인 서비스: ${running_services[*]}"
            echo "적용할 서비스를 선택하세요 (예: apache nginx mysql, 공백으로 구분, 종료하려면 Enter):"
            read -a selected
            for svc in "${selected[@]}"; do
                if [[ " ${services[*]} " =~ " $svc " ]]; then
                    local svc_upper=$(echo "$svc" | tr 'a-z' 'A-Z' | tr '-' '_')
                    if [ "$svc" = "php" ]; then
                        if grep -qE "^${svc_upper}_CONF(_[0-9]+)?=" "$log_file" 2>/dev/null; then
                            apply_services+=("$svc")
                        else
                            echo "경고: $svc 설정 파일이 없습니다." >&2
                            log_debug "선택된 서비스 $svc 설정 파일 없음"
                        fi
                    elif grep -qE "^${svc_upper}_RUNNING(_[0-9]+)?=1" "$log_file" 2>/dev/null; then
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
        local svc_upper=$(echo "$svc" | tr 'a-z' 'A-Z' | tr '-' '_')
        local conf_file=""
        case "$svc" in
            apache) conf_file="$tmp_conf_dir/mpm_config.conf" ;;
            nginx) conf_file="$tmp_conf_dir/nginx_config.conf" ;;
            php) conf_file="$tmp_conf_dir/php_config.ini" ;;
            php_fpm) conf_file="$tmp_conf_dir/php_fpm_config.conf" ;;
            mysql|mariadb) conf_file="$tmp_conf_dir/mysql_config.conf" ;;
            tomcat) conf_file="$tmp_conf_dir/tomcat_config.conf" ;;
        esac
        local apply_script="$SCRIPTS_DIR/apply/apply_${svc}.sh"

        if [ ! -f "$conf_file" ] || [ ! -s "$conf_file" ]; then
            echo "[SKIP] $svc: 추천 설정 파일($conf_file)이 없습니다." >&2
            log_debug "$svc: 추천 설정 파일($conf_file) 없음"
            continue
        fi
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

# conf 경로 추출 함수
extract_conf_from_log() {
    local service="$1"
    local log_file="$LOG_DIR/service_paths.log"
    local service_upper=$(echo "$service" | tr 'a-z' 'A-Z' | tr '-' '_')
    local conf_key=$([ "$service" = "apache" ] && echo "${service_upper}_MPM_CONF" || echo "${service_upper}_CONF")
    local extracted_paths=""

    local conf_lines=$(grep -E "^${conf_key}(_[0-9]+)?=" "$log_file" 2>/dev/null | cut -d'=' -f2- | tr '\n' ' ' | xargs)
    if [ -z "$conf_lines" ]; then
        log_debug "conf 추출 실패: $service"
        return 1
    fi

    extracted_paths="$conf_lines"
    log_debug "$service conf 경로 추출 성공: $extracted_paths"
    echo "$extracted_paths"
    return 0
}

# 바이너리 탐지 함수
find_binaries() {
    local service="$1" binary_names="$2" version_check="$3" _unused_pid_pattern="$4"
    local search_paths="$5"
    local bins=() seen_bins=()

    # 사용자 지정 경로에서 직접 탐색
    IFS=' ' read -ra path_array <<< "$search_paths"
    for path in "${path_array[@]}"; do
        for bin in $(find "$path" -maxdepth 1 -type f -executable -name "$binary_names" 2>/dev/null); do
            if [ -x "$bin" ]; then
                real_bin=$(realpath "$bin" 2>/dev/null)
                if [[ ! " ${seen_bins[*]} " =~ " $real_bin " ]]; then
                    if [ -n "$version_check" ]; then
                        if "$bin" --version 2>/dev/null | grep -qi "$version_check"; then
                            bins+=("$bin")
                            seen_bins+=("$real_bin")
                        fi
                    else
                        bins+=("$bin")
                        seen_bins+=("$real_bin")
                    fi
                fi
            fi
        done
    done

    # PATH 내 실행 가능한 동일 이름 바이너리 추가
    while IFS= read -r bin; do
        if [ -x "$bin" ]; then
            real_bin=$(realpath "$bin" 2>/dev/null)
            if [[ ! " ${seen_bins[*]} " =~ " $real_bin " ]]; then
                if [ -n "$version_check" ]; then
                    if "$bin" --version 2>/dev/null | grep -qi "$version_check"; then
                        bins+=("$bin")
                        seen_bins+=("$real_bin")
                    fi
                else
                    bins+=("$bin")
                    seen_bins+=("$real_bin")
                fi
            fi
        fi
    done < <(which -a "$binary_names" 2>/dev/null)

    if [ ${#bins[@]} -eq 0 ]; then
        log_debug "$service 바이너리 탐지 실패: $binary_names"
    else
        log_debug "$service 바이너리 탐지 성공: ${bins[*]}"
    fi
    printf "%s\n" "${bins[@]}" | sort -u
}

# PID 탐지 함수
find_pids() {
    local service="$1" pattern="$2"
    local pids=()
    while IFS= read -r pid; do
        pids+=("$pid")
    done < <(ps aux | grep -E "$pattern" | grep -v -E "/usr/local/php/bin/php|/usr/bin/php" | grep -v grep | awk '{print $2}' 2>/dev/null)
    if [ ${#pids[@]} -eq 0 ]; then
        log_debug "$service PID 탐지 실패: $pattern"
    else
        log_debug "$service PID 탐지 성공: ${pids[*]}"
    fi
    printf "%s\n" "${pids[@]}"
}

# 설정 파일 탐지 함수
find_config() {
    local service="$1" binary="$2" conf_names="$3" conf_command="$4"
    local conf=""
    if [ -n "$conf_command" ]; then
        conf=$($conf_command 2>/dev/null | xargs)
        if [ -n "$conf" ] && [ -f "$conf" ]; then
            log_debug "$service 설정 파일 탐지 성공: $conf (via $conf_command)"
            echo "$conf"
            return 0
        fi
    fi
    conf=$(find /etc /usr /usr/local /opt /var -type f -name "$conf_names" 2>/dev/null | head -1)
    if [ -n "$conf" ] && [ -f "$conf" ]; then
        log_debug "$service 설정 파일 탐지 성공: $conf (via find)"
        echo "$conf"
        return 0
    fi
    log_debug "$service 설정 파일 탐지 실패: $conf_names"
    echo ""
}

# 서비스 상태 확인 함수
check_service_status() {
    local service="$1" service_names="$2" binary="$3" pids=("${!4}") pattern="$5"
    local svc=""
    for s in $service_names; do
        if systemctl --quiet is-active "$s" 2>/dev/null; then
            svc="$s"
            log_debug "$service 서비스: $svc, systemctl로 실행 중 확인"
            return 0
        elif [ -f "/etc/init.d/$s" ] && /etc/init.d/"$s" status >/dev/null 2>&1; then
            svc="$s"
            log_debug "$service 서비스: $svc, init.d로 실행 중 확인"
            return 0
        fi
    done
    if [ ${#pids[@]} -gt 0 ]; then
        svc=$(ps aux | grep -E "$pattern" | grep -v grep | awk '{print $11}' | head -1 | xargs basename 2>/dev/null)
        log_debug "$service 서비스: $svc, PID로 실행 중 확인"
        return 0
    fi
    log_debug "$service 서비스: 실행 중인 서비스 없음"
    echo ""
}