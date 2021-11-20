#!/bin/bash
apt update -y
apt install -y mariadb-server

echo "[mysqld]
skip-networking=0
skip-bind-address" >> /etc/mysql/mariadb.conf.d/50-server.cnf

systemctl restart mariadb

echo "CREATE USER '${database_user}'@'${private_bridge_app_ip}' IDENTIFIED BY '${database_pass}';
CREATE DATABASE IF NOT EXISTS ${database_name} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
GRANT ALL PRIVILEGES ON ${database_name}.* TO '${database_user}'@'${private_bridge_app_ip}';
FLUSH PRIVILEGES;" > /home/ubuntu/setup.sql

mysql < /home/ubuntu/setup.sql