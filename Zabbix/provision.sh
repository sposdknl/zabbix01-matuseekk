#!/bin/bash

DB_PASSWORD="zabbix_db_password"
DB_USER="zabbix_user"
DB_NAME="zabbix_db"
ZABBIX_VERSION="7.0"

echo "=== Zabbix Automatizovaná Instalace pro Debian ==="

echo "Updating the system..."
sudo apt update && sudo apt upgrade -y

echo "Installing dependencies..."
sudo apt install -y wget curl gnupg2 lsb-release software-properties-common locales

echo "Configuring language locales..."
sudo sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8

echo "Adding Zabbix repository..."
wget https://repo.zabbix.com/zabbix/$ZABBIX_VERSION/debian/pool/main/z/zabbix-release/zabbix-release_$ZABBIX_VERSION-1+debian$(lsb_release -rs)_all.deb
sudo dpkg -i zabbix-release_$ZABBIX_VERSION-1+debian$(lsb_release -rs)_all.deb
sudo apt update

echo "Installing Zabbix server, frontend, and agent..."
sudo apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-agent

echo "Installing MariaDB..."
sudo apt install -y mariadb-server mariadb-client
sudo systemctl start mariadb
sudo systemctl enable mariadb

echo "Configuring MariaDB..."
sudo mysql -e "CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;"
sudo mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
sudo mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

echo "Checking if Zabbix schema file exists..."
SCHEMA_FILE="/usr/share/doc/zabbix-server-mysql/create.sql.gz"
if [ ! -f "$SCHEMA_FILE" ]; then
  echo "Schema file not found, downloading from Zabbix CDN..."
  wget https://cdn.zabbix.com/zabbix/sources/stable/$ZABBIX_VERSION/schema.sql.gz -O /tmp/create.sql.gz
  SCHEMA_FILE="/tmp/create.sql.gz"
fi

echo "Importing Zabbix database schema..."
zcat $SCHEMA_FILE | mysql -u$DB_USER -p$DB_PASSWORD $DB_NAME

echo "Configuring Zabbix server..."
sudo sed -i "s/^# DBPassword=.*/DBPassword=$DB_PASSWORD/" /etc/zabbix/zabbix_server.conf
sudo sed -i "s/^# DBName=.*/DBName=$DB_NAME/" /etc/zabbix/zabbix_server.conf

echo "Configuring PHP timezone..."
sudo sed -i "s/^# php_value\[date.timezone\] = .*/php_value\[date.timezone\] = Europe\/Prague/" /etc/zabbix/apache.conf

echo "Restarting services..."
sudo systemctl restart zabbix-server zabbix-agent apache2
sudo systemctl enable zabbix-server zabbix-agent apache2

echo "Installation completed. Access the Zabbix frontend at http://<your-ip>/zabbix"
echo "Default credentials: Admin / zabbix"
