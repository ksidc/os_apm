#!/bin/bash

source /usr/local/src/secure_os_collection/r9/common.sh

# 기본 불필요 계정을 삭제하고 삭제 내역을 요약 변수에 기록한다.
remove_unneeded_users() {
    local user_name

    for user_name in lp games ftp sync shutdown halt; do
        if id "$user_name" &>/dev/null; then
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
            echo "ERROR: /etc/passwd 수정 실패" >&2
            return 1
        }
        DELETED_USERS+="ftp (셸 변경) "
    fi
}

# root 비밀번호를 입력받아 변경하고 계정 상태 조회로 적용 여부를 확인한다.
step1_change_root_password() {
    local root_password confirm_password

    while true; do
        read -r -s -p "root 비밀번호 입력 (최소 ${MIN_PASSWORD_LENGTH}자): " root_password < /dev/tty
        echo
        if [ "${#root_password}" -lt "$MIN_PASSWORD_LENGTH" ]; then
            echo "  → 비밀번호는 최소 ${MIN_PASSWORD_LENGTH}자 이상이어야 합니다."
            continue
        fi

        read -r -s -p "비밀번호 확인: " confirm_password < /dev/tty
        echo
        if [ "$root_password" != "$confirm_password" ]; then
            echo "  → 비밀번호가 일치하지 않습니다. 다시 입력해주세요."
            continue
        fi
        break
    done

    echo "root:$root_password" | chpasswd || {
        echo "ERROR: root 비밀번호 설정 실패" >&2
        return 1
    }
    passwd -S root >/dev/null 2>&1 || {
        echo "ERROR: root 상태 조회 실패" >&2
        return 1
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
        PASSWORD_POLICY_SUMMARY="미적용"
        return 0
    fi

    echo "다음 항목에 대해 값을 입력합니다. (Enter 입력 시 기본값 적용)"
    read -r -p "1. 최대 사용일수 (default: 90): " max_days < /dev/tty
    read -r -p "2. 최소 길이 (default: 8): " min_len < /dev/tty
    read -r -p "3. 최소 사용일수 (default: 1): " min_days < /dev/tty
    read -r -p "4. 경고일수 (default: 7): " warn_days < /dev/tty

    max_days=${max_days:-90}
    min_len=${min_len:-8}
    min_days=${min_days:-1}
    warn_days=${warn_days:-7}

    PASSWORD_POLICY_SUMMARY="적용됨 (최대 $max_days일, 최소 길이 $min_len, 최소 $min_days일, 경고 $warn_days일)"

    user_list_output=$(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd 2>/dev/null) || {
        echo "ERROR: 사용자 목록 조회 실패" >&2
        return 1
    }

    if [ -n "$user_list_output" ]; then
        readarray -t user_list <<< "$user_list_output"
    fi

    for user_name in "${user_list[@]}"; do
        chage -M "$max_days" -m "$min_days" -W "$warn_days" "$user_name" || {
            echo "ERROR: 사용자 $user_name 패스워드 정책 설정 실패" >&2
            return 1
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
        echo "ERROR: /etc/login.defs 설정 실패" >&2
        return 1
    }
}

# 일반 운영 계정을 준비하고 root SSH 로그인을 차단한다.
create_fallback_and_restrict() {
    local existing_users user_name user_password password_confirm

    existing_users=$(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd 2>/dev/null) || {
        echo "ERROR: 기존 계정 조회 실패" >&2
        CREATED_USER="미생성 (계정 조회 실패)"
        return 1
    }

    if [ -n "$existing_users" ]; then
        echo "기존 일반 계정:"
        echo "$existing_users"
        if prompt_yes_no "새 계정 생성 없이 넘어가시겠습니까?"; then
            ensure_admin_access wheel $existing_users || return 1
            CREATED_USER="미생성 (기존 계정: $existing_users)"
        fi
    fi

    if [ -z "${CREATED_USER:-}" ] || [[ "$CREATED_USER" == "미생성" ]]; then
        while true; do
            read -r -p "생성할 일반 계정명 입력: " user_name < /dev/tty
            if [ -z "$user_name" ]; then
                echo "계정명을 입력해야 합니다."
                continue
            fi

            if id "$user_name" &>/dev/null; then
                ensure_admin_access wheel "$user_name" || return 1
                break
            fi

            if confirm_account_name "$user_name"; then
                break
            fi
            echo "계정명을 다시 입력해 주세요."
        done

        if id "$user_name" &>/dev/null; then
            CREATED_USER="$user_name (이미 존재)"
        else
            while true; do
                read -r -s -p "계정 '$user_name' 비밀번호 입력 (최소 ${MIN_PASSWORD_LENGTH}자): " user_password < /dev/tty
                echo
                if [ "${#user_password}" -lt "$MIN_PASSWORD_LENGTH" ]; then
                    echo "  → 최소 ${MIN_PASSWORD_LENGTH}자 이상이어야 합니다."
                    continue
                fi

                read -r -s -p "비밀번호 확인: " password_confirm < /dev/tty
                echo
                if [ "$user_password" != "$password_confirm" ]; then
                    echo "  → 비밀번호 불일치, 다시 입력해주세요."
                    continue
                fi
                break
            done

            useradd -m -G wheel "$user_name" || {
                echo "ERROR: 계정 $user_name 생성 실패" >&2
                CREATED_USER="미생성 (생성 실패)"
                return 1
            }
            echo "$user_name:$user_password" | chpasswd || {
                echo "ERROR: 계정 $user_name 비밀번호 설정 실패" >&2
                CREATED_USER="미생성 (비밀번호 설정 실패)"
                return 1
            }
            CREATED_USER="$user_name 생성됨"
        fi

        passwd -S "$user_name" >/dev/null 2>&1 || {
            echo "ERROR: 계정 $user_name 상태 조회 실패" >&2
            return 1
        }
        groups "$user_name" >/dev/null 2>&1 || {
            echo "ERROR: 계정 $user_name 그룹 조회 실패" >&2
            return 1
        }
        [ -d "/home/$user_name" ] && ls -ld "/home/$user_name" >/dev/null 2>&1
    fi

    sed -i '/^[[:space:]]*#\?[[:space:]]*PermitRootLogin[[:space:]]/d' /etc/ssh/sshd_config || {
        echo "ERROR: sshd_config 수정 실패" >&2
        return 1
    }
    echo 'PermitRootLogin no' >> /etc/ssh/sshd_config

    local dropin_dir="/etc/ssh/sshd_config.d"
    local dropin_file="$dropin_dir/01-permitrootlogin.conf"
    mkdir -p "$dropin_dir" || {
        echo "ERROR: sshd_config.d 디렉터리 생성 실패" >&2
        return 1
    }
    cat <<'EOF' > "$dropin_file"
PermitRootLogin no
EOF

    restarts_needed["sshd"]=1
}

# pwquality 설정에 복잡도 기준과 root 강제 적용 기준을 추가한다.
configure_pwquality() {
    sed -i '/^lcredit\|^ucredit\|^dcredit\|^ocredit\|^minlen\|^difok\|^enforce_for_root/d' /etc/security/pwquality.conf
    cat <<EOF >> /etc/security/pwquality.conf
lcredit=-1
ucredit=-1
dcredit=-1
ocredit=-1
minlen=8
difok=2
enforce_for_root
EOF
}

# pwhistory.conf와 opasswd를 생성해 비밀번호 재사용 이력을 관리한다.
configure_pwhistory() {
    cat <<EOF > /etc/security/pwhistory.conf
enforce_for_root
remember=4
file = /etc/security/opasswd
EOF
    [ -f /etc/security/opasswd ] || touch /etc/security/opasswd
    chmod 600 /etc/security/opasswd
    chown root:root /etc/security/opasswd
}

# authselect 기반 faillock 정책을 활성화하고 PAM 링크/설정 반영 여부를 검증한다.
configure_pam_lockout() {
    local fconf="/etc/security/faillock.conf"
    local pam_file

    if ! authselect check >/dev/null 2>&1; then
        authselect select sssd --force || {
            echo "ERROR: authselect select 실패" >&2
            return 1
        }
    fi

    authselect enable-feature with-faillock >/dev/null 2>&1 || true
    authselect enable-feature with-pwquality >/dev/null 2>&1 || true
    authselect apply-changes || {
        echo "ERROR: authselect 적용 실패" >&2
        return 1
    }

    if [ -f "$fconf" ]; then
        sed -i '/^deny/d; /^unlock_time/d; /^silent/d; /^audit/d' "$fconf"
    fi
    cat <<EOF >> "$fconf"
silent
audit
deny = 3
unlock_time = 300
EOF

    for pam_file in /etc/pam.d/password-auth /etc/pam.d/system-auth; do
        if [ ! -L "$pam_file" ]; then
            echo "ERROR: $pam_file 가 심볼릭 링크가 아님" >&2
            return 1
        fi
        if ! grep -q 'pam_faillock.so' "$pam_file"; then
            echo "ERROR: $pam_file 에 pam_faillock 라인이 보이지 않음" >&2
            return 1
        fi
    done
}

# su 사용을 wheel 그룹으로 제한하고 /usr/bin/su 권한을 재확인한다.
configure_su_restriction() {
    local su_file="/etc/pam.d/su"

    if ! getent group wheel >/dev/null; then
        groupadd wheel || {
            echo "ERROR: wheel group 생성 실패" >&2
            return 1
        }
    fi

    sed -i '/^[[:space:]]*auth[[:space:]]\+required[[:space:]]\+pam_wheel\.so.*use_uid/d' "$su_file" || return 1
    sed -i '/pam_rootok.so/a auth       required    pam_wheel.so use_uid' "$su_file" || {
        echo "ERROR: pam_wheel.so use_uid 라인 추가 실패" >&2
        return 1
    }

    authselect apply-changes || {
        echo "ERROR: su 제한 authselect 적용 실패" >&2
        return 1
    }

    chown root:wheel /usr/bin/su && chmod 4750 /usr/bin/su || {
        echo "ERROR: /usr/bin/su 권한 설정 실패" >&2
        return 1
    }
}

remove_unneeded_users || exit 1
configure_ftp_shell || exit 1
step1_change_root_password || exit 1
set_password_policy || exit 1
create_fallback_and_restrict || exit 1
configure_pwquality || exit 1
configure_pwhistory || exit 1
configure_pam_lockout || exit 1
configure_su_restriction || exit 1
