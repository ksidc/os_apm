#!/bin/bash

# go.sh: OS 감지 후 secure_os_collection/OS/ 하위의 main.sh 실행
# 실행: sudo bash /usr/local/src/secure_os_collection/go.sh
# 기반: KISA 가이드 Unix 섹션 (U-01~U-72) 준수 보안 강화

# CRLF 검증 및 수정
check_crlf() {
    if grep -U $'\r' "$0" >/dev/null; then
        echo "CRLF detected in $0. Converting to LF..."
        sed -i 's/\r$//' "$0"
        echo "Converted. Please rerun the script."
        exit 1
    fi
}
check_crlf

set -e  # 오류 시 중단

# 루트 권한 확인
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: root 권한으로 실행하세요 (sudo bash go.sh)."
    exit 1
fi

# 변수 정의
BASE_DIR=$(dirname "$(realpath "$0")")  # /usr/local/src/secure_os_collection/
SECURE_COLLECTION_DIR="$BASE_DIR"
LOG_DIR="$BASE_DIR/logs"
LOG_FILE="$LOG_DIR/go_$(date +%Y%m%d_%H%M%S).log"

# 로그 함수
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 로그 디렉토리 생성
mkdir -p "$LOG_DIR" && chmod 700 "$LOG_DIR" || { 
    echo "ERROR: 로그 디렉토리 $LOG_DIR 생성 실패" >&2
    exit 1
}
log "로그 디렉토리 $LOG_DIR 생성 성공"

# OS 감지 함수
detect_os() {
    log "OS 감지 시작"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID=$ID
        OS_VER=$VERSION_ID
    else
        log "ERROR: /etc/os-release 파일 없음. OS 감지 실패."
        exit 1
    fi

    # 메이저 버전 추출
    MAJOR_VER="${OS_VER%%.*}"

    # OS 서브디렉토리 매핑
    case "$OS_ID" in
        centos)
            if [ "$MAJOR_VER" = "7" ]; then
                OS_SUBDIR="c7"
            else
                log "ERROR: CentOS $OS_VER 미지원."
                exit 1
            fi
            ;;
        rocky)
            if [ "$MAJOR_VER" = "8" ]; then
                OS_SUBDIR="r8"
            elif [ "$MAJOR_VER" = "9" ]; then
                OS_SUBDIR="r9"
            else
                log "ERROR: Rocky $OS_VER 미지원."
                exit 1
            fi
            ;;
        ubuntu)
            if [ "$MAJOR_VER" = "18" ]; then
                OS_SUBDIR="u18"
            elif [ "$MAJOR_VER" = "20" ]; then
                OS_SUBDIR="u20"
            elif [ "$MAJOR_VER" = "22" ]; then
                OS_SUBDIR="u22"
            elif [ "$MAJOR_VER" = "24" ]; then
                OS_SUBDIR="u24"
            else
                log "ERROR: Ubuntu $OS_VER 미지원."
                exit 1
            fi
            ;;
        *)
            log "ERROR: 미지원 OS: $OS_ID $OS_VER."
            exit 1
            ;;
    esac
    log "감지된 OS: $OS_ID $OS_VER (서브디렉토리: $OS_SUBDIR, 메이저 버전: $MAJOR_VER)"
}

# 메인 로직
log "go.sh 시작"

# OS 감지
detect_os

# secure 스크립트 경로 구성
SOURCE_DIR="$SECURE_COLLECTION_DIR/$OS_SUBDIR"
SECURE_SCRIPT="$SOURCE_DIR/main.sh"
log "secure 스크립트 경로: $SECURE_SCRIPT"

if [ ! -f "$SECURE_SCRIPT" ]; then
    log "ERROR: $SECURE_SCRIPT 없음."
    exit 1
fi

# 하위 스크립트 권한 설정
log "하위 스크립트 권한 설정: $SOURCE_DIR/*.sh"
chmod +x "$SOURCE_DIR"/*.sh || { log "ERROR: $SOURCE_DIR/*.sh 권한 설정 실패"; exit 1; }
log "하위 스크립트 권한 설정 완료"

# secure 스크립트 실행
log "$SECURE_SCRIPT 실행 시작"
bash "$SECURE_SCRIPT" || {
    log "ERROR: $SECURE_SCRIPT 실행 실패. 롤백 실행 권장: bash $SOURCE_DIR/rollback.sh"
    exit 1
}
log "$SECURE_SCRIPT 실행 완료"

log "go.sh 완료"