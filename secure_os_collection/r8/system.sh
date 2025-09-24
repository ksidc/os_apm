#!/bin/bash

source /usr/local/src/secure_os_collection/r8/common.sh

# 시스템 설정 관련 작업
install_packages() {
    log_info "install_packages 시작"
    local pkgs=(epel-release chrony pandoc iptables iptables-services rsyslog lsof net-tools psmisc lrzsz screen iftop smartmontools vim unzip wget)
    for pkg in "${pkgs[@]}"; do
        if rpm -q "$pkg" &>/dev/null; then
            log_info "$pkg 이미 설치됨"
        else
            dnf install -y "$pkg" || { log_error "install_packages" "$pkg 설치 실패"; exit 1; }
            log_info "$pkg 설치 성공"
        fi
    done
}

configure_ntp() {
    log_info "configure_ntp 시작"
    backup_file /etc/chrony.conf /etc/cron.d/chrony_makestep
    dnf install -y chrony || { log_error "configure_ntp" "chrony 설치 실패"; exit 1; }
    log_info "chrony 설치 성공"
    systemctl enable --now chronyd || { log_error "configure_ntp" "chronyd 시작 실패"; exit 1; }
    log_info "chronyd 시작 성공"
    sed -i '/^server /d' /etc/chrony.conf
    echo "server $NTP_SERVER iburst" >> /etc/chrony.conf
    restarts_needed["chronyd"]=1
    chronyc makestep || log_error "configure_ntp" "즉시 동기화 실패"
    if [ ! -f /etc/cron.d/chrony_makestep ]; then
        echo "0 4 * * * root /usr/bin/chronyc makestep" > /etc/cron.d/chrony_makestep
        chmod 600 /etc/cron.d/chrony_makestep
        log_info "chrony makestep 크론 작업 추가"
    else
        log_info "chrony makestep 크론 작업 이미 존재"
    fi
}

configure_history_timeout() {
    log_info "configure_history_timeout 시작"
    backup_file /etc/profile
    grep -q HISTTIMEFORMAT /etc/profile || echo 'export HISTTIMEFORMAT="%Y-%m-%d[%H:%M:%S] "' >> /etc/profile
    grep -q TMOUT /etc/profile || echo 'export TMOUT=600' >> /etc/profile
    log_info "히스토리 및 타임아웃 설정 완료"
}

configure_etc_perms() {
    log_info "configure_etc_perms 시작"
    backup_file /etc/passwd /etc/shadow /etc/hosts /usr/bin/su
    set_file_perms /etc/passwd root:root 644
    set_file_perms /etc/shadow root:root 400
    set_file_perms /etc/hosts root:root 600
    set_file_perms /usr/bin/su root:wheel 4750
    if ! getent group wheel >/dev/null; then
        groupadd wheel && log_info "wheel group 생성" \
            || { log_error "configure_etc_perms" "wheel group 생성 실패"; exit 1; }
    else
        log_info "wheel group 이미 존재"
    fi
    if [ "$(stat -c '%a' /usr/bin/su)" = "4750" ] && [ "$(stat -c '%U:%G' /usr/bin/su)" = "root:wheel" ]; then
        log_info "/usr/bin/su 권한 및 소유자 설정 확인 완료"
    else
        log_error "configure_etc_perms" "/usr/bin/su 권한 또는 소유자 설정 실패"; exit 1
    fi
}

configure_file_permissions() {
    log_info "configure_file_permissions 시작"
    backup_file /sbin/unix_chkpwd /usr/bin/newgrp /usr/bin/perl /usr/bin/screen /usr/bin/wget /usr/bin/curl
    chmod -s /sbin/unix_chkpwd || log_error "configure_file_permissions" "unix_chkpwd setuid 제거 실패"
    chmod -s /usr/bin/newgrp || log_error "configure_file_permissions" "newgrp setuid 제거 실패"
    for f in /usr/bin/perl /usr/bin/screen /usr/bin/wget /usr/bin/curl; do
        set_file_perms "$f" root:root 700
    done
    log_info "파일 권한 설정 완료"
}

configure_motd() {
    log_info "configure_motd 시작"
    backup_file /etc/motd
    cat <<'EOF' > /etc/motd
********************************************************************
* 본 시스템은 허가된 사용자만 이용하실 수 있습니다.                    *
* 부당한 방법으로 전산망에 접속하거나 정보를 삭제/변경/유출하는        *
* 사용자는 관련 법령에 따라 처벌 받게 됩니다.                          *
********************************************************************
EOF
    log_info "motd 설정 완료"
}

configure_bash_vim() {
    log_info "configure_bash_vim 시작"
    backup_file /root/.bashrc /root/.vimrc
    for a in "alias vi='vim'" "alias grep='grep --color=auto'" "alias ll='ls -alF --color=tty'"; do
        grep -qF "$a" /root/.bashrc || echo "$a" >> /root/.bashrc
    done
    cat <<'EOF' > /root/.vimrc
set ignorecase
set cindent
set sw=4 ts=4 sts=4 shiftwidth=4
set showmode bg=dark paste ruler expandtab linebreak wrap showcmd
set laststatus=2 textwidth=80 wm=1 smartcase smartindent ttyfast
EOF
    log_info "bashrc 및 vim 설정 완료"
}

step2_change_ssh_port() {
    log_info "step2_change_ssh_port 시작"
    local old_port
    old_port=$(grep -i '^Port' /etc/ssh/sshd_config | awk '{print $2}' | head -1)
    [[ -z "$old_port" ]] && old_port=22

    local max_retries=3
    local new_port
    echo "현재 SSH 포트: $old_port, 권장 기본값: 38371 (설치 초기 기본은 22)"
    for ((i=1; i<=max_retries; i++)); do
        read -r -p "변경할 포트를 입력하세요 (Enter로 권장 38371 사용, $i/$max_retries): " new_port < /dev/tty
        new_port=${new_port:-38371}
        if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1 ] && [ "$new_port" -le 65535 ]; then
            break
        fi
        echo "오류: 유효한 포트 번호(1-65535)를 입력하세요."
        [ "$i" -eq "$max_retries" ] && { log_error "change_ssh_port" "유효한 포트 번호 입력 실패"; exit 1; }
    done

    if [[ "$new_port" == "$old_port" ]]; then
        echo "입력한 포트가 현재 포트와 동일합니다."
        read -r -p "변경 없이 진행? (Y/N): " proceed < /dev/tty
        if [[ "$proceed" =~ ^[Yy]$ ]]; then
            log_info "SSH 포트 변경 생략"
            NEW_SSH_PORT="$old_port (변경 없음)"
            return
        else
            step2_change_ssh_port
            return
        fi
    fi

    backup_file /etc/ssh/sshd_config
    sed -i "/^#Port /c\Port $new_port" /etc/ssh/sshd_config
    sed -i "/^Port /c\Port $new_port" /etc/ssh/sshd_config
    sshd -t || { log_error "change_ssh_port" "SSHD 설정 파일 오류"; exit 1; }
    log_info "SSH 포트 $new_port로 변경"
    NEW_SSH_PORT="$new_port"
    restarts_needed["sshd"]=1
}


configure_sysctl() {
    log_info "configure_sysctl 시작"
    backup_file /etc/sysctl.conf
    cat <<EOF > /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.tcp_rmem = 4096 10000000 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 1800
net.ipv4.tcp_max_syn_backlog = 4096
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.somaxconn = 10240
net.ipv4.ip_local_port_range = 4000 65535
EOF
    sysctl -p || log_error "sysctl" "적용 실패"
    log_info "sysctl 설정 완료"
}

configure_limits() {
    log_info "configure_limits 시작"
    backup_file /etc/security/limits.conf
    cat <<EOF > /etc/security/limits.conf
* soft nofile 61200
* hard nofile 61200
* soft nproc 61200
* hard nproc 61200
EOF
    log_info "limits.conf 설정 완료"
}

configure_rc_local() {
    log_info "configure_rc_local 시작"
    backup_file /etc/rc.d/rc.local
    chmod +x /etc/rc.d/rc.local || log_error "rc_local" "chmod 실패"
    systemctl enable rc-local &>/dev/null || log_error "rc_local" "enable 실패"
    log_info "rc.local 활성화 완료"
}

configure_rsyslog() {
    log_info "configure_rsyslog 시작"
    backup_file /etc/rsyslog.conf
    chown root:root /etc/rsyslog.conf \
        || log_error "configure_rsyslog" "/etc/rsyslog.conf 소유자 설정 실패"
    chmod 640 /etc/rsyslog.conf \
        || log_error "configure_rsyslog" "/etc/rsyslog.conf 권한 설정 실패"
    RSYSLOG_LINE="*.* @$RSYSLOG_SERVER"
    grep -qxF "$RSYSLOG_LINE" /etc/rsyslog.conf || echo "$RSYSLOG_LINE" >> /etc/rsyslog.conf
    restarts_needed["rsyslog"]=1
    log_info "rsyslog 설정 완료"
}

disable_selinux() {
    log_info "disable_selinux 시작"
    backup_file /etc/selinux/config
    setenforce 0 || log_error "selinux" "setenforce 실패"
    sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
    log_info "SELinux 비활성화 완료"
}

# 시스템 설정 실행
log_info "시스템 설정 작업 시작"
install_packages
configure_ntp
configure_history_timeout
configure_etc_perms
configure_file_permissions
configure_motd
configure_bash_vim
step2_change_ssh_port
configure_sysctl
configure_limits
configure_rc_local
configure_rsyslog
disable_selinux
log_info "시스템 설정 작업 완료"