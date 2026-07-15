#!/bin/bash
#
# 신규 CentOS 6.10 최소 설치 서버의 1차 보안조치 설계용 상태 수집 스크립트.
# C6에서 실제 사용할 인증, 서비스, 방화벽, 로그 및 권한 설정 방식만 확인한다.
# 시스템 설정과 패키지를 변경하지 않으며 결과는 표준 출력으로만 내보낸다.
#
# 사용법:
#   sudo bash collect_environment.sh

set -u
export LC_ALL=C

EXPECTED_RELEASE="CentOS release 6.10"
EXPECTED_RSYSLOG_SERVER="1.224.163.4"

# 수집 영역을 구분해 결과에서 필요한 설정을 바로 찾을 수 있게 한다.
section() {
    echo
    echo "==============================================================================="
    echo "[$1]"
    echo "==============================================================================="
}

# 보안 설정 파일을 읽기 위해 root 권한으로 실행했는지 확인한다.
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "ERROR: root 권한으로 실행해야 합니다." >&2
        exit 1
    fi
}

# 주석과 빈 줄을 제외하고 현재 적용 대상으로 작성된 설정만 출력한다.
print_active_config() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "--- $file"
        grep -Ev '^[[:space:]]*(#|$)' "$file" 2>/dev/null || true
    else
        echo "[없음] $file"
    fi
}

# 보안조치 대상 파일의 소유자, 그룹과 권한을 출력한다.
print_file_stat() {
    local file="$1"
    if [ -e "$file" ]; then
        stat -c '%n|%U:%G|%a' "$file" 2>/dev/null || ls -ld "$file"
    else
        echo "[없음] $file"
    fi
}

# C6 보안조치에 필요한 패키지의 현재 설치 여부와 버전을 출력한다.
print_package_state() {
    local package_name
    for package_name in "$@"; do
        if rpm -q "$package_name" >/dev/null 2>&1; then
            rpm -q "$package_name" --qf '설치|%{NAME}|%{VERSION}-%{RELEASE}|%{ARCH}\n'
        else
            echo "미설치|$package_name"
        fi
    done
}

# systemd가 없는 C6에서 실제 사용할 관리 명령이 존재하는지 확인한다.
print_command_support() {
    local command_name command_path
    for command_name in "$@"; do
        command_path="$(command -v "$command_name" 2>/dev/null || true)"
        if [ -n "$command_path" ]; then
            echo "지원|$command_name|$command_path"
        else
            echo "미지원|$command_name"
        fi
    done
}

# 로그인 실패 잠금과 비밀번호 복잡도에 사용할 PAM 모듈을 확인한다.
print_pam_module_support() {
    local module_name module_path found owner_package
    for module_name in pam_tally2.so pam_cracklib.so pam_pwquality.so pam_wheel.so pam_limits.so; do
        found=0
        for module_path in /lib/security/$module_name /lib64/security/$module_name; do
            if [ -f "$module_path" ]; then
                owner_package="$(rpm -qf "$module_path" 2>/dev/null || echo '소유 패키지 확인 불가')"
                echo "지원|$module_name|$module_path|$owner_package"
                found=1
            fi
        done
        [ "$found" -eq 1 ] || echo "미지원|$module_name"
    done
}

# 수집 대상이 고정 조건인 CentOS 6.10인지 확인한다.
collect_os_version() {
    local release
    section "1. OS 버전"

    release="$(cat /etc/centos-release 2>/dev/null || echo '확인 불가')"
    echo "OS: $release"

    case "$release" in
        "$EXPECTED_RELEASE"*) return 0 ;;
        *)
            echo "ERROR: CentOS 6.10 서버가 아닙니다." >&2
            return 1
            ;;
    esac
}

# 설치 스크립트에서 사용할 C6 명령, 패키지와 PAM 기능을 확인한다.
collect_security_capabilities() {
    section "2. C6 보안 기능 지원"

    echo "--- 관리 명령"
    print_command_support \
        service chkconfig authconfig pam_tally2 chage useradd chpasswd \
        visudo sshd iptables iptables-save ntpd ntpq rsyslogd \
        getenforce setenforce sysctl

    echo
    echo "--- 관련 패키지"
    print_package_state \
        pam cracklib cracklib-dicts openssh-server sudo rsyslog \
        ntp chrony cronie vixie-cron iptables tcp_wrappers xinetd \
        audit sysstat wget gcc make autoconf automake libtool

    echo
    echo "--- PAM 모듈"
    print_pam_module_support
}

# 일반 계정 기준과 관리자 그룹, 비밀번호 만료 정책의 기본 상태를 수집한다.
collect_accounts() {
    local uid_min user_name
    section "3. 계정 / 비밀번호 정책"

    uid_min="$(awk '/^[[:space:]]*UID_MIN[[:space:]]+/ {print $2; exit}' /etc/login.defs 2>/dev/null)"
    uid_min="${uid_min:-500}"
    echo "일반 계정 UID_MIN: $uid_min"

    echo
    echo "--- UID 0 계정"
    awk -F: '$3 == 0 {print $1 ":" $3 ":" $6 ":" $7}' /etc/passwd

    echo
    echo "--- 일반 계정과 관리자 그룹 포함 여부"
    for user_name in $(awk -F: -v min="$uid_min" '$3 >= min && $3 < 60000 {print $1}' /etc/passwd); do
        getent passwd "$user_name"
        id "$user_name" 2>&1 || true
        passwd -S "$user_name" 2>&1 || true
        chage -l "$user_name" 2>&1 || true
    done

    echo
    echo "--- wheel 그룹"
    getent group wheel 2>&1 || true

    echo
    echo "--- 불필요 기본 계정 존재 여부"
    for user_name in lp games ftp sync shutdown halt; do
        if id "$user_name" >/dev/null 2>&1; then
            getent passwd "$user_name"
        else
            echo "없음|$user_name"
        fi
    done

    echo
    echo "--- 중복 UID / GID"
    awk -F: '{count[$3]++; names[$3]=names[$3] " " $1} END {for (id in count) if (count[id] > 1) print "UID " id ":" names[id]}' /etc/passwd | sort -n
    awk -F: '{count[$3]++; names[$3]=names[$3] " " $1} END {for (id in count) if (count[id] > 1) print "GID " id ":" names[id]}' /etc/group | sort -n

    echo
    echo "--- 비밀번호 필드가 비어 있는 계정"
    awk -F: '$2 == "" {print $1}' /etc/shadow

    echo
    echo "--- login.defs 정책"
    grep -E '^[[:space:]]*(PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_WARN_AGE|PASS_MIN_LEN|UID_MIN|UID_MAX|UMASK)[[:space:]]+' /etc/login.defs 2>/dev/null || true
}

# C6 PAM 파일 구조와 SSH, su 제한을 적용할 현재 위치와 문법을 수집한다.
collect_authentication() {
    local pam_file
    section "4. PAM / SSH / su"

    echo "--- PAM 파일과 실제 연결 대상"
    for pam_file in /etc/pam.d/system-auth /etc/pam.d/password-auth; do
        if [ -e "$pam_file" ]; then
            ls -l "$pam_file"
            readlink -f "$pam_file" 2>/dev/null || true
        else
            echo "[없음] $pam_file"
        fi
        print_active_config "$pam_file"
    done
    print_active_config /etc/pam.d/su

    echo
    echo "--- 비밀번호 복잡도 설정 파일"
    print_active_config /etc/security/pwquality.conf

    echo
    echo "--- SSH 주요 적용값"
    if sshd -T >/dev/null 2>&1; then
        sshd -T 2>/dev/null | grep -E '^(port|permitrootlogin|passwordauthentication|pubkeyauthentication|maxauthtries|logingracetime|permitemptypasswords|usepam|protocol) '
    else
        print_active_config /etc/ssh/sshd_config
    fi
    sshd -t >/dev/null 2>&1 && echo "sshd 설정 문법: 정상" || echo "sshd 설정 문법: 확인 필요"

    echo
    echo "--- sudoers 활성 설정"
    grep -H -Ev '^[[:space:]]*(#|$)' /etc/sudoers /etc/sudoers.d/* 2>/dev/null || true
    command -v visudo >/dev/null 2>&1 && visudo -c 2>&1 || true
}

# C6에서 비활성화하거나 제한할 서비스의 설치, 부팅 등록과 설정만 확인한다.
collect_target_services() {
    local service_name config_file
    section "5. 보안조치 대상 서비스"

    echo "--- SysV 서비스 등록 / 상태"
    for service_name in sshd rsyslog ntpd chronyd crond iptables auditd xinetd autofs ypbind ypserv vsftpd postfix sendmail; do
        if [ -x "/etc/init.d/$service_name" ]; then
            echo "### $service_name"
            chkconfig --list "$service_name" 2>&1 || true
            service "$service_name" status 2>&1 || true
        else
            echo "미설치|$service_name"
        fi
    done

    echo
    echo "--- xinetd 비활성화 대상"
    for config_file in /etc/xinetd.d/echo* /etc/xinetd.d/discard* /etc/xinetd.d/daytime* /etc/xinetd.d/chargen* /etc/xinetd.d/rsh /etc/xinetd.d/rlogin /etc/xinetd.d/rexec /etc/xinetd.d/tftp /etc/xinetd.d/talk; do
        [ -f "$config_file" ] || continue
        print_active_config "$config_file"
    done

    echo
    echo "--- FTP / SMTP 보안 설정"
    [ -f /etc/vsftpd/vsftpd.conf ] && grep -E '^[[:space:]]*(anonymous_enable|local_enable|write_enable)=' /etc/vsftpd/vsftpd.conf || true
    [ -f /etc/postfix/main.cf ] && grep -E '^[[:space:]]*(disable_vrfy_command|inet_protocols|inet_interfaces)[[:space:]]*=' /etc/postfix/main.cf || true
}

# profile, sysctl, limits와 SELinux에서 실제 변경할 기본값을 수집한다.
collect_system_policy() {
    section "6. 시스템 보안 정책"

    echo "--- 이력 / 세션 타임아웃 / umask"
    grep -H -E '^[[:space:]]*(export[[:space:]]+)?(HISTTIMEFORMAT|TMOUT)=|^[[:space:]]*umask[[:space:]]+' /etc/profile /etc/bashrc 2>/dev/null || true

    echo
    echo "--- limits.conf"
    print_active_config /etc/security/limits.conf

    echo
    echo "--- sysctl 현재값"
    sysctl -a 2>/dev/null | grep -E '^(net\.ipv6\.conf\.all\.disable_ipv6|net\.ipv4\.(icmp_echo_ignore_broadcasts|tcp_rmem|tcp_wmem|tcp_fin_timeout|tcp_keepalive_time|tcp_max_syn_backlog|ip_local_port_range)|net\.core\.(rmem_max|wmem_max|somaxconn))[[:space:]]*=' | sort
    print_active_config /etc/sysctl.conf

    echo
    echo "--- SELinux"
    command -v getenforce >/dev/null 2>&1 && getenforce || true
    print_active_config /etc/selinux/config
}

# 중앙 로그 전송과 C6 시간 동기화 방식을 결정할 설정만 수집한다.
collect_logging_and_time() {
    section "7. 로그 / 시간 동기화"

    echo "--- rsyslog"
    print_file_stat /etc/rsyslog.conf
    print_active_config /etc/rsyslog.conf
    if grep -RqxF "*.* @$EXPECTED_RSYSLOG_SERVER" /etc/rsyslog.conf /etc/rsyslog.d 2>/dev/null; then
        echo "중앙 로그 전송: 설정됨"
    else
        echo "중앙 로그 전송: 미설정"
    fi

    echo
    echo "--- 시간 동기화"
    print_active_config /etc/ntp.conf
    print_active_config /etc/chrony.conf
    command -v ntpq >/dev/null 2>&1 && ntpq -pn 2>&1 || true
}

# iptables와 TCP Wrappers의 현재 파일 형식 및 적용 상태를 수집한다.
collect_access_control() {
    section "8. 방화벽 / 접근 통제"

    echo "--- iptables"
    chkconfig --list iptables 2>&1 || true
    service iptables status 2>&1 || true
    command -v iptables-save >/dev/null 2>&1 && iptables-save 2>&1 || true
    print_file_stat /etc/sysconfig/iptables

    echo
    echo "--- TCP Wrappers"
    print_active_config /etc/hosts.allow
    print_active_config /etc/hosts.deny

    echo
    echo "--- rhosts 신뢰 파일"
    print_file_stat /etc/hosts.equiv
    print_file_stat /root/.rhosts
}

# 보안 스크립트가 직접 조정할 파일과 취약 권한 파일의 현재 상태를 수집한다.
collect_file_permissions() {
    local file
    section "9. 보안조치 대상 파일 권한"

    for file in \
        /etc/passwd /etc/shadow /etc/hosts /etc/ssh/sshd_config \
        /etc/sudoers /etc/rsyslog.conf /etc/crontab \
        /etc/cron.allow /etc/cron.deny /etc/at.allow /etc/at.deny \
        /usr/bin/su /sbin/unix_chkpwd /usr/bin/newgrp \
        /usr/bin/perl /usr/bin/screen /usr/bin/wget /usr/bin/curl \
        /var/log/wtmp /var/log/btmp; do
        print_file_stat "$file"
    done

    echo
    echo "--- world-writable 일반 파일"
    find / -xdev -type f -perm -0002 ! -path '/proc/*' ! -path '/sys/*' ! -path '/dev/*' -printf '%p|%U:%G|%m\n' 2>/dev/null | sort
}

# 인자를 제한하고 보안조치 설계에 필요한 항목을 순서대로 수집한다.
main() {
    case "${1:-}" in
        "") ;;
        -h|--help)
            sed -n '2,/^$/p' "$0"
            return 0
            ;;
        *)
            echo "ERROR: 이 스크립트는 실행 옵션을 사용하지 않습니다." >&2
            return 2
            ;;
    esac

    [ "$#" -le 1 ] || {
        echo "ERROR: 이 스크립트는 실행 옵션을 사용하지 않습니다." >&2
        return 2
    }

    check_root
    echo "신규 CentOS 6.10 최소 설치 서버 보안조치 전 상태 수집"
    collect_os_version || return 1
    collect_security_capabilities
    collect_accounts
    collect_authentication
    collect_target_services
    collect_system_policy
    collect_logging_and_time
    collect_access_control
    collect_file_permissions

    section "수집 완료"
    echo "이 결과는 c6 1차 보안조치 스크립트와 verify.sh 작성에 사용합니다."
    echo "주의: 결과에는 계정명, SSH 설정과 방화벽 규칙이 포함됩니다."
}

main "$@"
