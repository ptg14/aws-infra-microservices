provider "aws" {
  region = var.region
}

locals {
  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, {
    Name = "${var.project}-${var.environment}-vpc"
  })
}

# Public subnets - removed auto-assign public IP
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false  # Changed from true to false

  tags = merge(local.tags, {
    Name = "${var.project}-${var.environment}-public-${count.index + 1}"
  })
}

# Private subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(local.tags, {
    Name = "${var.project}-${var.environment}-private-${count.index + 1}"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.tags, {
    Name = "${var.project}-${var.environment}-igw"
  })
}

# Elastic IPs for NAT Gateway
resource "aws_eip" "nat" {
  count      = length(var.public_subnet_cidrs)
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = merge(local.tags, {
    Name = "${var.project}-${var.environment}-eip-${count.index + 1}"
  })
}

# NAT Gateway
resource "aws_nat_gateway" "nat" {
  count         = length(var.public_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.tags, {
    Name = "${var.project}-${var.environment}-nat-${count.index + 1}"
  })
}

# Route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(local.tags, {
    Name = "${var.project}-${var.environment}-rt-public"
  })
}

# Route tables for private subnets
resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = merge(local.tags, {
    Name = "${var.project}-${var.environment}-rt-private-${count.index + 1}"
  })
}

# Route table associations
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Default security group with restrictive rules
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  # No ingress rules (empty block)
  ingress = []

  # No egress rules (empty block)
  egress = []

  tags = merge(local.tags, {
    Name = "${var.project}-${var.environment}-default-sg"
  })
}

# VPC Flow Logs
resource "aws_flow_log" "vpc_flow_log" {
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(local.tags, {
    Name = "${var.project}-${var.environment}-vpc-flow-log"
  })
}

# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  name              = "/aws/vpc/${var.project}-${var.environment}-flow-log"
  retention_in_days = 14

  tags = local.tags
}

# IAM role for VPC Flow Logs
resource "aws_iam_role" "flow_log" {
  name = "${var.project}-${var.environment}-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# IAM role policy for VPC Flow Logs
resource "aws_iam_role_policy" "flow_log" {
  name = "${var.project}-${var.environment}-flow-log-policy"
  role = aws_iam_role.flow_log.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}