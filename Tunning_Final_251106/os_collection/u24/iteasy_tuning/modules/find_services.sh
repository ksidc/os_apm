#!/bin/bash

# find_services.sh
# Detect Apache2 and MySQL/MariaDB services on Ubuntu 24.x systems.

BASE_DIR="${BASE_DIR:-/usr/local/src/iteasy_tuning}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$BASE_DIR/scripts}"
source "$SCRIPTS_DIR/common.sh"
source "$SCRIPTS_DIR/lib/kv_parser.sh"

output_entries=()

write_entry() {
    output_entries+=("$1")
}

dpkg_installed_any() {
    local pattern
    for pattern in "$@"; do
        if dpkg-query -W -f='${Status}' "$pattern" 2>/dev/null | grep -q "install ok installed"; then
            return 0
        fi
    done
    return 1
}

trim() {
    local value="$1"
    echo "$value" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//'
}

check_service_active() {
    local units="$1" pattern="$2"
    local unit
    for unit in $units; do
        if systemctl --quiet is-active "$unit" 2>/dev/null; then
            echo 1
            return
        fi
    done
    if [ -n "$pattern" ] && pgrep -f "$pattern" >/dev/null 2>&1; then
        echo 1
        return
    fi
    echo 0
}

detect_apache() {
    if ! dpkg_installed_any "apache2" "apache2-bin"; then
        log_warn "APT 패키지 apache2가 설치돼 있지 않아도 Apache 바이너리를 탐색합니다" "detect"
    fi

    local binary=""
    for candidate in /usr/sbin/apache2 /usr/bin/apache2; do
        if [ -x "$candidate" ]; then
            binary="$candidate"
            break
        fi
    done
    if [ -z "$binary" ]; then
        log_warn "Apache2 바이너리를 찾지 못했습니다" "detect"
        return
    fi

    local apachectl_cmd=""
    if command -v apachectl >/dev/null 2>&1; then
        apachectl_cmd="apachectl"
    elif command -v apache2ctl >/dev/null 2>&1; then
        apachectl_cmd="apache2ctl"
    fi

    local config="/etc/apache2/apache2.conf"
    local root=""
    local server_conf=""
    if [ -n "$apachectl_cmd" ]; then
        root=$("$apachectl_cmd" -V 2>/dev/null | awk -F'"' '/HTTPD_ROOT/ {print $2}')
        server_conf=$("$apachectl_cmd" -V 2>/dev/null | awk -F'"' '/SERVER_CONFIG_FILE/ {print $2}')
    else
        root=$("$binary" -V 2>/dev/null | awk -F'"' '/HTTPD_ROOT/ {print $2}')
        server_conf=$("$binary" -V 2>/dev/null | awk -F'"' '/SERVER_CONFIG_FILE/ {print $2}')
    fi
    if [ -n "$root" ] && [ -n "$server_conf" ] && [ -f "$root/$server_conf" ]; then
        config="$root/$server_conf"
    fi

    local mpm=""
    if [ -n "$apachectl_cmd" ]; then
        mpm=$("$apachectl_cmd" -V 2>/dev/null | awk -F':' '/Server MPM/ {print $2}')
    else
        mpm=$("$binary" -V 2>/dev/null | awk -F':' '/Server MPM/ {print $2}')
    fi
    mpm=$(trim "$mpm")
    mpm=${mpm,,}
    mpm=${mpm:-event}
    local mpm_conf="/etc/apache2/mods-available/mpm_${mpm}.conf"

    local running
    running=$(check_service_active "apache2" "$binary")

    write_entry "# Apache"
    write_entry "APACHE_BINARY=$binary"
    write_entry "APACHE_CONFIG=$config"
    write_entry "APACHE_MPM=$mpm"
    write_entry "APACHE_MPM_CONF=$mpm_conf"
    write_entry "APACHE_RUNNING=$running"
    log_info "Apache2 정보를 수집했습니다" "detect" "$(json_two binary "$binary" running "$running")"
}

select_mysql_binary() {
    for candidate in /usr/sbin/mysqld /usr/libexec/mysqld /usr/sbin/mariadbd /usr/libexec/mariadbd; do
        [ -x "$candidate" ] && { echo "$candidate"; return; }
    done
    echo ""
}

detect_mysql_family() {
    if ! dpkg_installed_any \
        "mysql-server" "mysql-server-*" \
        "mysql-community-server" "mysql-community-server-*" \
        "mariadb-server" "mariadb-server-*"; then
        log_warn "APT mysql/mariadb 서버 패키지를 찾지 못했습니다. 실행 중인 프로세스를 계속 탐색합니다" "detect"
    fi

    local mysql_bin
    mysql_bin=$(select_mysql_binary)
    if [ -z "$mysql_bin" ]; then
        log_warn "MySQL/MariaDB 바이너리를 찾지 못했습니다" "detect"
        write_entry "# MySQL"
        write_entry "MYSQL_BINARY=NOT_FOUND"
        write_entry "MYSQL_CONF=NOT_FOUND"
        write_entry "MYSQL_RUNNING=0"
        write_entry "MYSQL_SYSTEMD_UNIT=UNKNOWN"
        return
    fi

    local conf=""
    for candidate in /etc/mysql/mysql.conf.d/mysqld.cnf /etc/mysql/my.cnf; do
        [ -f "$candidate" ] && { conf="$candidate"; break; }
    done
    conf=${conf:-NOT_FOUND}

    local service_unit="mysql"
    if systemctl list-unit-files | grep -q '^mariadb\.service'; then
        service_unit="mariadb"
    elif systemctl list-unit-files | grep -q '^mysqld\.service'; then
        service_unit="mysqld"
    fi

    local running
    running=$(check_service_active "mysql mariadb mysqld" "$mysql_bin")

    write_entry "# MySQL"
    write_entry "MYSQL_BINARY=$mysql_bin"
    write_entry "MYSQL_CONF=$conf"
    write_entry "MYSQL_RUNNING=$running"
    write_entry "MYSQL_SYSTEMD_UNIT=$service_unit"
    log_info "MySQL/MariaDB 정보를 수집했습니다" "detect" "$(json_two binary "$mysql_bin" running "$running")"
}

log_info "서비스 탐지를 시작합니다" "detect"
> "$SERVICE_LOG"
chmod 600 "$SERVICE_LOG" 2>/dev/null || true

detect_apache
detect_mysql_family

if [ ${#output_entries[@]} -gt 0 ]; then
    printf '%s\n' "${output_entries[@]}" > "$SERVICE_LOG"
    log_info "서비스 탐지 결과를 기록했습니다" "detect" "$(json_kv path "$SERVICE_LOG")"
else
    : > "$SERVICE_LOG"
    log_warn "탐지된 서비스가 없어 service_paths.log를 비웠습니다" "detect"
fi
