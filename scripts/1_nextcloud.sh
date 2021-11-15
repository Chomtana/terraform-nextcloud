#!/bin/bash

apt-get update
apt-get install -y apache2 mariadb-server libapache2-mod-php php-gd php-json php-mysql php-curl php-mbstring php-intl php-imagick php-xml php-zip

wget https://download.nextcloud.com/server/releases/latest.tar.bz2
tar -xjf latest.tar.bz2