#!/bin/bash

source /usr/local/src/secure_os_collection/c7/common.sh

remove_unneeded_users() {
    log_info "remove_unneeded_users start"
    local user_name

    for user_name in lp games ftp sync shutdown halt; do
        if id "$user_name" >/dev/null 2>&1; then
            userdel -r "$user_name" && {
                log_info "$user_name removed"
                DELETED_USERS+="$user_name "
            } || log_error "remove_unneeded_users" "$user_name remove failed"
        else
            log_info "$user_name not present"
        fi
    done
}

configure_ftp_shell() {
    log_info "configure_ftp_shell start"

    if getent passwd ftp | grep -q '/sbin/nologin'; then
        sed -i '/^ftp:/s#/sbin/nologin#/bin/false#' /etc/passwd || {
            log_error "configure_ftp_shell" "/etc/passwd update failed"
            return 1
        }
        log_info "ftp shell changed to /bin/false"
        DELETED_USERS+="ftp(shell_changed) "
    else
        log_info "ftp shell change not required"
    fi
}

step1_change_root_password() {
    log_info "step1_change_root_password start"
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
        log_error "change_root_password" "root password update failed"
        exit 1
    }

    passwd -S root >> "$LOG_FILE" || log_error "change_root_password" "root status check failed"
    log_info "root password updated"
}

set_password_policy() {
    log_info "set_password_policy start"

    local ans max_days min_len min_days warn_days
    local user_list_output
    local -a user_list=()
    local user_name

    read -r -p "패스워드 만료 정책을 설정하시겠습니까? (Y/N): " ans < /dev/tty
    if [[ ! "$ans" =~ ^[Yy]$ ]]; then
        log_info "password expiry policy skipped"
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
    log_info "password policy selected: $PASSWORD_POLICY_SUMMARY"

    user_list_output=$(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd 2>/dev/null) || {
        log_error "set_password_policy" "regular user list read failed"
        exit 1
    }

    if [ -n "$user_list_output" ]; then
        readarray -t user_list <<< "$user_list_output"
    else
        log_info "no regular users found for chage update"
    fi

    for user_name in "${user_list[@]}"; do
        chage -M "$max_days" -m "$min_days" -W "$warn_days" "$user_name" || \
            log_error "set_password_policy" "chage update failed for $user_name"
        log_info "chage updated for $user_name"
        chage -l "$user_name" | grep -E 'Maximum|Minimum|Warning' >> "$LOG_FILE"
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
    } >> /etc/login.defs || log_error "set_password_policy" "/etc/login.defs update failed"

    log_info "/etc/login.defs updated"
}

create_fallback_and_restrict() {
    log_info "create_fallback_and_restrict start"

    local existing_users user_name user_password password_confirm

    existing_users=$(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd 2>/dev/null) || {
        log_error "create_fallback_and_restrict" "regular user lookup failed"
        CREATED_USER="not created(lookup failed)"
        return 1
    }

    log_info "existing regular users: ${existing_users:-none}"
    if [ -n "$existing_users" ]; then
        read -r -p "기존 일반 계정이 있습니다. 새 계정 생성 없이 진행하시겠습니까? (Y/N): " yn < /dev/tty
        if [[ "$yn" =~ ^[Yy]$ ]]; then
            log_info "fallback user creation skipped"
            CREATED_USER="not created(existing: $existing_users)"
        else
            read -r -p "생성할 일반 계정명 입력: " user_name < /dev/tty
            if [ -z "$user_name" ]; then
                log_error "create_user" "username is required"
                CREATED_USER="not created(username missing)"
                return 1
            fi

            if id "$user_name" >/dev/null 2>&1; then
                log_info "user already exists: $user_name"
                CREATED_USER="$user_name(existing)"
            else
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
                    log_error "create_user" "useradd failed: $user_name"
                    CREATED_USER="not created(useradd failed)"
                    return 1
                }
                echo "$user_name:$user_password" | chpasswd || {
                    log_error "create_user" "password set failed: $user_name"
                    CREATED_USER="not created(password set failed)"
                    return 1
                }
                log_info "user created: $user_name"
                CREATED_USER="$user_name(created)"
            fi
        fi
    else
        read -r -p "생성할 일반 계정명 입력: " user_name < /dev/tty
        if [ -z "$user_name" ]; then
            log_error "create_user" "username is required"
            CREATED_USER="not created(username missing)"
            return 1
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
            log_error "create_user" "useradd failed: $user_name"
            CREATED_USER="not created(useradd failed)"
            return 1
        }
        echo "$user_name:$user_password" | chpasswd || {
            log_error "create_user" "password set failed: $user_name"
            CREATED_USER="not created(password set failed)"
            return 1
        }
        log_info "user created: $user_name"
        CREATED_USER="$user_name(created)"
    fi

    sed -i -e 's/^#PermitRootLogin.*/PermitRootLogin no/' \
           -e 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config || {
        log_error "restrict_root" "sshd_config update failed"
        return 1
    }

    log_info "root ssh login disabled"
    restarts_needed["sshd"]=1

    if [ -n "${user_name:-}" ] && id "$user_name" >/dev/null 2>&1; then
        {
            echo ">>> user status: $user_name"
            passwd -S "$user_name"
            echo ">>> user groups: $user_name"
            groups "$user_name"
            echo ">>> home permissions: $user_name"
            ls -ld "/home/$user_name"
        } >> "$LOG_FILE"
    fi
}

configure_pwquality() {
    log_info "configure_pwquality start"

    sed -i '/^lcredit\|^ucredit\|^dcredit\|^ocredit\|^minlen\|^difok/d' /etc/security/pwquality.conf
    cat <<EOF >> /etc/security/pwquality.conf
lcredit=-1
ucredit=-1
dcredit=-1
ocredit=-1
minlen=8
difok=2
EOF

    log_info "pwquality configured"
}

configure_pam_lockout() {
    log_info "configure_pam_lockout start"
    local pam_file

    for pam_file in /etc/pam.d/system-auth /etc/pam.d/password-auth; do
        sed -i '/pam_tally2.so/d' "$pam_file"
        sed -i '/^auth\s\+required\s\+pam_env.so/a auth        required      pam_tally2.so deny=3 unlock_time=300' "$pam_file"
        sed -i '/^auth\s\+sufficient\s\+pam_unix.so/a auth        [default=die] pam_tally2.so deny=3 unlock_time=300' "$pam_file"
        sed -i '/^account\s\+required\s\+pam_unix.so/a account     required      pam_tally2.so' "$pam_file"
        log_info "pam_tally2 configured: $pam_file"
    done
}

configure_su_restriction() {
    log_info "configure_su_restriction start"
    local su_file="/etc/pam.d/su"

    if ! getent group wheel >/dev/null 2>&1; then
        groupadd wheel || {
            log_error "configure_su_restriction" "wheel group create failed"
            return 1
        }
        log_info "wheel group created"
    fi

    set_file_perms /usr/bin/su root:wheel 4750

    if grep -q '^#auth\s\+required\s\+pam_wheel.so\s\+use_uid' "$su_file"; then
        sed -i 's/^#\(auth\s\+required\s\+pam_wheel.so\s\+use_uid\)/\1/' "$su_file" &&
            log_info "pam_wheel uncommented"
    elif ! grep -q 'pam_wheel.so.*use_uid' "$su_file"; then
        sed -i '/pam_rootok.so/a auth       required    pam_wheel.so use_uid' "$su_file" &&
            log_info "pam_wheel added"
    else
        log_info "pam_wheel already configured"
    fi
}

log_info "accounts hardening start"
remove_unneeded_users
configure_ftp_shell
step1_change_root_password
set_password_policy
create_fallback_and_restrict
configure_pwquality
configure_pam_lockout
configure_su_restriction
log_info "accounts hardening complete"
