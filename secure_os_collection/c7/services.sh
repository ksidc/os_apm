#!/bin/bash

source /usr/local/src/secure_os_collection/c7/common.sh

# finger 패키지가 설치되어 있으면 서비스를 비활성화한다.
disable_finger() {
    if rpm -q finger >/dev/null 2>&1; then
        systemctl disable --now finger >/dev/null 2>&1 || { echo "ERROR: finger 비활성화 실패" >&2; exit 1; }
        SERVICES_DISABLED+="finger "
    fi
}

# vsftpd가 설치되어 있으면 익명 FTP 접속을 차단한다.
disable_anonymous_ftp() {
    if rpm -q vsftpd >/dev/null 2>&1; then
        sed -i 's/^anonymous_enable=.*/anonymous_enable=NO/' /etc/vsftpd/vsftpd.conf \
            || { echo "ERROR: vsftpd.conf 수정 실패" >&2; exit 1; }
        systemctl restart vsftpd >/dev/null 2>&1 || { echo "ERROR: vsftpd 재시작 실패" >&2; exit 1; }
    fi
}

# rsh/rlogin/rexec 계열 원격 접속 서비스를 비활성화한다.
disable_r_services() {
    local services=(rsh rlogin rexec)
    for svc in "${services[@]}"; do
        if rpm -q "$svc" >/dev/null 2>&1; then
            systemctl disable --now "$svc" >/dev/null 2>&1 || { echo "ERROR: $svc 비활성화 실패" >&2; exit 1; }
            SERVICES_DISABLED+="$svc "
        fi
    done
}

# cron/at 접근 제어 파일을 생성하고 root 전용 권한으로 제한한다.
configure_cron_permissions() {
    for f in /etc/cron.allow /etc/cron.deny /etc/at.allow /etc/at.deny; do
        if [ ! -e "$f" ]; then
            touch "$f"
        fi
        set_file_perms "$f" root:root 640
    done
}

# xinetd 기반 echo/discard/daytime/chargen 서비스를 비활성화한다.
disable_dos_services() {
    for svc in echo discard daytime chargen; do
        if [ -f "/etc/xinetd.d/$svc" ]; then
            sed -i 's/disable *= *no/disable = yes/' "/etc/xinetd.d/$svc" \
                || { echo "ERROR: $svc 설정 실패" >&2; exit 1; }
        fi
    done
    systemctl restart xinetd >/dev/null 2>&1 || true
}

# autofs 자동 마운트 서비스를 비활성화한다.
remove_automountd() {
    if rpm -q autofs >/dev/null 2>&1; then
        systemctl disable --now autofs >/dev/null 2>&1 || { echo "ERROR: autofs 비활성화 실패" >&2; exit 1; }
        SERVICES_DISABLED+="autofs "
    fi
}

# NIS 관련 yp* 서비스를 비활성화한다.
disable_nis() {
    local services=(ypbind ypserv ypxfrd rpc.yppasswdd rpc.ypupdated)
    for svc in "${services[@]}"; do
        if rpm -q "$svc" >/dev/null 2>&1; then
            systemctl disable --now "$svc" >/dev/null 2>&1 || { echo "ERROR: $svc 비활성화 실패" >&2; exit 1; }
            SERVICES_DISABLED+="$svc "
        fi
    done
}

# tftp/talk 서비스가 설치되어 있으면 비활성화한다.
disable_tftp_talk() {
    local services=(tftp talk)
    for svc in "${services[@]}"; do
        if rpm -q "$svc" >/dev/null 2>&1; then
            systemctl disable --now "$svc" >/dev/null 2>&1 || { echo "ERROR: $svc 비활성화 실패" >&2; exit 1; }
            SERVICES_DISABLED+="$svc "
        fi
    done
}

# postfix가 설치되어 있으면 VRFY를 막고 로컬 IPv4 바인딩만 사용하도록 제한한다.
configure_smtp_security() {
    if rpm -q postfix >/dev/null 2>&1; then
        if ! grep -q "^disable_vrfy_command[[:space:]]*=[[:space:]]*yes" /etc/postfix/main.cf; then
            if grep -q "^disable_vrfy_command" /etc/postfix/main.cf; then
                sed -i 's/^disable_vrfy_command.*/disable_vrfy_command = yes/' /etc/postfix/main.cf \
                    || { echo "ERROR: postfix main.cf 수정 실패" >&2; exit 1; }
            else
                echo "disable_vrfy_command = yes" >> /etc/postfix/main.cf \
                    || { echo "ERROR: postfix main.cf 추가 실패" >&2; exit 1; }
            fi
            postconf -e "inet_protocols = ipv4" || { echo "ERROR: inet_protocols 설정 실패" >&2; exit 1; }
            postconf -e "inet_interfaces = 127.0.0.1" || { echo "ERROR: inet_interfaces 설정 실패" >&2; exit 1; }

            if ! systemctl reload postfix >/dev/null 2>&1; then
                if ! systemctl restart postfix >/dev/null 2>&1; then
                    if ! systemctl enable --now postfix >/dev/null 2>&1; then
                        echo "ERROR: postfix 재시작 실패" >&2
                        exit 1
                    fi
                fi
            fi
        fi
    fi
}

# 서비스 강화 실행
disable_finger || exit 1
disable_anonymous_ftp || exit 1
disable_r_services || exit 1
configure_cron_permissions || exit 1
disable_dos_services || exit 1
remove_automountd || exit 1
disable_nis || exit 1
disable_tftp_talk || exit 1
configure_smtp_security || exit 1
