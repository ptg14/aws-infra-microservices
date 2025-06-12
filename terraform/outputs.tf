output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "ec2_instance_ids" {
  description = "List of EC2 instance IDs"
  value       = module.ec2.instance_ids
}

output "ec2_public_ips" {
  description = "List of EC2 instance public IPs"
  value       = module.ec2.instance_public_ips
}