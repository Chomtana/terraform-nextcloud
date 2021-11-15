data "aws_caller_identity" "current" {}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.65"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = var.region
}

// IAM

resource "aws_iam_user" "nc-s3" {
  name = "terraform-nc-s3"
}

resource "aws_iam_access_key" "nc-s3-access_key" {
  user = aws_iam_user.nc-s3.name
}

// VPC & Subnet

resource "aws_vpc" "nc_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name = "VPC"
  }
}

# Public subnet
resource "aws_subnet" "nc_app_subnet" {
  vpc_id            = aws_vpc.nc_vpc.id
  cidr_block        = var.public_subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name = "App public subnet"
  }
}

# Private subnet
resource "aws_subnet" "nc_db_subnet" {
  vpc_id            = aws_vpc.nc_vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name = "DB private subnet"
  }
}

resource "aws_subnet" "nc_app_private_subnet" {
  vpc_id            = aws_vpc.nc_vpc.id
  cidr_block        = var.private_subnet_app_cidr
  availability_zone = var.availability_zone

  tags = {
    Name = "App private subnet"
  }
}

# resource "aws_db_subnet_group" "nc_db_subnet_group" {
#   name       = "nc_db_subnet_group"
#   subnet_ids = [aws_subnet.nc_app_subnet.id, aws_subnet.nc_db_subnet.id]

#   tags = {
#     Name = "App and DB subnet group"
#   }
# }

# Internet gateway
resource "aws_internet_gateway" "nc_vpc_igw" {
  vpc_id = aws_vpc.nc_vpc.id

  tags = {
    Name = "Nextcloud internet gateway"
  }
}

# Nat gateway
resource "aws_nat_gateway" "nc_vpc_ngw" {
  allocation_id = aws_eip.nc_db_ip.id
  subnet_id     = aws_subnet.nc_app_subnet.id

  tags = {
    Name = "Nextcloud NAT gateway"
  }
}

# Elastic IP
resource "aws_eip" "nc_app_ip" {
  vpc               = true
  depends_on        = [aws_internet_gateway.nc_vpc_igw]
  network_interface = aws_network_interface.nc_public_eni.id
}

resource "aws_eip" "nc_db_ip" {
  vpc = true
}

# Route table
resource "aws_route_table" "nc_app_route_table" {
  vpc_id = aws_vpc.nc_vpc.id

  tags = {
    Name = "Nextcloud route table"
  }
}

resource "aws_route" "nc_app_route" {
  route_table_id         = aws_route_table.nc_app_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.nc_vpc_igw.id
}

resource "aws_route_table_association" "nc_app_rt_assoc" {
  subnet_id      = aws_subnet.nc_app_subnet.id
  route_table_id = aws_route_table.nc_app_route_table.id
}

resource "aws_route_table" "nc_db_route_table" {
  vpc_id = aws_vpc.nc_vpc.id

  tags = {
    Name = "Database route table"
  }
}

resource "aws_route" "nc_db_route" {
  route_table_id         = aws_route_table.nc_db_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nc_vpc_ngw.id
}

resource "aws_route_table_association" "nc_db_rt_assoc" {
  subnet_id      = aws_subnet.nc_db_subnet.id
  route_table_id = aws_route_table.nc_db_route_table.id
}

// ENI

resource "aws_network_interface" "nc_public_eni" {
  subnet_id       = aws_subnet.nc_app_subnet.id
  security_groups = [aws_security_group.nc_app_security_group.id]
}

resource "aws_network_interface" "nc_private_eni" {
  subnet_id       = aws_subnet.nc_app_private_subnet.id
  security_groups = [aws_security_group.nc_bridge_security_group.id]
  private_ips     = ["10.0.3.100"]
}

resource "aws_network_interface" "db_private_eni" {
  subnet_id       = aws_subnet.nc_app_private_subnet.id
  security_groups = [aws_security_group.nc_bridge_security_group.id]
  private_ips     = ["10.0.3.101"]
}

resource "aws_network_interface" "db_nat_eni" {
  subnet_id       = aws_subnet.nc_db_subnet.id
  security_groups = [aws_security_group.nc_db_security_group.id]
}

// S3 Bucket

resource "aws_s3_bucket" "nc_s3" {
  bucket = var.bucket_name
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "aws:kms"
      }
    }
  }

  force_destroy = false

  tags = {
    Name = "Nextcloud S3"
  }
}

# S3 bucket policy
resource "aws_s3_bucket_policy" "nc_s3_policy" {

  bucket = aws_s3_bucket.nc_s3.id

  policy = <<S3_POLICY
{
  "Id": "NextcloudS3Policy",
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllActions",
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": [ 
          "${aws_s3_bucket.nc_s3.arn}",
          "${aws_s3_bucket.nc_s3.arn}/*" 
        ],
      "Principal": {
        "AWS": [
            "${aws_iam_user.nc-s3.arn}",
            "${data.aws_caller_identity.current.arn}"
        ]
      }
    },
    {
      "Sid": "DenyTheRest",
      "Effect": "Deny",
      "Action": ["s3:*"],
      "Resource": [ "${aws_s3_bucket.nc_s3.arn}" ],
      "NotPrincipal": {
        "AWS": [
            "${aws_iam_user.nc-s3.arn}",
            "${data.aws_caller_identity.current.arn}"
        ]
      }
    }
  ]
}
S3_POLICY
}

// DB instance

resource "aws_instance" "nc_mysql_instance" {
  ami           = var.ami
  instance_type = var.instance_type_db
  key_name      = var.key_name
  # vpc_security_group_ids = [aws_security_group.nc_db_security_group.id]
  # db_subnet_group_name   = aws_db_subnet_group.nc_db_subnet_group.id

  network_interface {
    network_interface_id = aws_network_interface.db_nat_eni.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.db_private_eni.id
    device_index         = 1
  }

  user_data = data.template_file.install_database.rendered

  tags = {
    "Name" = "Nextclod Database Instance"
  }
}

# Security group for Bridge App <-> DB instance
resource "aws_security_group" "nc_bridge_security_group" {
  name        = "nc_bridge_security_group"
  description = "Allow traffic from Nextcloud app"

  vpc_id = aws_vpc.nc_vpc.id

  ingress {
    from_port         = 3306
    to_port           = 3306
    protocol          = "tcp"
    self              = true
  }

  egress {
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    cidr_blocks       = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Nextcloud bridge security group"
  }
}

# resource "aws_security_group_rule" "nc_bridge_port3306" {
#   type              = "ingress"
#   from_port         = 3306
#   to_port           = 3306
#   protocol          = "tcp"
#   self              = true
#   security_group_id = aws_security_group.nc_bridge_security_group.id
# }

# resource "aws_security_group_rule" "nc_bridge_egress" {
#   type              = "egress"
#   from_port         = 0
#   to_port           = 0
#   protocol          = "-1"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = aws_security_group.nc_bridge_security_group.id
# }

# Security group for DB instance
resource "aws_security_group" "nc_db_security_group" {
  name        = "nc_db_security_group"
  description = "Allow traffic from Nextcloud app"

  vpc_id = aws_vpc.nc_vpc.id

  ingress {
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    self              = true
  }

  egress {
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    cidr_blocks       = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Nextcloud DB security group"
  }
}

# resource "aws_security_group_rule" "nc_db_ingress" {
#   type              = "ingress"
#   from_port         = 0
#   to_port           = 0
#   protocol          = "-1"
#   self              = true
#   security_group_id = aws_security_group.nc_db_security_group.id
# }

# resource "aws_security_group_rule" "nc_db_egress" {
#   type              = "egress"
#   from_port         = 0
#   to_port           = 0
#   protocol          = "-1"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = aws_security_group.nc_db_security_group.id
# }

// App instance

resource "aws_instance" "nc_app_instance" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = var.key_name
  # vpc_security_group_ids = [aws_security_group.nc_app_security_group.id]
  # subnet_id              = aws_subnet.nc_app_subnet.id

  network_interface {
    network_interface_id = aws_network_interface.nc_public_eni.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.nc_private_eni.id
    device_index         = 1
  }

  tags = {
    Name = "Nextcloud EC2"
  }

  user_data = data.template_cloudinit_config.install_nextcloud.rendered

  depends_on = [
    aws_s3_bucket.nc_s3,
    aws_instance.nc_mysql_instance
  ]
}

# Security group for App instance
resource "aws_security_group" "nc_app_security_group" {
  name = "nc_app_security_group"

  vpc_id = aws_vpc.nc_vpc.id

  ingress {
    from_port         = 80
    to_port           = 80
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
  }

  ingress {
    from_port         = 443
    to_port           = 443
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
  }

  ingress {
    from_port         = 22
    to_port           = 22
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
  }

  egress {
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    cidr_blocks       = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# resource "aws_security_group_rule" "nc_app_port80" {
#   type              = "ingress"
#   from_port         = 80
#   to_port           = 80
#   protocol          = "tcp"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = aws_security_group.nc_app_security_group.id
# }

# resource "aws_security_group_rule" "nc_app_port443" {
#   type              = "ingress"
#   from_port         = 443
#   to_port           = 443
#   protocol          = "tcp"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = aws_security_group.nc_app_security_group.id
# }

# resource "aws_security_group_rule" "nc_app_port22" {
#   type              = "ingress"
#   from_port         = 22
#   to_port           = 22
#   protocol          = "tcp"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = aws_security_group.nc_app_security_group.id
# }

# resource "aws_security_group_rule" "nc_app_egress" {
#   type              = "egress"
#   from_port         = 0
#   to_port           = 0
#   protocol          = "-1"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = aws_security_group.nc_app_security_group.id
# }