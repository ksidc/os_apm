#!/bin/bash

# backup.sh
# 설정 파일 백업 전용 스크립트. main.sh에서 source로 호출.
# 의존성: common.sh의 log_debug, check_root, setup_logging 필요
# 수정: PHP 설정 파일 백업 보장, rsync 대신 cp 사용, 디렉터리 권한 확인
# 최신 수정: 실행 중인 서비스만 백업, 실패 시 스킵, 로그 강화

source "$BASE_DIR/scripts/common.sh"
setup_logging || { echo "오류: 로깅 설정 실패" >&2; exit 1; }

backup_files() {
    local files=("$@")
    check_root || { log_debug "루트 권한 없음"; return 1; }

    # 백업 디렉터리 생성 및 권한 설정
    mkdir -p "$BACKUP_DIR" || { log_debug "백업 디렉터리 생성 실패: $BACKUP_DIR"; echo "오류: 백업 디렉터리($BACKUP_DIR) 생성 실패" >&2; return 1; }
    chmod 700 "$BACKUP_DIR" 2>/dev/null || { log_debug "백업 디렉터리 권한 설정 실패: $BACKUP_DIR"; echo "오류: 백업 디렉터리 권한 설정 실패" >&2; return 1; }

    local backed_up=0
    local idx=1
    for conf in "${files[@]}"; do
        [ -z "$conf" ] && { log_debug "백업 스킵: 빈 파일 경로"; continue; }
        [ ! -f "$conf" ] && { log_debug "백업 스킵: 파일 없음 - $conf"; continue; }

        local timestamp=$(date +%Y%m%d_%H%M%S)
        local base_name=$(basename "$conf")
        local backup_path="$BACKUP_DIR/${base_name}_${idx}.bak.$timestamp"

        cp -a "$conf" "$backup_path" || { log_debug "백업 실패: $conf → $backup_path"; echo "오류: $conf 백업 실패" >&2; continue; }
        sed -i 's/password=.*/password=***/g; s/passwd=.*/passwd=***/g; s/db_pass=.*/db_pass=***/g' "$backup_path"
        chmod 600 "$backup_path" 2>/dev/null || { log_debug "chmod 실패: $backup_path"; echo "오류: $backup_path 권한 설정 실패" >&2; }
        log_debug "백업 완료: $conf → $backup_path (마스킹 적용)"
        echo "백업 완료: $conf → $backup_path" >> "$APPLY_LOG"
        backed_up=1
        ((idx++))
    done

    [ $backed_up -eq 0 ] && { log_debug "백업 실패: 유효한 파일 없음"; echo "오류: 백업할 파일이 없음" >&2; return 1; }
    return 0
}

backup_service_conf() {
    local service="$1"
    local log_file="$LOG_DIR/service_paths.log"
    local service_lower=$(echo "$service" | tr 'A-Z' 'a-z' | tr '-' '_')
    local service_upper=$(echo "$service_lower" | tr 'a-z' 'A-Z' | tr '-' '_')

    # 실행 중인지 확인
    if ! grep -qE "^${service_upper}_RUNNING(_[0-9]+)?=1" "$log_file" 2>/dev/null; then
        log_debug "서비스 $service 실행 중 아님, 백업 스킵"
        return 0
    fi

    local backed_up=0
    local idx=1
    local confs=()
    local conf_key=$([ "$service_lower" = "apache" ] && echo "${service_upper}_MPM_CONF" || echo "${service_upper}_CONF")

    while IFS= read -r line; do
        if [[ "$line" =~ ^${conf_key}(_[0-9]+)?= ]]; then
            conf="${line#*=}"
            [ -z "$conf" ] || [ ! -f "$conf" ] && { log_debug "백업 스킵: $service - 설정 파일($conf) 없음"; continue; }
            confs+=("$conf")
        fi
    done < "$log_file"

    for conf in "${confs[@]}"; do
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local base_name=$(basename "$conf")
        local backup_path="$BACKUP_DIR/${base_name}_${idx}.bak.$timestamp"

        cp -a "$conf" "$backup_path" || { log_debug "백업 실패: $conf → $backup_path"; echo "오류: $conf 백업 실패" >&2; continue; }
        sed -i 's/password=.*/password=***/g; s/passwd=.*/passwd=***/g; s/db_pass=.*/db_pass=***/g' "$backup_path"
        chmod 600 "$backup_path" 2>/dev/null || { log_debug "chmod 실패: $backup_path"; echo "오류: $backup_path 권한 설정 실패" >&2; }
        log_debug "백업 완료: $conf → $backup_path (마스킹 적용)"
        echo "백업 완료: $conf → $backup_path" >> "$APPLY_LOG"
        backed_up=1
        ((idx++))
    done

    [ $backed_up -eq 0 ] && { log_debug "[경고] $service conf 경로 중 실제 존재하는 파일 없음"; echo "경고: $service 설정 파일 백업 실패" >&2; return 0; }
    log_debug "$service conf 백업 완료"
    return 0
}

backup_all_services() {
    local services=("apache" "nginx" "mysql" "mariadb" "php" "php_fpm" "tomcat")
    local failed_services=()
    for service in "${services[@]}"; do
        backup_service_conf "$service" || failed_services+=("$service")
    done

    [ ${#failed_services[@]} -gt 0 ] && {
        log_debug "백업 실패 서비스: ${failed_services[*]}"
        echo "경고: 다음 서비스 백업 실패: ${failed_services[*]}" >&2
        return 0
    }

    log_debug "모든 서비스 conf 백업 완료"
    echo "롤백 팁: 백업 실패 시 'cp -a $BACKUP_DIR/*.bak /원본경로/'로 복원 (서비스 재시작 필수)" >> "$APPLY_LOG"
    return 0
}

log_debug "backup_all_services 함수 정의 완료"