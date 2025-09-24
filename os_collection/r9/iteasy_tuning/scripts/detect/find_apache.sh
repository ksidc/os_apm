#!/bin/bash

# find_apache.sh
# Apache 실행 경로, MPM 설정 파일, 동작 여부, MPM 모듈 탐지
# 수정: 컴파일 설치와 패키지 설치의 설정 파일 경로 명시, 모듈 경로 충돌 방지, PID 기반 탐지 간소화, 경로 정규화
# 추가 수정: 실행 중인 프로세스(/proc/$pid/exe) 기반으로 비표준 경로(/usr/local/apache/bin/httpd) 우선 탐지
# 환경: Rocky Linux 9, Apache 2.4 (패키지 및 컴파일 설치)

SCRIPTS_DIR="/usr/local/src/iteasy_tuning/scripts"
if [ ! -f "$SCRIPTS_DIR/common.sh" ]; then
    log_debug "오류: 공통 스크립트($SCRIPTS_DIR/common.sh)가 존재하지 않습니다."
    exit 1
fi
source "$SCRIPTS_DIR/common.sh"

log_debug "find_apache.sh 시작"

APACHE_BINARY=""
APACHE_MPM_CONF=""
APACHE_MPM=""
APACHE_RUNNING=0
APACHE_SERVICE=""
MULTIPLE_APACHE_FOUND=0
APACHE_BINARY_LIST=""
declare -A APACHE_RUNNING_STATUS
declare -A APACHE_MPM_STATUS
declare -A APACHE_MPM_CONF_PATHS
declare -A APACHE_CONFIG_PATHS

# 설치 유형 판단 함수
is_package_install() {
    local bin="$1"
    if [[ "$bin" == /usr/sbin/httpd || "$bin" == /usr/bin/httpd || "$bin" == /usr/sbin/apache2 || "$bin" == /usr/bin/apache2 ]]; then
        echo "package"
    else
        echo "compiled"
    fi
}

# 패키지 설치 MPM 설정 파일 탐지
check_package_mpm_conf() {
    local mpm_conf=""
    if [ -f "/etc/httpd/conf.modules.d/00-mpm.conf" ]; then
        mpm_conf="/etc/httpd/conf.modules.d/00-mpm.conf"
        log_debug "패키지 설치 관례 MPM conf 발견: $mpm_conf"
    elif [ -f "/etc/httpd/conf/extra/httpd-mpm.conf" ]; then
        mpm_conf="/etc/httpd/conf/extra/httpd-mpm.conf"
        log_debug "패키지 설치 추가 관례 MPM conf 발견: $mpm_conf"
    else
        for dir in "/etc/httpd/conf.modules.d" "/etc/httpd/conf/extra" "/etc/apache2/mods-available" "/etc/apache2/mods-enabled"; do
            mpm_conf=$(find "$dir" -type f -name "*mpm*.conf" 2>/dev/null | head -1)
            if [ -n "$mpm_conf" ]; then
                log_debug "OS별 MPM 디렉터리에서 발견: $mpm_conf"
                break
            fi
        done
    fi
    echo "$(realpath "$mpm_conf" 2>/dev/null || echo "$mpm_conf")"
}

# 컴파일 설치 설정 파일 탐지
check_compiled_config() {
    local bin="$1"
    local prefix=$(dirname "$(dirname "$bin")")
    local config_file="$prefix/conf/httpd.conf"
    if [ -f "$config_file" ]; then
        echo "$(realpath "$config_file" 2>/dev/null || echo "$config_file")"
    else
        config_file=$(find "$prefix/conf" -maxdepth 1 -type f -name "httpd.conf" 2>/dev/null | head -1)
        echo "$(realpath "$config_file" 2>/dev/null || echo "$config_file")"
    fi
}

log_debug "Apache 탐지 시작"

# 실행 중인 프로세스 기반 바이너리 탐지
APACHE_PIDS=($(find_pids "Apache" "[h]ttpd|[a]pache2"))
APACHE_BINS=()
declare -A BIN_PID_MAP
for pid in "${APACHE_PIDS[@]}"; do
    proc_bin=$(realpath "/proc/$pid/exe" 2>/dev/null)
    if [ -n "$proc_bin" ] && [ -x "$proc_bin" ]; then
        if [[ ! " ${APACHE_BINS[*]} " =~ " $proc_bin " ]]; then
            APACHE_BINS+=("$proc_bin")
            BIN_PID_MAP["$proc_bin"]="$pid"
            log_debug "Apache PID $pid, 바이너리: $proc_bin"
        fi
    fi
done

# 실행 중인 프로세스가 없으면 기본 경로 탐색
if [ ${#APACHE_BINS[@]} -eq 0 ]; then
    APACHE_BINS=($(find_binaries "Apache" "httpd apache2" "" "[h]ttpd|[a]pache2"))
    log_debug "실행 중인 Apache 프로세스 없음, 기본 경로에서 탐색: ${APACHE_BINS[*]}"
fi

if [ ${#APACHE_BINS[@]} -gt 1 ]; then
    MULTIPLE_APACHE_FOUND=${#APACHE_BINS[@]}
    log_debug "Apache: 다중 설치 발견 (${MULTIPLE_APACHE_FOUND}개)"
    APACHE_BINARY_LIST=$(printf "%s;" "${APACHE_BINS[@]}")
    for i in "${!APACHE_BINS[@]}"; do
        bin=$(realpath "${APACHE_BINS[$i]}" 2>/dev/null)
        APACHE_MPM_STATUS[$i]=$("$bin" -V 2>/dev/null | grep -i "Server MPM" | awk '{print $3}' | tr '[:upper:]' '[:lower:]' || echo "unknown")
        log_debug "Apache 인스턴스 $((i+1)): 바이너리=$bin, MPM=${APACHE_MPM_STATUS[$i]}"
        APACHE_RUNNING_STATUS[$i]=0
        mpm_conf=""
        config_file=""
        install_type=$(is_package_install "$bin")
        log_debug "인스턴스 $((i+1)) 설치 유형: $install_type"

        for pid in "${APACHE_PIDS[@]}"; do
            proc_bin=$(realpath "/proc/$pid/exe" 2>/dev/null)
            log_debug "Apache PID $pid, proc_bin=$proc_bin, 비교 대상=$bin"
            if [ "$proc_bin" = "$bin" ]; then
                APACHE_RUNNING_STATUS[$i]=1
                APACHE_RUNNING=1
                log_debug "Apache 인스턴스 $((i+1)) 실행 중 (PID: $pid)"
                # PID 기반 MPM 및 설정 파일 탐지
                cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)
                conf_file=$(echo "$cmdline" | grep -oP '(?<=-f\s)\S+' || echo "")
                if [ -n "$conf_file" ] && [ -f "$conf_file" ]; then
                    conf_dir=$(dirname "$conf_file")
                    if [ "$install_type" = "compiled" ]; then
                        prefix=$(dirname "$(dirname "$bin")")
                        mpm_conf="$prefix/conf/extra/httpd-mpm.conf"
                        config_file="$prefix/conf/httpd.conf"
                        if [ -f "$mpm_conf" ]; then
                            mpm_conf=$(realpath "$mpm_conf" 2>/dev/null || echo "$mpm_conf")
                            log_debug "컴파일 설치 MPM conf 발견: $mpm_conf (prefix=$prefix)"
                        else
                            mpm_conf=$(find "$prefix/conf" -maxdepth 2 -type f -name "*mpm*.conf" 2>/dev/null | head -1)
                            mpm_conf=$(realpath "$mpm_conf" 2>/dev/null || echo "$mpm_conf")
                            log_debug "컴파일 설치 MPM conf (find): $mpm_conf (prefix=$prefix)"
                        fi
                        if [ -f "$config_file" ]; then
                            config_file=$(realpath "$config_file" 2>/dev/null || echo "$config_file")
                            log_debug "컴파일 설치 설정 파일 발견: $config_file (prefix=$prefix)"
                        fi
                    else
                        mpm_conf=$(check_package_mpm_conf)
                        config_file="/etc/httpd/conf/httpd.conf"
                        log_debug "패키지 설치 MPM conf: $mpm_conf, 설정 파일: $config_file"
                    fi
                fi
                break
            fi
        done

        # PID 기반 탐지 실패 시 디렉터리 기반 탐지
        if [ -z "$mpm_conf" ] || [ ! -f "$mpm_conf" ]; then
            if [ "$install_type" = "compiled" ]; then
                prefix=$(dirname "$(dirname "$bin")")
                mpm_conf="$prefix/conf/extra/httpd-mpm.conf"
                config_file="$prefix/conf/httpd.conf"
                if [ -f "$mpm_conf" ]; then
                    mpm_conf=$(realpath "$mpm_conf" 2>/dev/null || echo "$mpm_conf")
                    log_debug "컴파일 설치 MPM conf 발견: $mpm_conf (prefix=$prefix)"
                else
                    mpm_conf=$(find "$prefix/conf" -maxdepth 2 -type f -name "*mpm*.conf" 2>/dev/null | head -1)
                    mpm_conf=$(realpath "$mpm_conf" 2>/dev/null || echo "$mpm_conf")
                    log_debug "컴파일 설치 MPM conf (find): $mpm_conf (prefix=$prefix)"
                fi
                if [ -f "$config_file" ]; then
                    config_file=$(realpath "$config_file" 2>/dev/null || echo "$config_file")
                    log_debug "컴파일 설치 설정 파일 발견: $config_file (prefix=$prefix)"
                fi
            else
                mpm_conf=$(check_package_mpm_conf)
                config_file="/etc/httpd/conf/httpd.conf"
                log_debug "패키지 설치 MPM conf: $mpm_conf, 설정 파일: $config_file"
            fi
        fi

        APACHE_MPM_CONF_PATHS[$i]=$([ -n "$mpm_conf" ] && [ -f "$mpm_conf" ] && echo "$mpm_conf" || echo "NOT_FOUND")
        APACHE_CONFIG_PATHS[$i]=$([ -n "$config_file" ] && [ -f "$config_file" ] && echo "$config_file" || echo "NOT_FOUND")
        log_debug "최종 MPM conf: ${APACHE_MPM_CONF_PATHS[$i]}, 설정 파일: ${APACHE_CONFIG_PATHS[$i]} (인스턴스 $((i+1)))"
    done
    APACHE_BINARY="${APACHE_BINS[0]}"
    APACHE_MPM="${APACHE_MPM_STATUS[0]}"
    APACHE_MPM_CONF="${APACHE_MPM_CONF_PATHS[0]}"
    log_debug "첫 번째 Apache 바이너리 선택: $APACHE_BINARY, MPM: $APACHE_MPM, MPM conf: $APACHE_MPM_CONF"
elif [ ${#APACHE_BINS[@]} -eq 1 ]; then
    APACHE_BINARY="${APACHE_BINS[0]}"
    APACHE_MPM=$("$APACHE_BINARY" -V 2>/dev/null | grep -i "Server MPM" | awk '{print $3}' | tr '[:upper:]' '[:lower:]' || echo "prefork")
    APACHE_RUNNING_STATUS[0]=0
    bin=$(realpath "${APACHE_BINS[0]}" 2>/dev/null)
    log_debug "Apache 바이너리: $bin, MPM: $APACHE_MPM"
    install_type=$(is_package_install "$bin")
    log_debug "단일 인스턴스 설치 유형: $install_type"

    for pid in "${APACHE_PIDS[@]}"; do
        proc_bin=$(realpath "/proc/$pid/exe" 2>/dev/null)
        log_debug "Apache PID $pid, proc_bin=$proc_bin, 비교 대상=$bin"
        if [ "$proc_bin" = "$bin" ]; then
            APACHE_RUNNING_STATUS[0]=1
            APACHE_RUNNING=1
            log_debug "Apache 단일 인스턴스 실행 중 (PID: $pid)"
            # PID 기반 MPM 및 설정 파일 탐지
            cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)
            conf_file=$(echo "$cmdline" | grep -oP '(?<=-f\s)\S+' || echo "")
            if [ -n "$conf_file" ] && [ -f "$conf_file" ]; then
                conf_dir=$(dirname "$conf_file")
                if [ "$install_type" = "compiled" ]; then
                    prefix=$(dirname "$(dirname "$bin")")
                    mpm_conf="$prefix/conf/extra/httpd-mpm.conf"
                    config_file="$prefix/conf/httpd.conf"
                    if [ -f "$mpm_conf" ]; then
                        mpm_conf=$(realpath "$mpm_conf" 2>/dev/null || echo "$mpm_conf")
                        log_debug "컴파일 설치 MPM conf 발견: $mpm_conf (prefix=$prefix)"
                    else
                        mpm_conf=$(find "$prefix/conf" -maxdepth 2 -type f -name "*mpm*.conf" 2>/dev/null | head -1)
                        mpm_conf=$(realpath "$mpm_conf" 2>/dev/null || echo "$mpm_conf")
                        log_debug "컴파일 설치 MPM conf (find): $mpm_conf (prefix=$prefix)"
                    fi
                    if [ -f "$config_file" ]; then
                        config_file=$(realpath "$config_file" 2>/dev/null || echo "$config_file")
                        log_debug "컴파일 설치 설정 파일 발견: $config_file (prefix=$prefix)"
                    fi
                else
                    mpm_conf=$(check_package_mpm_conf)
                    config_file="/etc/httpd/conf/httpd.conf"
                    log_debug "패키지 설치 MPM conf: $mpm_conf, 설정 파일: $config_file"
                fi
            fi
            break
        fi
    done

    # PID 기반 탐지 실패 시 디렉터리 기반 탐지
    if [ -z "$mpm_conf" ] || [ ! -f "$mpm_conf" ]; then
        if [ "$install_type" = "compiled" ]; then
            prefix=$(dirname "$(dirname "$bin")")
            mpm_conf="$prefix/conf/extra/httpd-mpm.conf"
            config_file="$prefix/conf/httpd.conf"
            if [ -f "$mpm_conf" ]; then
                mpm_conf=$(realpath "$mpm_conf" 2>/dev/null || echo "$mpm_conf")
                log_debug "컴파일 설치 MPM conf 발견: $mpm_conf (prefix=$prefix)"
            else
                mpm_conf=$(find "$prefix/conf" -maxdepth 2 -type f -name "*mpm*.conf" 2>/dev/null | head -1)
                mpm_conf=$(realpath "$mpm_conf" 2>/dev/null || echo "$mpm_conf")
                log_debug "컴파일 설치 MPM conf (find): $mpm_conf (prefix=$prefix)"
            fi
            if [ -f "$config_file" ]; then
                config_file=$(realpath "$config_file" 2>/dev/null || echo "$config_file")
                log_debug "컴파일 설치 설정 파일 발견: $config_file (prefix=$prefix)"
            fi
        else
            mpm_conf=$(check_package_mpm_conf)
            config_file="/etc/httpd/conf/httpd.conf"
            log_debug "패키지 설치 MPM conf: $mpm_conf, 설정 파일: $config_file"
        fi
    fi

    APACHE_MPM_CONF=$([ -n "$mpm_conf" ] && [ -f "$mpm_conf" ] && echo "$mpm_conf" || echo "NOT_FOUND")
    APACHE_CONFIG_PATHS[0]=$([ -n "$config_file" ] && [ -f "$config_file" ] && echo "$config_file" || echo "NOT_FOUND")
    log_debug "최종 MPM conf: $APACHE_MPM_CONF, 설정 파일: ${APACHE_CONFIG_PATHS[0]} (단일 인스턴스)"
fi

# 서비스 상태 확인
if [ -n "$APACHE_BINARY" ]; then
    APACHE_PIDS=($(find_pids "Apache" "[h]ttpd|[a]pache2"))
    APACHE_SERVICE=$(check_service_status "Apache" "httpd apache2" "$APACHE_BINARY" APACHE_PIDS[@] "[h]ttpd|[a]pache2")
    if [ -n "$APACHE_SERVICE" ] || [ ${#APACHE_PIDS[@]} -gt 0 ]; then
        APACHE_RUNNING=1
        APACHE_RUNNING_STATUS[0]=1
    fi
    log_debug "Apache 서비스: $APACHE_SERVICE, 실행 여부: $APACHE_RUNNING, MPM: $APACHE_MPM, MPM conf: $APACHE_MPM_CONF"
fi

# 버전 확인
if [ -n "$APACHE_BINARY" ]; then
    APACHE_VERSION_RAW=$("$APACHE_BINARY" -V 2>/dev/null | grep -i "Server version" || echo "")
    APACHE_VERSION=$(echo "$APACHE_VERSION_RAW" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?' || echo "")
    log_debug "Apache 버전 원본: $APACHE_VERSION_RAW, 파싱된 버전: $APACHE_VERSION"
fi

# 결과 출력
OUTPUT="# Apache\n"
for i in "${!APACHE_BINS[@]}"; do
    bin="${APACHE_BINS[$i]}"
    idx=$((i+1))
    mpm_conf="${APACHE_MPM_CONF_PATHS[$i]}"
    config_file="${APACHE_CONFIG_PATHS[$i]}"
    if [ -z "$mpm_conf" ] || [ ! -f "$mpm_conf" ] || [ "$mpm_conf" = "NOT_FOUND" ]; then
        install_type=$(is_package_install "$bin")
        if [ "$install_type" = "compiled" ]; then
            prefix=$(dirname "$(dirname "$bin")")
            mpm_conf="$prefix/conf/extra/httpd-mpm.conf"
            config_file="$prefix/conf/httpd.conf"
            if [ -f "$mpm_conf" ]; then
                mpm_conf=$(realpath "$mpm_conf" 2>/dev/null || echo "$mpm_conf")
                log_debug "컴파일 설치 MPM conf 발견 (최종): $mpm_conf (prefix=$prefix)"
            else
                mpm_conf=$(find "$prefix/conf" -maxdepth 2 -type f -name "*mpm*.conf" 2>/dev/null | head -1)
                mpm_conf=$(realpath "$mpm_conf" 2>/dev/null || echo "$mpm_conf")
                log_debug "컴파일 설치 MPM conf (find, 최종): $mpm_conf (prefix=$prefix)"
            fi
            if [ -f "$config_file" ]; then
                config_file=$(realpath "$config_file" 2>/dev/null || echo "$config_file")
                log_debug "컴파일 설치 설정 파일 발견 (최종): $config_file (prefix=$prefix)"
            fi
        else
            mpm_conf=$(check_package_mpm_conf)
            config_file="/etc/httpd/conf/httpd.conf"
            log_debug "패키지 설치 MPM conf (최종): $mpm_conf, 설정 파일: $config_file"
        fi
        mpm_conf=$([ -n "$mpm_conf" ] && [ -f "$mpm_conf" ] && echo "$mpm_conf" || echo "NOT_FOUND")
        config_file=$([ -n "$config_file" ] && [ -f "$config_file" ] && echo "$config_file" || echo "NOT_FOUND")
        log_debug "최종 MPM conf: $mpm_conf, 설정 파일: $config_file (인스턴스 $idx)"
    fi

    mpm=$("$bin" -V 2>/dev/null | grep -i "Server MPM" | awk '{print $3}' | tr '[:upper:]' '[:lower:]' || echo "unknown")
    running=0
    for pid in "${APACHE_PIDS[@]}"; do
        proc_bin=$(realpath "/proc/$pid/exe" 2>/dev/null)
        [ "$proc_bin" = "$(realpath "$bin")" ] && running=1 && break
    done

    OUTPUT+="APACHE_BINARY_${idx}=$bin\n"
    OUTPUT+="APACHE_MPM_CONF_${idx}=$mpm_conf\n"
    OUTPUT+="APACHE_MPM_${idx}=$mpm\n"
    OUTPUT+="APACHE_RUNNING_${idx}=$running\n"
    OUTPUT+="APACHE_CONFIG_${idx}=$config_file\n"
done
OUTPUT+="APACHE_SERVICE=\n"
OUTPUT+="MULTIPLE_APACHE_FOUND=${#APACHE_BINS[@]}\n"
OUTPUT+="APACHE_BINARY_LIST=$(printf "%s;" "${APACHE_BINS[@]}")\n"
echo -e "$OUTPUT"
