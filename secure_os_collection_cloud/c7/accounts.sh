#!/bin/bash
# c7/accounts.sh : 계정 관련
# 제거: root 로그인 차단, 패스워드 만료 정책, 계정 잠금 임계값

source /usr/local/src/secure_os_collection/c7/common.sh

remove_unneeded_users() {
    log_info "remove_unneeded_users 시작"
    for u in lp games ftp sync shutdown halt; do
        if id "$u" &>/dev/null; then
            userdel -r "$u" && { log_info "$u 삭제"; DELETED_USERS+="$u "; } || log_error "remove_unneeded_users" "$u 삭제 실패"
        else
            log_info "$u 없음"
        fi
    done
}

# 유지: ftp 계정 쉘 제한(보안상 권장) – 시스템 정책 유지
configure_ftp_shell() {
    log_info "configure_ftp_shell 시작"
    backup_file /etc/passwd
    if getent passwd ftp >/dev/null; then
        if ! getent passwd ftp | grep -qE '(/bin/false|/sbin/nologin)'; then
            sed -i '/^ftp:/s#\([^:]*:\)\{6\}[^:]*#\1/bin/false#' /etc/passwd \
                || { log_error "configure_ftp_shell" "/etc/passwd 수정 실패"; return 1; }
            log_info "ftp 계정 셸 제한(/bin/false)"
        else
            log_info "ftp 계정 셸 이미 제한"
        fi
    else
        log_info "ftp 계정 없음"
    fi
}

# 실행
remove_unneeded_users
configure_ftp_shell