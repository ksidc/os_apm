#!/bin/bash

# 여러 조치 파일에서 공통으로 사용하는 권한, 입력 확인 및 서비스 재시작 함수다.

# 지정 파일의 소유자와 권한을 고정하고 실패 시 호출자에게 오류를 반환한다.
set_file_perms() {
    local file="$1" owner="$2" perms="$3"
    [ -e "$file" ] || {
        echo "ERROR: 권한 설정 대상이 없습니다: $file" >&2
        return 1
    }
    chown "$owner" "$file" || {
        echo "ERROR: 소유자 설정 실패: $file" >&2
        return 1
    }
    chmod "$perms" "$file" || {
        echo "ERROR: 권한 설정 실패: $file" >&2
        return 1
    }
}

# 스크립트가 시스템 설정을 변경할 수 있도록 root 실행 여부를 확인한다.
check_root() {
    [ "$(id -u)" -eq 0 ] || {
        echo "ERROR: root 권한으로 실행해야 합니다." >&2
        exit 1
    }
}

# Y/N 이외 입력은 다시 받아 잘못된 선택으로 진행되지 않게 한다.
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

# 신규 계정명을 다시 표시하고 오타가 없는지 생성 전에 확인한다.
confirm_account_name() {
    local user_name="$1"
    echo "입력한 계정명: $user_name"
    prompt_yes_no "이 계정명으로 생성하시겠습니까?"
}

# CentOS 6 useradd에서 사용할 수 있는 일반 계정명 형식인지 확인한다.
valid_account_name() {
    echo "$1" | grep -Eq '^[a-z_][a-z0-9_-]{0,31}$'
}

# wheel 그룹에 실제 sudo 권한을 부여하고 sudoers 문법을 검증한다.
configure_wheel_sudo() {
    [ -d /etc/sudoers.d ] || mkdir -p /etc/sudoers.d || return 1
    sed -i '\|^[[:space:]]*#includedir[[:space:]]\+/etc/sudoers\.d[[:space:]]*$|d' /etc/sudoers || return 1
    echo '#includedir /etc/sudoers.d' >> /etc/sudoers || return 1
    echo '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/99-wheel || return 1
    chown root:root /etc/sudoers.d/99-wheel || return 1
    chmod 440 /etc/sudoers.d/99-wheel || return 1
    visudo -c >/dev/null 2>&1 || {
        echo "ERROR: sudoers 문법 검증 실패" >&2
        return 1
    }
}

# 기존 일반 계정 중 wheel 구성원이 없을 때만 그룹 추가 여부를 묻는다.
ensure_admin_access() {
    local user_name

    for user_name in "$@"; do
        if id -nG "$user_name" 2>/dev/null | tr ' ' '\n' | grep -qx wheel; then
            echo "관리자 권한 확인: $user_name (wheel)"
            ADMIN_USER="$user_name"
            return 0
        fi
    done

    for user_name in "$@"; do
        echo "관리자 권한 없음: $user_name (wheel)"
        if prompt_yes_no "$user_name 계정을 wheel 그룹에 추가하시겠습니까?"; then
            usermod -aG wheel "$user_name" || {
                echo "ERROR: wheel 그룹 추가 실패: $user_name" >&2
                return 1
            }
            ADMIN_USER="$user_name"
            return 0
        fi
    done

    echo "ERROR: root SSH 차단 전에 wheel 권한 일반 계정이 필요합니다." >&2
    return 1
}

# 설정 변경 후 마지막에 한 번만 재시작할 SysV 서비스명을 중복 없이 기록한다.
mark_restart() {
    local service_name="$1"
    case " $RESTARTS_NEEDED " in
        *" $service_name "*) ;;
        *) RESTARTS_NEEDED="${RESTARTS_NEEDED}${service_name} " ;;
    esac
}
