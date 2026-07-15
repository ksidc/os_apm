#!/bin/bash

source /usr/local/src/secure_os_collection/c6/common.sh

# 기존 Yum 저장소를 제거하고 CentOS 6.10 Vault 세 개만 고정값으로 생성한다.
configure_yum_repos() {
    rm -f /etc/yum.repos.d/*.repo || {
        echo "ERROR: 기존 Yum 저장소 설정 제거 실패" >&2
        return 1
    }
    cat > /etc/yum.repos.d/CentOS-Base.repo <<'EOF' || return 1
[base]
name=CentOS-6 - Base (Vault)
baseurl=https://vault.centos.org/6.10/os/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6
enabled=1

[updates]
name=CentOS-6 - Updates (Vault)
baseurl=https://vault.centos.org/6.10/updates/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6
enabled=1

[extras]
name=CentOS-6 - Extras (Vault)
baseurl=https://vault.centos.org/6.10/extras/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6
enabled=1
EOF

    yum clean all >/dev/null 2>&1 && yum makecache || {
        echo "ERROR: CentOS 6.10 Vault 저장소 캐시 생성 실패" >&2
        return 1
    }
}

# EOS 정책에 따라 CentOS 6.10 Vault에서 제공되는 최신 패키지를 강제로 적용한다.
update_all_packages() {
    yum -y update || {
        echo "ERROR: CentOS 6.10 전체 업데이트 실패" >&2
        return 1
    }
    SUMMARY="${SUMMARY}Package update: forced latest\n"
}

# 기본 운영과 C6 보안조치, Snoopy 빌드에 필요한 패키지를 빠짐없이 설치한다.
install_required_packages() {
    local package_name missing_packages=""
    for package_name in \
        ca-certificates ntp rsyslog sysstat lsof net-tools psmisc lrzsz screen \
        smartmontools vim-enhanced unzip wget curl gzip tar gcc make autoconf automake \
        libtool perl sudo openssh-server cronie iptables tcp_wrappers audit; do
        rpm -q "$package_name" >/dev/null 2>&1 || missing_packages="$missing_packages $package_name"
    done

    if [ -n "$missing_packages" ]; then
        yum install -y $missing_packages || {
            echo "ERROR: 필수 패키지 설치 실패:$missing_packages" >&2
            return 1
        }
    fi
}

# SSH, 로그, 예약 작업과 감사 서비스를 부팅 시 항상 실행하도록 고정한다.
configure_core_services() {
    local service_name
    for service_name in sshd rsyslog crond auditd; do
        [ -x "/etc/init.d/$service_name" ] || {
            echo "ERROR: 필수 서비스가 없습니다: $service_name" >&2
            return 1
        }
        chkconfig "$service_name" on || return 1
        service "$service_name" status >/dev/null 2>&1 || service "$service_name" start || return 1
    done
}

# ntpd를 지정 서버로 설정하고 부팅 시 자동 시작되게 등록한다.
configure_ntp() {
    [ -f /etc/ntp.conf ] || {
        echo "ERROR: ntp 설치 후 /etc/ntp.conf가 없습니다." >&2
        return 1
    }
    sed -i '/^[[:space:]]*server[[:space:]]/d' /etc/ntp.conf || return 1
    echo "server $NTP_SERVER iburst" >> /etc/ntp.conf || return 1
    chkconfig ntpd on || return 1
    mark_restart ntpd
}

# sysstat 수집을 부팅 시 활성화하고 C6 cron 수집 파일의 존재를 확인한다.
configure_sysstat() {
    rpm -q sysstat >/dev/null 2>&1 || {
        echo "ERROR: sysstat 패키지가 설치되지 않았습니다." >&2
        return 1
    }
    if [ -x /etc/init.d/sysstat ]; then
        chkconfig sysstat on || return 1
        mark_restart sysstat
    fi
    [ -f /etc/cron.d/sysstat ] || {
        echo "ERROR: sysstat cron 설정이 없습니다." >&2
        return 1
    }
}

# 명령 이력에 실행 시간을 표시하고 유휴 셸을 600초 후 종료한다.
configure_history_timeout() {
    sed -i '/^[[:space:]]*\(export[[:space:]]\+\)\?HISTTIMEFORMAT=/d; /^[[:space:]]*\(export[[:space:]]\+\)\?TMOUT=/d' /etc/profile || return 1
    echo 'export HISTTIMEFORMAT="%Y-%m-%d[%H:%M:%S] "' >> /etc/profile || return 1
    echo 'export TMOUT=600' >> /etc/profile || return 1
}

# 계정 파일과 C6의 실제 su 경로인 /bin/su 권한을 보안 기준으로 고정한다.
configure_core_file_permissions() {
    getent group wheel >/dev/null 2>&1 || groupadd wheel
    set_file_perms /etc/passwd root:root 644 || return 1
    set_file_perms /etc/shadow root:root 400 || return 1
    set_file_perms /etc/hosts root:root 600 || return 1
    set_file_perms /etc/ssh/sshd_config root:root 600 || return 1
    set_file_perms /etc/sudoers root:root 440 || return 1
    set_file_perms /bin/su root:wheel 4750 || return 1
}

# 불필요한 SUID를 제거하고 설치된 관리 도구는 root만 실행하도록 제한한다.
configure_command_permissions() {
    local file
    for file in /sbin/unix_chkpwd /usr/bin/newgrp; do
        [ -e "$file" ] && chmod u-s,g-s "$file" || return 1
    done
    for file in /usr/bin/perl /usr/bin/screen /usr/bin/wget /usr/bin/curl; do
        [ -e "$file" ] || {
            echo "ERROR: 필수 명령 파일이 없습니다: $file" >&2
            return 1
        }
        set_file_perms "$file" root:root 700 || return 1
    done
}

# 로그인 시 허가 사용자 전용 시스템임을 알리는 고정 경고문을 표시한다.
configure_motd() {
    local script_version="unknown"
    [ -f /usr/local/src/secure_os_collection/version.conf ] && source /usr/local/src/secure_os_collection/version.conf
    script_version="${SCRIPT_VERSION:-unknown}"

    cat > /etc/motd <<EOF || return 1
********************************************************************
*                                                                  *
* 본 시스템은 허가된 사용자만 이용할 수 있습니다.                 *
* 모든 사용 기록은 보안 정책에 따라 수집될 수 있습니다.           *
*                                                                  *
* This system is for authorized users only.                        *
* Usage may be monitored and recorded.                             *
*                                                                  *
* Apply version ${script_version}                                  *
********************************************************************
EOF
}

# root 운영 환경의 공통 alias와 vim 설정을 고정한다.
configure_shell_tools() {
    local alias_line
    for alias_line in "alias vi='vim'" "alias grep='grep --color=auto'" "alias ll='ls -alF --color=tty'"; do
        grep -qF "$alias_line" /root/.bashrc || echo "$alias_line" >> /root/.bashrc || return 1
    done
    cat > /root/.vimrc <<'EOF' || return 1
set ignorecase
set cindent
set sw=4 ts=4 sts=4 shiftwidth=4
set showmode bg=dark paste ruler expandtab linebreak wrap showcmd
set laststatus=2 textwidth=80 wm=1 smartcase smartindent ttyfast
EOF
}

# SSH 포트를 확인 입력받아 단일 설정으로 만들고 문법 검증 후 재시작 대상으로 기록한다.
configure_ssh_port() {
    local current_port new_port attempt
    current_port="$(sshd -T 2>/dev/null | awk '/^port / {print $2; exit}')"
    current_port="${current_port:-22}"
    echo "현재 SSH 포트: $current_port, 권장 기본값: 38371"

    attempt=1
    while [ "$attempt" -le 3 ]; do
        read -r -p "변경할 포트 (Enter: 38371, $attempt/3): " new_port < /dev/tty
        new_port="${new_port:-38371}"
        if echo "$new_port" | grep -Eq '^[0-9]+$' && [ "$new_port" -ge 1 ] && [ "$new_port" -le 65535 ]; then
            break
        fi
        echo "유효한 포트 번호(1~65535)를 입력하세요."
        attempt=$((attempt + 1))
    done
    [ "$attempt" -le 3 ] || {
        echo "ERROR: SSH 포트 입력 실패" >&2
        return 1
    }

    if [ "$new_port" = "22" ] && ! prompt_yes_no "기본 SSH 포트 22를 그대로 사용하시겠습니까?"; then
        configure_ssh_port
        return $?
    fi

    sed -i '/^[[:space:]#]*Port[[:space:]]/d' /etc/ssh/sshd_config || return 1
    echo "Port $new_port" >> /etc/ssh/sshd_config || return 1
    sshd -t || {
        echo "ERROR: sshd_config 문법 오류" >&2
        return 1
    }
    NEW_SSH_PORT="$new_port"
    mark_restart sshd
}

# 네트워크와 커널 보안값을 C6 고정 정책으로 덮어쓰고 즉시 적용한다.
configure_sysctl() {
    cat > /etc/sysctl.conf <<'EOF' || return 1
net.ipv4.ip_forward = 0
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.tcp_syncookies = 1
kernel.sysrq = 0
kernel.core_uses_pid = 1
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
    sysctl -p || {
        echo "ERROR: sysctl 적용 실패" >&2
        return 1
    }
}

# 전체 사용자에게 필요한 파일 디스크립터와 프로세스 제한을 설정한다.
configure_limits() {
    cat > /etc/security/limits.conf <<'EOF' || return 1
* soft nofile 61200
* hard nofile 61200
* soft nproc 61200
* hard nproc 61200
EOF
}

# rsyslog 권한과 중앙 로그 서버 전송 라인을 단일 값으로 설정한다.
configure_rsyslog() {
    set_file_perms /etc/rsyslog.conf root:root 640 || return 1
    sed -i "\|^[[:space:]]*\*\.\*[[:space:]]\+@${RSYSLOG_SERVER}[[:space:]]*$|d" /etc/rsyslog.conf || return 1
    echo "*.* @$RSYSLOG_SERVER" >> /etc/rsyslog.conf || return 1
    mark_restart rsyslog
}

# 기존 운영 정책과 동일하게 SELinux를 현재와 재부팅 후 모두 비활성화한다.
disable_selinux() {
    if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce)" != "Disabled" ]; then
        setenforce 0 || return 1
    fi
    sed -i '/^[[:space:]]*SELINUX=/d' /etc/selinux/config || return 1
    echo 'SELINUX=disabled' >> /etc/selinux/config || return 1
}

# profile과 bashrc의 기존 umask를 모두 022로 맞춘다.
configure_umask() {
    local file
    for file in /etc/profile /etc/bashrc; do
        [ -f "$file" ] || continue
        if grep -qE '^[[:space:]]*umask[[:space:]]+[0-9]+' "$file"; then
            sed -i 's/^[[:space:]]*umask[[:space:]]\+[0-9]\+/    umask 022/' "$file" || return 1
        else
            echo 'umask 022' >> "$file" || return 1
        fi
    done
}

# cron과 at 접근 제어 파일을 생성해 root 전용 권한으로 고정한다.
configure_scheduler_permissions() {
    local file
    for file in /etc/cron.allow /etc/cron.deny /etc/at.allow /etc/at.deny; do
        [ -e "$file" ] || touch "$file" || return 1
        set_file_perms "$file" root:root 640 || return 1
    done
    set_file_perms /etc/crontab root:root 640 || return 1
}

# C6 부팅 시 rc.sysinit이 되돌리는 wtmp 권한을 rc.local에서 최종 보정한다.
configure_login_log_permissions() {
    local rc_local="/etc/rc.d/rc.local"
    local wtmp_boot_line='[ -e /var/log/wtmp ] && chown root:utmp /var/log/wtmp && chmod 0644 /var/log/wtmp'
    local btmp_boot_line='[ -e /var/log/btmp ] && chown root:utmp /var/log/btmp && chmod 0600 /var/log/btmp'

    if [ -f /etc/logrotate.conf ]; then
        sed -i 's/^[[:space:]]*create[[:space:]]\+0664[[:space:]]\+root[[:space:]]\+utmp/create 0644 root utmp/' /etc/logrotate.conf || return 1
    fi
    [ -f /var/log/wtmp ] || { echo "ERROR: /var/log/wtmp가 없습니다." >&2; return 1; }
    [ -f /var/log/btmp ] || { echo "ERROR: /var/log/btmp가 없습니다." >&2; return 1; }
    chown root:utmp /var/log/wtmp && chmod 644 /var/log/wtmp || return 1
    chown root:utmp /var/log/btmp && chmod 600 /var/log/btmp || return 1

    [ -f "$rc_local" ] || touch "$rc_local" || return 1
    sed -i '\|/var/log/wtmp.*chmod 0644 /var/log/wtmp[[:space:]]*$|d; \|/var/log/btmp.*chmod 0600 /var/log/btmp[[:space:]]*$|d' "$rc_local" || return 1
    echo "$wtmp_boot_line" >> "$rc_local" || return 1
    echo "$btmp_boot_line" >> "$rc_local" || return 1
    set_file_perms "$rc_local" root:root 755 || return 1
}

# 동일 루트 파일시스템의 world-writable 일반 파일에서 other-write를 제거한다.
fix_world_writable() {
    find / -xdev -type f -perm -0002 \
        ! -path '/proc/*' ! -path '/sys/*' ! -path '/dev/*' \
        -exec chmod o-w {} + 2>/dev/null || {
        echo "ERROR: world-writable 파일 권한 정리 실패" >&2
        return 1
    }
}

# Snoopy 2.5.2를 C6 GCC 4.4 호환 옵션으로 빌드하고 auth syslog 전송을 활성화한다.
configure_snoopy() {
    local version="2.5.2" archive source_dir library_path
    library_path="$(grep 'libsnoopy' /etc/ld.so.preload 2>/dev/null | head -1)"
    if [ -n "$library_path" ] && [ -f "$library_path" ] \
        && [ -x /usr/local/sbin/snoopyctl ] \
        && /usr/local/sbin/snoopyctl version 2>/dev/null | grep -q 'Snoopy library version:[[:space:]]*2\.5\.2' \
        && /usr/local/sbin/snoopyctl conf 2>/dev/null | grep -q 'Options from config file (or defaults): /etc/snoopy.ini' \
        && grep -q '^syslog_facility = LOG_AUTH$' /etc/snoopy.ini 2>/dev/null \
        && grep -q '^syslog_level = LOG_INFO$' /etc/snoopy.ini 2>/dev/null; then
        set_file_perms /etc/ld.so.preload root:root 644 || return 1
        set_file_perms /etc/snoopy.ini root:root 600 || return 1
        return 0
    fi
    if [ -f /etc/ld.so.preload ]; then
        sed -i '/libsnoopy/d' /etc/ld.so.preload || return 1
    fi

    archive="/usr/local/src/snoopy-${version}.tar.gz"
    source_dir="/usr/local/src/snoopy-${version}"
    rm -rf "$archive" "$source_dir"
    curl -fL "https://github.com/a2o/snoopy/releases/download/snoopy-${version}/snoopy-${version}.tar.gz" -o "$archive" || {
        echo "ERROR: Snoopy 다운로드 실패" >&2
        return 1
    }
    tar -xzf "$archive" -C /usr/local/src || {
        echo "ERROR: Snoopy 압축 해제 실패" >&2
        return 1
    }
    cd "$source_dir" || {
        echo "ERROR: Snoopy 소스 디렉터리 이동 실패: $source_dir" >&2
        return 1
    }

    echo "Snoopy configure 진행 중..."
    CFLAGS="-O2 -fno-strict-aliasing" \
        ./configure --enable-config-file --sysconfdir=/etc --enable-filtering >/dev/null || {
        echo "ERROR: Snoopy configure 실패" >&2
        [ -f config.log ] && tail -n 30 config.log >&2
        return 1
    }

    # C6 GCC 4.4가 지원하지 않는 pedantic 옵션과 경고의 오류 승격을 제거한다.
    find "$source_dir" -type f -name Makefile \
        -exec sed -i 's/-Wno-pedantic//g; s/-Wpedantic//g; s/-Werror//g' {} \; || {
        echo "ERROR: Snoopy C6 컴파일 옵션 변환 실패" >&2
        return 1
    }

    echo "Snoopy make 진행 중..."
    make >/dev/null || {
        echo "ERROR: Snoopy make 실패" >&2
        return 1
    }
    echo "Snoopy make install 진행 중..."
    make install >/dev/null || {
        echo "ERROR: Snoopy make install 실패" >&2
        return 1
    }
    ldconfig || {
        echo "ERROR: Snoopy 설치 후 ldconfig 실패" >&2
        return 1
    }
    library_path="$(find /usr/local/lib /usr/local/lib64 -maxdepth 2 \( -name 'libsnoopy.so' -o -name 'libsnoopy.so.0' \) 2>/dev/null | sort | head -1)"
    [ -n "$library_path" ] || {
        echo "ERROR: Snoopy 라이브러리를 찾지 못했습니다." >&2
        return 1
    }
    LD_PRELOAD="$library_path" /bin/true || {
        echo "ERROR: Snoopy 라이브러리 로드 검증 실패: $library_path" >&2
        return 1
    }
    cat > /etc/snoopy.ini <<'EOF' || return 1
[snoopy]
message_format = "[login:%{login}][uid:%{uid}][user:%{username}][tty:%{tty}][cwd:%{cwd}]: %{cmdline}"
syslog_facility = LOG_AUTH
syslog_level = LOG_INFO
EOF
    set_file_perms /etc/snoopy.ini root:root 600 || return 1
    grep -qxF "$library_path" /etc/ld.so.preload 2>/dev/null || echo "$library_path" >> /etc/ld.so.preload || return 1
    set_file_perms /etc/ld.so.preload root:root 644 || return 1

    cd /usr/local/src || return 1
    rm -rf "$source_dir" "$archive"
}

# 순서 중 하나가 실패하면 source 호출자에게 반환해 main.sh가 실패 파일을 정확히 표시하게 한다.
apply_system_hardening() {
    configure_yum_repos || return 1
    update_all_packages || return 1
    install_required_packages || return 1
    configure_core_services || return 1
    configure_ntp || return 1
    configure_sysstat || return 1
    configure_history_timeout || return 1
    configure_core_file_permissions || return 1
    configure_command_permissions || return 1
    configure_motd || return 1
    configure_shell_tools || return 1

    # 소스 빌드 실패가 SSH 포트 변경을 남기지 않도록 Snoopy를 먼저 완료한다.
    configure_snoopy || return 1

    configure_ssh_port || return 1
    configure_sysctl || return 1
    configure_limits || return 1
    configure_rsyslog || return 1
    disable_selinux || return 1
    configure_umask || return 1
    configure_scheduler_permissions || return 1
    configure_login_log_permissions || return 1
    fix_world_writable || return 1
}

apply_system_hardening
