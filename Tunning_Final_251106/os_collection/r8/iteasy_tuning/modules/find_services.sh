#!/bin/bash

# find_services.sh
# DNF 기반 시스템에서 Apache 및 MySQL/MariaDB 서비스를 탐지해 service_paths.log에 기록합니다.

BASE_DIR="${BASE_DIR:-/usr/local/src/iteasy_tuning}"
source "$BASE_DIR/scripts/common.sh"

output_entries=()

write_entry() {
    output_entries+=("$1")
}

check_service_active() {
    local unit="$1" pattern="$2"
    if systemctl --quiet is-active "$unit" 2>/dev/null; then
        echo 1
        return
    fi
    if [ -n "$pattern" ] && pgrep -f "$pattern" >/dev/null 2>&1; then
        echo 1
        return
    fi
    echo 0
}

detect_apache() {
    local binary=""
    for candidate in /usr/sbin/httpd /usr/bin/httpd; do
        if [ -x "$candidate" ]; then
            binary="$candidate"
            break
        fi
    done
    [ -z "$binary" ] && return 0

    local config="/etc/httpd/conf/httpd.conf"
    local mpm_conf="/etc/httpd/conf.modules.d/00-mpm.conf"
    if [ -x "$binary" ]; then
        local root
        root=$("$binary" -V 2>/dev/null | awk -F'"' '/HTTPD_ROOT/ {print $2}' )
        local server_conf
        server_conf=$("$binary" -V 2>/dev/null | awk -F'"' '/SERVER_CONFIG_FILE/ {print $2}')
        if [ -n "$root" ] && [ -n "$server_conf" ] && [ -f "$root/$server_conf" ]; then
            config="$root/$server_conf"
        fi
    fi
    local mpm
    mpm=$("$binary" -V 2>/dev/null | awk -F': ' '/Server MPM/ {print tolower($2)}')
    local running
    running=$(check_service_active httpd "$binary")

    write_entry "# Apache"
    write_entry "APACHE_BINARY=$binary"
    write_entry "APACHE_CONFIG=$config"
    write_entry "APACHE_MPM_CONF=$mpm_conf"
    write_entry "APACHE_MPM=${mpm:-unknown}"
    write_entry "APACHE_RUNNING=$running"
    log_info "Apache 서비스를 탐지했습니다" "detect" "$(json_two binary "$binary" running "$running")"
}

select_mysql_binary() {
    for candidate in /usr/libexec/mysqld /usr/sbin/mysqld; do
        [ -x "$candidate" ] && { echo "$candidate"; return; }
    done
    echo ""
}

select_mariadb_binary() {
    for candidate in /usr/libexec/mariadbd /usr/sbin/mariadbd; do
        [ -x "$candidate" ] && { echo "$candidate"; return; }
    done
    echo ""
}

detect_mysql_family() {
    local mysql_bin
    mysql_bin=$(select_mysql_binary)
    local mariadb_bin
    mariadb_bin=$(select_mariadb_binary)

    local conf_candidates=(/etc/my.cnf /etc/my.cnf.d/server.cnf)

    if [ -n "$mysql_bin" ]; then
        local conf=""
        for candidate in "${conf_candidates[@]}"; do
            [ -f "$candidate" ] && { conf="$candidate"; break; }
        done
        local running
        running=$(check_service_active mysqld "$mysql_bin")
        write_entry "# MySQL"
        write_entry "MYSQL_BINARY=$mysql_bin"
        write_entry "MYSQL_CONF=${conf:-NOT_FOUND}"
        write_entry "MYSQL_RUNNING=$running"
        log_info "MySQL 서비스를 탐지했습니다" "detect" "$(json_two binary "$mysql_bin" running "$running")"
    fi

    if [ -n "$mariadb_bin" ]; then
        local conf=""
        for candidate in /etc/my.cnf.d/server.cnf /etc/my.cnf; do
            [ -f "$candidate" ] && { conf="$candidate"; break; }
        done
        local running
        running=$(check_service_active mariadb "$mariadb_bin")
        write_entry "# MariaDB"
        write_entry "MARIADB_BINARY=$mariadb_bin"
        write_entry "MARIADB_CONF=${conf:-NOT_FOUND}"
        write_entry "MARIADB_RUNNING=$running"
        log_info "MariaDB 서비스를 탐지했습니다" "detect" "$(json_two binary "$mariadb_bin" running "$running")"
    fi

    if [ -z "$mysql_bin" ] && [ -z "$mariadb_bin" ]; then
        log_warn "MySQL/MariaDB 바이너리를 찾지 못했습니다" "detect"
    fi
}

log_info "서비스 탐지를 시작합니다" "detect"
> "$SERVICE_LOG"
chmod 600 "$SERVICE_LOG" 2>/dev/null || true

detect_apache
detect_mysql_family

if [ ${#output_entries[@]} -gt 0 ]; then
    printf '%s\n' "${output_entries[@]}" > "$SERVICE_LOG"
    log_info "서비스 탐지 결과를 저장했습니다" "detect" "$(json_kv path "$SERVICE_LOG")"
else
    : > "$SERVICE_LOG"
    log_warn "탐지 결과가 없어 service_paths.log를 비웠습니다" "detect"
fi
