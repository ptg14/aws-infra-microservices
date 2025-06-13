output "web_instance_ids" {
  description = "IDs of the web server instances"
  value       = aws_instance.web[*].id
}

output "app_instance_ids" {
  description = "IDs of the application server instances"
  value       = aws_instance.app[*].id
}

output "web_instance_public_ips" {
  description = "Public IP addresses of web server instances"
  value       = aws_instance.web[*].public_ip
}

output "web_instance_private_ips" {
  description = "Private IP addresses of web server instances"
  value       = aws_instance.web[*].private_ip
}

output "app_instance_private_ips" {
  description = "Private IP addresses of application server instances"
  value       = aws_instance.app[*].private_ip
}

output "web_security_group_id" {
  description = "ID of the web security group"
  value       = aws_security_group.web.id
}

output "app_security_group_id" {
  description = "ID of the application security group"
  value       = aws_security_group.app.id
}