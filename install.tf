data "template_cloudinit_config" "install_nextcloud" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/scripts/1_nextcloud.sh", {})
  }

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/scripts/2_db.sh", {
      database_name = var.database_name,
      database_user = var.database_user,
      database_pass = var.database_pass,
      database_host = "10.0.3.101"

      admin_user = var.admin_user,
      admin_pass = var.admin_pass,
    })
  }

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/scripts/3_s3.sh", {
      region          = var.region,
      bucket_name     = var.bucket_name,
      user_access_key = aws_iam_access_key.nc-s3-access_key.id,
      user_secret_key = aws_iam_access_key.nc-s3-access_key.secret
    })
  }

  part {
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/scripts/4_apache.sh", {})
  }

  part {
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/scripts/5_start.sh", {})
  }
}

data "template_file" "install_database" {
  template = file("${path.module}/scripts/db_install.sh")
  vars = {
    database_user = var.database_user
    database_pass = var.database_pass
    database_name = var.database_name
  }
}