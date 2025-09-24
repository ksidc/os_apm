#!/bin/bash

# check_service_versions.sh
# find_service.sh의 service_paths.log를 읽어 각 서비스(Apache, Nginx, MySQL, MariaDB, Tomcat, PHP-FPM)의 버전 확인
# 결과는 service_versions.log에 저장, 디버깅 로그는 debug.log에 기록
# Tomcat 버전 확인 시 표준 출력 유출 방지
# MySQL/MariaDB: mysqld --version 실패 시 mysql/mariadb 클라이언트로 폴백
# MySQL: 실행 중인 프로세스의 바이너리 기준으로 중복 제거
# 수정: PHP 관련 코드 완전히 제거, PHP-FPM 버전 확인 유지

# 기본 디렉터리 설정
BASE_DIR="/usr/local/src/iteasy_tuning"
LOG_DIR="$BASE_DIR/logs"
SERVICE_LOG="$LOG_DIR/service_paths.log"
VERSION_LOG="$LOG_DIR/service_versions.log"
DEBUG_LOG="$LOG_DIR/debug.log"
SCRIPTS_DIR="$BASE_DIR/scripts"

# 로그 디렉터리 및 파일 생성
mkdir -p "$LOG_DIR" || { echo "오류: 로그 디렉터리($LOG_DIR) 생성 실패" >&2; exit 1; }
chmod 700 "$LOG_DIR" 2>/dev/null
touch "$VERSION_LOG" || { echo "오류: 버전 로그 파일($VERSION_LOG) 생성 실패" >&2; exit 1; }
chmod 600 "$VERSION_LOG" 2>/dev/null
touch "$DEBUG_LOG" || { echo "오류: 디버깅 로그 파일($DEBUG_LOG) 생성 실패" >&2; exit 1; }
chmod 600 "$DEBUG_LOG" 2>/dev/null

# 디버깅 로그 함수
log_debug() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" >> "$DEBUG_LOG"
}

log_debug "BASE_DIR=$BASE_DIR"
log_debug "service_paths.log 내용: $(cat "$SERVICE_LOG" 2>/dev/null || echo '읽기 실패')"

# 버전 확인 함수
check_version() {
    local service="$1" binary="$2" cmd="$3"
    local version=""
    log_debug "버전 확인 시작: $service, 바이너리: $binary, 명령: $cmd"
    if [ -n "$binary" ] && [ -x "$binary" ]; then
        if [ "$service" = "Tomcat" ]; then
            # Tomcat: ServerInfo.properties에서 우선 확인
            local catalina_base=$(dirname "$(dirname "$binary")")
            if [ -f "$catalina_base/lib/org.apache.catalina.util.ServerInfo.properties" ]; then
                version=$(grep "server.number=" "$catalina_base/lib/org.apache.catalina.util.ServerInfo.properties" | cut -d'=' -f2 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?(-[a-zA-Z0-9]+)?' || echo "")
                log_debug "Tomcat: ServerInfo.properties에서 버전 추출: $version"
            fi
            if [ -z "$version" ]; then
                version=$($cmd 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?(-[a-zA-Z0-9]+)?' || echo "")
                log_debug "Tomcat: $cmd에서 버전 추출: $version"
            fi
        elif [ "$service" = "MySQL" ] || [ "$service" = "MariaDB" ]; then
            version=$($cmd 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?' || echo "")
            if [ -z "$version" ]; then
                version=$(mysql --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?' || mariadb --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?' || echo "")
                log_debug "$service: 클라이언트로 폴백, 버전: $version"
            fi
        else
            version=$($cmd 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?' || echo "")
        fi
        log_debug "$service 버전: $version"
    else
        log_debug "$service 바이너리 실행 불가: $binary"
    fi
    echo "$version"
}

# 버전 및 바이너리 정보 저장
declare -A VERSIONS
declare -A MULTIPLE_VERSIONS
OUTPUT=""

# Apache 버전 확인
log_debug "Apache 버전 확인 시작"
APACHE_BINS=($(grep -E "^APACHE_BINARY(_[0-9]+)?=" "$SERVICE_LOG" | cut -d'=' -f2))
if [ ${#APACHE_BINS[@]} -gt 1 ]; then
    OUTPUT+="# Apache\n"
    for i in "${!APACHE_BINS[@]}"; do
        bin="${APACHE_BINS[$i]}"
        version=$(check_version "Apache" "$bin" "$bin -V")
        MULTIPLE_VERSIONS["apache_$((i+1))"]="$version"
        OUTPUT+="APACHE_VERSION_$((i+1))=$version\n"
        OUTPUT+="APACHE_BINARY_$((i+1))=$bin\n"
        echo "Apache 인스턴스 $((i+1)): $version"
    done
elif [ ${#APACHE_BINS[@]} -eq 1 ]; then
    bin="${APACHE_BINS[0]}"
    version=$(check_version "Apache" "$bin" "$bin -V")
    VERSIONS["apache"]="$version"
    OUTPUT+="# Apache\nAPACHE_VERSION=$version\nAPACHE_BINARY=$bin\n"
    echo "Apache: $version"
fi

# Nginx 버전 확인
log_debug "Nginx 버전 확인 시작"
NGINX_BINS=($(grep -E "^NGINX_BINARY(_[0-9]+)?=" "$SERVICE_LOG" | cut -d'=' -f2))
if [ ${#NGINX_BINS[@]} -gt 1 ]; then
    OUTPUT+="# Nginx\n"
    for i in "${!NGINX_BINS[@]}"; do
        bin="${NGINX_BINS[$i]}"
        version=$(check_version "Nginx" "$bin" "$bin -v")
        MULTIPLE_VERSIONS["nginx_$((i+1))"]="$version"
        OUTPUT+="NGINX_VERSION_$((i+1))=$version\n"
        OUTPUT+="NGINX_BINARY_$((i+1))=$bin\n"
        echo "Nginx 인스턴스 $((i+1)): $version"
    done
elif [ ${#NGINX_BINS[@]} -eq 1 ]; then
    bin="${NGINX_BINS[0]}"
    version=$(check_version "Nginx" "$bin" "$bin -v")
    VERSIONS["nginx"]="$version"
    OUTPUT+="# Nginx\nNGINX_VERSION=$version\nNGINX_BINARY=$bin\n"
    echo "Nginx: $version"
fi

# MySQL 버전 확인
log_debug "MySQL 버전 확인 시작"
MYSQL_BINS=($(grep -E "^MYSQL_BINARY(_[0-9]+)?=" "$SERVICE_LOG" | cut -d'=' -f2 | sort -u))
if [ ${#MYSQL_BINS[@]} -gt 1 ]; then
    OUTPUT+="# MySQL\n"
    for i in "${!MYSQL_BINS[@]}"; do
        bin="${MYSQL_BINS[$i]}"
        version=$(check_version "MySQL" "$bin" "$bin --version")
        MULTIPLE_VERSIONS["mysql_$((i+1))"]="$version"
        OUTPUT+="MYSQL_VERSION_$((i+1))=$version\n"
        OUTPUT+="MYSQL_BINARY_$((i+1))=$bin\n"
        echo "MySQL 인스턴스 $((i+1)): $version"
    done
elif [ ${#MYSQL_BINS[@]} -eq 1 ]; then
    bin="${MYSQL_BINS[0]}"
    version=$(check_version "MySQL" "$bin" "$bin --version")
    VERSIONS["mysql"]="$version"
    OUTPUT+="# MySQL\nMYSQL_VERSION=$version\nMYSQL_BINARY=$bin\n"
    echo "MySQL: $version"
fi

# Tomcat 버전 확인
log_debug "Tomcat 버전 확인 시작"
TOMCAT_BINS=($(grep -E "^TOMCAT_BINARY(_[0-9]+)?=" "$SERVICE_LOG" | cut -d'=' -f2))
if [ ${#TOMCAT_BINS[@]} -gt 1 ]; then
    OUTPUT+="# Tomcat\n"
    for i in "${!TOMCAT_BINS[@]}"; do
        bin="${TOMCAT_BINS[$i]}"
        version=$(check_version "Tomcat" "$bin" "$bin version")
        MULTIPLE_VERSIONS["tomcat_$((i+1))"]="$version"
        OUTPUT+="TOMCAT_VERSION_$((i+1))=$version\n"
        OUTPUT+="TOMCAT_BINARY_$((i+1))=$bin\n"
        echo "Tomcat 인스턴스 $((i+1)): $version"
    done
elif [ ${#TOMCAT_BINS[@]} -eq 1 ]; then
    bin="${TOMCAT_BINS[0]}"
    version=$(check_version "Tomcat" "$bin" "$bin version")
    VERSIONS["tomcat"]="$version"
    OUTPUT+="# Tomcat\nTOMCAT_VERSION=$version\nTOMCAT_BINARY=$bin\n"
    echo "Tomcat: $version"
fi

# PHP-FPM 버전 확인
log_debug "PHP-FPM 버전 확인 시작"
PHP_FPM_BINS=($(grep -E "^PHP_FPM_BINARY(_[0-9]+)?=" "$SERVICE_LOG" | cut -d'=' -f2))
if [ ${#PHP_FPM_BINS[@]} -gt 1 ]; then
    OUTPUT+="# PHP-FPM\n"
    for i in "${!PHP_FPM_BINS[@]}"; do
        bin="${PHP_FPM_BINS[$i]}"
        version=$(check_version "PHP-FPM" "$bin" "$bin --version")
        MULTIPLE_VERSIONS["php-fpm_$((i+1))"]="$version"
        OUTPUT+="PHP_FPM_VERSION_$((i+1))=$version\n"
        OUTPUT+="PHP_FPM_BINARY_$((i+1))=$bin\n"
        echo "PHP-FPM 인스턴스 $((i+1)): $version"
    done
elif [ ${#PHP_FPM_BINS[@]} -eq 1 ]; then
    bin="${PHP_FPM_BINS[0]}"
    version=$(check_version "PHP-FPM" "$bin" "$bin --version")
    VERSIONS["php-fpm"]="$version"
    OUTPUT+="# PHP-FPM\nPHP_FPM_VERSION=$version\nPHP_FPM_BINARY=$bin\n"
    echo "PHP-FPM: $version"
fi

# 로그 파일에 출력
echo -e "$OUTPUT" > "$VERSION_LOG" || { echo "오류: 로그 파일($VERSION_LOG)에 쓰기 실패" >&2 | tee -a "$DEBUG_LOG"; exit 1; }
chmod 600 "$VERSION_LOG" 2>/dev/null
log_debug "로그 파일 생성 완료: $VERSION_LOG"
log_debug "service_versions.log 내용: $(cat "$VERSION_LOG")"
echo "결과가 $VERSION_LOG에 저장되었습니다."
