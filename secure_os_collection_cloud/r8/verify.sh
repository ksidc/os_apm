#!/bin/bash

set -euo pipefail

BASE_DIR="/usr/local/src/secure_os_collection/r8"

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
    local pkgs=(epel-release lsof net-tools psmisc lrzsz screen iftop smartmontools vim unzip wget)
    if ! command -v rpm >/dev/null 2>&1; then
        fail "rpm command not found; cannot verify package installation"
        return
    fi
    local missing=()
    local pkg
    for pkg in "${pkgs[@]}"; do
        rpm -q "$pkg" &>/dev/null || missing+=("$pkg")
    done
    if [ "${#missing[@]}" -eq 0 ]; then
        pass "Required packages installed"
    else
        fail "Missing packages: ${missing[*]}"
    fi
}

check_removed_users() {
    local users=(lp games sync shutdown halt)
    local remaining=()
    local u
    for u in "${users[@]}"; do
        id "$u" &>/dev/null && remaining+=("$u")
    done
    if [ "${#remaining[@]}" -eq 0 ]; then
        pass "Legacy accounts removed"
    else
        fail "Accounts still present: ${remaining[*]}"
    fi
}

check_ftp_shell() {
    if id ftp &>/dev/null; then
        local shell
        shell=$(getent passwd ftp | cut -d: -f7)
        case "$shell" in
            /sbin/nologin|/usr/sbin/nologin) pass "ftp login disabled" ;;
            *) fail "ftp shell is $shell" ;;
        esac
    else
        pass "ftp account absent"
    fi
}

check_vsftpd_anonymous() {
    if rpm -q vsftpd &>/dev/null && [ -f /etc/vsftpd/vsftpd.conf ]; then
        if grep -Fxq 'anonymous_enable=NO' /etc/vsftpd/vsftpd.conf; then
            pass "Anonymous FTP disabled"
        else
            fail "anonymous_enable=NO not found in vsftpd.conf"
        fi
    else
        pass "vsftpd not installed or no config"
    fi
}

check_finger() {
    if rpm -q finger &>/dev/null; then
        service_disabled_or_missing finger && pass "finger service disabled" || fail "finger service enabled"
    else
        pass "finger package absent"
    fi
}

check_r_services() {
    local services=(rsh rlogin rexec)
    local active=()
    local svc
    for svc in "${services[@]}"; do
        if rpm -q "$svc" &>/dev/null; then
            service_disabled_or_missing "$svc" || active+=("$svc")
        fi
    done
    if [ "${#active[@]}" -eq 0 ]; then
        pass "r-services disabled"
    else
        fail "r-services active: ${active[*]}"
    fi
}

check_dos_services() {
    local services=(echo discard daytime chargen)
    local problematic=()
    local svc file
    for svc in "${services[@]}"; do
        file="/etc/xinetd.d/$svc"
        if [ -f "$file" ] && ! grep -Eq '^\s*disable\s*=\s*yes\b' "$file"; then
            problematic+=("$svc")
        fi
    done
    if [ "${#problematic[@]}" -eq 0 ]; then
        pass "xinetd echo-style services disabled"
    else
        fail "Check xinetd configs for: ${problematic[*]}"
    fi
}

check_autofs() {
    if rpm -q autofs &>/dev/null; then
        service_disabled_or_missing autofs && pass "autofs disabled" || fail "autofs enabled"
    else
        pass "autofs package absent"
    fi
}

check_nis() {
    local services=(ypbind ypserv ypxfrd rpc.yppasswdd rpc.ypupdated)
    local active=()
    local svc
    for svc in "${services[@]}"; do
        if rpm -q "$svc" &>/dev/null; then
            service_disabled_or_missing "$svc" || active+=("$svc")
        fi
    done
    if [ "${#active[@]}" -eq 0 ]; then
        pass "NIS family services disabled"
    else
        fail "NIS services active: ${active[*]}"
    fi
}

check_tftp_talk() {
    local services=(tftp-server talk)
    local active=()
    local svc
    for svc in "${services[@]}"; do
        if rpm -q "$svc" &>/dev/null; then
            service_disabled_or_missing "$svc" || active+=("$svc")
        fi
    done
    if [ "${#active[@]}" -eq 0 ]; then
        pass "tftp/talk disabled"
    else
        fail "Services active: ${active[*]}"
    fi
}

check_cron_permissions() {
    local files=(/etc/cron.allow /etc/cron.deny)
    local bad=()
    local f info
    for f in "${files[@]}"; do
        if [ -e "$f" ]; then
            info=$(stat -c '%a %U:%G' "$f")
            [ "$info" = "640 root:root" ] || bad+=("$f -> $info")
        fi
    done
    if [ "${#bad[@]}" -eq 0 ]; then
        pass "cron access file permissions ok"
    else
        fail "cron access file permissions: ${bad[*]}"
    fi
}

check_rhosts() {
    local home_dir="${HOME:-/root}"
    local remaining=()
    [ ! -e /etc/hosts.equiv ] || remaining+=("/etc/hosts.equiv")
    [ ! -e "$home_dir/.rhosts" ] || remaining+=("$home_dir/.rhosts")
    if [ "${#remaining[@]}" -eq 0 ]; then
        pass "rhosts/hosts.equiv removed"
    else
        fail "Remove trusted host files: ${remaining[*]}"
    fi
}

check_core_permissions() {
    local entries=(
        "/etc/passwd:644:root:root"
        "/etc/shadow:400:root:root"
        "/etc/hosts:600:root:root"
    )
    local bad=()
    local entry file mode owner group info
    for entry in "${entries[@]}"; do
        IFS=':' read -r file mode owner group <<<"$entry"
        if [ -f "$file" ]; then
            info=$(stat -c '%a:%U:%G' "$file")
            [ "$info" = "$mode:$owner:$group" ] || bad+=("$file -> $info")
        else
            bad+=("$file missing")
        fi
    done
    if [ "${#bad[@]}" -eq 0 ]; then
        pass "Core file permissions ok"
    else
        fail "Core file permissions: ${bad[*]}"
    fi
}

check_wheel() {
    getent group wheel >/dev/null && pass "wheel group present" || fail "wheel group missing"
}

check_su() {
    if [ -f /usr/bin/su ]; then
        local info
        info=$(stat -c '%a:%U:%G' /usr/bin/su)
        [ "$info" = "4750:root:wheel" ] && pass "/usr/bin/su restricted" || fail "/usr/bin/su perms are $info"
    else
        fail "/usr/bin/su missing"
    fi
}

check_privileged_bins() {
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
        pass "Privileged binaries locked down"
    else
        fail "Binary permissions: ${bad[*]}"
    fi
}

check_motd() {
    if [ ! -f /etc/motd ]; then
        fail "/etc/motd missing"
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
        pass "MOTD banner updated"
    else
        fail "/etc/motd content differs"
    fi
    rm -f "$tmp"
}

check_sysctl() {
    if [ ! -f /etc/sysctl.conf ]; then
        fail "/etc/sysctl.conf missing"
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
        pass "sysctl.conf matches hardened values"
    else
        fail "sysctl entries missing: ${missing[*]}"
    fi
}

check_limits() {
    if [ ! -f /etc/security/limits.conf ]; then
        fail "/etc/security/limits.conf missing"
        return
    fi
    local tmp
    tmp=$(mktemp)
    cat <<'EOF' >"$tmp"
* soft nofile 61200
* hard nofile 61200
* soft nproc 61200
* hard nproc 61200
EOF
    if cmp -s /etc/security/limits.conf "$tmp"; then
        pass "limits.conf matches baseline"
    else
        fail "/etc/security/limits.conf content differs"
    fi
    rm -f "$tmp"
}

check_rc_local() {
    local file=/etc/rc.d/rc.local
    if [ -x "$file" ]; then
        pass "rc.local is executable"
    else
        fail "rc.local not executable"
    fi
}

check_packages
check_removed_users
check_ftp_shell
check_vsftpd_anonymous
check_finger
check_r_services
check_dos_services
check_autofs
check_nis
check_tftp_talk
check_cron_permissions
check_rhosts
check_core_permissions
check_wheel
check_su
check_privileged_bins
check_motd
check_sysctl
check_limits
check_rc_local

if [ "${#fails[@]}" -eq 0 ]; then
    printf 'Verification passed.\n'
    for msg in "${passes[@]}"; do
        printf ' - %s\n' "$msg"
    done
    exit 0
else
    printf 'Verification found issues.\n'
    for msg in "${fails[@]}"; do
        printf ' [FAIL] %s\n' "$msg"
    done
    if [ "${#passes[@]}" -gt 0 ]; then
        printf 'Checks that passed:\n'
        for msg in "${passes[@]}"; do
            printf ' [OK] %s\n' "$msg"
        done
    fi
    exit 1
}
