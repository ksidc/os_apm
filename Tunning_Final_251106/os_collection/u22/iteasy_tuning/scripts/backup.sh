#!/bin/bash

# backup.sh
# Back up key configuration files for detected services.

BASE_DIR="${BASE_DIR:-/usr/local/src/iteasy_tuning}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$BASE_DIR/scripts}"
source "$SCRIPTS_DIR/common.sh"
source "$SCRIPTS_DIR/lib/kv_parser.sh"

backup_files() {
    local files=("$@")
    check_root || { log_error "Root privilege is required for backup" "backup"; return 1; }

    _setup_dir "$BACKUP_DIR" 700 || {
        log_error "Failed to prepare backup directory" "backup" "$(json_kv path "$BACKUP_DIR")"
        return 1
    }

    local backed_up=0 index=1
    for conf in "${files[@]}"; do
        if [ -z "$conf" ] || [ ! -f "$conf" ]; then
            log_warn "Skip backup; file not found" "backup" "$(json_kv path "$conf")"
            continue
        fi

        local filename
        filename=$(basename "$conf")
        local backup_path="$BACKUP_DIR/${index}_$(date +%Y%m%d_%H%M%S)_${filename}"

        if cp -a "$conf" "$backup_path"; then
            local detail
            detail=$(json_two source "$conf" target "$backup_path")
            log_info "Config file backed up" "backup" "$detail"
            backed_up=$((backed_up + 1))
        else
            log_error "Failed to back up config file" "backup" "$(json_kv path "$conf")"
        fi
        index=$((index + 1))
    done

    if [ "$backed_up" -eq 0 ]; then
        log_warn "No config files were backed up" "backup"
    else
        log_info "Backed up ${backed_up} config file(s)" "backup"
    fi
}

backup_all_services() {
    local log_file="$SERVICE_LOG"
    local backed_files=()

    if grep -qE '^APACHE_RUNNING=1' "$log_file" 2>/dev/null; then
        local apache_conf
        apache_conf=$(kv_get_value "$log_file" "APACHE_MPM_CONF")
        apache_conf=${apache_conf:-/etc/apache2/mods-available/mpm_event.conf}
        if [ -f "$apache_conf" ]; then
            backed_files+=("$apache_conf")
            log_info "Queued Apache config for backup" "backup" "$(json_kv file "$apache_conf")"
        fi
    fi

    if grep -qE '^MYSQL_RUNNING=1' "$log_file" 2>/dev/null; then
        local mysql_conf="/etc/mysql/mysql.conf.d/zz-iteasy_tuning.cnf"
        if [ -f "$mysql_conf" ]; then
            backed_files+=("$mysql_conf")
            log_info "Queued DB config for backup" "backup" "$(json_kv file "$mysql_conf")"
        fi
    fi

    if [ ${#backed_files[@]} -gt 0 ]; then
        backup_files "${backed_files[@]}"
    else
        log_warn "No config files detected for backup" "backup"
    fi
}
