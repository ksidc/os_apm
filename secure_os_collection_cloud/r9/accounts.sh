#!/bin/bash
# 계정 최소 정리 (입력無)
# 제외: root 원격차단, 패스워드 만료/복잡도, faillock, 신규계정 생성, 백업

source /usr/local/src/secure_os_collection/r9/common.sh

remove_unneeded_users() {
    log_info "remove_unneeded_users 시작"
    for u in lp games sync shutdown halt; do
        if id "$u" &>/dev/null; then
            userdel -r "$u" && log_info "$u 삭제" || log_error "remove_unneeded_users" "$u 삭제 실패"
        else
            log_info "$u 없음"
        fi
    done
    log_info "remove_unneeded_users 완료"
}

configure_ftp_shell() {
    log_info "configure_ftp_shell 시작"
    if id ftp &>/dev/null; then
        usermod -s /sbin/nologin ftp 2>/dev/null || true
        log_info "ftp 로그인 쉘 제한 적용"
    else
        log_info "ftp 계정 없음"
    fi
    log_info "configure_ftp_shell 완료"
}

log_info "계정 설정 시작"
remove_unneeded_users
configure_ftp_shell
log_info "계정 설정 완료"