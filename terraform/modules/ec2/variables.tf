variable "project" {
  description = "Project name for resource tagging"
  type        = string
  default     = "microservices"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "vpc_id" {
  description = "VPC ID where the EC2 instance will be created"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs where the EC2 instances will be created"
  type        = list(string)
}

variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 1
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
  default     = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI ID
}

variable "key_name" {
  description = "Key pair name for SSH access"
  type        = string
  default     = ""
}

variable "instance_name" {
  description = "Name for the EC2 instances"
  type        = string
  default     = "microservice-instance"
}