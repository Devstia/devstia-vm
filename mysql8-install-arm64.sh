#
# Pre-install stuff, TBD
#

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

apt install -y equivs libaio1 libncurses6

#
# MySQL 8.0.41 Installation
#
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
NEW_PASSWORD=$(date +%s | sha256sum | base64 | head -c 12)

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

# Create MySQL configuration file
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

# Create systemd service file
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

# Create symbolic links for MySQL binaries
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

# Write the roor password to our /root/.my.cnf file
echo -e "[client]\npassword='$NEW_PASSWORD'\n" > /root/.my.cnf
chmod 600 /root/.my.cnf

# Clean up
rm /tmp/${MYSQL_TAR}

# Fake-mysql-server apt installer/deb package; helps HestiaCP installer to continue on ARM64
mkdir -p /var/local/fake-mysql-server
cd /var/local/fake-mysql-server
cat <<EOT >> ./fake-mysql-server
Section: misc
Priority: optional
Standards-Version: 3.9.2
Package: mysql-server
Version: 8.0.36
Architecture: arm64
Maintainer: Local Admin <admin@localhost>
Description: Fake MySQL 8 package for HestiaCP
EOT
equivs-build fake-mysql-server

# Fake-mysql-client apt installer/deb package; helps HestiaCP installer to continue on ARM64
mkdir -p /var/local/fake-mysql-client
cd /var/local/fake-mysql-client
cat <<EOT >> ./fake-mysql-client
Section: misc
Priority: optional
Standards-Version: 3.9.2
Package: mysql-client
Version: 8.0.36
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
mpass=$NEW_PASSWORD
export MYSQL_TCP_PORT=3306
export MYSQL_UNIX_PORT=/run/mysqld/mysqld.sock
