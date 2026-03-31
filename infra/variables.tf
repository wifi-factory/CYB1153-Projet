variable "project_name" {
  description = "Short project prefix used in tags and supporting resource names."
  type        = string
  default     = "cyb1153-annuaire"
}

variable "aws_region" {
  description = "AWS region for the deployment."
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "Optional VPC ID override. When omitted, the default VPC of the account is used."
  type        = string
  default     = null
  nullable    = true
}

variable "web_availability_zones" {
  description = "Availability zones used for the two web instances and the ALB."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.web_availability_zones) == 2
    error_message = "Provide exactly two availability zones for the web tier."
  }
}

variable "web_subnet_ids" {
  description = "Optional explicit subnet IDs for the two web instances and the ALB. Leave empty to auto-discover the default subnets for the selected availability zones."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.web_subnet_ids) == 0 || length(var.web_subnet_ids) == 2
    error_message = "Provide either zero subnet IDs for auto-discovery or exactly two explicit subnet IDs."
  }
}

variable "db_subnet_group_name" {
  description = "Optional DB subnet group name override. When omitted, the default DB subnet group of the selected VPC is used."
  type        = string
  default     = null
  nullable    = true
}

variable "ami_id" {
  description = "AMI ID used by the current lab deployment."
  type        = string
  default     = "ami-0c3389a4fa5bddaad"
}

variable "instance_type" {
  description = "EC2 instance type for the web servers."
  type        = string
  default     = "t2.micro"
}

variable "key_pair_name" {
  description = "Existing EC2 key pair name."
  type        = string
  default     = "cyb1153-key"
}

variable "associate_public_ip_address" {
  description = "Associate a public IP address to each EC2 instance."
  type        = bool
  default     = true
}

variable "admin_cidr_ipv4" {
  description = "IPv4 CIDR allowed to SSH into the web instances."
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.admin_cidr_ipv4, 0))
    error_message = "admin_cidr_ipv4 must be a valid IPv4 CIDR block such as 0.0.0.0/0 or 203.0.113.10/32."
  }
}

variable "lb_security_group_name" {
  description = "Name of the load balancer security group."
  type        = string
  default     = "LB-SG"
}

variable "web_security_group_name" {
  description = "Name of the web security group."
  type        = string
  default     = "Web-SG"
}

variable "db_security_group_name" {
  description = "Name of the database security group."
  type        = string
  default     = "DB-SG"
}

variable "alb_name" {
  description = "Name of the Application Load Balancer."
  type        = string
  default     = "ALB-annuaire"
}

variable "alb_deletion_protection" {
  description = "Enable deletion protection on the Application Load Balancer."
  type        = bool
  default     = false
}

variable "target_group_name" {
  description = "Name of the ALB target group."
  type        = string
  default     = "Group-web"
}

variable "db_instance_identifier" {
  description = "RDS instance identifier."
  type        = string
  default     = "tutorial-db-instance"
}

variable "db_engine_version" {
  description = "MySQL engine version for RDS."
  type        = string
  default     = "8.4.7"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS in GiB."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "sample"
}

variable "db_username" {
  description = "RDS master username."
  type        = string
  default     = "tutorial_user"
}

variable "db_password" {
  description = "Optional RDS master password override. When omitted, Terraform generates one automatically."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "db_port" {
  description = "MySQL port."
  type        = number
  default     = 3306
}

variable "db_multi_az" {
  description = "Enable Multi-AZ on the RDS instance."
  type        = bool
  default     = true
}

variable "db_backup_retention_period" {
  description = "Automated backup retention period in days."
  type        = number
  default     = 7
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot when destroying the RDS instance."
  type        = bool
  default     = true
}

variable "db_deletion_protection" {
  description = "Enable RDS deletion protection."
  type        = bool
  default     = false
}

variable "db_storage_encrypted" {
  description = "Encrypt the RDS storage."
  type        = bool
  default     = true
}

variable "db_copy_tags_to_snapshot" {
  description = "Copy tags from the DB instance to automated snapshots."
  type        = bool
  default     = true
}

variable "db_max_allocated_storage" {
  description = "Maximum autoscaled storage for the RDS instance."
  type        = number
  default     = 1000
}

variable "s3_bucket_name" {
  description = "Bucket name used for the static website."
  type        = string
  default     = "cyb1153-annuaire-2026"
}

variable "s3_force_destroy" {
  description = "Allow Terraform to delete non-empty bucket contents on destroy."
  type        = bool
  default     = false
}

variable "cloudwatch_dashboard_name" {
  description = "Name of the CloudWatch dashboard."
  type        = string
  default     = "CYB1153-Dashboard"
}
