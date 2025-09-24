#!/bin/bash

# find_mysql_mariadb.sh
# MySQL 및 MariaDB 실행 경로, 설정 파일 탐지 (ps -ef로 간단한 프로세스 확인)
# 수정: ps -ef | grep으로 프로세스 실행 상태 확인 간소화

BASE_DIR="/usr/local/src/iteasy_tuning"
SCRIPTS_DIR="$BASE_DIR/scripts"
LOG_DIR="$BASE_DIR/logs"

source "$SCRIPTS_DIR/common.sh"
setup_logging

# 변수 초기화
declare -A SERVICES=(
    ["mysql"]=""
    ["mariadb"]=""
)
declare -A MULTIPLE_FOUND=(
    ["mysql"]=0
    ["mariadb"]=0
)
MYSQL_CONF=""
MYSQL_RUNNING=0
MYSQL_SERVICE=""
MYSQL_BINARY_LIST=""
MARIADB_CONF=""
MARIADB_RUNNING=0
MARIADB_SERVICE=""
MARIADB_BINARY_LIST=""
declare -A MYSQL_RUNNING_STATUS MARIADB_RUNNING_STATUS
declare -A MYSQL_CONF_FILES MARIADB_CONF_FILES

# 간단한 프로세스 실행 확인 함수
check_process_running() {
    local service_name="$1"  # "mysql" 또는 "mariadb"
    
    log_debug "$service_name: ps -ef로 프로세스 실행 확인"
    
    local ps_result
    if [ "$service_name" = "mysql" ]; then
        ps_result=$(ps -ef | grep -E "(mysqld|mysql)" | grep -v grep | grep -v "$0")
    else
        ps_result=$(ps -ef | grep -E "(mariadbd|mariadb)" | grep -v grep | grep -v "$0")
    fi
    
    if [ -n "$ps_result" ]; then
        log_debug "$service_name: 실행 중인 프로세스 발견"
        log_debug "$ps_result"
        return 0
    else
        log_debug "$service_name: 실행 중인 프로세스 없음"
        return 1
    fi
}

# ps -ef에서 --defaults-file 옵션 파싱
find_defaults_file_from_ps() {
    local service_name="$1"  # "mysql" 또는 "mariadb"
    
    log_debug "$service_name: ps -ef에서 --defaults-file 옵션 탐지 시작"
    
    # ps -ef에서 mysql/mariadb 프로세스 찾기
    local ps_output
    if [ "$service_name" = "mysql" ]; then
        ps_output=$(ps -ef | grep -E "(mysqld|mysql)" | grep -v grep | grep -v "$0")
    else
        ps_output=$(ps -ef | grep -E "(mariadbd|mariadb)" | grep -v grep | grep -v "$0")
    fi
    
    if [ -z "$ps_output" ]; then
        log_debug "$service_name: ps -ef에서 실행 중인 프로세스 없음"
        return 1
    fi
    
    # --defaults-file 옵션 추출
    local defaults_file
    defaults_file=$(echo "$ps_output" | grep -oE '\--defaults-file[[:space:]]*=[[:space:]]*[^[:space:]]+' | head -1 | sed 's/--defaults-file[[:space:]]*=[[:space:]]*//')
    
    if [ -n "$defaults_file" ] && [ -f "$defaults_file" ]; then
        log_debug "$service_name: ps -ef에서 --defaults-file 발견: $defaults_file"
        echo "$defaults_file"
        return 0
    else
        log_debug "$service_name: ps -ef에서 유효한 --defaults-file 없음"
        return 1
    fi
}

# mysql --help로 기본 설정 파일 찾기
find_mysql_help_defaults() {
    local mysql_client="$1"  # mysql 클라이언트 경로
    
    if [ ! -x "$mysql_client" ]; then
        log_debug "mysql 클라이언트 없음: $mysql_client"
        return 1
    fi
    
    log_debug "mysql --help로 Default options 탐지: $mysql_client"
    
    local default_options
    default_options=$("$mysql_client" --help 2>/dev/null | grep -A 1 "Default options" | tail -n 1 | awk '{for(i=1;i<=NF;i++) print $i}')
    
    for default_conf in $default_options; do
        if [ -f "$default_conf" ]; then
            log_debug "mysql --help에서 발견된 설정 파일: $default_conf"
            echo "$default_conf"
            return 0
        fi
    done
    
    log_debug "mysql --help에서 유효한 설정 파일 없음"
    return 1
}

# 설정 파일 탐지 (통합 함수)
detect_config_file() {
    local service_name="$1"  # "mysql" 또는 "mariadb"
    local config_var=""
    
    log_debug "$service_name: 설정 파일 탐지 시작"
    
    # 1. mysql --help의 Default options 시도
    local mysql_clients=("/usr/bin/mysql" "/usr/local/bin/mysql" "/opt/*/bin/mysql")
    for mysql_client in "${mysql_clients[@]}"; do
        if [ -x "$mysql_client" ]; then
            config_var=$(find_mysql_help_defaults "$mysql_client")
            if [ -n "$config_var" ]; then
                log_debug "$service_name: mysql --help로 설정 파일 발견: $config_var"
                echo "$config_var"
                return 0
            fi
        fi
    done
    
    # 2. ps -ef에서 --defaults-file 옵션 시도
    config_var=$(find_defaults_file_from_ps "$service_name")
    if [ -n "$config_var" ]; then
        log_debug "$service_name: ps -ef로 설정 파일 발견: $config_var"
        echo "$config_var"
        return 0
    fi
    
    # 3. find 명령으로 datadir 포함 *.cnf 탐지
    config_var=$(find /etc /usr/local /opt /usr/libexec -type f -name "*.cnf" -exec grep -l "^[[:space:]]*datadir[[:space:]]*=" {} \; 2>/dev/null | head -1)
    if [ -n "$config_var" ] && [ -f "$config_var" ]; then
        log_debug "$service_name: find로 datadir 포함 설정 파일 발견: $config_var"
        echo "$config_var"
        return 0
    fi
    
    log_debug "$service_name: 유효한 설정 파일 없음"
    return 1
}

# 포함된 설정 파일에서 datadir, pid-file, socket 확인
check_included_conf_files() {
    local conf_file="$1"
    local settings=("datadir" "pid-file" "socket")
    local included_files=()

    # !include 및 !includedir 지시어 파싱
    if [ -f "$conf_file" ]; then
        included_files+=($(grep -E '^[[:space:]]*!include[[:space:]]+' "$conf_file" | awk '{print $2}' | xargs))
        local included_dirs=($(grep -E '^[[:space:]]*!includedir[[:space:]]+' "$conf_file" | awk '{print $2}' | xargs))
        for dir in "${included_dirs[@]}"; do
            if [ -d "$dir" ]; then
                included_files+=($(find "$dir" -type f -name "*.cnf" 2>/dev/null))
            fi
        done
    fi

    # 포함된 파일에서 datadir, pid-file, socket 확인
    for file in "$conf_file" "${included_files[@]}"; do
        if [ -f "$file" ]; then
            for setting in "${settings[@]}"; do
                if grep -qE "^[[:space:]]*$setting[[:space:]]*=" "$file"; then
                    echo "$file"
                    return 0
                fi
            done
        fi
    done
    # 유효한 설정이 없으면 원본 파일 반환
    if [ -f "$conf_file" ]; then
        echo "$conf_file"
        return 0
    fi
    return 1
}

# 실행 중인 바이너리 탐지 (간소화)
detect_running_mysql_like_binary() {
    local proc_name="$1"
    local label="$2"

    # ps -ef로 프로세스 실행 확인
    if check_process_running "$label"; then
        # 실행 중이면 첫 번째 PID의 실행 파일 경로 가져오기
        local pids
        if [ "$label" = "mysql" ]; then
            pids=($(ps -ef | grep -E "(mysqld|mysql)" | grep -v grep | grep -v "$0" | awk '{print $2}'))
        else
            pids=($(ps -ef | grep -E "(mariadbd|mariadb)" | grep -v grep | grep -v "$0" | awk '{print $2}'))
        fi
        
        if [ ${#pids[@]} -gt 0 ]; then
            local exe_path=$(readlink -f "/proc/${pids[0]}/exe" 2>/dev/null)
            if [ -x "$exe_path" ]; then
                SERVICES["$label"]="$exe_path"
                eval "${label^^}_RUNNING=1"
                log_debug "$label 실행 중: $exe_path (PID: ${pids[0]})"

                # 설정 파일 탐지
                local detected_conf
                detected_conf=$(detect_config_file "$label")
                if [ -n "$detected_conf" ]; then
                    local valid_conf
                    valid_conf=$(check_included_conf_files "$detected_conf")
                    if [ -n "$valid_conf" ]; then
                        eval "${label^^}_CONF=\"$valid_conf\""
                        log_debug "$label conf: $valid_conf (탐지된 설정 파일)"
                    else
                        eval "${label^^}_CONF=\"$detected_conf\""
                        log_debug "$label conf: $detected_conf (기본 설정 파일)"
                    fi
                else
                    eval "${label^^}_CONF=\"\""
                    log_debug "$label conf: 유효한 설정 파일 없음"
                fi
                return 0
            fi
        fi
    fi
    
    log_debug "$label: 실행 중인 프로세스 없음"
    return 1
}

# 실행 중인 바이너리 탐지 우선
detect_running_mysql_like_binary "mysqld" "mysql"
detect_running_mysql_like_binary "mariadbd" "mariadb"

# 실행 중이 아니면 경로 기반 스캔
if [ -z "${SERVICES["mysql"]}" ]; then
    for dir in /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin /opt/*/bin /usr/libexec; do
        bin="$dir/mysqld"
        if [ -x "$bin" ]; then
            SERVICES["mysql"]="$bin"
            MYSQL_RUNNING=0
            log_debug "mysqld 발견: $bin"

            # 설정 파일 탐지
            detected_conf=$(detect_config_file "mysql")
            if [ -n "$detected_conf" ]; then
                valid_conf=$(check_included_conf_files "$detected_conf")
                if [ -n "$valid_conf" ]; then
                    MYSQL_CONF="$valid_conf"
                    log_debug "MySQL conf: $valid_conf (탐지된 설정 파일)"
                else
                    MYSQL_CONF="$detected_conf"
                    log_debug "MySQL conf: $detected_conf (기본 설정 파일)"
                fi
            else
                MYSQL_CONF=""
                log_debug "MySQL conf: 유효한 설정 파일 없음"
            fi
            break
        fi
    done
fi

if [ -z "${SERVICES["mariadb"]}" ]; then
    for dir in /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin /opt/*/bin /usr/libexec; do
        bin="$dir/mariadbd"
        if [ -x "$bin" ]; then
            SERVICES["mariadb"]="$bin"
            MARIADB_RUNNING=0
            log_debug "mariadbd 발견: $bin"

            # 설정 파일 탐지
            detected_conf=$(detect_config_file "mariadb")
            if [ -n "$detected_conf" ]; then
                valid_conf=$(check_included_conf_files "$detected_conf")
                if [ -n "$valid_conf" ]; then
                    MARIADB_CONF="$valid_conf"
                    log_debug "MariaDB conf: $valid_conf (탐지된 설정 파일)"
                else
                    MARIADB_CONF="$detected_conf"
                    log_debug "MariaDB conf: $detected_conf (기본 설정 파일)"
                fi
            else
                MARIADB_CONF=""
                log_debug "MariaDB conf: 유효한 설정 파일 없음"
            fi
            break
        fi
    done
fi

# MySQL 다중 인스턴스 탐지
log_debug "MySQL 탐지 시작"
MYSQL_BINS=($(find_binaries "MySQL" "mysqld" "mysql" "mysqld" "/usr/bin /usr/sbin /usr/local/bin /usr/local/sbin /opt/*/bin /usr/libexec"))
if [ ${#MYSQL_BINS[@]} -gt 1 ]; then
    MULTIPLE_FOUND["mysql"]=${#MYSQL_BINS[@]}
    log_debug "MySQL: 다중 설치 발견 (${MULTIPLE_FOUND["mysql"]}개)"
    MYSQL_BINARY_LIST=$(printf "%s;" "${MYSQL_BINS[@]}" | sed 's/;$//')
    for i in "${!MYSQL_BINS[@]}"; do
        bin=$(realpath "${MYSQL_BINS[$i]}" 2>/dev/null)
        MYSQL_RUNNING_STATUS[$i]=0
        MYSQL_CONF_FILES[$i]=""

        detected_conf=$(detect_config_file "mysql")
        if [ -n "$detected_conf" ]; then
            valid_conf=$(check_included_conf_files "$detected_conf")
            if [ -n "$valid_conf" ]; then
                MYSQL_CONF_FILES[$i]="$valid_conf"
                log_debug "MySQL 인스턴스 $((i+1)): $valid_conf (탐지된 설정 파일)"
            else
                MYSQL_CONF_FILES[$i]="$detected_conf"
                log_debug "MySQL 인스턴스 $((i+1)): $detected_conf (기본 설정 파일)"
            fi
        else
            MYSQL_CONF_FILES[$i]=""
            log_debug "MySQL 인스턴스 $((i+1)): 유효한 설정 파일 없음"
        fi
        
        log_debug "MySQL 인스턴스 $((i+1)): 바이너리=$bin, 설정 파일=${MYSQL_CONF_FILES[$i]}"
        
        # ps -ef로 간단하게 실행 상태 확인
        if check_process_running "mysql"; then
            MYSQL_RUNNING_STATUS[$i]=1
            MYSQL_RUNNING=1
            log_debug "MySQL 인스턴스 $((i+1)) 실행 중"
        else
            MYSQL_RUNNING_STATUS[$i]=0
            log_debug "MySQL 인스턴스 $((i+1)) 실행 중 아님"
        fi
    done
    SERVICES["mysql"]="${MYSQL_BINS[0]}"
    MYSQL_CONF="${MYSQL_CONF_FILES[0]}"
    log_debug "첫 번째 MySQL 바이너리 선택: ${MYSQL_BINS[0]}, 설정 파일: ${MYSQL_CONF_FILES[0]}"
elif [ ${#MYSQL_BINS[@]} -eq 1 ]; then
    SERVICES["mysql"]="${MYSQL_BINS[0]}"
    
    detected_conf=$(detect_config_file "mysql")
    if [ -n "$detected_conf" ]; then
        valid_conf=$(check_included_conf_files "$detected_conf")
        if [ -n "$valid_conf" ]; then
            MYSQL_CONF="$valid_conf"
            log_debug "MySQL conf: $valid_conf (탐지된 설정 파일)"
        else
            MYSQL_CONF="$detected_conf"
            log_debug "MySQL conf: $detected_conf (기본 설정 파일)"
        fi
    else
        MYSQL_CONF=""
        log_debug "MySQL conf: 유효한 설정 파일 없음"
    fi
    
    MYSQL_CONF_FILES[0]="$MYSQL_CONF"
    MYSQL_RUNNING_STATUS[0]=0
    
    # ps -ef로 간단하게 실행 상태 확인
    if check_process_running "mysql"; then
        MYSQL_RUNNING_STATUS[0]=1
        MYSQL_RUNNING=1
        log_debug "MySQL 단일 인스턴스 실행 중"
    else
        MYSQL_RUNNING_STATUS[0]=0
        log_debug "MySQL 단일 인스턴스 실행 중 아님"
    fi
    log_debug "단일 MySQL 바이너리 선택: ${MYSQL_BINS[0]}, 설정 파일: $MYSQL_CONF"
fi

# MariaDB 다중 인스턴스 탐지
log_debug "MariaDB 탐지 시작"
MARIADB_BINS=($(find_binaries "MariaDB" "mariadbd" "MariaDB" "mariadbd" "/usr/bin /usr/sbin /usr/local/bin /usr/local/sbin /opt/*/bin /usr/libexec"))
if [ ${#MARIADB_BINS[@]} -gt 1 ]; then
    MULTIPLE_FOUND["mariadb"]=${#MARIADB_BINS[@]}
    log_debug "MariaDB: 다중 설치 발견 (${MULTIPLE_FOUND["mariadb"]}개)"
    MARIADB_BINARY_LIST=$(printf "%s;" "${MARIADB_BINS[@]}" | sed 's/;$//')
    for i in "${!MARIADB_BINS[@]}"; do
        bin=$(realpath "${MARIADB_BINS[$i]}" 2>/dev/null)
        MARIADB_RUNNING_STATUS[$i]=0
        MARIADB_CONF_FILES[$i]=""

        detected_conf=$(detect_config_file "mariadb")
        if [ -n "$detected_conf" ]; then
            valid_conf=$(check_included_conf_files "$detected_conf")
            if [ -n "$valid_conf" ]; then
                MARIADB_CONF_FILES[$i]="$valid_conf"
                log_debug "MariaDB 인스턴스 $((i+1)): $valid_conf (탐지된 설정 파일)"
            else
                MARIADB_CONF_FILES[$i]="$detected_conf"
                log_debug "MariaDB 인스턴스 $((i+1)): $detected_conf (기본 설정 파일)"
            fi
        else
            MARIADB_CONF_FILES[$i]=""
            log_debug "MariaDB 인스턴스 $((i+1)): 유효한 설정 파일 없음"
        fi
        
        log_debug "MariaDB 인스턴스 $((i+1)): 바이너리=$bin, 설정 파일=${MARIADB_CONF_FILES[$i]}"
        
        # ps -ef로 간단하게 실행 상태 확인
        if check_process_running "mariadb"; then
            MARIADB_RUNNING_STATUS[$i]=1
            MARIADB_RUNNING=1
            log_debug "MariaDB 인스턴스 $((i+1)) 실행 중"
        else
            MARIADB_RUNNING_STATUS[$i]=0
            log_debug "MariaDB 인스턴스 $((i+1)) 실행 중 아님"
        fi
    done
    SERVICES["mariadb"]="${MARIADB_BINS[0]}"
    MARIADB_CONF="${MARIADB_CONF_FILES[0]}"
    log_debug "첫 번째 MariaDB 바이너리 선택: ${MARIADB_BINS[0]}, 설정 파일: ${MARIADB_CONF_FILES[0]}"
elif [ ${#MARIADB_BINS[@]} -eq 1 ]; then
    SERVICES["mariadb"]="${MARIADB_BINS[0]}"
    
    detected_conf=$(detect_config_file "mariadb")
    if [ -n "$detected_conf" ]; then
        valid_conf=$(check_included_conf_files "$detected_conf")
        if [ -n "$valid_conf" ]; then
            MARIADB_CONF="$valid_conf"
            log_debug "MariaDB conf: $valid_conf (탐지된 설정 파일)"
        else
            MARIADB_CONF="$detected_conf"
            log_debug "MariaDB conf: $detected_conf (기본 설정 파일)"
        fi
    else
        MARIADB_CONF=""
        log_debug "MariaDB conf: 유효한 설정 파일 없음"
    fi
    
    MARIADB_CONF_FILES[0]="$MARIADB_CONF"
    MARIADB_RUNNING_STATUS[0]=0
    
    # ps -ef로 간단하게 실행 상태 확인
    if check_process_running "mariadb"; then
        MARIADB_RUNNING_STATUS[0]=1
        MARIADB_RUNNING=1
        log_debug "MariaDB 단일 인스턴스 실행 중"
    else
        MARIADB_RUNNING_STATUS[0]=0
        log_debug "MariaDB 단일 인스턴스 실행 중 아님"
    fi
    log_debug "단일 MariaDB 바이너리 선택: ${MARIADB_BINS[0]}, 설정 파일: $MARIADB_CONF"
fi

# 서비스 상태 점검 (간소화)
if [ -n "${SERVICES["mysql"]}" ]; then
    if check_process_running "mysql"; then
        MYSQL_RUNNING=1
        MYSQL_RUNNING_STATUS[0]=1
        # 서비스 이름 탐지 (간단한 방법)
        for svc in mysqld mysql mariadb; do
            if systemctl --quiet is-active "$svc" 2>/dev/null; then
                MYSQL_SERVICE="$svc"
                break
            elif [ -f "/etc/init.d/$svc" ] && /etc/init.d/"$svc" status >/dev/null 2>&1; then
                MYSQL_SERVICE="$svc"
                break
            fi
        done
        log_debug "MySQL 서비스: $MYSQL_SERVICE, 실행 중"
    else
        MYSQL_RUNNING=0
        MYSQL_RUNNING_STATUS[0]=0
        log_debug "MySQL 서비스: 실행 중 아님"
    fi
fi

if [ -n "${SERVICES["mariadb"]}" ]; then
    if check_process_running "mariadb"; then
        MARIADB_RUNNING=1
        MARIADB_RUNNING_STATUS[0]=1
        # 서비스 이름 탐지 (간단한 방법)
        for svc in mariadb mysqld mysql; do
            if systemctl --quiet is-active "$svc" 2>/dev/null; then
                MARIADB_SERVICE="$svc"
                break
            elif [ -f "/etc/init.d/$svc" ] && /etc/init.d/"$svc" status >/dev/null 2>&1; then
                MARIADB_SERVICE="$svc"
                break
            fi
        done
        log_debug "MariaDB 서비스: $MARIADB_SERVICE, 실행 중"
    else
        MARIADB_RUNNING=0
        MARIADB_RUNNING_STATUS[0]=0
        log_debug "MariaDB 서비스: 실행 중 아님"
    fi
fi

# 결과 출력
OUTPUT=""
if [ -n "${SERVICES["mysql"]}" ] || [ ${MULTIPLE_FOUND["mysql"]} -gt 0 ]; then
    OUTPUT+="# MySQL\n"
    if [ ${MULTIPLE_FOUND["mysql"]} -gt 1 ]; then
        for i in "${!MYSQL_BINS[@]}"; do
            bin=${MYSQL_BINS[$i]}
            conf="${MYSQL_CONF_FILES[$i]}"
            if [ -z "$conf" ]; then
                conf=""
                log_debug "MySQL 인스턴스 $((i+1)): 유효한 설정 파일 없음"
            fi
            OUTPUT+="MYSQL_BINARY_$((i+1))=$bin\n"
            OUTPUT+="MYSQL_CONF_$((i+1))=$conf\n"
            OUTPUT+="MYSQL_RUNNING_$((i+1))=${MYSQL_RUNNING_STATUS[$i]}\n"
        done
    else
        OUTPUT+="MYSQL_BINARY=${SERVICES["mysql"]}\n"
        OUTPUT+="MYSQL_CONF=$MYSQL_CONF\n"
        OUTPUT+="MYSQL_RUNNING=$MYSQL_RUNNING\n"
    fi
    OUTPUT+="MYSQL_SERVICE=$MYSQL_SERVICE\n"
    OUTPUT+="MULTIPLE_MYSQL_FOUND=${MULTIPLE_FOUND["mysql"]}\n"
    OUTPUT+="MYSQL_BINARY_LIST=$MYSQL_BINARY_LIST\n"
fi
if [ -n "${SERVICES["mariadb"]}" ] || [ ${MULTIPLE_FOUND["mariadb"]} -gt 0 ]; then
    OUTPUT+="# MariaDB\n"
    if [ ${MULTIPLE_FOUND["mariadb"]} -gt 1 ]; then
        for i in "${!MARIADB_BINS[@]}"; do
            bin=${MARIADB_BINS[$i]}
            conf="${MARIADB_CONF_FILES[$i]}"
            if [ -z "$conf" ]; then
                conf=""
                log_debug "MariaDB 인스턴스 $((i+1)): 유효한 설정 파일 없음"
            fi
            OUTPUT+="MARIADB_BINARY_$((i+1))=$bin\n"
            OUTPUT+="MARIADB_CONF_$((i+1))=$conf\n"
            OUTPUT+="MARIADB_RUNNING_$((i+1))=${MARIADB_RUNNING_STATUS[$i]}\n"
        done
    else
        OUTPUT+="MARIADB_BINARY=${SERVICES["mariadb"]}\n"
        OUTPUT+="MARIADB_CONF=$MARIADB_CONF\n"
        OUTPUT+="MARIADB_RUNNING=$MARIADB_RUNNING\n"
    fi
    OUTPUT+="MARIADB_SERVICE=$MARIADB_SERVICE\n"
    OUTPUT+="MULTIPLE_MARIADB_FOUND=${MULTIPLE_FOUND["mariadb"]}\n"
    OUTPUT+="MARIADB_BINARY_LIST=$MARIADB_BINARY_LIST\n"
fi
if [ -n "$OUTPUT" ]; then
    echo -e "${OUTPUT}\n" | sed '/^$/d'
else
    log_debug "MySQL 및 MariaDB 탐지 결과 없음"
    exit 1
fi
