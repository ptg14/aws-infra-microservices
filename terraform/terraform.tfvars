# AWS Configuration
region = "us-east-1"

# Project Configuration
project     = "microservices"
environment = "dev"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
azs                  = ["us-east-1a", "us-east-1b"]

# EC2 Configuration
instance_type       = "t3.micro"
ec2_instance_count  = 2
ami_id              = "ami-0c02fb55956c7d316"  # Amazon Linux 2 AMI
key_name            = ""  # Để trống nếu không cần SSH access