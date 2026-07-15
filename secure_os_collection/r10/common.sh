#!/bin/bash

# 공통 함수

# 지정 파일의 소유자와 권한을 보안 기준값으로 맞춘다.
set_file_perms() {
    local file="$1" owner="$2" perms="$3"
    if [ -f "$file" ]; then
        chown "$owner" "$file" || { echo "ERROR: $file 소유자 설정 실패" >&2; return 1; }
        chmod "$perms" "$file" || { echo "ERROR: $file 권한 설정 실패" >&2; return 1; }
    else
        return 1
    fi
}

# 스크립트가 root 권한으로 실행 중인지 확인한다.
check_root() {
    [ "$EUID" -ne 0 ] && { echo "ERROR: root 권한 필요" >&2; exit 1; }
}

# y/N 입력을 반복해서 받아 잘못된 선택값을 차단한다.
prompt_yes_no() {
    local prompt="$1" reply
    while true; do
        read -r -p "$prompt (Y/N): " reply < /dev/tty
        case "$reply" in
            [Yy]) return 0 ;;
            [Nn]) return 1 ;;
            *) echo "Y 또는 N으로 입력해 주세요." ;;
        esac
    done
}

# 입력한 신규 계정명을 다시 표시하고 생성 여부를 확인한다.
confirm_account_name() {
    local user_name="$1"
    echo "입력한 계정명: $user_name"
    prompt_yes_no "이 계정명으로 생성하시겠습니까?"
}

# 기존 일반 계정 중 관리자 그룹 구성원이 있는지 확인하고, 없을 때만 추가 여부를 묻는다.
ensure_admin_access() {
    local admin_group="$1" user_name
    shift

    for user_name in "$@"; do
        if id -nG "$user_name" 2>/dev/null | tr ' ' '\n' | grep -qx "$admin_group"; then
            echo "관리자 권한 확인: $user_name ($admin_group)"
            return 0
        fi
    done

    for user_name in "$@"; do
        echo "관리자 권한 없음: $user_name ($admin_group)"
        if prompt_yes_no "$user_name 계정을 $admin_group 그룹에 추가하시겠습니까?"; then
            usermod -aG "$admin_group" "$user_name" || {
                echo "ERROR: $user_name 계정의 $admin_group 그룹 추가 실패" >&2
                return 1
            }
            return 0
        fi
    done

    echo "ERROR: root SSH 로그인을 차단하려면 관리자 권한이 있는 일반 계정이 필요합니다." >&2
    return 1
}
