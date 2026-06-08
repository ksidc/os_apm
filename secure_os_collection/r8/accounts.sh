#!/bin/bash

source /usr/local/src/secure_os_collection/r8/common.sh

# 계정 관련 작업
remove_unneeded_users() {
    log_info "remove_unneeded_users 시작"
    for u in lp games ftp sync shutdown halt; do
        if id "$u" &>/dev/null; then
            userdel -r "$u" && { log_info "$u 삭제 성공"; DELETED_USERS+="$u "; } || log_error "remove_unneeded_users" "$u 삭제 실패"
        else
            log_info "$u 없음"
        fi
    done
}

configure_ftp_shell() {
    log_info "configure_ftp_shell 시작"
    if getent passwd ftp | grep -q '/sbin/nologin'; then
        sed -i '/^ftp:/s#/sbin/nologin#/bin/false#' /etc/passwd \
            || { log_error "configure_ftp_shell" "/etc/passwd 수정 실패"; return 1; }
        log_info "ftp 계정 셸을 /bin/false로 변경"
        DELETED_USERS+="ftp (셸 변경) "
    else
        log_info "ftp 계정 셸 변경 불필요 또는 이미 적용"
    fi
}

step1_change_root_password() {
    log_info "step1_change_root_password 시작"
    while true; do
        read -r -s -p "root 비밀번호 입력 (최소 ${MIN_PASSWORD_LENGTH}자): " RootPassword < /dev/tty; echo
        if [ "${#RootPassword}" -lt "$MIN_PASSWORD_LENGTH" ]; then
            echo "  → 비밀번호는 최소 ${MIN_PASSWORD_LENGTH}자 이상이어야 합니다."
            continue
        fi
        read -r -s -p "비밀번호 확인: " ConfirmPassword < /dev/tty; echo
        if [ "$RootPassword" != "$ConfirmPassword" ]; then
            echo "  → 비밀번호가 일치하지 않습니다. 다시 입력해주세요."
            continue
        fi
        break
    done
    echo "root:$RootPassword" | chpasswd \
        || { log_error "change_root_password" "root 비밀번호 설정 실패"; exit 1; }
    passwd -S root >> "$LOG_FILE" \
        || log_error "change_root_password" "root 상태 조회 실패"
    log_info "root 비밀번호 설정 완료"
}

# ────────────────────────────────────────────────────────────
# [2026 수정] U-02: 비밀번호 정책 — 기본값을 2026 기준으로 변경
# ────────────────────────────────────────────────────────────
set_password_policy() {
    log_info "set_password_policy 시작"
    read -r -p "패스워드 만료 정책을 설정하시겠습니까? (Y/N): " ans < /dev/tty
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        echo "다음 항목에 대해 값을 입력합니다. (Enter 입력 시 기본값 적용)"
        read -r -p "1. 최대 사용일수 (default: 90): " max_days < /dev/tty
        read -r -p "2. 최소 길이 (default: 8): " min_len < /dev/tty
        read -r -p "3. 최소 사용일수 (default: 1): " min_days < /dev/tty
        read -r -p "4. 경고일수 (default: 7): " warn_days < /dev/tty
        max_days=${max_days:-90}
        min_len=${min_len:-8}
        min_days=${min_days:-1}
        warn_days=${warn_days:-7}

        log_info "패스워드 정책 설정: 최대 $max_days일, 최소 길이 $min_len, 최소 $min_days일, 경고 $warn_days일"
        PASSWORD_POLICY_SUMMARY="적용됨 (최대 $max_days일, 최소 길이 $min_len, 최소 $min_days일, 경고 $warn_days일)"
        local user_list
        user_list=($(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd 2>/dev/null)) || { 
            log_error "set_password_policy" "사용자 목록 조회 실패"; exit 1; 
        }
        for user in "${user_list[@]}"; do
            chage -M "$max_days" -m "$min_days" -W "$warn_days" "$user" \
                || log_error "set_password_policy" "사용자 $user 설정 실패"
            log_info "$user 설정 완료"
            chage -l "$user" | grep -E 'Maximum|Minimum|Warning' >> "$LOG_FILE"
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
        } >> /etc/login.defs \
            || log_error "set_password_policy" "/etc/login.defs 설정 실패"
        log_info "/etc/login.defs 설정 완료"
    else
        log_info "패스워드 만료 정책 설정 생략"
        PASSWORD_POLICY_SUMMARY="미적용"
    fi
}

create_fallback_and_restrict() {
    log_info "create_fallback_and_restrict 시작"
    local existing
    existing=$(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd 2>/dev/null) || { 
        log_error "create_fallback_and_restrict" "기존 계정 조회 실패"
        CREATED_USER="미생성 (계정 조회 실패)"
        return 1
    }
    log_info "기존 일반 계정 확인: ${existing:-없음}"
    if [ -n "$existing" ]; then
        log_info "기존 일반 계정 발견: $existing"
        read -r -p "새 계정 생성 없이 넘어가시겠습니까? (Y/N): " yn < /dev/tty
        if [[ "$yn" =~ ^[Yy]$ ]]; then
            log_info "계정 생성 건너뜀"
            CREATED_USER="미생성 (기존 계정: $existing)"
            return
        fi
    fi

    read -r -p "생성할 일반 계정명 입력: " UserName < /dev/tty
    if [ -z "$UserName" ]; then
        log_error "create_user" "계정명을 입력해야 합니다"
        CREATED_USER="미생성 (계정명 입력 없음)"
        return 1
    fi
    if id "$UserName" &>/dev/null; then
        log_info "계정 $UserName 이미 존재"
        CREATED_USER="$UserName (이미 존재)"
    else
        local UserPassword PasswordConfirm
        while true; do
            read -r -s -p "계정 '$UserName' 비밀번호 입력 (최소 ${MIN_PASSWORD_LENGTH}자): " UserPassword < /dev/tty; echo
            if [ "${#UserPassword}" -lt "$MIN_PASSWORD_LENGTH" ]; then
                echo "  → 최소 ${MIN_PASSWORD_LENGTH}자 이상이어야 합니다."
                continue
            fi
            read -r -s -p "비밀번호 확인: " PasswordConfirm < /dev/tty; echo
            if [ "$UserPassword" != "$PasswordConfirm" ]; then
                echo "  → 비밀번호 불일치, 다시 입력해주세요."
                continue
            fi
            break
        done
        useradd -m -G wheel "$UserName" \
            || { log_error "create_user" "계정 $UserName 생성 실패"; CREATED_USER="미생성 (생성 실패)"; return 1; }
        echo "$UserName:$UserPassword" | chpasswd \
            || { log_error "create_user" "계정 $UserName 비밀번호 설정 실패"; CREATED_USER="미생성 (비밀번호 설정 실패)"; return 1; }
        log_info "계정 $UserName 생성 및 비밀번호 설정 완료"
        CREATED_USER="$UserName 생성됨"
    fi

    sed -i -e 's/^#PermitRootLogin.*/PermitRootLogin no/' \
           -e 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
        || { log_error "restrict_root" "sshd_config 수정 실패"; return 1; }
    log_info "root 원격 로그인 제한 적용"
    restarts_needed["sshd"]=1

    local dropin_dir="/etc/ssh/sshd_config.d"
    local dropin_file="$dropin_dir/01-permitrootlogin.conf"
    if mkdir -p "$dropin_dir"; then
        cat <<'EOF' > "$dropin_file"
PermitRootLogin no
EOF
        log_info "sshd drop-in (${dropin_file})에 PermitRootLogin no 적용"
    else
        log_error "restrict_root" "sshd_config.d 디렉터리 생성 실패"
        return 1
    fi

    {
        echo ">>> 계정 $UserName 상태:"; passwd -S "$UserName"
        echo ">>> 계정 $UserName 그룹:"; groups "$UserName"
        echo ">>> 홈 디렉토리 권한:"; ls -ld "/home/$UserName"
    } >> "$LOG_FILE"
}

# ────────────────────────────────────────────────────────────
# [2026 수정] U-02: pwquality — enforce_for_root 추가
# ────────────────────────────────────────────────────────────
configure_pwquality() {
    log_info "configure_pwquality 시작"
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
    log_info "pwquality.conf 설정 완료 (enforce_for_root 포함)"
}

# ────────────────────────────────────────────────────────────
# [2026 신규] U-02: pwhistory.conf 생성 — 비밀번호 이력 관리
# ────────────────────────────────────────────────────────────
configure_pwhistory() {
    log_info "configure_pwhistory 시작"
    cat <<EOF > /etc/security/pwhistory.conf
enforce_for_root
remember=4
file = /etc/security/opasswd
EOF
    [ -f /etc/security/opasswd ] || touch /etc/security/opasswd
    chmod 600 /etc/security/opasswd
    chown root:root /etc/security/opasswd
    log_info "pwhistory.conf 설정 완료 (remember=4, enforce_for_root)"
}

# ────────────────────────────────────────────────────────────
# [2026 수정] U-03: faillock.conf — deny=3, unlock_time=300 명시
# ────────────────────────────────────────────────────────────
configure_pam_lockout() {
    log_info "configure_pam_lockout 시작"
    if ! authselect check >/dev/null 2>&1; then
        log_info "authselect check 실패 → 프로필 강제 선택"
        authselect select sssd --force || { log_error "pam_lockout" "authselect select 실패"; return 1; }
    fi

    authselect enable-feature with-faillock >/dev/null 2>&1 || true
    authselect enable-feature with-pwquality >/dev/null 2>&1 || true
    authselect apply-changes || { log_error "pam_lockout" "authselect 적용 실패"; return 1; }

    local fconf="/etc/security/faillock.conf"
    if [ -f "$fconf" ]; then
        sed -i '/^deny/d; /^unlock_time/d; /^silent/d; /^audit/d' "$fconf"
    fi
    cat <<EOF >> "$fconf"
silent
audit
deny = 3
unlock_time = 300
EOF
    log_info "faillock.conf 설정 완료 (deny=3, unlock_time=300)"

    for pam_file in /etc/pam.d/password-auth /etc/pam.d/system-auth; do
        if [ ! -L "$pam_file" ]; then
            log_error "pam_lockout" "$pam_file 가 심볼릭 링크가 아님(비정상)"
            return 1
        fi
        if ! grep -q 'pam_faillock.so' "$pam_file"; then
            log_error "pam_lockout" "$pam_file 에 pam_faillock 라인이 보이지 않음"
            return 1
        fi
        log_info "$pam_file 검증 OK"
    done
}

# ────────────────────────────────────────────────────────────
# [2026 수정] U-06: su 제한 — authselect 이후 su 권한 재설정
# ────────────────────────────────────────────────────────────
configure_su_restriction() {
    log_info "configure_su_restriction 시작"
    local su_file="/etc/pam.d/su"
    if ! getent group wheel >/dev/null; then
        groupadd wheel && log_info "wheel group 생성" \
            || { log_error "configure_su_restriction" "wheel group 생성 실패"; return 1; }
    fi
    if grep -q '^#auth\s\+required\s\+pam_wheel.so\s\+use_uid' "$su_file"; then
        sed -i 's/^#\(auth\s\+required\s\+pam_wheel.so\s\+use_uid\)/\1/' "$su_file" \
            && log_info "pam_wheel.so use_uid 라인 활성화 완료"
    elif ! grep -q 'pam_wheel.so.*use_uid' "$su_file"; then
        sed -i '/pam_rootok.so/a auth       required    pam_wheel.so use_uid' "$su_file" \
            && log_info "pam_wheel.so use_uid 라인 추가 완료"
    else
        log_info "pam_wheel.so use_uid 설정 이미 적용됨"
    fi
    authselect apply-changes || { log_error "su_restriction" "authselect 적용 실패"; return 1; }

    chown root:wheel /usr/bin/su && chmod 4750 /usr/bin/su \
        && log_info "/usr/bin/su 권한 4750:wheel 재설정 완료" \
        || log_error "configure_su_restriction" "/usr/bin/su 권한 설정 실패"
}

# 계정 관련 작업 실행
log_info "계정 관련 작업 시작"
remove_unneeded_users
configure_ftp_shell
step1_change_root_password
set_password_policy
create_fallback_and_restrict
configure_pwquality
configure_pwhistory
configure_pam_lockout
configure_su_restriction
log_info "계정 관련 작업 완료"
