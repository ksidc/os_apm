#!/bin/bash

set -euo pipefail

BASE_DIR="/usr/local/src/secure_os_collection/u18"

source "$BASE_DIR/common.sh"

check_root

passes=()
fails=()

pass() {
    passes+=("$1")
}

fail() {
    fails+=("$1")
}

service_disabled_or_missing() {
    local unit="$1"
    if ! command -v systemctl >/dev/null 2>&1; then
        return 0
    fi
    local output
    if output=$(systemctl is-enabled "$unit" 2>&1); then
        case "$output" in
            disabled|masked|static|indirect|generated) return 0 ;;
            *) return 1 ;;
        esac
    else
        if echo "$output" | grep -qiE 'could not be found|no such file|not-found'; then
            return 0
        fi
        return 1
    fi
}

check_packages() {
    local pkgs=(lsof net-tools psmisc screen iftop vim unzip wget curl)
    local missing=()
    local pkg
    for pkg in "${pkgs[@]}"; do
        dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
    done
    if [ "${#missing[@]}" -eq 0 ]; then
        pass "필수 패키지가 설치되어 있습니다."
    else
        fail "다음 패키지가 설치되어 있지 않습니다: ${missing[*]}"
    fi
}

check_removed_users() {
    local users=(lp games news uucp sync shutdown halt)
    local remaining=()
    local u
    for u in "${users[@]}"; do
        id "$u" >/dev/null 2>&1 && remaining+=("$u")
    done
    if [ "${#remaining[@]}" -eq 0 ]; then
        pass "불필요 계정이 제거되었습니다."
    else
        fail "남아 있는 계정: ${remaining[*]}"
    fi
}

check_ftp_shell() {
    if id ftp >/dev/null 2>&1; then
        local shell
        shell=$(getent passwd ftp | cut -d: -f7)
        case "$shell" in
            /usr/sbin/nologin|/usr/bin/nologin) pass "ftp 계정이 nologin 쉘을 사용합니다." ;;
            *) fail "ftp 계정 쉘을 확인하세요: $shell" ;;
        esac
    else
        pass "ftp 계정이 존재하지 않습니다."
    fi
}

check_finger() {
    if dpkg -s finger >/dev/null 2>&1; then
        service_disabled_or_missing finger && pass "finger 서비스가 비활성화되었습니다." || fail "finger 서비스가 활성 상태입니다."
    else
        pass "finger 패키지가 설치되어 있지 않습니다."
    fi
}

check_vsftpd() {
    if dpkg -s vsftpd >/dev/null 2>&1 && [ -f /etc/vsftpd.conf ]; then
        if grep -Fxq 'anonymous_enable=NO' /etc/vsftpd.conf; then
            pass "vsftpd 익명 접속이 차단되었습니다."
        else
            fail "/etc/vsftpd.conf에서 anonymous_enable=NO 항목을 찾지 못했습니다."
        fi
    else
        pass "vsftpd가 설치되어 있지 않아 추가 설정이 필요 없습니다."
    fi
}

check_r_services() {
    local services=(rsh rlogin rexec)
    local active=()
    local svc
    for svc in "${services[@]}"; do
        if dpkg -s "$svc" >/dev/null 2>&1; then
            service_disabled_or_missing "$svc" || active+=("$svc")
        fi
    done
    if [ "${#active[@]}" -eq 0 ]; then
        pass "r 계열 서비스가 비활성화되었습니다."
    else
        fail "활성 상태인 r 계열 서비스: ${active[*]}"
    fi
}

check_cron_permissions() {
    local files=(/etc/cron.allow /etc/cron.deny /etc/at.allow /etc/at.deny)
    local bad=()
    local f info
    for f in "${files[@]}"; do
        if [ -e "$f" ]; then
            info=$(stat -c '%a %U:%G' "$f")
            [ "$info" = "640 root:root" ] || bad+=("$f -> $info")
        fi
    done
    if [ "${#bad[@]}" -eq 0 ]; then
        pass "cron/at 접근 제어 파일 권한이 적절합니다."
    else
        fail "다음 파일 권한을 확인하세요: ${bad[*]}"
    fi
}

check_autofs() {
    if dpkg -s autofs >/dev/null 2>&1; then
        service_disabled_or_missing autofs && pass "autofs 서비스가 비활성화되었습니다." || fail "autofs 서비스가 활성 상태입니다."
    else
        pass "autofs 패키지가 설치되어 있지 않습니다."
    fi
}

check_nis() {
    local services=(ypbind ypserv ypxfrd rpc.yppasswdd rpc.ypupdated)
    local active=()
    local svc
    for svc in "${services[@]}"; do
        if dpkg -s "$svc" >/dev/null 2>&1; then
            service_disabled_or_missing "$svc" || active+=("$svc")
        fi
    done
    if [ "${#active[@]}" -eq 0 ]; then
        pass "NIS 관련 서비스가 비활성화되었습니다."
    else
        fail "활성 상태인 NIS 서비스: ${active[*]}"
    fi
}

check_tftp_talk() {
    local services=(tftpd-hpa talk)
    local active=()
    local svc
    for svc in "${services[@]}"; do
        if dpkg -s "$svc" >/dev/null 2>&1; then
            service_disabled_or_missing "$svc" || active+=("$svc")
        fi
    done
    if [ "${#active[@]}" -eq 0 ]; then
        pass "tftp/talk 관련 서비스가 비활성화되었습니다."
    else
        fail "활성 상태인 tftp/talk 서비스: ${active[*]}"
    fi
}

check_core_permissions() {
    local entries=(
        "/etc/passwd:644:root:root"
        "/etc/shadow:640:root:shadow"
        "/etc/hosts:644:root:root"
    )
    local bad=()
    local entry file mode owner group info
    for entry in "${entries[@]}"; do
        IFS=':' read -r file mode owner group <<<"$entry"
        if [ -f "$file" ]; then
            info=$(stat -c '%a:%U:%G' "$file")
            [ "$info" = "$mode:$owner:$group" ] || bad+=("$file -> $info")
        else
            bad+=("$file 없음")
        fi
    done
    if [ "${#bad[@]}" -eq 0 ]; then
        pass "/etc/passwd, /etc/shadow, /etc/hosts 권한이 올바릅니다."
    else
        fail "다음 핵심 파일 권한을 확인하세요: ${bad[*]}"
    fi
}

check_privileged_binaries() {
    local files=(/usr/bin/perl /usr/bin/screen /usr/bin/wget /usr/bin/curl)
    local bad=()
    local f info
    for f in "${files[@]}"; do
        if [ -f "$f" ]; then
            info=$(stat -c '%a:%U:%G' "$f")
            [ "$info" = "700:root:root" ] || bad+=("$f -> $info")
        fi
    done
    if [ "${#bad[@]}" -eq 0 ]; then
        pass "주요 실행 파일 권한이 제한되었습니다."
    else
        fail "다음 실행 파일 권한을 확인하세요: ${bad[*]}"
    fi
}

check_motd() {
    if [ ! -f /etc/motd ]; then
        fail "/etc/motd 파일이 존재하지 않습니다."
        return
    fi
    local tmp
    tmp=$(mktemp)
    cat <<'EOF' >"$tmp"
********************************************************************
* This system is for authorized users only.                        *
* Unauthorized access or misuse will be prosecuted.                *
********************************************************************
EOF
    if cmp -s /etc/motd "$tmp"; then
        pass "/etc/motd 배너가 적용되었습니다."
    else
        fail "/etc/motd 내용이 예상과 다릅니다."
    fi
    rm -f "$tmp"
}

check_sysctl() {
    if [ ! -f /etc/sysctl.conf ]; then
        fail "/etc/sysctl.conf 파일이 존재하지 않습니다."
        return
    fi
    local entries=(
        "net.ipv6.conf.all.disable_ipv6 = 1"
        "net.ipv4.icmp_echo_ignore_broadcasts = 1"
        "net.ipv4.tcp_rmem = 4096 10000000 16777216"
        "net.ipv4.tcp_wmem = 4096 65536 16777216"
        "net.ipv4.tcp_tw_reuse = 1"
        "net.ipv4.tcp_fin_timeout = 10"
        "net.ipv4.tcp_keepalive_time = 1800"
        "net.ipv4.tcp_max_syn_backlog = 4096"
        "net.core.rmem_max = 16777216"
        "net.core.wmem_max = 16777216"
        "net.core.somaxconn = 10240"
        "net.ipv4.ip_local_port_range = 4000 65535"
    )
    local missing=()
    local entry
    for entry in "${entries[@]}"; do
        grep -Fxq "$entry" /etc/sysctl.conf || missing+=("$entry")
    done
    if [ "${#missing[@]}" -eq 0 ]; then
        pass "sysctl.conf 값이 적용되었습니다."
    else
        fail "다음 sysctl 항목을 확인하세요: ${missing[*]}"
    fi
}

check_packages
check_removed_users
check_ftp_shell
check_finger
check_vsftpd
check_r_services
check_cron_permissions
check_autofs
check_nis
check_tftp_talk
check_core_permissions
check_privileged_binaries
check_motd
check_sysctl

if [ "${#fails[@]}" -eq 0 ]; then
    printf '모든 검증을 통과했습니다.\n'
    for msg in "${passes[@]}"; do
        printf ' - %s\n' "$msg"
    done
    exit 0
else
    printf '검증 확인이 필요합니다.\n'
    for msg in "${fails[@]}"; do
        printf ' [실패] %s\n' "$msg"
    done
    if [ "${#passes[@]}" -gt 0 ]; then
        printf '통과 항목:\n'
        for msg in "${passes[@]}"; do
            printf ' [통과] %s\n' "$msg"
        done
    fi
    exit 1
fi
