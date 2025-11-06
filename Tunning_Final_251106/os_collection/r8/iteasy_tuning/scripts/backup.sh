#!/bin/bash

# backup.sh
# 서비스별 주요 설정 파일을 백업합니다.

source "$BASE_DIR/scripts/common.sh"

backup_files() {
    local files=("$@")
    check_root || { log_error "루트 권한이 없어 백업을 진행할 수 없습니다" "backup"; return 1; }

    _setup_dir "$BACKUP_DIR" 700 || {
        log_error "백업 디렉터리를 생성하지 못했습니다" "backup" "$(json_kv path "$BACKUP_DIR")"
        return 1
    }

    local backed_up=0 index=1
    for conf in "${files[@]}"; do
        if [ -z "$conf" ]; then
            log_warn "백업할 파일 경로가 비어 있어 건너뜁니다" "backup"
            continue
        fi
        if [ ! -f "$conf" ]; then
            log_warn "백업 대상 파일이 존재하지 않아 건너뜁니다" "backup" "$(json_kv path "$conf")"
            continue
        fi

        local filename
        filename=$(basename "$conf")
        local backup_path="$BACKUP_DIR/${index}_$(date +%Y%m%d_%H%M%S)_${filename}"

        if cp -a "$conf" "$backup_path"; then
            log_info "설정 파일을 백업했습니다" "backup" "$(json_two source "$conf" target "$backup_path")"
            backed_up=$((backed_up + 1))
        else
            log_error "설정 파일을 백업하지 못했습니다" "backup" "$(json_kv path "$conf")"
        fi
        index=$((index + 1))
    done

    if [ "$backed_up" -eq 0 ]; then
        log_warn "백업한 설정 파일이 없습니다" "backup"
    else
        log_info "총 ${backed_up}개의 설정 파일을 백업했습니다" "backup"
    fi
}

backup_service_conf() {
    local service="$1"
    local conf_list="$2"
    local files=()
    while IFS= read -r line; do
        files+=("$line")
    done <<< "$conf_list"
    backup_files "${files[@]}"
}

backup_all_services() {
    local log_file="$SERVICE_LOG"
    local backed_files=()

    # Apache: 00-mpm.conf 백업 (MPM 설정이 실제로 저장되는 곳)
    if grep -qE "^APACHE_RUNNING=1" "$log_file" 2>/dev/null; then
        local mpm_conf
        mpm_conf=$(grep -E "^APACHE_MPM_CONF=" "$log_file" 2>/dev/null | cut -d'=' -f2-)
        if [ -n "$mpm_conf" ] && [ -f "$mpm_conf" ]; then
            backed_files+=("$mpm_conf")
            log_info "Apache MPM 설정 파일을 백업 대상에 추가했습니다" "backup" "$(json_kv file "$mpm_conf")"
        elif [ -f "/etc/httpd/conf.modules.d/00-mpm.conf" ]; then
            backed_files+=("/etc/httpd/conf.modules.d/00-mpm.conf")
            log_info "Apache MPM 설정 파일을 백업 대상에 추가했습니다" "backup" "$(json_kv file "/etc/httpd/conf.modules.d/00-mpm.conf")"
        fi
    fi

    # MySQL/MariaDB: zz-iteasy_tuning.cnf만 백업 (원본 my.cnf는 건드리지 않음)
    if grep -qE "^MYSQL_RUNNING=1" "$log_file" 2>/dev/null || grep -qE "^MARIADB_RUNNING=1" "$log_file" 2>/dev/null; then
        if [ -f "/etc/my.cnf.d/zz-iteasy_tuning.cnf" ]; then
            backed_files+=("/etc/my.cnf.d/zz-iteasy_tuning.cnf")
            log_info "MySQL/MariaDB 튜닝 파일을 백업 대상에 추가했습니다" "backup" "$(json_kv file "/etc/my.cnf.d/zz-iteasy_tuning.cnf")"
        fi
    fi

    if [ ${#backed_files[@]} -gt 0 ]; then
        backup_files "${backed_files[@]}"
    else
        log_warn "백업할 설정 파일을 찾지 못했습니다 (아직 튜닝이 적용되지 않았을 수 있습니다)" "backup"
    fi
}
