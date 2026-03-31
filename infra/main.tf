terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
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
  description = "Allow HTTP traffic from the Internet to the load balancer."
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from the Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
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
  description = "Allow HTTP from the ALB and optional SSH administration."
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from the load balancer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb.id]
  }

  dynamic "ingress" {
    for_each = var.admin_cidr_ipv4 == null ? [] : [var.admin_cidr_ipv4]

    content {
      description = "Optional SSH administration access"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    description = "All outbound traffic"
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
  description = "Allow MySQL access from the web servers."
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from web servers"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = var.db_security_group_name
  })
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.db_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-db-subnet-group"
  })
}

resource "aws_db_instance" "main" {
  identifier              = var.db_instance_identifier
  engine                  = "mysql"
  engine_version          = var.db_engine_version
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  port                    = var.db_port
  multi_az                = var.db_multi_az
  publicly_accessible     = false
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  skip_final_snapshot     = var.db_skip_final_snapshot
  deletion_protection     = var.db_deletion_protection
  apply_immediately       = true
  backup_retention_period = 1

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
        Sid       = "PublicReadForStaticWebsite"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject"]
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
  subnets                    = var.web_subnet_ids
  enable_deletion_protection = var.alb_deletion_protection

  tags = merge(local.common_tags, {
    Name = var.alb_name
  })
}

resource "aws_lb_target_group" "web" {
  name        = var.target_group_name
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = "/SamplePage.php"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge(local.common_tags, {
    Name = var.target_group_name
  })
}

resource "aws_instance" "web" {
  count = length(var.web_subnet_ids)

  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_pair_name
  subnet_id                   = var.web_subnet_ids[count.index]
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
      password = var.db_password
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

resource "aws_lb_listener_rule" "sample_page" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

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

resource "aws_lb_listener_rule" "index_redirect" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type = "redirect"

    redirect {
      host        = local.s3_redirect_host
      path        = "/index.html"
      port        = "80"
      protocol    = "HTTP"
      query       = "#{query}"
      status_code = "HTTP_302"
    }
  }

  condition {
    path_pattern {
      values = ["/index.html"]
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
        width  = 12
        height = 6
        properties = {
          title   = "RequestCount"
          region  = var.aws_region
          period  = 300
          stat    = "Sum"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix, { label = var.alb_name }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "DatabaseConnections"
          region  = var.aws_region
          period  = 300
          stat    = "Average"
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.main.id, { label = var.db_instance_identifier }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "NumberOfObjects"
          region  = var.aws_region
          period  = 300
          stat    = "Average"
          metrics = [
            ["AWS/S3", "NumberOfObjects", "BucketName", aws_s3_bucket.static.bucket, "StorageType", "AllStorageTypes", { label = var.s3_bucket_name }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "CPUUtilization"
          region  = var.aws_region
          period  = 300
          stat    = "Average"
          metrics = [
            for index, instance in aws_instance.web :
            ["AWS/EC2", "CPUUtilization", "InstanceId", instance.id, { label = "Web-${index + 1}" }]
          ]
        }
      }
    ]
  })
}
