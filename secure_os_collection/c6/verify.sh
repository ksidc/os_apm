#!/bin/bash
#
# CentOS 6.10 전용 1차 보안조치 결과 검증 스크립트.
# 사용법: sudo bash verify.sh [--no-color] [--check-worldwritable]

set -u
export LC_ALL=C

USE_COLOR=1
CHECK_WORLDWRITABLE=0
readonly NTP_SERVER="kr.pool.ntp.org"
readonly RSYSLOG_SERVER="1.224.163.4"

for arg in "$@"; do
    case "$arg" in
        --no-color) USE_COLOR=0 ;;
        --check-worldwritable) CHECK_WORLDWRITABLE=1 ;;
        --skip-worldwritable) CHECK_WORLDWRITABLE=0 ;;
        -h|--help)
            sed -n '2,/^$/p' "$0"
            exit 0
            ;;
        *)
            echo "ERROR: 지원하지 않는 옵션입니다: $arg" >&2
            exit 2
            ;;
    esac
done

if [ "$USE_COLOR" -eq 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    CYAN=''
    BOLD=''
    NC=''
fi

PASS=0
FAIL=0
SKIP=0

# 검증 성공, 실패와 선택 항목 건수를 구분해 최종 종료 코드에 반영한다.
pass() { echo -e "  [${GREEN}PASS${NC}] $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  [${RED}FAIL${NC}] $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "  [${CYAN}SKIP${NC}] $1"; SKIP=$((SKIP + 1)); }
header() { echo -e "\n${BOLD}${CYAN}=== $1 ===${NC}"; }

# 파일이 기대 권한과 소유자로 설정되었는지 확인한다.
check_file() {
    local file="$1" expected_perm="$2" expected_owner="$3" label="$4" actual_perm actual_owner
    [ -e "$file" ] || {
        fail "$label: 파일 없음 ($file)"
        return
    }
    actual_perm="$(stat -c '%a' "$file" 2>/dev/null)"
    actual_owner="$(stat -c '%U:%G' "$file" 2>/dev/null)"
    [ "$actual_perm" = "$expected_perm" ] \
        && pass "$label 권한: $actual_perm" \
        || fail "$label 권한: 실제=$actual_perm 기대=$expected_perm"
    [ "$actual_owner" = "$expected_owner" ] \
        && pass "$label 소유자: $actual_owner" \
        || fail "$label 소유자: 실제=$actual_owner 기대=$expected_owner"
}

# 고정 문자열이 지정 파일에 정확히 한 줄만 존재하는지 확인한다.
check_single_fixed_line() {
    local file="$1" expected_line="$2" label="$3" count
    [ -f "$file" ] || {
        fail "$label: 파일 없음 ($file)"
        return
    }
    count="$(grep -Fxc "$expected_line" "$file" 2>/dev/null || true)"
    [ "$count" -eq 1 ] \
        && pass "$label: 1개" \
        || fail "$label: 실제=${count}개 기대=1개"
}

# 정규식에 맞는 활성 설정이 정확히 한 줄인지 확인한다.
check_single_pattern() {
    local file="$1" pattern="$2" label="$3" count
    [ -f "$file" ] || {
        fail "$label: 파일 없음 ($file)"
        return
    }
    count="$(grep -Ec "$pattern" "$file" 2>/dev/null || true)"
    [ "$count" -eq 1 ] \
        && pass "$label: 1개" \
        || fail "$label: 실제=${count}개 기대=1개"
}

# 필수 RPM이 설치되어 있는지 확인한다.
check_package() {
    local package_name="$1"
    rpm -q "$package_name" >/dev/null 2>&1 \
        && pass "필수 패키지: $package_name" \
        || fail "필수 패키지 미설치: $package_name"
}

# SysV 서비스가 현재 실행 중이고 런레벨 3과 5에서 활성화되었는지 확인한다.
check_service_enabled() {
    local service_name="$1" chk_output
    [ -x "/etc/init.d/$service_name" ] || {
        fail "필수 서비스 없음: $service_name"
        return
    }
    service "$service_name" status >/dev/null 2>&1 \
        && pass "서비스 실행: $service_name" \
        || fail "서비스 미실행: $service_name"
    chk_output="$(chkconfig --list "$service_name" 2>/dev/null || true)"
    echo "$chk_output" | grep -q '3:on' && echo "$chk_output" | grep -q '5:on' \
        && pass "부팅 활성화: $service_name (3:on, 5:on)" \
        || fail "부팅 활성화 실패: $service_name"
}

# 설치된 불필요 SysV 서비스가 중지되고 부팅 비활성화되었는지 확인한다.
check_service_disabled() {
    local service_name="$1" chk_output
    if [ ! -x "/etc/init.d/$service_name" ]; then
        skip "미설치: $service_name"
        return
    fi
    service "$service_name" status >/dev/null 2>&1 \
        && fail "불필요 서비스 실행 중: $service_name" \
        || pass "불필요 서비스 중지: $service_name"
    chk_output="$(chkconfig --list "$service_name" 2>/dev/null || true)"
    echo "$chk_output" | grep -Eq '[2-5]:on' \
        && fail "불필요 서비스 부팅 활성 상태: $service_name" \
        || pass "불필요 서비스 부팅 비활성: $service_name"
}

# 현재 sysctl 값이 조치 스크립트의 고정값과 일치하는지 확인한다.
check_sysctl() {
    local key="$1" expected="$2" actual
    actual="$(sysctl -n "$key" 2>/dev/null | awk '{$1=$1; print}' || true)"
    expected="$(echo "$expected" | awk '{$1=$1; print}')"
    [ "$actual" = "$expected" ] \
        && pass "sysctl $key=$actual" \
        || fail "sysctl $key: 실제='${actual:-없음}' 기대='$expected'"
}

# CentOS 6.10, Vault 고정값과 업데이트 후 실행 커널 상태를 확인한다.
verify_platform() {
    local release newest_kernel running_kernel repo_file repo_count enabled_count gpgcheck_count
    header "1. OS / 업데이트 정책"

    release="$(cat /etc/centos-release 2>/dev/null || true)"
    echo "$release" | grep -q '^CentOS release 6\.10' \
        && pass "지원 OS: $release" \
        || fail "CentOS 6.10이 아님: ${release:-확인 불가}"

    repo_file="/etc/yum.repos.d/CentOS-Base.repo"
    repo_count="$(find /etc/yum.repos.d -maxdepth 1 -type f -name '*.repo' 2>/dev/null | wc -l)"
    [ "$repo_count" -eq 1 ] \
        && pass "활성 Yum repo 파일: CentOS-Base.repo 단일 구성" \
        || fail "활성 Yum repo 파일 개수 불일치: ${repo_count}개"
    check_single_fixed_line "$repo_file" 'baseurl=https://vault.centos.org/6.10/os/$basearch/' "Vault base"
    check_single_fixed_line "$repo_file" 'baseurl=https://vault.centos.org/6.10/updates/$basearch/' "Vault updates"
    check_single_fixed_line "$repo_file" 'baseurl=https://vault.centos.org/6.10/extras/$basearch/' "Vault extras"
    enabled_count="$(grep -c '^enabled=1$' "$repo_file" 2>/dev/null || true)"
    enabled_count="${enabled_count:-0}"
    [ "$enabled_count" -eq 3 ] \
        && pass "Vault repo enabled=1: 3개" \
        || fail "Vault repo enabled=1 개수 불일치"
    gpgcheck_count="$(grep -c '^gpgcheck=1$' "$repo_file" 2>/dev/null || true)"
    gpgcheck_count="${gpgcheck_count:-0}"
    [ "$gpgcheck_count" -eq 3 ] \
        && pass "Vault repo gpgcheck=1: 3개" \
        || fail "Vault repo gpgcheck=1 개수 불일치"

    running_kernel="$(uname -r)"
    newest_kernel="$(rpm -q kernel --qf '%{INSTALLTIME}|%{VERSION}-%{RELEASE}.%{ARCH}\n' 2>/dev/null | sort -n | tail -1 | cut -d'|' -f2)"
    [ -n "$newest_kernel" ] && [ "$running_kernel" = "$newest_kernel" ] \
        && pass "최신 설치 커널로 실행 중: $running_kernel" \
        || fail "실행 커널=$running_kernel, 최신 설치 커널=${newest_kernel:-확인 불가} (재부팅 필요)"

    for package_name in \
        ca-certificates ntp rsyslog sysstat lsof net-tools psmisc lrzsz screen \
        smartmontools vim-enhanced unzip wget curl gzip tar gcc make autoconf automake \
        libtool perl sudo openssh-server cronie iptables tcp_wrappers audit; do
        check_package "$package_name"
    done
}

# root와 관리자 일반 계정, 불필요 계정 및 비밀번호 기본 안전 상태를 확인한다.
verify_accounts() {
    local root_status uid_min user_name user_status admin_found=0 duplicate_count
    header "2. 계정 / sudo"

    root_status="$(passwd -S root 2>/dev/null | awk '{print $2}')"
    case "$root_status" in
        P|PS) pass "root 비밀번호 설정 상태: $root_status" ;;
        *) fail "root 비밀번호 상태: ${root_status:-확인 불가}" ;;
    esac

    for user_name in lp games ftp sync shutdown halt; do
        id "$user_name" >/dev/null 2>&1 \
            && fail "불필요 계정 잔존: $user_name" \
            || pass "불필요 계정 삭제: $user_name"
    done

    [ -z "$(awk -F: '$2 == "" {print $1}' /etc/shadow)" ] \
        && pass "빈 비밀번호 계정 없음" \
        || fail "빈 비밀번호 계정 존재"

    duplicate_count="$(awk -F: '{count[$3]++} END {for (id in count) if (count[id] > 1) duplicate++} END {print duplicate+0}' /etc/passwd)"
    [ "$duplicate_count" -eq 0 ] && pass "중복 UID 없음" || fail "중복 UID 존재: ${duplicate_count}건"
    duplicate_count="$(awk -F: '{count[$3]++} END {for (id in count) if (count[id] > 1) duplicate++} END {print duplicate+0}' /etc/group)"
    [ "$duplicate_count" -eq 0 ] && pass "중복 GID 없음" || fail "중복 GID 존재: ${duplicate_count}건"

    check_single_fixed_line /etc/sudoers.d/99-wheel '%wheel ALL=(ALL) ALL' "wheel sudo 규칙"
    check_file /etc/sudoers.d/99-wheel 440 root:root "wheel sudoers"
    check_single_fixed_line /etc/sudoers '#includedir /etc/sudoers.d' "sudoers includedir"
    visudo -c >/dev/null 2>&1 && pass "sudoers 문법 정상" || fail "sudoers 문법 오류"

    uid_min="$(awk '/^[[:space:]]*UID_MIN[[:space:]]+/ {print $2; exit}' /etc/login.defs)"
    uid_min="${uid_min:-500}"
    for user_name in $(awk -F: -v min="$uid_min" '$3 >= min && $3 < 60000 {print $1}' /etc/passwd); do
        if id -nG "$user_name" 2>/dev/null | tr ' ' '\n' | grep -qx wheel \
            && sudo -l -U "$user_name" >/dev/null 2>&1; then
            user_status="$(passwd -S "$user_name" 2>/dev/null | awk '{print $2}')"
            case "$user_status" in
                P|PS)
                    pass "관리자 일반 계정: $user_name (wheel/sudo)"
                    admin_found=1
                    break
                    ;;
            esac
        fi
    done
    [ "$admin_found" -eq 1 ] || fail "사용 가능한 wheel/sudo 일반 계정 없음"

    for policy_key in PASS_MAX_DAYS PASS_MIN_LEN PASS_MIN_DAYS PASS_WARN_AGE; do
        check_single_pattern /etc/login.defs "^[[:space:]]*${policy_key}[[:space:]]+" "login.defs $policy_key 중복 방지"
    done
    if grep -Eq '^[[:space:]]*PASS_MAX_DAYS[[:space:]]+99999' /etc/login.defs; then
        skip "선택형 비밀번호 만료 정책 미적용"
    else
        pass "선택형 비밀번호 만료 정책 적용"
    fi
}

# C6 PAM 실제 파일의 잠금, 복잡도와 su wheel 제한을 확인한다.
verify_pam() {
    local pam_link pam_file cracklib_line
    header "3. PAM / su"

    for pam_link in /etc/pam.d/system-auth /etc/pam.d/password-auth; do
        [ -L "$pam_link" ] \
            && pass "PAM 심볼릭 링크 유지: $pam_link" \
            || fail "PAM 심볼릭 링크 손상: $pam_link"
        pam_file="$(readlink -f "$pam_link" 2>/dev/null || true)"
        [ -f "$pam_file" ] || {
            fail "PAM 실제 파일 없음: $pam_link"
            continue
        }
        check_single_pattern "$pam_file" '^[[:space:]]*auth[[:space:]]+required[[:space:]]+pam_tally2\.so.*deny=3.*unlock_time=300' "$pam_link pam_tally2 auth"
        check_single_pattern "$pam_file" '^[[:space:]]*account[[:space:]]+required[[:space:]]+pam_tally2\.so' "$pam_link pam_tally2 account"
        cracklib_line="$(grep 'pam_cracklib\.so' "$pam_file" 2>/dev/null || true)"
        if [ "$(echo "$cracklib_line" | grep -c .)" -eq 1 ] \
            && echo "$cracklib_line" | grep -q 'minlen=' \
            && echo "$cracklib_line" | grep -q 'difok=2' \
            && echo "$cracklib_line" | grep -q 'lcredit=-1' \
            && echo "$cracklib_line" | grep -q 'ucredit=-1' \
            && echo "$cracklib_line" | grep -q 'dcredit=-1' \
            && echo "$cracklib_line" | grep -q 'ocredit=-1'; then
            pass "$pam_link pam_cracklib 복잡도"
        else
            fail "$pam_link pam_cracklib 복잡도 누락 또는 중복"
        fi
        echo "$cracklib_line" | grep -Eq 'minlen=([8-9]|[1-9][0-9]+)([[:space:]]|$)' \
            && pass "$pam_link pam_cracklib 최소 길이 8 이상" \
            || fail "$pam_link pam_cracklib 최소 길이 확인 필요"
        grep -qE '^[[:space:]]*(auth|password).*pam_unix\.so.*[[:space:]]nullok([[:space:]]|$)' "$pam_file" \
            && fail "$pam_link pam_unix nullok 잔존" \
            || pass "$pam_link pam_unix nullok 제거"
    done

    check_single_pattern /etc/pam.d/su '^[[:space:]]*auth[[:space:]]+required[[:space:]]+pam_wheel\.so[[:space:]]+use_uid' "su pam_wheel"
    check_file /bin/su 4750 root:wheel "su"
}

# SSH root 차단, 선택 포트와 설정 문법을 확인한다.
verify_ssh() {
    local permit_root ssh_port
    header "4. SSH"

    sshd -t >/dev/null 2>&1 && pass "sshd_config 문법 정상" || fail "sshd_config 문법 오류"
    permit_root="$(sshd -T 2>/dev/null | awk '/^permitrootlogin / {print $2; exit}')"
    [ "$permit_root" = "no" ] \
        && pass "PermitRootLogin no" \
        || fail "PermitRootLogin: 실제=${permit_root:-확인 불가} 기대=no"
    ssh_port="$(sshd -T 2>/dev/null | awk '/^port / {print $2; exit}')"
    if [ -n "$ssh_port" ] && [ "$ssh_port" != "22" ]; then
        pass "SSH 포트 변경: $ssh_port"
    elif [ "$ssh_port" = "22" ]; then
        skip "확인 선택에 따라 SSH 기본 포트 22 사용"
    else
        fail "SSH 포트 확인 실패"
    fi
    check_single_pattern /etc/ssh/sshd_config '^[[:space:]]*Port[[:space:]]+[0-9]+' "SSH Port 중복 방지"
    check_single_fixed_line /etc/ssh/sshd_config 'PermitRootLogin no' "PermitRootLogin 중복 방지"
    check_service_enabled sshd
}

# sysctl, limits, 세션 환경, SELinux와 기본 서비스 상태를 확인한다.
verify_system_policy() {
    local selinux_runtime file
    header "5. 시스템 정책"

    check_single_fixed_line /etc/profile 'export HISTTIMEFORMAT="%Y-%m-%d[%H:%M:%S] "' "HISTTIMEFORMAT"
    check_single_fixed_line /etc/profile 'export TMOUT=600' "TMOUT"
    for file in /etc/profile /etc/bashrc; do
        if ! grep -Eq '^[[:space:]]*umask[[:space:]]+022([[:space:]]|$)' "$file"; then
            fail "umask 022 설정 없음: $file"
        elif grep -E '^[[:space:]]*umask[[:space:]]+[0-9]+' "$file" 2>/dev/null \
            | grep -Ev '^[[:space:]]*umask[[:space:]]+022([[:space:]]|$)' \
            | grep -q .; then
            fail "umask 022 외 활성값 존재: $file"
        else
            pass "umask 022 고정: $file"
        fi
    done

    check_single_fixed_line /etc/security/limits.conf '* soft nofile 61200' "limits soft nofile"
    check_single_fixed_line /etc/security/limits.conf '* hard nofile 61200' "limits hard nofile"
    check_single_fixed_line /etc/security/limits.conf '* soft nproc 61200' "limits soft nproc"
    check_single_fixed_line /etc/security/limits.conf '* hard nproc 61200' "limits hard nproc"

    check_sysctl net.ipv4.ip_forward 0
    check_sysctl net.ipv4.tcp_syncookies 1
    check_sysctl net.ipv6.conf.all.disable_ipv6 1
    check_sysctl net.ipv4.icmp_echo_ignore_broadcasts 1
    check_sysctl net.ipv4.tcp_fin_timeout 10
    check_sysctl net.ipv4.tcp_keepalive_time 1800
    check_sysctl net.ipv4.tcp_max_syn_backlog 4096
    check_sysctl net.ipv4.tcp_rmem '4096 10000000 16777216'
    check_sysctl net.ipv4.tcp_wmem '4096 65536 16777216'
    check_sysctl net.core.rmem_max 16777216
    check_sysctl net.core.wmem_max 16777216
    check_sysctl net.core.somaxconn 10240
    check_sysctl net.ipv4.ip_local_port_range '4000 65535'

    grep -q '^SELINUX=disabled$' /etc/selinux/config \
        && pass "SELinux 부팅 설정: disabled" \
        || fail "SELinux 부팅 설정이 disabled가 아님"
    selinux_runtime="$(getenforce 2>/dev/null || true)"
    case "$selinux_runtime" in
        Disabled|Permissive) pass "SELinux 현재 상태: $selinux_runtime" ;;
        *) fail "SELinux 현재 상태: ${selinux_runtime:-확인 불가}" ;;
    esac

    check_service_enabled rsyslog
    check_service_enabled crond
    check_service_enabled auditd
    if [ -x /etc/init.d/sysstat ]; then
        chkconfig --list sysstat 2>/dev/null | grep -q '3:on' \
            && pass "sysstat 부팅 활성화" \
            || fail "sysstat 부팅 비활성"
    fi
    [ -f /etc/cron.d/sysstat ] && pass "sysstat cron 존재" || fail "sysstat cron 없음"
}

# 중앙 로그 한 줄, ntpd 설정과 부팅 상태를 확인한다.
verify_logging_time() {
    header "6. 로그 / 시간 동기화"

    check_file /etc/rsyslog.conf 640 root:root "rsyslog.conf"
    check_single_fixed_line /etc/rsyslog.conf "*.* @$RSYSLOG_SERVER" "중앙 로그 전송"
    check_single_fixed_line /etc/ntp.conf "server $NTP_SERVER iburst" "NTP 서버"
    check_service_enabled ntpd
}

# 핵심 계정·예약 작업·명령·로그 파일 권한과 world-writable 잔존 여부를 확인한다.
verify_file_permissions() {
    local world_count
    header "7. 파일 권한"

    check_file /etc/passwd 644 root:root "passwd"
    check_file /etc/shadow 400 root:root "shadow"
    check_file /etc/hosts 600 root:root "hosts"
    check_file /etc/ssh/sshd_config 600 root:root "sshd_config"
    check_file /etc/sudoers 440 root:root "sudoers"
    check_file /etc/crontab 640 root:root "crontab"
    check_file /etc/cron.allow 640 root:root "cron.allow"
    check_file /etc/cron.deny 640 root:root "cron.deny"
    check_file /etc/at.allow 640 root:root "at.allow"
    check_file /etc/at.deny 640 root:root "at.deny"
    check_file /sbin/unix_chkpwd 755 root:root "unix_chkpwd"
    check_file /usr/bin/newgrp 755 root:root "newgrp"
    check_file /usr/bin/perl 700 root:root "perl"
    check_file /usr/bin/screen 700 root:root "screen"
    check_file /usr/bin/wget 700 root:root "wget"
    check_file /usr/bin/curl 700 root:root "curl"
    check_file /var/log/wtmp 644 root:utmp "wtmp"
    check_file /var/log/btmp 600 root:utmp "btmp"
    check_file /etc/rc.d/rc.local 755 root:root "rc.local"
    check_single_fixed_line /etc/rc.d/rc.local '[ -e /var/log/wtmp ] && chown root:utmp /var/log/wtmp && chmod 0644 /var/log/wtmp' "부팅 후 wtmp 권한 유지"
    check_single_fixed_line /etc/rc.d/rc.local '[ -e /var/log/btmp ] && chown root:utmp /var/log/btmp && chmod 0600 /var/log/btmp' "부팅 후 btmp 권한 유지"
    grep -Eq '^[[:space:]]*create[[:space:]]+0644[[:space:]]+root[[:space:]]+utmp' /etc/logrotate.conf \
        && pass "wtmp logrotate 생성 권한: 0644" \
        || fail "wtmp logrotate 생성 권한이 0644가 아님"

    if [ "$CHECK_WORLDWRITABLE" -eq 1 ]; then
        world_count="$(find / -xdev -type f -perm -0002 ! -path '/proc/*' ! -path '/sys/*' ! -path '/dev/*' 2>/dev/null | wc -l)"
        [ "$world_count" -eq 0 ] \
            && pass "world-writable 일반 파일 없음" \
            || fail "world-writable 일반 파일 잔존: ${world_count}개"
    else
        skip "world-writable 검사 제외 (--check-worldwritable 지정 시 실행)"
    fi
}

# 레거시 서비스 비활성화와 postfix 로컬 바인딩을 확인한다.
verify_services() {
    local service_name config_file
    header "8. 불필요 서비스"

    for service_name in autofs ypbind ypserv ypxfrd yppasswdd ypupdated; do
        check_service_disabled "$service_name"
    done

    for config_file in \
        /etc/xinetd.d/finger \
        /etc/xinetd.d/rsh /etc/xinetd.d/rlogin /etc/xinetd.d/rexec \
        /etc/xinetd.d/echo* /etc/xinetd.d/discard* \
        /etc/xinetd.d/daytime* /etc/xinetd.d/chargen* \
        /etc/xinetd.d/tftp /etc/xinetd.d/talk /etc/xinetd.d/ntalk; do
        [ -f "$config_file" ] || continue
        grep -Eq '^[[:space:]]*disable[[:space:]]*=[[:space:]]*yes' "$config_file" \
            && pass "xinetd 비활성: $config_file" \
            || fail "xinetd 활성 가능: $config_file"
    done

    if [ -f /etc/vsftpd/vsftpd.conf ]; then
        grep -q '^anonymous_enable=NO$' /etc/vsftpd/vsftpd.conf \
            && pass "vsftpd 익명 접속 차단" \
            || fail "vsftpd 익명 접속 설정 확인 필요"
    else
        skip "vsftpd 미설치"
    fi

    if rpm -q postfix >/dev/null 2>&1; then
        [ "$(postconf -h disable_vrfy_command 2>/dev/null)" = "yes" ] \
            && pass "postfix VRFY 차단" || fail "postfix VRFY 차단 실패"
        [ "$(postconf -h inet_protocols 2>/dev/null)" = "ipv4" ] \
            && pass "postfix IPv4 제한" || fail "postfix IPv4 제한 실패"
        [ "$(postconf -h inet_interfaces 2>/dev/null)" = "127.0.0.1" ] \
            && pass "postfix localhost 바인딩" || fail "postfix localhost 바인딩 실패"
    else
        skip "postfix 미설치"
    fi
}

# 선택한 iptables 적용 또는 완전 비활성화 상태 중 하나가 정확한지 확인한다.
verify_firewall() {
    local chk_output ssh_port source_ip service_port
    header "9. 방화벽 / 접근 통제"

    chk_output="$(chkconfig --list iptables 2>/dev/null || true)"
    if echo "$chk_output" | grep -q '3:on' && echo "$chk_output" | grep -q '5:on'; then
        service iptables status >/dev/null 2>&1 \
            && pass "iptables 실행 및 부팅 활성" \
            || fail "iptables 부팅 활성이나 현재 미실행"
        check_file /etc/sysconfig/iptables 600 root:root "iptables 규칙 파일"
        grep -q '^:INPUT DROP ' /etc/sysconfig/iptables \
            && pass "iptables INPUT 기본 DROP" \
            || fail "iptables INPUT 기본 DROP 미설정"
        grep -Eq -- '--state (ESTABLISHED,RELATED|RELATED,ESTABLISHED) -j ACCEPT' /etc/sysconfig/iptables \
            && pass "iptables 기존 연결 허용" \
            || fail "iptables 기존 연결 허용 규칙 없음"
        grep -q -- '-j REJECT --reject-with icmp-host-prohibited' /etc/sysconfig/iptables \
            && pass "iptables 최종 REJECT" \
            || fail "iptables 최종 REJECT 규칙 없음"
        ssh_port="$(sshd -T 2>/dev/null | awk '/^port / {print $2; exit}')"
        grep -q -- "--dport ${ssh_port} -j ACCEPT" /etc/sysconfig/iptables \
            && pass "iptables SSH 포트 허용: $ssh_port" \
            || fail "iptables SSH 포트 허용 규칙 없음: $ssh_port"
        for source_ip in 116.122.36.109 218.50.1.130 110.9.167.210 211.200.178.141 218.237.67.200 121.166.140.142; do
            grep -Eq -- "-s ${source_ip}(/32)?([[:space:]].*)?-j ACCEPT" /etc/sysconfig/iptables \
                && pass "iptables 관리자 IP: $source_ip" \
                || fail "iptables 관리자 IP 누락: $source_ip"
        done
        for service_port in 20 21 25 80 110 143 443 587 3306 8080 8090; do
            grep -q -- "--dport ${service_port} -j ACCEPT" /etc/sysconfig/iptables \
                && pass "iptables 서비스 포트: $service_port" \
                || fail "iptables 서비스 포트 누락: $service_port"
        done
        grep -q -- '--dport 5000:5050 -j ACCEPT' /etc/sysconfig/iptables \
            && pass "iptables FTP passive 포트: 5000:5050" \
            || fail "iptables FTP passive 포트 누락"
        grep -q -- '--dport 161 -j ACCEPT' /etc/sysconfig/iptables \
            && pass "iptables SNMP 포트: 161/udp" \
            || fail "iptables SNMP 포트 누락"
        iptables-save 2>/dev/null | grep -q '^:INPUT DROP ' \
            && pass "iptables 현재 로드 규칙 INPUT DROP" \
            || fail "iptables 현재 로드 규칙 불일치"
        check_single_fixed_line /etc/hosts.allow 'sshd: ALL' "hosts.allow"
        check_single_fixed_line /etc/hosts.deny 'ALL: ALL' "hosts.deny"
    else
        if service iptables status >/dev/null 2>&1; then
            fail "iptables 비활성 선택이나 현재 실행 중"
        elif echo "$chk_output" | grep -Eq '[2-5]:on'; then
            fail "iptables 일부 런레벨이 아직 활성 상태"
        else
            pass "iptables 중지 및 전체 부팅 비활성"
        fi
    fi

    [ ! -e /etc/hosts.equiv ] && pass "hosts.equiv 없음" || fail "hosts.equiv 잔존"
    [ ! -e /root/.rhosts ] && pass "root .rhosts 없음" || fail "root .rhosts 잔존"
}

# Snoopy 라이브러리, 설정과 재실행 시 중복될 수 있는 고정 라인을 확인한다.
verify_snoopy_and_idempotency() {
    local library_path preload_count snoopy_version snoopy_config
    header "10. Snoopy / 재실행 안정성"

    library_path="$(grep 'libsnoopy' /etc/ld.so.preload 2>/dev/null | head -1)"
    [ -n "$library_path" ] && [ -f "$library_path" ] \
        && pass "Snoopy preload 라이브러리: $library_path" \
        || fail "Snoopy preload 라이브러리 없음"
    preload_count="$(grep -c 'libsnoopy' /etc/ld.so.preload 2>/dev/null || true)"
    preload_count="${preload_count:-0}"
    [ "$preload_count" -eq 1 ] \
        && pass "Snoopy preload 중복 없음" \
        || fail "Snoopy preload 중복 또는 누락"
    grep -q '^syslog_facility = LOG_AUTH$' /etc/snoopy.ini 2>/dev/null \
        && pass "Snoopy auth 로그 facility" \
        || fail "Snoopy 설정 누락"
    check_file /etc/ld.so.preload 644 root:root "ld.so.preload"
    check_file /etc/snoopy.ini 600 root:root "snoopy.ini"

    if [ -x /usr/local/sbin/snoopyctl ]; then
        snoopy_version="$(/usr/local/sbin/snoopyctl version 2>/dev/null || true)"
        echo "$snoopy_version" | grep -q 'Snoopy library version:[[:space:]]*2\.5\.2' \
            && pass "Snoopy 라이브러리 버전: 2.5.2" \
            || fail "Snoopy 라이브러리 버전 또는 로드 실패"

        snoopy_config="$(/usr/local/sbin/snoopyctl conf 2>/dev/null || true)"
        echo "$snoopy_config" | grep -q 'Options from config file (or defaults): /etc/snoopy.ini' \
            && pass "Snoopy 설정 경로: /etc/snoopy.ini" \
            || fail "Snoopy가 /etc/snoopy.ini를 사용하지 않음"
        echo "$snoopy_config" | grep -q '^syslog_facility = AUTH$' \
            && echo "$snoopy_config" | grep -q '^syslog_level = INFO$' \
            && pass "Snoopy 실행 설정: AUTH/INFO" \
            || fail "Snoopy 실행 설정이 /etc/snoopy.ini와 불일치"
    else
        fail "Snoopy 관리 명령 없음: /usr/local/sbin/snoopyctl"
    fi

    check_single_fixed_line /etc/profile 'export HISTTIMEFORMAT="%Y-%m-%d[%H:%M:%S] "' "재실행 HISTTIMEFORMAT"
    check_single_fixed_line /etc/profile 'export TMOUT=600' "재실행 TMOUT"
    check_single_fixed_line /etc/rsyslog.conf "*.* @$RSYSLOG_SERVER" "재실행 rsyslog"
    check_single_fixed_line /etc/ntp.conf "server $NTP_SERVER iburst" "재실행 NTP server"
    check_single_fixed_line /etc/ssh/sshd_config 'PermitRootLogin no' "재실행 PermitRootLogin"
    check_single_pattern /etc/ssh/sshd_config '^[[:space:]]*Port[[:space:]]+[0-9]+' "재실행 SSH Port"
    check_single_pattern /etc/pam.d/su 'pam_wheel\.so[[:space:]]+use_uid' "재실행 pam_wheel"
}

# root와 OS를 확인한 뒤 모든 C6 조치 항목을 순서대로 검증한다.
main() {
    [ "$(id -u)" -eq 0 ] || {
        echo "ERROR: root 권한으로 실행해야 합니다." >&2
        exit 1
    }
    grep -q '^CentOS release 6\.10' /etc/centos-release 2>/dev/null || {
        echo "ERROR: 이 verify.sh는 CentOS 6.10 전용입니다." >&2
        exit 1
    }

    echo "CentOS 6.10 1차 보안조치 검증"
    verify_platform
    verify_accounts
    verify_pam
    verify_ssh
    verify_system_policy
    verify_logging_time
    verify_file_permissions
    verify_services
    verify_firewall
    verify_snoopy_and_idempotency

    header "검증 결과"
    echo "PASS: $PASS"
    echo "FAIL: $FAIL"
    echo "SKIP: $SKIP"

    if [ "$FAIL" -gt 0 ]; then
        echo "결과: 보안조치 미충족 항목이 있습니다."
        return 1
    fi
    echo "결과: CentOS 6.10 1차 보안조치 검증 통과"
    return 0
}

main
