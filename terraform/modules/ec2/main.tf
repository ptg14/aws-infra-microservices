locals {
  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# IAM role for EC2 instances
resource "aws_iam_role" "ec2_role" {
  name = "${var.project}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# IAM instance profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = local.tags
}

# Security group for EC2 instances
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project}-${var.environment}-ec2-sg"
  description = "Security group for EC2 instances"
  vpc_id      = var.vpc_id

  # SSH access (restrict to specific IP if needed)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Only from VPC
    description = "SSH access from VPC"
  }

  # HTTP access - restrict to load balancer or specific CIDR
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Changed from 0.0.0.0/0 to VPC only
    description = "HTTP access from VPC"
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  # Application port
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Application port from VPC"
  }

  # Specific outbound rules instead of allowing all
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP outbound"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound"
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS outbound"
  }

  egress {
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "NTP outbound"
  }

  tags = merge(local.tags, {
    Name = "${var.project}-${var.environment}-ec2-sg"
  })
}

# Launch template for EC2 instances
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project}-${var.environment}-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name != "" ? var.key_name : null

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  # EBS optimization
  ebs_optimized = true

  # Block device mapping with encryption
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type          = "gp3"
      encrypted            = true
      delete_on_termination = true
    }
  }

  # IAM instance profile
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker htop
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ec2-user

              # Install CloudWatch agent
              wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
              rpm -U ./amazon-cloudwatch-agent.rpm

              # Basic monitoring script
              cat > /home/ec2-user/monitor.sh << 'SCRIPT'
              #!/bin/bash
              echo "Instance monitoring started at $(date)"
              SCRIPT
              chmod +x /home/ec2-user/monitor.sh
              EOF
  )

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"  # Require IMDSv2
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.tags, {
      Name = "${var.project}-${var.environment}-${var.instance_name}"
    })
  }

  tags = merge(local.tags, {
    Name = "${var.project}-${var.environment}-launch-template"
  })
}

# EC2 instances using launch template
resource "aws_instance" "app" {
  count = var.instance_count

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  subnet_id = element(var.subnet_ids, count.index % length(var.subnet_ids))

  # Explicit monitoring and EBS optimization
  monitoring    = true
  ebs_optimized = true

  # Root block device encryption
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  # Metadata options for IMDSv2
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(local.tags, {
    Name = "${var.project}-${var.environment}-${var.instance_name}-${count.index + 1}"
  })
}