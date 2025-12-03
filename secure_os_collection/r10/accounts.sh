#!/bin/bash

source /usr/local/src/secure_os_collection/r10/common.sh

# 계정 관련 보안 설정

remove_unneeded_users() {
    log_info "remove_unneeded_users 시작"
    for u in lp games ftp sync shutdown halt; do
        if id "$u" &>/dev/null; then
            if userdel -r "$u"; then
                log_info "$u 계정 삭제 완료"
                DELETED_USERS+="$u "
            else
                log_error "remove_unneeded_users" "$u 계정 삭제 실패"
            fi
        else
            log_info "$u 계정 없음"
        fi
    done
}

configure_ftp_shell() {
    log_info "configure_ftp_shell 시작"
    backup_file /etc/passwd
    if getent passwd ftp | grep -q '/sbin/nologin'; then
        sed -i '/^ftp:/s#/sbin/nologin#/bin/false#' /etc/passwd || {
            log_error "configure_ftp_shell" "/etc/passwd 수정 실패"
            return 1
        }
        log_info "ftp 계정 쉘을 /bin/false로 변경"
        DELETED_USERS+="ftp(쉘 변경) "
    else
        log_info "ftp 계정 추가 조치 불필요"
    fi
}

step1_change_root_password() {
    log_info "step1_change_root_password 시작"
    while true; do
        read -r -s -p "root 비밀번호 입력 (최소 ${MIN_PASSWORD_LENGTH}자): " RootPassword < /dev/tty; echo
        if [ "${#RootPassword}" -lt "$MIN_PASSWORD_LENGTH" ]; then
            echo "  최소 ${MIN_PASSWORD_LENGTH}자 이상 입력해야 합니다."
            continue
        fi
        read -r -s -p "비밀번호 확인: " ConfirmPassword < /dev/tty; echo
        if [ "$RootPassword" != "$ConfirmPassword" ]; then
            echo "  비밀번호가 일치하지 않습니다. 다시 입력하세요."
            continue
        fi
        break
    done
    echo "root:$RootPassword" | chpasswd || {
        log_error "change_root_password" "root 비밀번호 설정 실패"
        exit 1
    }
    passwd -S root >> "$LOG_FILE" || log_error "change_root_password" "root 상태 조회 실패"
    log_info "root 비밀번호 변경 완료"
}

set_password_policy() {
    log_info "set_password_policy 시작"
    read -r -p "비밀번호 만료 정책을 설정하시겠습니까? (Y/N): " ans < /dev/tty
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        echo "다음 항목을 입력하세요. Enter 입력 시 기본값이 적용됩니다."
        read -r -p "1. 최대 사용일수 (기본 90): " max_days < /dev/tty
        read -r -p "2. 최소 길이 (기본 8): " min_len < /dev/tty
        read -r -p "3. 최소 사용일수 (기본 0): " min_days < /dev/tty
        read -r -p "4. 경고 시작일 (기본 7): " warn_days < /dev/tty
        max_days=${max_days:-90}
        min_len=${min_len:-8}
        min_days=${min_days:-0}
        warn_days=${warn_days:-7}

        log_info "비밀번호 정책 설정: 최대 $max_days일, 최소 길이 $min_len, 최소 사용 $min_days일, 경고 $warn_days일"
        PASSWORD_POLICY_SUMMARY="적용됨(최대 $max_days일, 최소 길이 $min_len, 최소 $min_days일, 경고 $warn_days일)"
        mapfile -t user_list < <(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd 2>/dev/null)
        if [ ${#user_list[@]} -eq 0 ]; then
            log_info "정책을 적용할 일반 사용자 계정이 없음"
        fi
        for user in "${user_list[@]}"; do
            chage -M "$max_days" -m "$min_days" -W "$warn_days" "$user" || log_error "set_password_policy" "$user chage 실패"
            log_info "$user 비밀번호 정책 적용"
            chage -l "$user" | grep -E 'Maximum|Minimum|Warning' >> "$LOG_FILE"
        done

        backup_file /etc/login.defs
        sed -i '/^PASS_MAX_DAYS/d' /etc/login.defs
        sed -i '/^PASS_MIN_LEN/d' /etc/login.defs
        sed -i '/^PASS_MIN_DAYS/d' /etc/login.defs
        sed -i '/^PASS_WARN_AGE/d' /etc/login.defs
        {
            echo "PASS_MAX_DAYS   $max_days"
            echo "PASS_MIN_LEN    $min_len"
            echo "PASS_MIN_DAYS   $min_days"
            echo "PASS_WARN_AGE   $warn_days"
        } >> /etc/login.defs || log_error "set_password_policy" "/etc/login.defs 갱신 실패"
        log_info "login.defs 비밀번호 정책 업데이트"
    else
        log_info "비밀번호 만료 정책 설정을 건너뜀"
        PASSWORD_POLICY_SUMMARY="미적용"
    fi
}

add_to_wheel_if_needed() {
    local user="$1"
    if id -nG "$user" | tr ' ' '\n' | grep -qx wheel; then
        log_info "$user 는 이미 wheel 그룹 구성원"
    else
        if usermod -aG wheel "$user"; then
            log_info "$user 를 wheel 그룹에 추가"
        else
            log_error "add_to_wheel" "$user wheel 그룹 추가 실패"
        fi
    fi
}

create_fallback_and_restrict() {
    log_info "create_fallback_and_restrict 시작"
    backup_file /etc/passwd /etc/shadow /etc/ssh/sshd_config /etc/pam.d/su

    mapfile -t existing_users < <(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd 2>/dev/null)
    local UserName=""

    if [ ${#existing_users[@]} -gt 0 ]; then
        log_info "기존 일반 계정 발견: ${existing_users[*]}"
        for user in "${existing_users[@]}"; do
            add_to_wheel_if_needed "$user"
        done
        CREATED_USER="기존 계정 사용(${existing_users[*]})"
        UserName="${existing_users[0]}"
    else
        read -r -p "생성할 운영 계정 이름: " UserName < /dev/tty
        if [ -z "$UserName" ]; then
            log_error "create_user" "계정명이 입력되지 않음"
            CREATED_USER="미생성(계정명 미입력)"
            return 1
        fi
        if id "$UserName" &>/dev/null; then
            log_info "계정 $UserName 이미 존재"
            add_to_wheel_if_needed "$UserName"
            CREATED_USER="$UserName(이미 존재)"
        else
            local UserPassword PasswordConfirm
            while true; do
                read -r -s -p "계정 '$UserName' 비밀번호 입력 (최소 ${MIN_PASSWORD_LENGTH}자): " UserPassword < /dev/tty; echo
                if [ "${#UserPassword}" -lt "$MIN_PASSWORD_LENGTH" ]; then
                    echo "  최소 ${MIN_PASSWORD_LENGTH}자 이상 입력해야 합니다."
                    continue
                fi
                read -r -s -p "비밀번호 확인: " PasswordConfirm < /dev/tty; echo
                if [ "$UserPassword" != "$PasswordConfirm" ]; then
                    echo "  비밀번호가 일치하지 않습니다. 다시 입력하세요."
                    continue
                fi
                break
            done
            if useradd -m -G wheel "$UserName"; then
                echo "$UserName:$UserPassword" | chpasswd || {
                    log_error "create_user" "$UserName 비밀번호 설정 실패"
                    CREATED_USER="미생성(비밀번호 설정 실패)"
                    return 1
                }
                log_info "계정 $UserName 생성 및 비밀번호 설정 완료"
                CREATED_USER="$UserName 생성"
            else
                log_error "create_user" "계정 $UserName 생성 실패"
                CREATED_USER="미생성(계정 생성 실패)"
                return 1
            fi
        fi
    fi

    sed -i -e 's/^#PermitRootLogin.*/PermitRootLogin no/' \
           -e 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config || {
        log_error "restrict_root" "sshd_config 수정 실패"
        return 1
    }

    # Rocky 10 기본 이미지에서 drop-in(01-permitrootlogin.conf)에 PermitRootLogin yes가 남을 수 있어 no로 덮어쓴다.
    log_info "root 원격 로그인 차단 적용"
    local dropin_dir="/etc/ssh/sshd_config.d"
    local dropin_file="${dropin_dir}/01-permitrootlogin.conf"
    if mkdir -p "$dropin_dir"; then
        [ -f "$dropin_file" ] && backup_file "$dropin_file"
        cat <<'EOF' > "$dropin_file"
PermitRootLogin no
EOF
        log_info "sshd drop-in(${dropin_file})에 PermitRootLogin no 적용"
    else
        log_error "restrict_root" "sshd_config.d 디렉터리 생성 실패"
        return 1
    fi
    restarts_needed["sshd"]=1

    if [ -n "$UserName" ]; then
        {
            echo ">>> 계정 $UserName 상태:"; passwd -S "$UserName"
            echo ">>> 계정 $UserName 그룹:"; groups "$UserName"
            echo ">>> 홈 디렉터리 정보:"; ls -ld "/home/$UserName"
        } >> "$LOG_FILE"
    fi
}

configure_pwquality() {
    log_info "configure_pwquality 시작"
    backup_file /etc/security/pwquality.conf
    sed -i '/^lcredit\|^ucredit\|^dcredit\|^ocredit\|^minlen\|^difok/d' /etc/security/pwquality.conf
    cat <<EOF >> /etc/security/pwquality.conf
lcredit=-1
ucredit=-1
dcredit=-1
ocredit=-1
minlen=8
difok=2
EOF
    log_info "pwquality.conf 갱신 완료"
}

configure_pam_lockout() {
    log_info "configure_pam_lockout 시작"
    if ! authselect check >/dev/null 2>&1; then
        log_info "authselect 구성이 없어 기본 프로파일 선택"
        authselect select sssd --force || { log_error "pam_lockout" "authselect select 실패"; return 1; }
    fi

    authselect enable-feature with-faillock >/dev/null 2>&1 || true
    authselect enable-feature with-pwquality >/dev/null 2>&1 || true
    authselect apply-changes || { log_error "pam_lockout" "authselect 적용 실패"; return 1; }

    for pam_file in /etc/pam.d/password-auth /etc/pam.d/system-auth; do
        if [ ! -L "$pam_file" ]; then
            log_error "pam_lockout" "$pam_file 심볼릭 링크가 아님"
            return 1
        fi
        if ! grep -q 'pam_faillock.so' "$pam_file"; then
            log_error "pam_lockout" "$pam_file 에 pam_faillock 설정 없음"
            return 1
        fi
        log_info "$pam_file 검사 완료"
    done
}

configure_su_restriction() {
    log_info "configure_su_restriction 시작"
    local su_file="/etc/pam.d/su"
    backup_file "$su_file"
    if ! getent group wheel >/dev/null; then
        groupadd wheel && log_info "wheel 그룹 생성" || { log_error "configure_su_restriction" "wheel 그룹 생성 실패"; return 1; }
    fi
    set_file_perms /usr/bin/su root:wheel 4750
    if grep -q '^#auth\s\+required\s\+pam_wheel.so\s\+use_uid' "$su_file"; then
        sed -i 's/^#\(auth\s\+required\s\+pam_wheel.so\s\+use_uid\)/\1/' "$su_file" && log_info "pam_wheel.so use_uid 주석 해제"
    elif ! grep -q 'pam_wheel.so.*use_uid' "$su_file"; then
        sed -i '/pam_rootok.so/a auth       required    pam_wheel.so use_uid' "$su_file" && log_info "pam_wheel.so use_uid 설정 추가"
    else
        log_info "pam_wheel.so use_uid 이미 적용됨"
    fi
    authselect apply-changes || { log_error "su_restriction" "authselect 적용 실패"; return 1; }
}

enable_wheel_in_sudoers() {
    log_info "enable_wheel_in_sudoers 시작"
    backup_file /etc/sudoers
    if grep -Eq '^[[:space:]]*#?[[:space:]]*%wheel' /etc/sudoers; then
        sed -i 's/^#\s*\(%wheel\s\+ALL=(ALL).*\)/\1/' /etc/sudoers
        log_info "sudoers의 wheel 항목 활성화"
    else
        echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers
        log_info "sudoers에 wheel 항목 추가"
    fi
    if ! visudo -c >/dev/null 2>&1; then
        log_error "enable_wheel_in_sudoers" "sudoers 구문 검사 실패"
        return 1
    fi
}

log_info "계정 보안 작업 시작"
remove_unneeded_users
configure_ftp_shell
step1_change_root_password
set_password_policy
create_fallback_and_restrict
configure_pwquality
configure_pam_lockout
configure_su_restriction
enable_wheel_in_sudoers
log_info "계정 보안 작업 완료"
