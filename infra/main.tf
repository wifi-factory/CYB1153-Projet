terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "web_a" {
  filter {
    name   = "vpc-id"
    values = [coalesce(var.vpc_id, data.aws_vpc.default.id)]
  }

  filter {
    name   = "availability-zone"
    values = [var.web_availability_zones[0]]
  }
}

data "aws_subnets" "web_b" {
  filter {
    name   = "vpc-id"
    values = [coalesce(var.vpc_id, data.aws_vpc.default.id)]
  }

  filter {
    name   = "availability-zone"
    values = [var.web_availability_zones[1]]
  }
}

resource "random_password" "db" {
  length  = 24
  special = true
}

locals {
  vpc_id             = coalesce(var.vpc_id, data.aws_vpc.default.id)
  web_subnet_ids     = length(var.web_subnet_ids) == 2 ? var.web_subnet_ids : [data.aws_subnets.web_a.ids[0], data.aws_subnets.web_b.ids[0]]
  db_subnet_group    = coalesce(var.db_subnet_group_name, "default-${local.vpc_id}")
  db_master_password = coalesce(var.db_password, random_password.db.result)
  https_message_body = "Use /SamplePage.php for HTTPS. The static S3 website remains on HTTP."

  common_tags = {
    Project   = var.project_name
    Course    = "CYB1153"
    ManagedBy = "Terraform"
  }

  static_assets = {
    "index.html" = {
      source       = "${path.module}/../s3-site/index.html"
      content_type = "text/html"
    }
    "error.html" = {
      source       = "${path.module}/../s3-site/error.html"
      content_type = "text/html"
    }
    "photos.png" = {
      source       = "${path.module}/../s3-site/photos.png"
      content_type = "image/png"
    }
  }

  s3_redirect_host = replace(
    replace(aws_s3_bucket_website_configuration.static.website_endpoint, "http://", ""),
    "https://",
    ""
  )
}

resource "aws_security_group" "lb" {
  name        = var.lb_security_group_name
  description = "Security group pour Load Balancer"
  vpc_id      = local.vpc_id

  ingress {
    description = "Permettre HTTP de Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Permettre HTTPS de Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = var.lb_security_group_name
  })
}

resource "aws_security_group" "web" {
  name        = var.web_security_group_name
  description = "Security group pour web servers"
  vpc_id      = local.vpc_id

  ingress {
    description     = "Permettre HTTP de Load Balancer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb.id]
  }

  ingress {
    description = "Permettre SSH de admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr_ipv4]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = var.web_security_group_name
  })
}

resource "aws_security_group" "db" {
  name        = var.db_security_group_name
  description = "Security group pour Database"
  vpc_id      = local.vpc_id

  ingress {
    description     = "Permettre MySQL depuis web servers"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = var.db_security_group_name
  })
}

resource "aws_db_instance" "main" {
  identifier              = var.db_instance_identifier
  engine                  = "mysql"
  engine_version          = var.db_engine_version
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  max_allocated_storage   = var.db_max_allocated_storage
  storage_type            = "gp2"
  storage_encrypted       = var.db_storage_encrypted
  db_name                 = var.db_name
  username                = var.db_username
  password                = local.db_master_password
  port                    = var.db_port
  multi_az                = var.db_multi_az
  publicly_accessible     = false
  db_subnet_group_name    = local.db_subnet_group
  vpc_security_group_ids  = [aws_security_group.db.id]
  skip_final_snapshot     = var.db_skip_final_snapshot
  deletion_protection     = var.db_deletion_protection
  apply_immediately       = true
  backup_retention_period = var.db_backup_retention_period
  copy_tags_to_snapshot   = var.db_copy_tags_to_snapshot

  tags = merge(local.common_tags, {
    Name = var.db_instance_identifier
  })
}

resource "aws_s3_bucket" "static" {
  bucket        = var.s3_bucket_name
  force_destroy = var.s3_force_destroy

  tags = merge(local.common_tags, {
    Name = var.s3_bucket_name
  })
}

resource "aws_s3_bucket_public_access_block" "static" {
  bucket = aws_s3_bucket.static.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "static" {
  bucket = aws_s3_bucket.static.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_policy" "static" {
  bucket = aws_s3_bucket.static.id

  depends_on = [aws_s3_bucket_public_access_block.static]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.static.arn}/*"
      }
    ]
  })
}

resource "aws_s3_object" "static_assets" {
  for_each = local.static_assets

  bucket       = aws_s3_bucket.static.id
  key          = each.key
  source       = each.value.source
  etag         = filemd5(each.value.source)
  content_type = each.value.content_type
}

resource "aws_lb" "main" {
  name                       = var.alb_name
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.lb.id]
  subnets                    = local.web_subnet_ids
  enable_deletion_protection = var.alb_deletion_protection

  tags = merge(local.common_tags, {
    Name = var.alb_name
  })
}

resource "tls_private_key" "alb_https" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "alb_https" {
  private_key_pem       = tls_private_key.alb_https.private_key_pem
  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  dns_names = [aws_lb.main.dns_name]

  subject {
    common_name  = aws_lb.main.dns_name
    organization = "UQO CYB1153"
    locality     = "Gatineau"
    province     = "Quebec"
    country      = "CA"
  }
}

resource "aws_acm_certificate" "alb_https" {
  private_key      = tls_private_key.alb_https.private_key_pem
  certificate_body = tls_self_signed_cert.alb_https.cert_pem

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-alb-selfsigned"
  })
}

resource "aws_lb_target_group" "web" {
  name        = var.target_group_name
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = local.vpc_id

  health_check {
    enabled             = true
    path                = "/SamplePage.php"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  tags = merge(local.common_tags, {
    Name = var.target_group_name
  })
}

resource "aws_instance" "web" {
  count = length(local.web_subnet_ids)

  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_pair_name
  subnet_id                   = local.web_subnet_ids[count.index]
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = var.associate_public_ip_address
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/../scripts/user-data-web.sh", {
    sample_page_php = file("${path.module}/../app/SamplePage.php")
    db_config_php   = file("${path.module}/../app/db_config.php")
    db_settings_json = jsonencode({
      host     = aws_db_instance.main.address
      port     = var.db_port
      name     = var.db_name
      user     = var.db_username
      password = local.db_master_password
      charset  = "utf8mb4"
    })
  })

  tags = merge(local.common_tags, {
    Name = "Web-${count.index + 1}"
  })
}

resource "aws_lb_target_group_attachment" "web" {
  count = length(aws_instance.web)

  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.alb_https.arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = local.https_message_body
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "index_redirect" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 1

  action {
    type = "redirect"

    redirect {
      host        = local.s3_redirect_host
      path        = "/index.html"
      port        = "80"
      protocol    = "HTTP"
      query       = ""
      status_code = "HTTP_302"
    }
  }

  condition {
    path_pattern {
      values = ["/index.html"]
    }
  }
}

resource "aws_lb_listener_rule" "sample_page" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 2

  action {
    type = "redirect"

    redirect {
      host        = "#{host}"
      path        = "/SamplePage.php"
      port        = "443"
      protocol    = "HTTPS"
      query       = "#{query}"
      status_code = "HTTP_302"
    }
  }

  condition {
    path_pattern {
      values = ["/SamplePage.php"]
    }
  }
}

resource "aws_lb_listener_rule" "https_sample_page" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  condition {
    path_pattern {
      values = ["/SamplePage.php"]
    }
  }
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = var.cloudwatch_dashboard_name

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 6
        height = 6
        properties = {
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix]
          ]
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 6
        y      = 0
        width  = 6
        height = 6
        properties = {
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          period  = 86400
          stat    = "Average"
          title   = "S3 NumberOfObjects"
          metrics = [
            ["AWS/S3", "NumberOfObjects", "BucketName", aws_s3_bucket.static.bucket, "StorageType", "AllStorageTypes"]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 6
        height = 6
        properties = {
          view    = "timeSeries"
          stacked = false
          metrics = [
            for instance in aws_instance.web :
            ["AWS/EC2", "CPUUtilization", "InstanceId", instance.id]
          ]
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 18
        y      = 0
        width  = 6
        height = 6
        properties = {
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.main.id, { period = 60 }]
          ]
          region = var.aws_region
        }
      }
    ]
  })
}
