#!/bin/bash

# go.sh: CentOS 6.10·7, Rocky 8~10, Ubuntu 18~26을 감지해 OS별 main.sh 실행
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

set -e

# 루트 권한 확인
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: root 권한으로 실행하세요 (sudo bash go.sh)." >&2
    exit 1
fi

# 변수 정의
BASE_DIR=$(cd "$(dirname "$0")" && pwd -P)
SECURE_COLLECTION_DIR="$BASE_DIR"

# OS 감지 함수
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID=$ID
        OS_VER=$VERSION_ID
    elif [ -f /etc/centos-release ] && grep -q '^CentOS release 6\.10' /etc/centos-release; then
        OS_ID="centos"
        OS_VER="6.10"
    else
        echo "ERROR: OS 버전 파일을 확인할 수 없습니다." >&2
        exit 1
    fi

    MAJOR_VER="${OS_VER%%.*}"

    case "$OS_ID" in
        centos)
            if [ "$MAJOR_VER" = "6" ]; then
                OS_SUBDIR="c6"
            elif [ "$MAJOR_VER" = "7" ]; then
                OS_SUBDIR="c7"
            else
                echo "ERROR: CentOS $OS_VER 미지원." >&2
                exit 1
            fi
            ;;
        rocky)
            if [ "$MAJOR_VER" = "8" ]; then
                OS_SUBDIR="r8"
            elif [ "$MAJOR_VER" = "9" ]; then
                OS_SUBDIR="r9"
            elif [ "$MAJOR_VER" = "10" ]; then
                OS_SUBDIR="r10"
            else
                echo "ERROR: Rocky $OS_VER 미지원." >&2
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
            elif [ "$MAJOR_VER" = "26" ]; then
                OS_SUBDIR="u26"
            else
                echo "ERROR: Ubuntu $OS_VER 미지원." >&2
                exit 1
            fi
            ;;
        *)
            echo "ERROR: 미지원 OS: $OS_ID $OS_VER." >&2
            exit 1
            ;;
    esac
}

detect_os

SOURCE_DIR="$SECURE_COLLECTION_DIR/$OS_SUBDIR"
SECURE_SCRIPT="$SOURCE_DIR/main.sh"

if [ ! -f "$SECURE_SCRIPT" ]; then
    echo "ERROR: $SECURE_SCRIPT 없음." >&2
    exit 1
fi

chmod +x "$SOURCE_DIR"/*.sh || {
    echo "ERROR: $SOURCE_DIR/*.sh 권한 설정 실패" >&2
    exit 1
}

bash "$SECURE_SCRIPT" || {
    echo "ERROR: $SECURE_SCRIPT 실행 실패." >&2
    exit 1
}
