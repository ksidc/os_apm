#!/bin/bash
# apm.sh : Apache + MariaDB + PHP + FTP + Sendmail 설치 및 연동
# Rocky Linux 8/9 기준

source /usr/local/src/secure_os_collection/r8/common.sh

echo "APM 설치 해 말아? (Apache + MariaDB + PHP + FTP + Sendmail)"
echo "yes(y) or no(n)"
read install

case $install in
yes|y|Y|YES)
    log_info "=== APM 설치 및 연동 시작 ==="

    ########################################
    # Apache 설치 및 설정
    ########################################
    dnf -y install httpd httpd-tools mod_ssl
    systemctl enable --now httpd

    # 보안상 apache 대신 nobody 계정으로 동작
    sed -i 's/^User .*/User nobody/g' /etc/httpd/conf/httpd.conf
    sed -i 's/^Group .*/Group nobody/g' /etc/httpd/conf/httpd.conf
    sed -i 's/#ServerName www.example.com:80/ServerName localhost:80/g' /etc/httpd/conf/httpd.conf

    # VirtualHost 설정 (conf.d 별도 파일로 추가)
    IPaddress=$(hostname -I | awk '{print $1}')
    mkdir -p /home/iteasy
    cat <<EOF > /etc/httpd/conf.d/vhost.conf
<VirtualHost *:80>
    DocumentRoot /home/iteasy
    ServerName ${IPaddress:-localhost}
    ErrorLog logs/${IPaddress:-localhost}-error_log
    CustomLog logs/${IPaddress:-localhost}-access_log common
</VirtualHost>
EOF

    # Prefork MPM 튜닝
    cat <<EOF > /etc/httpd/conf.d/mpm_tuning.conf
<IfModule mpm_prefork_module>
    ServerLimit          1024
    StartServers            5
    MinSpareServers         5
    MaxSpareServers        10
    MaxClients            2048
    MaxRequestsPerChild      0
</IfModule>
EOF

    systemctl restart httpd

    ########################################
    # MariaDB 설치 및 설정
    ########################################
    curl -LsS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | \
        sudo bash -s -- --mariadb-server-version=10.6
    dnf module disable mariadb:10.3 -y
    dnf clean all
    dnf -y install mariadb-server mariadb
    systemctl enable --now mariadb

    # 기본 my.cnf 교체
    mv /etc/my.cnf /etc/my.cnf_org 2>/dev/null
    cat <<EOF > /etc/my.cnf
[mysqld]
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
max_connections = 500
max_allowed_packet=1024M
symbolic-links=0

[mysqld_safe]
log-error=/var/log/mariadb/mariadb.log
pid-file=/var/run/mariadb/mariadb.pid

!includedir /etc/my.cnf.d
EOF
    systemctl restart mariadb

    # Root 비밀번호 설정 (사용자 입력)
    read -sp "Set MariaDB root password: " RootPassword
    echo
    mysqladmin -u root password "$RootPassword"

    ########################################
    # PHP 8.1 설치 및 설정
    ########################################
    #dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
    dnf install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm
    dnf module disable php:remi-7.* -y
    dnf module enable php:remi-8.1 -y
    dnf install -y php php-bcmath php-bz2 php-cgi php-cli php-curl php-dba php-enchant php-fpm php-gd php-gmp php-intl php-json php-ldap php-mbstring php-mysqlnd php-odbc php-opcache php-pgsql php-readline php-snmp php-soap php-sqlite3 php-xml php-xsl php-zip

    echo "<?php phpinfo(); ?>" > /home/iteasy/info.php

    sed -i 's/listen.acl_users = apache,nginx/;listen.acl_users = apache,nginx/g' /etc/php-fpm.d/www.conf
    sed -i 's/;listen.owner = nobody/listen.owner = nobody/g' /etc/php-fpm.d/www.conf
    sed -i 's/;listen.group = nobody/listen.group = nobody/g' /etc/php-fpm.d/www.conf

    systemctl enable --now php-fpm
    systemctl restart httpd

    ########################################
    # vsftpd 설치 및 설정
    ########################################
    dnf -y install vsftpd
    sed -i 's/anonymous_enable=YES/anonymous_enable=NO/g' /etc/vsftpd/vsftpd.conf
    sed -i 's/#chroot_local_user=YES/chroot_local_user=YES/g' /etc/vsftpd/vsftpd.conf
    cat <<EOF >> /etc/vsftpd/vsftpd.conf
allow_writeable_chroot=YES
pasv_enable=YES
pasv_min_port=5000
pasv_max_port=5050
EOF
    systemctl enable --now vsftpd

    ########################################
    # Sendmail 설치 및 설정
    ########################################
    dnf -y install sendmail sendmail-cf
    cp -f /etc/mail/sendmail.mc /etc/mail/sendmail.mc_ori
    [ -f /etc/mail/sendmail.cf ] && mv /etc/mail/sendmail.cf /etc/mail/sendmail.cf_ori
    sed -i 's/dnl TRUST_AUTH_MECH/TRUST_AUTH_MECH/g' /etc/mail/sendmail.mc
    sed -i 's/dnl define(`confAUTH_MECHANISMS/define(`confAUTH_MECHANISMS/g' /etc/mail/sendmail.mc
    sed -i 's/Addr=127.0.0.1/Addr=0.0.0.0/g' /etc/mail/sendmail.mc
    m4 /etc/mail/sendmail.mc > /etc/mail/sendmail.cf
    systemctl enable --now sendmail

    log_info "=== APM 설치 및 연동 완료 ==="
    ;;
no|n|N|NO)
    echo "APM 설치를 건너뜁니다."
    ;;
*)
    echo "잘못된 입력입니다. yes(y) 또는 no(n)을 입력하세요."
    ;;
esac
