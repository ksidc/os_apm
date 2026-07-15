#!/bin/bash

source /usr/local/src/secure_os_collection/r9/common.sh

# finger 패키지와 inetd/xinetd 등록 정보를 제거해 원격 사용자 조회 서비스를 차단한다.
disable_finger() {
    if rpm -q finger &>/dev/null; then
        systemctl disable --now finger &>/dev/null || {
            echo "ERROR: finger 비활성화 실패" >&2
            return 1
        }
        rm -f /etc/xinetd.d/finger
        sed -i '/finger/d' /etc/inetd.conf 2>/dev/null
        SERVICES_DISABLED+="finger "
    fi
}

# vsftpd가 설치된 경우 익명 FTP 접속을 비활성화하고 서비스를 재시작한다.
disable_anonymous_ftp() {
    if rpm -q vsftpd &>/dev/null; then
        grep -q '^anonymous_enable=NO' /etc/vsftpd/vsftpd.conf || \
            sed -i 's/^anonymous_enable=.*/anonymous_enable=NO/' /etc/vsftpd/vsftpd.conf
        systemctl restart vsftpd &>/dev/null || {
            echo "ERROR: vsftpd 재시작 실패" >&2
            return 1
        }
        SERVICES_DISABLED+="vsftpd "
    fi
}

# rsh/rlogin/rexec 계열 원격 명령 서비스를 비활성화한다.
disable_r_services() {
    local svc

    for svc in rsh rlogin rexec; do
        if rpm -q "$svc" &>/dev/null; then
            systemctl disable --now "$svc" &>/dev/null || {
                echo "ERROR: $svc 비활성화 실패" >&2
                return 1
            }
            rm -f /etc/xinetd.d/"$svc"
            sed -i "/$svc/d" /etc/inetd.conf 2>/dev/null
            SERVICES_DISABLED+="$svc "
        fi
    done
}

# echo/discard/daytime/chargen 등 DoS 악용 가능 xinetd 서비스를 비활성화한다.
disable_dos_services() {
    local svc

    for svc in echo discard daytime chargen; do
        if [ -f /etc/xinetd.d/"$svc" ]; then
            sed -i 's/disable *= *no/disable = yes/' /etc/xinetd.d/"$svc"
            SERVICES_DISABLED+="$svc "
        fi
    done
    systemctl restart xinetd &>/dev/null || true
}

# autofs 자동 마운트 서비스를 비활성화한다.
remove_automountd() {
    if rpm -q autofs &>/dev/null; then
        systemctl disable --now autofs &>/dev/null || {
            echo "ERROR: autofs 비활성화 실패" >&2
            return 1
        }
        SERVICES_DISABLED+="autofs "
    fi
}

# ypbind/ypserv 등 NIS 관련 서비스를 비활성화한다.
disable_nis() {
    local svc

    for svc in ypbind ypserv ypxfrd rpc.yppasswdd rpc.ypupdated; do
        if rpm -q "$svc" &>/dev/null; then
            systemctl disable --now "$svc" &>/dev/null || {
                echo "ERROR: $svc 비활성화 실패" >&2
                return 1
            }
            SERVICES_DISABLED+="$svc "
        fi
    done
}

# tftp/talk 서비스를 비활성화하고 xinetd 설정이 있으면 disable=yes로 고정한다.
disable_tftp_talk() {
    local svc

    for svc in tftp-server talk; do
        if rpm -q "$svc" &>/dev/null; then
            systemctl disable --now "$svc" &>/dev/null || {
                echo "ERROR: $svc 비활성화 실패" >&2
                return 1
            }
            [ -f /etc/xinetd.d/${svc%-server} ] && sed -i 's/disable *= *no/disable = yes/' /etc/xinetd.d/${svc%-server}
            SERVICES_DISABLED+="$svc "
        fi
    done
}

# cron 접근 제어 파일이 존재하면 root 소유와 640 권한으로 맞춘다.
configure_cron_permissions() {
    local file

    for file in /etc/cron.allow /etc/cron.deny; do
        [ -e "$file" ] && set_file_perms "$file" root:root 640
    done
}

# r 계열 신뢰 접속 파일을 제거해 hosts.equiv/.rhosts 기반 우회를 막는다.
disable_rhosts_hosts_equiv() {
    rm -f /etc/hosts.equiv "$HOME/.rhosts"
}

disable_finger || exit 1
disable_anonymous_ftp || exit 1
disable_r_services || exit 1
disable_dos_services || exit 1
remove_automountd || exit 1
disable_nis || exit 1
disable_tftp_talk || exit 1
configure_cron_permissions || exit 1
disable_rhosts_hosts_equiv || exit 1
