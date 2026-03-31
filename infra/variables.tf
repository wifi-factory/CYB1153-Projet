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
  description = "Existing VPC ID used for the project."
  type        = string
}

variable "web_subnet_ids" {
  description = "Exactly two subnet IDs for the ALB and the two web servers."
  type        = list(string)

  validation {
    condition     = length(var.web_subnet_ids) == 2
    error_message = "Provide exactly two web subnet IDs so the EC2 instances can be split across two availability zones."
  }
}

variable "db_subnet_ids" {
  description = "At least two subnet IDs for the RDS DB subnet group."
  type        = list(string)

  validation {
    condition     = length(var.db_subnet_ids) >= 2
    error_message = "Provide at least two DB subnet IDs for RDS."
  }
}

variable "ami_id" {
  description = "AMI ID for Amazon Linux 2 in us-east-1."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the web servers."
  type        = string
  default     = "t2.micro"
}

variable "key_pair_name" {
  description = "Existing EC2 key pair name."
  type        = string
}

variable "associate_public_ip_address" {
  description = "Associate a public IP address to each EC2 instance."
  type        = bool
  default     = true
}

variable "admin_cidr_ipv4" {
  description = "Optional IPv4 CIDR allowed to SSH into the web instances. Set to null to disable SSH ingress."
  type        = string
  default     = null

  validation {
    condition     = var.admin_cidr_ipv4 == null || can(cidrhost(var.admin_cidr_ipv4, 0))
    error_message = "admin_cidr_ipv4 must be null or a valid IPv4 CIDR block such as 203.0.113.10/32."
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
  default     = "Groupe-web"
}

variable "db_instance_identifier" {
  description = "RDS instance identifier."
  type        = string
  default     = "tutorial-db-instance"
}

variable "db_engine_version" {
  description = "MySQL engine version for RDS."
  type        = string
  default     = "8.0"
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
  description = "RDS master password. Supply this via terraform.tfvars or TF_VAR_db_password."
  type        = string
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

variable "s3_bucket_name" {
  description = "Globally unique bucket name used for the static website."
  type        = string
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
