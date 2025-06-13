# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.vpc.internet_gateway_id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = module.vpc.nat_gateway_ids
}

# EC2 Outputs
output "web_instance_ids" {
  description = "IDs of the web server instances"
  value       = module.ec2.web_instance_ids
}

output "app_instance_ids" {
  description = "IDs of the application server instances"
  value       = module.ec2.app_instance_ids
}

output "web_instance_public_ips" {
  description = "Public IP addresses of web server instances"
  value       = module.ec2.web_instance_public_ips
}

output "web_instance_private_ips" {
  description = "Private IP addresses of web server instances"
  value       = module.ec2.web_instance_private_ips
}

output "app_instance_private_ips" {
  description = "Private IP addresses of application server instances"
  value       = module.ec2.app_instance_private_ips
}

output "web_security_group_id" {
  description = "ID of the web security group"
  value       = module.ec2.web_security_group_id
}

output "app_security_group_id" {
  description = "ID of the application security group"
  value       = module.ec2.app_security_group_id
}

# Application URLs
output "web_server_urls" {
  description = "URLs of the web servers"
  value       = [for ip in module.ec2.web_instance_public_ips : "http://${ip}"]
}