#!/bin/bash

# get_server_specs.sh
# 서버 자원(메모리, CPU 코어, 디스크 공간) 계산 및 로그 저장
# 결과는 system_specs.log에 저장, 디버깅 로그는 debug.log에 기록

# 기본 디렉터리 설정
BASE_DIR="/usr/local/src/iteasy_tuning"
LOG_DIR="$BASE_DIR/logs"
SPEC_LOG="$LOG_DIR/system_specs.log"
DEBUG_LOG="$LOG_DIR/debug.log"

# 로그 디렉터리 및 파일 생성
mkdir -p "$LOG_DIR" || { echo "오류: 로그 디렉터리($LOG_DIR) 생성 실패" >&2; exit 1; }
chmod 700 "$LOG_DIR" 2>/dev/null
touch "$SPEC_LOG" || { echo "오류: 로그 파일($SPEC_LOG) 생성 실패" >&2; exit 1; }
chmod 600 "$SPEC_LOG" 2>/dev/null
touch "$DEBUG_LOG" || { echo "오류: 디버깅 로그 파일($DEBUG_LOG) 생성 실패" >&2; exit 1; }
chmod 600 "$DEBUG_LOG" 2>/dev/null

# 디버깅 로그 함수
log_debug() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" >> "$DEBUG_LOG"
}

log_debug "BASE_DIR=$BASE_DIR"

# 서버 자원 확인 함수
get_server_specs() {
    # 의존성 체크
    if ! command -v free >/dev/null 2>&1; then
        echo "오류: 'free' 명령이 없습니다. 'procps' 패키지를 설치하세요." >&2 | tee -a "$DEBUG_LOG"
        return 1
    fi
    if ! command -v nproc >/dev/null 2>&1; then
        echo "오류: 'nproc' 명령이 없습니다. 'coreutils' 패키지를 설치하세요." >&2 | tee -a "$DEBUG_LOG"
        return 1
    fi
    if ! command -v df >/dev/null 2>&1; then
        echo "오류: 'df' 명령이 없습니다. 'coreutils' 패키지를 설치하세요." >&2 | tee -a "$DEBUG_LOG"
        return 1
    fi

    # 자원 정보 수집
    TOTAL_MEMORY=$(free -m | awk '/Mem:/ {print $2}') || { echo "오류: 메모리 정보 가져오기 실패" >&2 | tee -a "$DEBUG_LOG"; return 1; }
    CPU_CORES=$(nproc) || { echo "오류: CPU 코어 수 가져오기 실패" >&2 | tee -a "$DEBUG_LOG"; return 1; }
    DISK_SPACE=$(df -h / | awk 'NR==2 {print $4}') || { echo "오류: 디스크 정보 가져오기 실패" >&2 | tee -a "$DEBUG_LOG"; return 1; }

    log_debug "TOTAL_MEMORY=$TOTAL_MEMORY MB"
    log_debug "CPU_CORES=$CPU_CORES"
    log_debug "DISK_SPACE=$DISK_SPACE"

    # 결과 출력 및 로그 저장
    {
        echo "TOTAL_MEMORY=$TOTAL_MEMORY"
        echo "CPU_CORES=$CPU_CORES"
        echo "DISK_SPACE=$DISK_SPACE"
    } | tee "$SPEC_LOG" || { echo "오류: 로그 파일($SPEC_LOG)에 쓰기 실패" >&2 | tee -a "$DEBUG_LOG"; return 1; }
    chmod 600 "$SPEC_LOG" 2>/dev/null

    # 표준 출력
    echo "서버 자원 정보:"
    echo "총 메모리: $TOTAL_MEMORY MB"
    echo "CPU 코어 수: $CPU_CORES"
    echo "사용 가능 디스크 공간: $DISK_SPACE"
    echo "결과가 $SPEC_LOG에 저장되었습니다."
}

# 스크립트 실행
get_server_specs || exit 1