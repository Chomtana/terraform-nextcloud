#!/bin/bash

cat << EOF > nextcloud/config/autoconfig.php
<?php
\$AUTOCONFIG = array(
  "dbtype"        => "mysql",
  "dbname"        => "${database_name}",
  "dbuser"        => "${database_user}",
  "dbpass"        => "${database_pass}",
  "dbhost"        => "${database_host}",
  "dbtableprefix" => "",
  "adminlogin"    => "${admin_user}",
  "adminpass"     => "${admin_pass}",
  "directory"     => "/var/www/nextcloud/data",
);
EOF