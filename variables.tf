// ==== General ====

variable "region" {
  description = "Region"
}

variable "availability_zone" {
  description = "Region"
}

variable "instance_type" {
  description = "Instance type"
  default     = "t2.micro"
}

variable "instance_type_db" {
  description = "DB Instance type"
  default     = "t2.micro"
}

variable "ami" {
  description = "AMI ID"
}

variable "key_name" {
  description = "SSH key name for Nextcloud app instance"
  default     = null
}

variable "db_instance_type" {
  description = "Database instance type"
  default     = "db.t2.micro"
}


// ==== Network ====

variable "vpc_cidr" {
  description = "CIDR of the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR of the public subnet"
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR of the private subnet for DB"
  default     = "10.0.2.0/24"
}

variable "private_subnet_app_cidr" {
  description = "CIDR of the private subnet for App"
  default     = "10.0.3.0/24"
}

variable "private_bridge_app_ip" {
  description = "App private IP in the bridge ENI"
  default     = "10.0.3.100"
}

variable "private_bridge_db_ip" {
  description = "DB private IP in the bridge ENI"
  default     = "10.0.3.101"
}


// ==== Database ====

variable "database_name" {
  description = "Database name"
}

variable "database_user" {
  description = "Database root user"
}

variable "database_pass" {
  description = "Database root password"
}


// ==== Admin ====

variable "admin_user" {
  description = "Nextcloud admin user"
}

variable "admin_pass" {
  description = "Nextcloud admin password"
}

// ==== S3 ====

variable "bucket_name" {
  description = "Name of s3 bucket for nextcloud"
}
