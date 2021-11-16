#!/bin/bash

cat << EOF > nextcloud/config/storage.config.php
<?php
\$CONFIG = array (
  "objectstore" => array( 
    "class" => "OC\\Files\\ObjectStore\\S3",
    "arguments" => array(
      "bucket" => "${bucket_name}",
      "key"    => "${user_access_key}",
      "secret" => "${user_secret_key}",
      "use_ssl" => true,
      "region" => "${region}"
    ),
  ),
);
EOF