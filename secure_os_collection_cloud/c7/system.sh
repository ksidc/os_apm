#!/bin/bash
# c7/system.sh : 시스템 기본 설정
# 제거: chrony/rsyslog/SELinux 설정, /etc/profile(HISTTIMEFORMAT/TMOUT), SSH 포트 변경

source /usr/local/src/secure_os_collection/c7/common.sh

install_packages() {
    log_info "install_packages 시작"
    # 꼭 필요한 기본 유틸만 설치 (chrony/rsyslog 제외)
    local pkgs=(epel-release lsof net-tools psmisc lrzsz screen iftop smartmontools vim unzip wget)
    for pkg in "${pkgs[@]}"; do
        if rpm -q "$pkg" &>/dev/null; then
            log_info "$pkg 이미 설치됨"
        else
            yum install -y "$pkg" || { log_error "install_packages" "$pkg 설치 실패"; exit 1; }
            log_info "$pkg 설치 성공"
        fi
    done
}

# 유지: 핵심 파일 권한 강화
configure_etc_perms() {
    log_info "configure_etc_perms 시작"
    backup_file /etc/passwd /etc/shadow /etc/hosts /usr/bin/su
    set_file_perms /etc/passwd root:root 644
    set_file_perms /etc/shadow root:root 400
    set_file_perms /etc/hosts  root:root 600
    if ! getent group wheel >/dev/null; then
        groupadd wheel || { log_error "configure_etc_perms" "wheel group 생성 실패"; exit 1; }
        log_info "wheel group 생성"
    else
        log_info "wheel group 이미 존재"
    fi
    chown root:wheel /usr/bin/su && chmod 4750 /usr/bin/su || { log_error "configure_etc_perms" "/usr/bin/su 설정 실패"; exit 1; }
    log_info "/usr/bin/su 소유자/권한 설정 완료"
}

# 유지: 배너(MOTD) 고지
configure_motd() {
    log_info "configure_motd 시작"
    backup_file /etc/motd
    cat <<'EOF' > /etc/motd
********************************************************************
* 본 시스템은 허가된 사용자만 이용하실 수 있습니다.               *
* 부당한 접속/정보 변경·유출 시 관련 법령에 따라 처벌될 수 있습니다. *
********************************************************************
EOF
    log_info "motd 설정 완료"
}

# 실행
install_packages
configure_etc_perms
configure_motd