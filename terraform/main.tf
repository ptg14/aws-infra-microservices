terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "your-terraform-state-bucket-name"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project              = var.project
  environment         = var.environment
  region              = var.region
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  azs                 = var.azs
}

# EC2 Module
module "ec2" {
  source = "./modules/ec2"

  project         = var.project
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids  # Use private subnets for better security
  ami_id          = var.ami_id
  instance_type   = var.instance_type
  instance_count  = var.instance_count
  instance_name   = var.instance_name
  key_name        = var.key_name
}