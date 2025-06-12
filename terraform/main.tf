provider "aws" {
  region = var.region
}

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration for remote state
  backend "s3" {
    bucket         = "your-terraform-state-bucket-name"  # Thay bằng tên bucket bạn vừa tạo
    key            = "microservices/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

# VPC and network infrastructure
module "vpc" {
  source = "./modules/vpc"

  project              = var.project
  environment          = var.environment
  region               = var.region
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  azs                  = var.azs
}

# EC2 instances
module "ec2" {
  source = "./modules/ec2"

  project        = var.project
  environment    = var.environment
  instance_type  = var.instance_type
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.public_subnet_ids
  instance_count = var.ec2_instance_count
  ami_id         = var.ami_id
  key_name       = var.key_name
  instance_name  = "api-server"
}