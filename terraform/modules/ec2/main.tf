# Security Group for Web Servers
resource "aws_security_group" "web" {
  name_prefix = "${var.project}-${var.environment}-web-"
  description = "Security group for web servers"
  vpc_id      = var.vpc_id

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH - Hạn chế IP thay vì 0.0.0.0/0
  dynamic "ingress" {
    for_each = var.key_name != "" ? [1] : []
    content {
      description = "SSH from trusted IPs"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"] # Chỉ cho phép từ VPC
    }
  }

  # Hạn chế egress thay vì mở toàn bộ
  egress {
    description = "HTTP outbound"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS outbound"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.environment}-web-sg"
    Project     = var.project
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for App Servers
resource "aws_security_group" "app" {
  name_prefix = "${var.project}-${var.environment}-app-"
  description = "Security group for application servers"
  vpc_id      = var.vpc_id

  # Application port (8080)
  ingress {
    description     = "App port from web servers"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  # SSH (only if key_name is provided)
  dynamic "ingress" {
    for_each = var.key_name != "" ? [1] : []
    content {
      description     = "SSH from web servers"
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      security_groups = [aws_security_group.web.id]
    }
  }

  # Hạn chế egress
  egress {
    description = "HTTP outbound"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS outbound"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.environment}-app-sg"
    Project     = var.project
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Web Server Instances
resource "aws_instance" "web" {
  count = var.ec2_instance_count

  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name != "" ? var.key_name : null
  vpc_security_group_ids      = [aws_security_group.web.id]
  subnet_id                   = var.public_subnet_ids[count.index % length(var.public_subnet_ids)]
  associate_public_ip_address = true # Đảm bảo có public IP

  # Thêm các cấu hình bảo mật
  monitoring    = true # Enable detailed monitoring
  ebs_optimized = true # Enable EBS optimization

  # Cấu hình IMDS v2
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Force IMDSv2
    http_put_response_hop_limit = 1
  }

  user_data = base64encode(templatefile("${path.module}/user_data_web.sh", {
    instance_name = "${var.project}-${var.environment}-web-${count.index + 1}"
  }))

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name        = "${var.project}-${var.environment}-web-${count.index + 1}-root"
      Project     = var.project
      Environment = var.environment
    }
  }

  tags = {
    Name        = "${var.project}-${var.environment}-web-${count.index + 1}"
    Type        = "WebServer"
    Project     = var.project
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Application Server Instances
resource "aws_instance" "app" {
  count = var.ec2_instance_count

  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name != "" ? var.key_name : null
  vpc_security_group_ids = [aws_security_group.app.id]
  subnet_id              = var.private_subnet_ids[count.index % length(var.private_subnet_ids)]

  # Thêm các cấu hình bảo mật
  monitoring    = true # Enable detailed monitoring
  ebs_optimized = true # Enable EBS optimization

  # Cấu hình IMDS v2
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Force IMDSv2
    http_put_response_hop_limit = 1
  }

  user_data = base64encode(templatefile("${path.module}/user_data_app.sh", {
    instance_name = "${var.project}-${var.environment}-app-${count.index + 1}"
  }))

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name        = "${var.project}-${var.environment}-app-${count.index + 1}-root"
      Project     = var.project
      Environment = var.environment
    }
  }

  tags = {
    Name        = "${var.project}-${var.environment}-app-${count.index + 1}"
    Type        = "AppServer"
    Project     = var.project
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}