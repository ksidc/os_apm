#!/bin/bash

source /usr/local/src/secure_os_collection/c7/common.sh

# 기본 불필요 계정을 삭제하고 삭제 내역을 요약 변수에 기록한다.
remove_unneeded_users() {
    local user_name

    for user_name in lp games ftp sync shutdown halt; do
        if id "$user_name" >/dev/null 2>&1; then
            if userdel -r "$user_name"; then
                DELETED_USERS+="$user_name "
            fi
        fi
    done
}

# ftp 계정이 남아 있을 경우 로그인 불가 셸을 /bin/false로 맞춘다.
configure_ftp_shell() {
    if getent passwd ftp | grep -q '/sbin/nologin'; then
        sed -i '/^ftp:/s#/sbin/nologin#/bin/false#' /etc/passwd || {
            echo "ERROR: /etc/passwd update failed" >&2
            return 1
        }
        DELETED_USERS+="ftp(shell_changed) "
    fi
}

# root 비밀번호를 입력받아 변경하고 계정 상태 조회로 적용 여부를 확인한다.
step1_change_root_password() {
    local root_password confirm_password

    while true; do
        read -r -s -p "root 비밀번호 입력 (최소 ${MIN_PASSWORD_LENGTH}자): " root_password < /dev/tty
        echo
        if [ "${#root_password}" -lt "$MIN_PASSWORD_LENGTH" ]; then
            echo "  최소 ${MIN_PASSWORD_LENGTH}자 이상 입력해야 합니다."
            continue
        fi

        read -r -s -p "비밀번호 확인: " confirm_password < /dev/tty
        echo
        if [ "$root_password" != "$confirm_password" ]; then
            echo "  비밀번호가 일치하지 않습니다. 다시 입력하세요."
            continue
        fi
        break
    done

    echo "root:$root_password" | chpasswd || {
        echo "ERROR: root password update failed" >&2
        exit 1
    }

    passwd -S root >/dev/null 2>&1 || {
        echo "ERROR: root status check failed" >&2
        exit 1
    }
}

# 선택 시 기존 일반 사용자와 login.defs에 패스워드 만료 정책을 적용한다.
set_password_policy() {
    local ans max_days min_len min_days warn_days
    local user_list_output
    local -a user_list=()
    local user_name

    read -r -p "패스워드 만료 정책을 설정하시겠습니까? (Y/N): " ans < /dev/tty
    if [[ ! "$ans" =~ ^[Yy]$ ]]; then
        PASSWORD_POLICY_SUMMARY="not applied"
        return 0
    fi

    echo "다음 항목에 대해 값을 입력합니다. (Enter 입력 시 기본값 적용)"
    read -r -p "1. 최대 사용일수 (default: 90): " max_days < /dev/tty
    read -r -p "2. 최소 길이 (default: 8): " min_len < /dev/tty
    read -r -p "3. 최소 사용일수 (default: 0): " min_days < /dev/tty
    read -r -p "4. 경고일수 (default: 7): " warn_days < /dev/tty

    max_days=${max_days:-90}
    min_len=${min_len:-8}
    min_days=${min_days:-0}
    warn_days=${warn_days:-7}

    PASSWORD_POLICY_SUMMARY="applied(max=$max_days min_len=$min_len min_days=$min_days warn=$warn_days)"

    user_list_output=$(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd 2>/dev/null) || {
        echo "ERROR: regular user list read failed" >&2
        exit 1
    }

    if [ -n "$user_list_output" ]; then
        readarray -t user_list <<< "$user_list_output"
    fi

    for user_name in "${user_list[@]}"; do
        chage -M "$max_days" -m "$min_days" -W "$warn_days" "$user_name" || {
            echo "ERROR: chage update failed for $user_name" >&2
            exit 1
        }
    done

    sed -i '/^PASS_MAX_DAYS/d' /etc/login.defs
    sed -i '/^PASS_MIN_LEN/d' /etc/login.defs
    sed -i '/^PASS_MIN_DAYS/d' /etc/login.defs
    sed -i '/^PASS_WARN_AGE/d' /etc/login.defs
    {
        echo "PASS_MAX_DAYS   $max_days"
        echo "PASS_MIN_LEN    $min_len"
        echo "PASS_MIN_DAYS   $min_days"
        echo "PASS_WARN_AGE   $warn_days"
    } >> /etc/login.defs || {
        echo "ERROR: /etc/login.defs update failed" >&2
        exit 1
    }
}

# 일반 운영 계정을 준비하고 root SSH 로그인을 차단한다.
create_fallback_and_restrict() {
    local existing_users user_name user_password password_confirm
    local create_user=1

    existing_users=$(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd 2>/dev/null) || {
        echo "ERROR: regular user lookup failed" >&2
        CREATED_USER="not created(lookup failed)"
        return 1
    }

    if [ -n "$existing_users" ]; then
        echo "기존 일반 계정:"
        echo "$existing_users"
        if prompt_yes_no "새 계정 생성 없이 진행하시겠습니까?"; then
            ensure_admin_access wheel $existing_users || return 1
            CREATED_USER="not created(existing: $existing_users)"
            create_user=0
        fi
    fi

    if [ "$create_user" -eq 1 ]; then
        while true; do
            read -r -p "생성할 일반 계정명 입력: " user_name < /dev/tty
            if [ -z "$user_name" ]; then
                echo "계정명을 입력해야 합니다."
                continue
            fi

            if id "$user_name" >/dev/null 2>&1; then
                ensure_admin_access wheel "$user_name" || return 1
                CREATED_USER="$user_name(existing)"
                break
            fi

            if ! confirm_account_name "$user_name"; then
                echo "계정명을 다시 입력해 주세요."
                continue
            fi

            while true; do
                read -r -s -p "계정 '$user_name' 비밀번호 입력 (최소 ${MIN_PASSWORD_LENGTH}자): " user_password < /dev/tty
                echo
                if [ "${#user_password}" -lt "$MIN_PASSWORD_LENGTH" ]; then
                    echo "  최소 ${MIN_PASSWORD_LENGTH}자 이상 입력해야 합니다."
                    continue
                fi

                read -r -s -p "비밀번호 확인: " password_confirm < /dev/tty
                echo
                if [ "$user_password" != "$password_confirm" ]; then
                    echo "  비밀번호가 일치하지 않습니다. 다시 입력하세요."
                    continue
                fi
                break
            done

            useradd -m -G wheel "$user_name" || {
                echo "ERROR: useradd failed: $user_name" >&2
                CREATED_USER="not created(useradd failed)"
                return 1
            }
            echo "$user_name:$user_password" | chpasswd || {
                echo "ERROR: password set failed: $user_name" >&2
                CREATED_USER="not created(password set failed)"
                return 1
            }
            CREATED_USER="$user_name(created)"
            break
        done
    fi

    sed -i '/^[[:space:]]*#\?[[:space:]]*PermitRootLogin[[:space:]]/d' /etc/ssh/sshd_config || {
        echo "ERROR: sshd_config update failed" >&2
        return 1
    }
    echo 'PermitRootLogin no' >> /etc/ssh/sshd_config

    restarts_needed["sshd"]=1
}

# pwquality 설정에 복잡도 기준을 추가해 신규 비밀번호 품질을 제한한다.
configure_pwquality() {
    sed -i '/^lcredit\|^ucredit\|^dcredit\|^ocredit\|^minlen\|^difok/d' /etc/security/pwquality.conf
    cat <<EOF >> /etc/security/pwquality.conf
lcredit=-1
ucredit=-1
dcredit=-1
ocredit=-1
minlen=8
difok=2
EOF
}

# pam_tally2 기반 로그인 실패 잠금 정책을 system-auth/password-auth에 적용한다.
configure_pam_lockout() {
    local pam_file

    for pam_file in /etc/pam.d/system-auth /etc/pam.d/password-auth; do
        sed -i '/pam_tally2.so/d' "$pam_file"
        sed -i '/^auth\s\+required\s\+pam_env.so/a auth        required      pam_tally2.so deny=3 unlock_time=300' "$pam_file"
        sed -i '/^auth\s\+sufficient\s\+pam_unix.so/a auth        [default=die] pam_tally2.so deny=3 unlock_time=300' "$pam_file"
        sed -i '/^account\s\+required\s\+pam_unix.so/a account     required      pam_tally2.so' "$pam_file"
    done
}

# su 사용을 wheel 그룹으로 제한하고 /usr/bin/su 권한을 재확인한다.
configure_su_restriction() {
    local su_file="/etc/pam.d/su"

    if ! getent group wheel >/dev/null 2>&1; then
        groupadd wheel || {
            echo "ERROR: wheel group create failed" >&2
            return 1
        }
    fi

    set_file_perms /usr/bin/su root:wheel 4750

    sed -i '/^[[:space:]]*auth[[:space:]]\+required[[:space:]]\+pam_wheel\.so.*use_uid/d' "$su_file"
    sed -i '/pam_rootok.so/a auth       required    pam_wheel.so use_uid' "$su_file"
}

remove_unneeded_users || exit 1
configure_ftp_shell || exit 1
step1_change_root_password || exit 1
set_password_policy || exit 1
create_fallback_and_restrict || exit 1
configure_pwquality || exit 1
configure_pam_lockout || exit 1
configure_su_restriction || exit 1
