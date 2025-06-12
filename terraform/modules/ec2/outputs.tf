output "instance_ids" {
  description = "IDs of created EC2 instances"
  value       = aws_instance.app[*].id
}

output "instance_private_ips" {
  description = "Private IPs of created EC2 instances"
  value       = aws_instance.app[*].private_ip
}

output "instance_public_ips" {
  description = "Public IPs of created EC2 instances"
  value       = aws_instance.app[*].public_ip
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.ec2_sg.id
}