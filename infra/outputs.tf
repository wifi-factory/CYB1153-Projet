output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer."
  value       = aws_lb.main.dns_name
}

output "sample_page_url" {
  description = "Dynamic application URL served through the ALB."
  value       = "http://${aws_lb.main.dns_name}/SamplePage.php"
}

output "static_redirect_url" {
  description = "ALB URL that redirects to the S3 static website."
  value       = "http://${aws_lb.main.dns_name}/index.html"
}

output "s3_website_endpoint" {
  description = "Website endpoint of the S3 static site."
  value       = "http://${aws_s3_bucket_website_configuration.static.website_endpoint}"
}

output "rds_endpoint" {
  description = "RDS endpoint address."
  value       = aws_db_instance.main.address
}

output "web_instance_ids" {
  description = "IDs of the EC2 web servers."
  value       = aws_instance.web[*].id
}

output "dashboard_name" {
  description = "CloudWatch dashboard name."
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "security_group_ids" {
  description = "Security group IDs created by Terraform."
  value = {
    lb  = aws_security_group.lb.id
    web = aws_security_group.web.id
    db  = aws_security_group.db.id
  }
}
