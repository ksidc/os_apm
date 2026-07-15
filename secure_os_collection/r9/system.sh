#!/bin/bash

source /usr/local/src/secure_os_collection/r9/common.sh

# 기본 운영 도구와 Snoopy 소스 빌드에 필요한 패키지를 설치한다.
install_packages() {
    local pkgs=(epel-release chrony rsyslog sysstat lsof net-tools psmisc lrzsz screen iftop smartmontools vim unzip wget gcc make autoconf automake libtool)
    local pkg

    for pkg in "${pkgs[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            dnf install -y "$pkg" || {
                echo "ERROR: $pkg 설치 실패" >&2
                exit 1
            }
        fi
    done
}

# chrony를 설치하고 지정 NTP 서버와 정기 makestep 작업을 설정한다.
configure_ntp() {
    dnf install -y chrony || { echo "ERROR: chrony 설치 실패" >&2; exit 1; }
    systemctl enable --now chronyd || { echo "ERROR: chronyd 시작 실패" >&2; exit 1; }
    sed -i '/^server /d' /etc/chrony.conf
    echo "server $NTP_SERVER iburst" >> /etc/chrony.conf
    restarts_needed["chronyd"]=1
    chronyc makestep >/dev/null 2>&1 || true
    if [ ! -f /etc/cron.d/chrony_makestep ]; then
        echo "0 4 * * * root /usr/bin/chronyc makestep" > /etc/cron.d/chrony_makestep
        chmod 600 /etc/cron.d/chrony_makestep
    fi
}

# sysstat 수집 서비스 또는 timer를 활성화해 성능 지표 수집을 켠다.
configure_sysstat() {
    local unit_enabled=0

    if ! rpm -q sysstat >/dev/null 2>&1; then
        echo "ERROR: sysstat 패키지가 설치되어 있지 않습니다." >&2
        exit 1
    fi

    if systemctl list-unit-files | grep -q '^sysstat.service'; then
        systemctl enable --now sysstat >/dev/null 2>&1 || {
            echo "ERROR: sysstat 서비스 활성화 실패" >&2
            exit 1
        }
        unit_enabled=1
    fi

    if systemctl list-unit-files | grep -q '^sysstat-collect.timer'; then
        systemctl enable --now sysstat-collect.timer >/dev/null 2>&1 || {
            echo "ERROR: sysstat-collect.timer 활성화 실패" >&2
            exit 1
        }
        unit_enabled=1
    fi

    if systemctl list-unit-files | grep -q '^sysstat-summary.timer'; then
        systemctl enable --now sysstat-summary.timer >/dev/null 2>&1 || {
            echo "ERROR: sysstat-summary.timer 활성화 실패" >&2
            exit 1
        }
        unit_enabled=1
    fi

    if [ "$unit_enabled" -eq 0 ]; then
        echo "ERROR: 활성화할 sysstat 서비스 또는 timer 유닛을 찾지 못했습니다." >&2
        exit 1
    fi
}

# root 셸 환경에 명령 이력 시간 표시와 세션 타임아웃을 적용한다.
configure_history_timeout() {
    sed -i '/^[[:space:]]*\(export[[:space:]]\+\)\?HISTTIMEFORMAT=/d; /^[[:space:]]*\(export[[:space:]]\+\)\?TMOUT=/d' /etc/profile
    echo 'export HISTTIMEFORMAT="%Y-%m-%d[%H:%M:%S] "' >> /etc/profile
    echo 'export TMOUT=600' >> /etc/profile
}

# 주요 시스템 파일과 su 명령의 소유자/권한을 보안 기준으로 맞춘다.
configure_etc_perms() {
    set_file_perms /etc/passwd root:root 644
    set_file_perms /etc/shadow root:root 400
    set_file_perms /etc/hosts root:root 600
    if ! getent group wheel >/dev/null; then
        groupadd wheel || { echo "ERROR: wheel group 생성 실패" >&2; exit 1; }
    fi
    set_file_perms /usr/bin/su root:wheel 4750
    if [ "$(stat -c '%a' /usr/bin/su)" != "4750" ] || [ "$(stat -c '%U:%G' /usr/bin/su)" != "root:wheel" ]; then
        echo "ERROR: /usr/bin/su 권한 또는 소유자 설정 실패" >&2
        exit 1
    fi
}

# 불필요한 setuid 권한을 제거하고 주요 도구 실행 권한을 제한한다.
configure_file_permissions() {
    chmod -s /sbin/unix_chkpwd || { echo "ERROR: unix_chkpwd setuid 제거 실패" >&2; exit 1; }
    chmod -s /usr/bin/newgrp || { echo "ERROR: newgrp setuid 제거 실패" >&2; exit 1; }
    for f in /usr/bin/perl /usr/bin/screen /usr/bin/wget /usr/bin/curl; do
        [ -f "$f" ] && set_file_perms "$f" root:root 700
    done
}

# 로그인 배너에 접근 경고와 스크립트 버전 정보를 표시한다.
configure_motd() {
    SCRIPT_VERSION="unknown"
    if [[ -f /usr/local/src/secure_os_collection/version.conf ]]; then
        source /usr/local/src/secure_os_collection/version.conf
    fi

    cat <<EOF > /etc/motd
********************************************************************
*                                                                  *
* 본 시스템은 허가된 사용자만 이용하실 수 있습니다.                *
* 부당한 방법으로 전산망에 접속하거나 정보를 삭제/변경/유출하는    *
* 관련 법령에 따라 처벌 받게 됩니다.                               *
*                                                                  *
* This system is for the use of authorized users only.  Usage of   *
* this system may be monitored and recorded by system personnel.   *
*                                                                  *
* Anyone using this system expressly consents to such monitoring   *
* and is advised that if such monitoring reveals possible          *
* evidence of criminal activity, system personnel may provide the  *
* evidence from such monitoring to law enforcement officials.      *
*                                                                  *
* Apply version ${SCRIPT_VERSION}                                  *
********************************************************************
EOF
}

# root 계정의 기본 alias와 vim 설정을 표준 운영값으로 맞춘다.
configure_bash_vim() {
    local alias_line

    for alias_line in "alias vi='vim'" "alias grep='grep --color=auto'" "alias ll='ls -alF --color=tty'"; do
        grep -qF "$alias_line" /root/.bashrc || echo "$alias_line" >> /root/.bashrc
    done
    cat <<'EOF' > /root/.vimrc
set ignorecase
set cindent
set sw=4 ts=4 sts=4 shiftwidth=4
set showmode bg=dark paste ruler expandtab linebreak wrap showcmd
set laststatus=2 textwidth=80 wm=1 smartcase smartindent ttyfast
EOF
}

# SSH 포트를 입력받아 sshd_config에 반영하고 설정 문법을 검증한다.
step2_change_ssh_port() {
    local old_port
    old_port=$(grep -i '^Port' /etc/ssh/sshd_config | awk '{print $2}' | head -1)
    [[ -z "$old_port" ]] && old_port=22

    local new_port
    echo "현재 SSH 포트: $old_port, 권장 기본값: 38371 (설치 초기 기본은 22)"
    while true; do
        read -r -p "변경할 포트를 입력하세요 (Enter로 권장 38371 사용): " new_port < /dev/tty
        new_port=${new_port:-38371}
        if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1 ] && [ "$new_port" -le 65535 ]; then
            break
        fi
        echo "오류: 유효한 포트 번호(1-65535)를 입력하세요."
    done

    if [[ "$new_port" == "$old_port" ]]; then
        echo "입력한 포트가 현재 포트와 동일합니다."
        read -r -p "변경 없이 진행? (Y/N): " proceed < /dev/tty
        if [[ "$proceed" =~ ^[Yy]$ ]]; then
            NEW_SSH_PORT="$old_port"
            return
        else
            step2_change_ssh_port
            return
        fi
    fi

    sed -i "/^#Port /c\Port $new_port" /etc/ssh/sshd_config
    sed -i "/^Port /c\Port $new_port" /etc/ssh/sshd_config
    sshd -t || { echo "ERROR: SSHD 설정 파일 오류" >&2; exit 1; }
    NEW_SSH_PORT="$new_port"
    restarts_needed["sshd"]=1
}

# 네트워크와 커널 관련 sysctl 값을 기준 설정으로 덮어쓴다.
configure_sysctl() {
    cat <<EOF > /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.tcp_rmem = 4096 10000000 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 1800
net.ipv4.tcp_max_syn_backlog = 4096
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.somaxconn = 10240
net.ipv4.ip_local_port_range = 4000 65535
EOF
    sysctl -p || { echo "ERROR: sysctl 적용 실패" >&2; exit 1; }
}

# 전체 사용자에 대한 파일 디스크립터와 프로세스 제한값을 설정한다.
configure_limits() {
    cat <<EOF > /etc/security/limits.conf
* soft nofile 61200
* hard nofile 61200
* soft nproc 61200
* hard nproc 61200
EOF
}

# rc.local 실행 권한을 부여하고 rc-local 유닛 활성화를 시도한다.
configure_rc_local() {
    [ -f /etc/rc.d/rc.local ] && chmod +x /etc/rc.d/rc.local
    systemctl enable rc-local &>/dev/null || true
}

# rsyslog 설정 파일 권한을 제한하고 원격 로그 전송 대상을 추가한다.
configure_rsyslog() {
    chown root:root /etc/rsyslog.conf || { echo "ERROR: /etc/rsyslog.conf 소유자 설정 실패" >&2; exit 1; }
    chmod 640 /etc/rsyslog.conf || { echo "ERROR: /etc/rsyslog.conf 권한 설정 실패" >&2; exit 1; }
    RSYSLOG_LINE="*.* @$RSYSLOG_SERVER"
    sed -i "\|^\\*\\.\\* @${RSYSLOG_SERVER}$|d" /etc/rsyslog.conf
    echo "$RSYSLOG_LINE" >> /etc/rsyslog.conf
    restarts_needed["rsyslog"]=1
}

# SELinux를 런타임과 재부팅 후 설정 모두에서 비활성화한다.
disable_selinux() {
    setenforce 0 2>/dev/null || true
    sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
}

# 기본 umask를 022로 맞춰 신규 파일/디렉터리 권한을 제한한다.
configure_umask() {
    local file

    for file in /etc/profile /etc/bashrc; do
        if [ -f "$file" ]; then
            if grep -q 'umask[[:space:]]\+[0-9]' "$file"; then
                sed -i 's/umask[[:space:]]\+[0-9]\+/umask 022/g' "$file"
            else
                echo 'umask 022' >> "$file"
            fi
        fi
    done
}

# crontab과 cron.deny 파일 권한을 root 전용 기준으로 맞춘다.
configure_crontab_perms() {
    if [ -f /etc/crontab ]; then
        chown root:root /etc/crontab
        chmod 640 /etc/crontab
    fi
    if [ -f /etc/cron.deny ]; then
        chown root:root /etc/cron.deny
        chmod 640 /etc/cron.deny
    fi
}

# wtmp/btmp 로그 파일 권한이 부팅 후에도 유지되도록 tmpfiles 설정을 추가한다.
configure_wtmp_btmp_perms() {
    local tf="/etc/tmpfiles.d/99-hardening-perms.conf"
    cat > "$tf" << 'EOF'
# Override systemd default wtmp/btmp permissions (KISA hardening)
z /var/log/wtmp 0644 root utmp -
z /var/log/btmp 0600 root utmp -
EOF
    systemd-tmpfiles --create "$tf" >/dev/null 2>&1 || { echo "ERROR: tmpfiles --create 실패" >&2; exit 1; }
    chmod 644 /var/log/wtmp 2>/dev/null || true
    chmod 600 /var/log/btmp 2>/dev/null || true
}

# 동일 파일시스템 안의 world-writable 일반 파일에서 other write 권한을 제거한다.
fix_world_writable() {
    local file

    while IFS= read -r file; do
        chmod o-w "$file" || { echo "ERROR: $file 권한 변경 실패" >&2; exit 1; }
    done < <(find / -xdev -type f -perm -0002 ! -path '/proc/*' ! -path '/sys/*' ! -path '/dev/*' 2>/dev/null)
}

# /var/log 최상위 주요 로그 파일의 소유자와 권한을 보안 기준으로 맞춘다.
configure_var_log_perms() {
    local file perm

    for file in /var/log/wtmp /var/log/lastlog; do
        if [ -f "$file" ]; then
            chown root:root "$file"
            chmod 644 "$file"
        fi
    done
    for file in /var/log/btmp /var/log/btmp-*; do
        if [ -f "$file" ]; then
            chown root:root "$file"
            chmod 600 "$file"
        fi
    done
    while IFS= read -r file; do
        perm=$(stat -c '%a' "$file" 2>/dev/null)
        if [ "$perm" -gt 644 ] 2>/dev/null; then
            chmod 644 "$file"
        fi
    done < <(find /var/log -maxdepth 1 -type f 2>/dev/null)
}

# Snoopy를 소스에서 빌드해 명령 실행 감사를 활성화한다.
configure_snoopy() {
    local version="2.5.2"
    local url="https://github.com/a2o/snoopy/releases/download/snoopy-${version}/snoopy-${version}.tar.gz"
    local lib

    if grep -q 'libsnoopy' /etc/ld.so.preload 2>/dev/null; then
        return 0
    fi

    cd /usr/local/src || { echo "ERROR: 디렉터리 이동 실패" >&2; return 1; }
    wget -q "$url" -O "snoopy-${version}.tar.gz" || { echo "ERROR: 다운로드 실패" >&2; return 1; }
    tar -xzf "snoopy-${version}.tar.gz" || { echo "ERROR: 압축 해제 실패" >&2; return 1; }
    cd "snoopy-${version}" || { echo "ERROR: 소스 디렉터리 이동 실패" >&2; return 1; }
    ./configure >/dev/null 2>&1 || { echo "ERROR: configure 실패" >&2; return 1; }
    make >/dev/null 2>&1 || { echo "ERROR: make 실패" >&2; return 1; }
    make install >/dev/null 2>&1 || { echo "ERROR: make install 실패" >&2; return 1; }
    lib=$(find /usr/local/lib /usr/local/lib64 -maxdepth 2 \( -name 'libsnoopy.so' -o -name 'libsnoopy.so.0' \) 2>/dev/null | sort | head -1)
    [ -z "$lib" ] && { echo "ERROR: libsnoopy.so 탐색 실패" >&2; return 1; }
    grep -qxF "$lib" /etc/ld.so.preload 2>/dev/null || echo "$lib" >> /etc/ld.so.preload
    ldconfig

    cat > /etc/snoopy.ini << 'SNOOPY_CONF'
[snoopy]
message_format = "[login:%{login}][uid:%{uid}][user:%{username}][tty:%{tty}][cwd:%{cwd}]: %{cmdline}"
syslog_facility = LOG_AUTH
syslog_level = LOG_INFO
SNOOPY_CONF

    cd /usr/local/src
    rm -rf "snoopy-${version}" "snoopy-${version}.tar.gz"
}

install_packages || exit 1
configure_ntp || exit 1
configure_sysstat || exit 1
configure_history_timeout || exit 1
configure_etc_perms || exit 1
configure_file_permissions || exit 1
configure_motd || exit 1
configure_bash_vim || exit 1
step2_change_ssh_port || exit 1
configure_sysctl || exit 1
configure_limits || exit 1
configure_rc_local || exit 1
configure_rsyslog || exit 1
disable_selinux || exit 1
configure_umask || exit 1
configure_crontab_perms || exit 1
configure_wtmp_btmp_perms || exit 1
fix_world_writable || exit 1
configure_var_log_perms || exit 1
configure_snoopy || exit 1
