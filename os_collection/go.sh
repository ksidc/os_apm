#!/bin/bash

# go.sh: OS 감지 후 적합한 iteasy_tuning 세트를 /usr/local/src/iteasy_tuning에 배포 및 실행
# 실행: sudo bash /usr/local/src/os_collection/go.sh

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

# 변수 정의
BASE_DIR="/usr/local/src"
OS_COLLECTION_DIR="$BASE_DIR/os_collection"
TARGET_DIR="$BASE_DIR/iteasy_tuning"
LOG_FILE="/$BASE_DIR/go.log"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# 로그 함수
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 디스크 공간 확인 함수
check_disk_space() {
    local available=$(df -k "$BASE_DIR" | tail -1 | awk '{print $4}')
    if [ "$available" -lt 102400 ]; then  # 100MB 미만
        log "ERROR: 디스크 공간 부족 ($BASE_DIR)."
        exit 1
    fi
}

# OS 감지 함수
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID=$ID
        OS_VER=$VERSION_ID
    else
        log "ERROR: /etc/os-release 파일 없음. OS 감지 실패."
        exit 1
    fi

    # OS 매핑
    case "$OS_ID" in
        centos)
            if [ "$OS_VER" = "7" ]; then
                OS_SUBDIR="c7"
            else
                log "ERROR: CentOS $OS_VER 미지원."
                exit 1
            fi
            ;;
        rocky)
            if [[ "$OS_VER" =~ ^8(\.[0-9]+)?$ ]]; then
                OS_SUBDIR="r8"
            elif [[ "$OS_VER" =~ ^9(\.[0-9]+)?$ ]]; then
                OS_SUBDIR="r9"
            else
                log "ERROR: Rocky $OS_VER 미지원."
                exit 1
            fi
            ;;
        ubuntu)
            if [ "$OS_VER" = "18.04" ]; then
                OS_SUBDIR="u18"
            elif [ "$OS_VER" = "20.04" ]; then
                OS_SUBDIR="u20"
            elif [ "$OS_VER" = "22.04" ]; then
                OS_SUBDIR="u22"
            elif [ "$OS_VER" = "24.04" ]; then
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
    log "감지된 OS: $OS_ID $OS_VER (서브디렉토리: $OS_SUBDIR)"
}

# 메인 로직
log "go.sh 시작."

# 디스크 공간 확인
check_disk_space

# OS 감지
detect_os

# 복사
SOURCE_DIR="$OS_COLLECTION_DIR/$OS_SUBDIR/iteasy_tuning"
if [ ! -d "$SOURCE_DIR" ]; then
    log "ERROR: $SOURCE_DIR 없음."
    exit 1
fi

log "$SOURCE_DIR -> $TARGET_DIR 복사 중."
[ -d "$TARGET_DIR" ] && rm -rf "$TARGET_DIR"  # 기존 디렉토리 삭제
cp -r "$SOURCE_DIR" "$TARGET_DIR"
chmod 700 "$TARGET_DIR"  # 디렉토리 권한
find "$TARGET_DIR" -type d -exec chmod 700 {} \;  # 하위 디렉토리 권한
find "$TARGET_DIR" -type f -exec chmod 600 {} \;  # 파일 권한
find "$TARGET_DIR" -type f \( -name "*.sh" \) -exec chmod +x {} \;  # 스크립트만 실행 가능
log "권한 설정 완료."

# main.sh 실행
MAIN_SH="$TARGET_DIR/main.sh"
if [ -x "$MAIN_SH" ]; then
    log "main.sh 실행 중."
    bash "$MAIN_SH"
else
    log "ERROR: $MAIN_SH 없거나 실행 불가."
    exit 1
fi

log "go.sh 완료."