locals {
  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
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

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
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

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
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

  tags = merge(local.tags, {
    Name = "${var.project}-${var.environment}-${var.instance_name}-${count.index + 1}"
  })
}