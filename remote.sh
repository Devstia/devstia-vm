#!/bin/bash
#
# Devstia VM Remote Installer
# Project URI: https://github.com/devstia/devstia-vm
# Description: This is the remote script used to install Devstia on a remote server
# Author: Virtuosoft/Stephen J. Carnam
# License AGPL-3.0, for other licensing options contact support@virtuosoft.com
#
# This script is easier to read/manage when #region folding for VS Code see:
# https://marketplace.visualstudio.com/items?itemName=maptz.regionfolder
#

export DEBIAN_FRONTEND=noninteractive

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --hestiacp-version) HESTIACP_VERSION="$2"; shift ;;
        --devstia-domain) DEVSTIA_DOMAIN="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Default values if not provided
HESTIACP_VERSION="${HESTIACP_VERSION:-1.9.3}"
DEVSTIA_DOMAIN="${DEVSTIA_DOMAIN:-local.dev.pw}"

echo ""
echo "Starting automated install of HestiaCP $HESTIACP_VERSION."
echo "This will take a long while, please be patient..."
sleep 1
apt update

# Replace line in /etc/default/grub
echo "Updating GRUB timeout value to zero."
new_timeout_value="GRUB_TIMEOUT=0"
sed -i "s/GRUB_TIMEOUT=.*/$new_timeout_value/" /etc/default/grub
update-grub

# Remove apparmor
echo "Removing AppArmor."
apt remove -y apparmor

# Add ll globally
alias ll='ls -alF'
cat <<EOT >> /etc/bash.bashrc
alias ll='ls -alF'
EOT

# Download HesitaCP Installer
echo "Downloading HestiaCP $HESTIACP_VERSION installer."
cd /tmp
wget "https://raw.githubusercontent.com/hestiacp/hestiacp/refs/tags/$HESTIACP_VERSION/install/hst-install-debian.sh"

###
#region Begin Dectect ARM64; MySQL8 pre-install and modify HestiaCP installer
###
if [ "$(uname -m)" == "aarch64" ]; then
    echo "ARM64 architecture detected; pre-installing MySQL8."
    
    # Install dependencies
    apt install -y equivs libaio1 libncurses6

    # Variables
    MYSQL_VERSION="8.0.41"
    MYSQL_TAR="mysql-${MYSQL_VERSION}-linux-glibc2.28-aarch64.tar.xz"
    MYSQL_URL="https://dev.mysql.com/get/Downloads/MySQL-8.0/${MYSQL_TAR}"
    MYSQL_INSTALL_DIR="/usr/local/mysql"
    MYSQL_DATA_DIR="/var/lib/mysql"
    MYSQL_LOG_DIR="/var/log/mysql"
    MYSQL_RUN_DIR="/run/mysqld"
    MYSQL_USER="mysql"
    MYSQL_GROUP="mysql"
    NEW_PASSWORD=$(date +%s | sha256sum | base64 | head -c 20)

    # Download MySQL binaries
    wget ${MYSQL_URL} -O /tmp/${MYSQL_TAR}

    # Extract MySQL binaries
    mkdir -p ${MYSQL_INSTALL_DIR}
    tar -xvf /tmp/${MYSQL_TAR} -C ${MYSQL_INSTALL_DIR} --strip-components=1

    # Create MySQL user and group
    groupadd ${MYSQL_GROUP}
    useradd -r -g ${MYSQL_GROUP} -s /bin/false ${MYSQL_USER}

    # Set up directory structure
    mkdir -p ${MYSQL_DATA_DIR} ${MYSQL_LOG_DIR} ${MYSQL_RUN_DIR}
    chown -R ${MYSQL_USER}:${MYSQL_GROUP} ${MYSQL_DATA_DIR} ${MYSQL_LOG_DIR} ${MYSQL_RUN_DIR}

    # Initialize MySQL data directory and capture output
    init_output=$(${MYSQL_INSTALL_DIR}/bin/mysqld --initialize --user=${MYSQL_USER} --datadir=${MYSQL_DATA_DIR} 2>&1)
    ${MYSQL_INSTALL_DIR}/bin/mysql_ssl_rsa_setup --datadir=${MYSQL_DATA_DIR}

    # Extract the temporary password from the initialization output
    temp_password=$(echo "$init_output" | grep 'temporary password' | awk '{print $NF}')
    echo "Temporary password: $temp_password"

    # Create MySQL configuration directory
    mkdir -p /etc/mysql /etc/mysql/conf.d /etc/mysql/mysql.conf.d

    #region Create MySQL configuration file
    cat <<EOT > /etc/mysql/my.cnf
[client]
port=3306
socket=${MYSQL_RUN_DIR}/mysqld.sock
default-character-set=utf8mb4

[mysql]
default-character-set=utf8mb4

[mysqld_safe]
socket=${MYSQL_RUN_DIR}/mysqld.sock

[mysqld]
user=${MYSQL_USER}
pid-file=${MYSQL_RUN_DIR}/mysqld.pid
socket=${MYSQL_RUN_DIR}/mysqld.sock
port=3306
basedir=${MYSQL_INSTALL_DIR}
datadir=${MYSQL_DATA_DIR}
tmpdir=/tmp
lc-messages-dir=${MYSQL_INSTALL_DIR}/share
log_error=${MYSQL_LOG_DIR}/error.log
collation-server = utf8mb4_unicode_520_ci
init-connect='SET NAMES utf8mb4'
character-set-server = utf8mb4

symbolic-links=0
local-infile=0

skip-external-locking
key_buffer_size = 256M
max_allowed_packet = 32M
table_open_cache = 256
sort_buffer_size = 1M
read_buffer_size = 1M
read_rnd_buffer_size = 4M
myisam_sort_buffer_size = 64M
thread_cache_size = 8

#innodb_use_native_aio = 0
innodb_file_per_table

max_connections=200
max_user_connections=50
wait_timeout=10
interactive_timeout=50
long_query_time=5

!includedir /etc/mysql/conf.d/
!includedir /etc/mysql/mysql.conf.d/
EOT
    #endregion

    #region Create systemd service file
    cat <<EOT > /etc/systemd/system/mysql.service
[Unit]
Description=MySQL Server
After=network.target

[Service]
User=${MYSQL_USER}
Group=${MYSQL_GROUP}
PermissionsStartOnly=true
ExecStartPre=/bin/mkdir -p ${MYSQL_RUN_DIR}
ExecStartPre=/bin/chown ${MYSQL_USER}:${MYSQL_GROUP} ${MYSQL_RUN_DIR}
ExecStart=${MYSQL_INSTALL_DIR}/bin/mysqld --defaults-file=/etc/mysql/my.cnf
LimitNOFILE=5000
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOT
    #endregion

    #region Create symbolic links for MySQL binaries
    ln -s /usr/local/mysql/bin/mysql /usr/bin/mysql
    ln -s /usr/local/mysql/bin/mysqld /usr/sbin/mysqld
    ln -s /usr/local/mysql/bin/mysqladmin /usr/bin/mysqladmin
    ln -s /usr/local/mysql/bin/mysqldump /usr/bin/mysqldump
    ln -s /usr/local/mysql/bin/mysqlshow /usr/bin/mysqlshow
    ln -s /usr/local/mysql/bin/mysqlcheck /usr/bin/mysqlcheck
    ln -s /usr/local/mysql/bin/mysqlslap /usr/bin/mysqlslap
    ln -s /usr/local/mysql/bin/mysqlimport /usr/bin/mysqlimport
    ln -s /usr/local/mysql/bin/mysqlpump /usr/bin/mysqlpump
    ln -s /usr/local/mysql/bin/mysqlbinlog /usr/bin/mysqlbinlog
    ln -s /usr/local/mysql/bin/mysql_config_editor /usr/bin/mysql_config_editor
    ln -s /usr/local/mysql/bin/mysql_secure_installation /usr/bin/mysql_secure_installation
    ln -s /usr/local/mysql/bin/mysql_upgrade /usr/bin/mysql_upgrade
    ln -s /usr/local/mysql/bin/myisamchk /usr/bin/myisamchk
    ln -s /usr/local/mysql/bin/myisam_ftdump /usr/bin/myisam_ftdump
    ln -s /usr/local/mysql/bin/myisamlog /usr/bin/myisamlog
    ln -s /usr/local/mysql/bin/myisampack /usr/bin/myisampack
    ln -s /usr/local/mysql/bin/my_print_defaults /usr/bin/my_print_defaults
    ln -s /usr/local/mysql/bin/mysqld_multi /usr/bin/mysqld_multi
    ln -s /usr/local/mysql/bin/mysqld_safe /usr/bin/mysqld_safe
    ln -s /usr/local/mysql/bin/mysqldumpslow /usr/bin/mysqldumpslow
    ln -s /usr/local/mysql/bin/mysql_migrate_keyring /usr/bin/mysql_migrate_keyring
    ln -s /usr/local/mysql/bin/mysql_ssl_rsa_setup /usr/bin/mysql_ssl_rsa_setup
    ln -s /usr/local/mysql/bin/mysql_tzinfo_to_sql /usr/bin/mysql_tzinfo_to_sql
    #endregion

    # Reload systemd daemon to recognize the new service
    systemctl daemon-reload

    # Enable and start the MySQL service
    systemctl enable mysql
    systemctl start mysql

    # Wait for MySQL server to be fully ready
    sleep 10

    # Set the root password using mysqladmin
    mysqladmin -u root --password="$temp_password" password "$NEW_PASSWORD"

    # Verify the root user configuration
    mysql -u root -p"$NEW_PASSWORD" -e "SELECT user, host, plugin FROM mysql.user WHERE user = 'root';"

    # Write the root password to our /root/.my.cnf file
    echo -e "[client]\npassword='$NEW_PASSWORD'\n" > /root/.my.cnf
    chmod 600 /root/.my.cnf

    # Clean up
    rm /tmp/${MYSQL_TAR}

    #region Create fake apt deb packages to satisfy HestiaCP installer
    # Fake-mysql-server apt
    mkdir -p /var/local/fake-mysql-server
    cd /var/local/fake-mysql-server

    cat <<EOT > ./fake-mysql-server
Section: misc
Priority: optional
Standards-Version: 3.9.2
Package: mysql-server
Version: ${MYSQL_VERSION}
Architecture: arm64
Maintainer: Local Admin <admin@localhost>
Description: Fake MySQL 8 package for HestiaCP
EOT

    equivs-build fake-mysql-server

    # Fake-mysql-client apt
    mkdir -p /var/local/fake-mysql-client
    cd /var/local/fake-mysql-client
cat <<EOT > ./fake-mysql-client
Section: misc
Priority: optional
Standards-Version: 3.9.2
Package: mysql-client
Version: ${MYSQL_VERSION}
Architecture: arm64
Maintainer: Local Admin <admin@localhost>
Description: Fake MySQL 8 package for HestiaCP
EOT
    equivs-build fake-mysql-client

    # Generate Packages files
    cd /var/local/fake-mysql-server
    dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
    cd /var/local/fake-mysql-client
    dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz

    # Update apt with new packages
    sudo dpkg -i /var/local/fake-mysql-server/*.deb
    sudo dpkg -i /var/local/fake-mysql-client/*.deb
    apt update

    # Add our fake MySQL8 packages to the apt repository to satisfy HestiaCP installer
    echo "deb [trusted=yes] file:/var/local/fake-mysql-server ./" | sudo tee /etc/apt/sources.list.d/mysql-server-local.list
    echo "deb [trusted=yes] file:/var/local/fake-mysql-client ./" | sudo tee /etc/apt/sources.list.d/mysql-client-local.list
   

    # Append to /etc/hestiacp/local.conf
    mkdir -p /etc/hestiacp
    cat <<EOT > /etc/hestiacp/local.conf
# MySQL environment variables
export MYSQL_TCP_PORT=3306
export MYSQL_UNIX_PORT=/run/mysqld/mysqld.sock
EOT
    #endregion  Create fake apt deb packages to satisfy HestiaCP installer

    # Modify HestiaCP installer; comment out code to allow MySQL8 on ARM64
    sed -i '416,418 s/^/#/' /tmp/hst-install-debian.sh
    sed -i '964,969 s/^/#/' /tmp/hst-install-debian.sh
    sed -i '1786,1794 s/^/#/' /tmp/hst-install-debian.sh

    # Set the MySQL mpass password and environment variables needed to 
    # allow HestiaCP to work with pre-installed MySQL8 on ARM64
    export mpass=$NEW_PASSWORD
    export MYSQL_TCP_PORT=3306
    export MYSQL_UNIX_PORT=/run/mysqld/mysqld.sock
fi

###
###endregion End Dectect ARM64; MySQL8 pre-install and modify HestiaCP installer
###


###
###region Install HestiaCP for Devstia Personal Web edition
###
cd /tmp
if [ "$DEVSTIA_DOMAIN" == "local.dev.pw" ]; then
    echo "Installing HestiaCP for Devstia Personal Web edition."
    bash hst-install-debian.sh --apache yes --phpfpm yes --multiphp yes --vsftpd yes --proftpd no --named no --mariadb no --mysql8 yes --postgresql yes --exim no --dovecot no --sieve no --clamav no --spamassassin no --iptables yes --fail2ban no --quota no --api yes --interactive no --with-debs yes --port '8083' --hostname 'local.dev.pw' --email 'devstia@dev.pw' --username 'admin' --password 'personalweb' --lang 'en' --webterminal no

    # Customize the SSH login message for dev.pw
    cat <<EOT > /etc/update-motd.d/00-header
#!/bin/bash
printf '%b\n' '\033[2J\033[:H'
clear
asciiart="\e[38;5;244m 
\e[38;5;244m                     \e[38;5;60m▒\e[38;5;130m▓\e[38;5;166m▄\e[38;5;167m▄
\e[38;5;244m   Welcome to        \e[38;5;67m▐\e[38;5;32m▒\e[38;5;94m▒\e[38;5;208m▒\e[38;5;208m▒\e[38;5;208m▌
\e[38;5;244m                     \e[38;5;66m▐\e[38;5;26m▒\e[38;5;32m▒\e[38;5;172m▒\e[38;5;214m▒\e[38;5;214m▒\e[38;5;214m▒
\e[38;5;244m   Devstia\xe2\x84\xa2 PW       \e[38;5;60m▐\e[38;5;25m▓\e[38;5;25m▒\e[38;5;239m▒\e[38;5;214m▒\e[38;5;214m▒▒
\e[38;5;244m                     \e[38;5;60m▐\e[38;5;25m▓\e[38;5;25m▓\e[38;5;24m▓\e[38;5;202m▒\e[38;5;202m▒▒
\e[38;5;244m                     \e[38;5;60m▐\e[38;5;24m▓\e[38;5;24m▓\e[38;5;17m▓\e[38;5;202m▒\e[38;5;202m▒▒
\e[38;5;244m                     \e[38;5;60m▐\e[38;5;24m▓\e[38;5;24m▓\e[38;5;53m▓\e[38;5;196m▒\e[38;5;196m▒\e[38;5;160m▌
\e[38;5;244m             \e[38;5;68m▄\e[38;5;32m▒\e[38;5;33m▒\e[38;5;26m▒\e[38;5;25m▓\e[38;5;25m▓\e[38;5;25m▓\e[38;5;24m▓\e[38;5;24m▓\e[38;5;24m▓\e[38;5;24m▓\e[38;5;89m▓\e[38;5;160m▓\e[38;5;160m▓
\e[38;5;244m          \e[38;5;67m▒\e[38;5;68m░\e[38;5;32m░\e[38;5;26m▒\e[38;5;25m▓\e[38;5;25m▓\e[38;5;25m▓\e[38;5;24m▀\e[38;5;60m▀  \e[38;5;25m▓\e[38;5;25m▓\e[38;5;24m▓\e[38;5;124m▓\e[38;5;160m▓\e[38;5;160m▓
\e[38;5;244m        \e[38;5;67m░\e[38;5;67m░\e[38;5;67m░\e[38;5;31m▒\e[38;5;25m▓\e[38;5;25m▓▓▓     ▓\e[38;5;25m▓\e[38;5;24m▓\e[38;5;124m▓\e[38;5;124m▓\e[38;5;124m▌
\e[38;5;244m       \e[38;5;67m░\e[38;5;67m░\e[38;5;67m░\e[38;5;31m█\e[38;5;25m▓\e[38;5;25m▓▓\e[38;5;25m▓     \e[38;5;60m▐\e[38;5;25m▓\e[38;5;25m▓\e[38;5;236m▓\e[38;5;124m▓\e[38;5;124m▓
\e[38;5;244m      \e[38;5;32m▒\e[38;5;68m░░\e[38;5;32m░\e[38;5;32m▒\e[38;5;32m▒▒▒      \e[38;5;25m▓\e[38;5;25m▓\e[38;5;25m▓\e[38;5;1m▓\e[38;5;124m▓\e[38;5;124m▓
\e[38;5;244m      \e[38;5;32m▒\e[38;5;32m▒▒\e[38;5;33m▒\e[38;5;33m▒▒▒\e[38;5;32m▌      \e[38;5;25m▓\e[38;5;25m▓\e[38;5;24m▓\e[38;5;88m▓\e[38;5;88m▓\e[38;5;88m▓
\e[38;5;244m     \e[38;5;67m▐\e[38;5;33m▒\e[38;5;33m▒▒\e[38;5;33m▒\e[38;5;32m▒\e[38;5;32m▒\e[38;5;32m▒      \e[38;5;25m▓\e[38;5;25m▓\e[38;5;24m▓\e[38;5;53m▓\e[38;5;88m▓\e[38;5;88m▓\e[38;5;88m▌
\e[38;5;244m      \e[38;5;26m▒\e[38;5;26m▒▒\e[38;5;32m░\e[38;5;68m░\e[38;5;67m░\e[38;5;67m░\e[38;5;67m░    \e[38;5;32m▐\e[38;5;24m▓\e[38;5;24m▓\e[38;5;24m▓\e[38;5;53m▓\e[38;5;124m▓\e[38;5;124m▓\e[38;5;124m▌   \e[38;5;244m \xc2\xa92025 Virtuosoft
\e[38;5;244m      \e[38;5;60m▀\e[38;5;25m▓\e[38;5;25m▓\e[38;5;25m▓\e[38;5;67m░\e[38;5;67m░\e[38;5;31m█\e[38;5;67m░░ \e[38;5;67m▄\e[38;5;25m▓\e[38;5;60m▀ \e[38;5;24m▓\e[38;5;24m▓\e[38;5;25m▓\e[38;5;53m▓\e[38;5;124m▓\e[38;5;124m▓
\e[38;5;244m        \e[38;5;60m▀\e[38;5;24m▓\e[38;5;24m▓\e[38;5;24m▓\e[38;5;25m▓\e[38;5;25m▓\e[38;5;25m▓\e[38;5;60m▀     \e[38;5;60m▀\e[38;5;25m▓\e[38;5;25m▒▒\e[38;5;238m▒\e[38;5;89m▓\e[38;5;95m▄\e[38;5;95m▄
\e[38;5;244m "
echo -e "\$asciiart"
EOT
    chmod +x /etc/update-motd.d/00-header
    : > /etc/motd

    # White label the HestiaCP control panel interface
    cd /usr/local/hestia/bin
    ./v-change-sys-config-value LOGIN_STYLE old
    ./v-change-sys-config-value APP_NAME "Devstia PW"
    ./v-change-sys-config-value FROM_NAME "Devstia PW"

    # Create our devstia user and package
    cat <<EOT > /tmp/devstia.txt
PACKAGE='devstia'
WEB_TEMPLATE='default'
BACKEND_TEMPLATE='default'
PROXY_TEMPLATE='default'
DNS_TEMPLATE='default'
WEB_DOMAINS='unlimited'
WEB_ALIASES='unlimited'
DNS_DOMAINS='unlimited'
DNS_RECORDS='unlimited'
MAIL_DOMAINS='unlimited'
MAIL_ACCOUNTS='unlimited'
RATE_LIMIT='200'
DATABASES='unlimited'
CRON_JOBS='unlimited'
DISK_QUOTA='unlimited'
BANDWIDTH='unlimited'
NS='ns1.dev.pw,ns2.dev.pw'
SHELL='bash'
BACKUPS_INCREMENTAL='yes'
BACKUPS='1'
SHELL_JAIL_ENABLED='yes'
EOT
    ./v-add-user-package /tmp/devstia.txt devstia
    ./v-add-user devstia personalweb devstia@dev.pw devstia Devstia PersonalWeb
    ./v-update-user-package devstia
    chsh -s /bin/bash devstia
    ./v-add-user-composer devstia
    ./v-add-user-wp-cli devstia
    ./v-change-sys-config-value POLICY_USER_EDIT_WEB_TEMPLATES yes
    ./v-change-sys-config-value POLICY_SYSTEM_HIDE_ADMIN yes
    ./v-change-user-role devstia admin
###
###endregion Install HestiaCP for Devstia Personal Web edition
###


###
###region Install HestiaCP for Devstia Cloud Connect edition
###
else
    echo "Installing HestiaCP for Devstia Cloud Connect edition."
    CC_PW=$(date +%s | sha256sum | base64 | head -c 20)
    bash hst-install-debian.sh --apache yes --phpfpm yes --multiphp yes --vsftpd yes --proftpd no --named yes --mariadb no --mysql8 yes --postgresql yes --exim yes --dovecot yes --sieve no --clamav yes --spamassassin yes --iptables yes --fail2ban yes --quota yes --api yes --interactive no --with-debs yes --port '8083' --hostname $DEVSTIA_DOMAIN --email 'support@devstia.com' --username 'admin' --password "$CC_PW" --lang 'en' --webterminal no

    # Customize the SSH login message for dev.cc
    cat <<EOT > /etc/update-motd.d/00-header
#!/bin/bash
printf '%b\n' '\033[2J\033[:H'
clear
asciiart="\e[38;5;244m 
\e[38;5;244m                     \e[38;5;60m▒\e[38;5;130m▓\e[38;5;166m▄\e[38;5;167m▄
\e[38;5;244m   Welcome to        \e[38;5;67m▐\e[38;5;32m▒\e[38;5;94m▒\e[38;5;208m▒\e[38;5;208m▒\e[38;5;208m▌
\e[38;5;244m                     \e[38;5;66m▐\e[38;5;26m▒\e[38;5;32m▒\e[38;5;172m▒\e[38;5;214m▒\e[38;5;214m▒\e[38;5;214m▒
\e[38;5;244m   Devstia\xe2\x84\xa2 CC       \e[38;5;60m▐\e[38;5;25m▓\e[38;5;25m▒\e[38;5;239m▒\e[38;5;214m▒\e[38;5;214m▒▒
\e[38;5;244m                     \e[38;5;60m▐\e[38;5;25m▓\e[38;5;25m▓\e[38;5;24m▓\e[38;5;202m▒\e[38;5;202m▒▒
\e[38;5;244m                     \e[38;5;60m▐\e[38;5;24m▓\e[38;5;24m▓\e[38;5;17m▓\e[38;5;202m▒\e[38;5;202m▒▒
\e[38;5;244m                     \e[38;5;60m▐\e[38;5;24m▓\e[38;5;24m▓\e[38;5;53m▓\e[38;5;196m▒\e[38;5;196m▒\e[38;5;160m▌
\e[38;5;244m             \e[38;5;68m▄\e[38;5;32m▒\e[38;5;33m▒\e[38;5;26m▒\e[38;5;25m▓\e[38;5;25m▓\e[38;5;25m▓\e[38;5;24m▓\e[38;5;24m▓\e[38;5;24m▓\e[38;5;24m▓\e[38;5;89m▓\e[38;5;160m▓\e[38;5;160m▓
\e[38;5;244m          \e[38;5;67m▒\e[38;5;68m░\e[38;5;32m░\e[38;5;26m▒\e[38;5;25m▓\e[38;5;25m▓\e[38;5;25m▓\e[38;5;24m▀\e[38;5;60m▀  \e[38;5;25m▓\e[38;5;25m▓\e[38;5;24m▓\e[38;5;124m▓\e[38;5;160m▓\e[38;5;160m▓
\e[38;5;244m        \e[38;5;67m░\e[38;5;67m░\e[38;5;67m░\e[38;5;31m▒\e[38;5;25m▓\e[38;5;25m▓▓▓     ▓\e[38;5;25m▓\e[38;5;24m▓\e[38;5;124m▓\e[38;5;124m▓\e[38;5;124m▌
\e[38;5;244m       \e[38;5;67m░\e[38;5;67m░\e[38;5;67m░\e[38;5;31m█\e[38;5;25m▓\e[38;5;25m▓▓\e[38;5;25m▓     \e[38;5;60m▐\e[38;5;25m▓\e[38;5;25m▓\e[38;5;236m▓\e[38;5;124m▓\e[38;5;124m▓
\e[38;5;244m      \e[38;5;32m▒\e[38;5;68m░░\e[38;5;32m░\e[38;5;32m▒\e[38;5;32m▒▒▒      \e[38;5;25m▓\e[38;5;25m▓\e[38;5;25m▓\e[38;5;1m▓\e[38;5;124m▓\e[38;5;124m▓
\e[38;5;244m      \e[38;5;32m▒\e[38;5;32m▒▒\e[38;5;33m▒\e[38;5;33m▒▒▒\e[38;5;32m▌      \e[38;5;25m▓\e[38;5;25m▓\e[38;5;24m▓\e[38;5;88m▓\e[38;5;88m▓\e[38;5;88m▓
\e[38;5;244m     \e[38;5;67m▐\e[38;5;33m▒\e[38;5;33m▒▒\e[38;5;33m▒\e[38;5;32m▒\e[38;5;32m▒\e[38;5;32m▒      \e[38;5;25m▓\e[38;5;25m▓\e[38;5;24m▓\e[38;5;53m▓\e[38;5;88m▓\e[38;5;88m▓\e[38;5;88m▌
\e[38;5;244m      \e[38;5;26m▒\e[38;5;26m▒▒\e[38;5;32m░\e[38;5;68m░\e[38;5;67m░\e[38;5;67m░\e[38;5;67m░    \e[38;5;32m▐\e[38;5;24m▓\e[38;5;24m▓\e[38;5;24m▓\e[38;5;53m▓\e[38;5;124m▓\e[38;5;124m▓\e[38;5;124m▌   \e[38;5;244m \xc2\xa92025 Virtuosoft
\e[38;5;244m      \e[38;5;60m▀\e[38;5;25m▓\e[38;5;25m▓\e[38;5;25m▓\e[38;5;67m░\e[38;5;67m░\e[38;5;31m█\e[38;5;67m░░ \e[38;5;67m▄\e[38;5;25m▓\e[38;5;60m▀ \e[38;5;24m▓\e[38;5;24m▓\e[38;5;25m▓\e[38;5;53m▓\e[38;5;124m▓\e[38;5;124m▓
\e[38;5;244m        \e[38;5;60m▀\e[38;5;24m▓\e[38;5;24m▓\e[38;5;24m▓\e[38;5;25m▓\e[38;5;25m▓\e[38;5;25m▓\e[38;5;60m▀     \e[38;5;60m▀\e[38;5;25m▓\e[38;5;25m▒▒\e[38;5;238m▒\e[38;5;89m▓\e[38;5;95m▄\e[38;5;95m▄
\e[38;5;244m "
echo -e "\$asciiart"
EOT
    chmod +x /etc/update-motd.d/00-header
    : > /etc/motd

    # Limit ClamAV threads
    file_path="/etc/clamav/clamd.conf"
    if [ -f "$file_path" ]; then
        echo "MaxThreads 2" >> "$file_path"
    fi

    # White label the HestiaCP control panel interface
    cd /usr/local/hestia/bin
    ./v-change-sys-config-value APP_NAME "Devstia CC"
    ./v-change-sys-config-value FROM_NAME "Devstia CC"

    # Add default IP blacklist and turn off autoupdates in production
    ./v-add-firewall-ipset blacklist 'script:/usr/local/hestia/install/common/firewall/ipset/blacklist.sh' v4 yes
    ./v-delete-cron-hestia-autoupdate 

fi
###
###endregion Install HestiaCP for Devstia Cloud Connect edition
###


###
###region Operating System Settings
###

# Allocate 4G Swap file
sudo fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
line="/swapfile none swap sw 0 0"
echo "$line" >> /etc/fstab

# Limit the journal for production
file_path="/etc/systemd/journald.conf"

# Backup the original file
cp "$file_path" "$file_path.bak"

# Update the file with the desired values
file_path="/etc/systemd/journald.conf"
sed -i 's/^#SystemMaxUse=.*/SystemMaxUse=100M/' "$file_path"
sed -i 's/^#SystemKeepFree=.*/SystemKeepFree=50M/' "$file_path"
sed -i 's/^#SystemMaxFileSize=.*/SystemMaxFileSize=50M/' "$file_path"
sed -i 's/^#SystemMaxFiles=.*/SystemMaxFiles=5/' "$file_path"

###
###endregion Operating System Settings
###

###
###region Install Virtuosoft's HesticCP-Pluginable and HCPP Based Plugins
###

# Install Virtuosoft's HesticCP-Pluginable project
cd /etc/hestiacp
git clone --depth 1 --branch "version2.0.0" https://github.com/virtuosoft-dev/hestiacp-pluginable.git ./hooks
cd /etc/hestiacp/hooks
./post_install.sh

# Install Virtuosoft's HCPP-NodeApp plugin
cd /usr/local/hestia/plugins
git clone --depth 1 --branch "version2.0.0" https://github.com/virtuosoft-dev/hcpp-nodeapp.git ./nodeapp
cd /usr/local/hestia/plugins/nodeapp
./install
touch "/usr/local/hestia/data/hcpp/installed/nodeapp"

###
###endregion Install Virtuosoft's HesticCP-Pluginable and HCPP Based Plugins
###

# Turn off autoupdates for debugging
cd /usr/local/hestia/bin
./v-delete-cron-hestia-autoupdate

# Restart HestiaCP and turn logging on
systemctl restart hestia
touch /etc/hestiacp/hooks/logging

if [ "$DEVSTIA_DOMAIN" == "local.dev.pw" ]; then

else
    echo "Devstia Cloud Connect at https://$DEVSTIA_DOMAIN:8083 admin password: $CC_PW"
fi
# Reboot the server
#echo "Shutting down server."
#sleep 60
#poweroff
