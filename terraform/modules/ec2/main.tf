# Web Security Group
resource "aws_security_group" "web" {
  name_prefix = "${var.project}-${var.environment}-web-"
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

  # SSH (only if key_name is provided)
  dynamic "ingress" {
    for_each = var.key_name != "" ? [1] : []
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
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

# Application Security Group
resource "aws_security_group" "app" {
  name_prefix = "${var.project}-${var.environment}-app-"
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

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
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

# Web Servers (Public Subnets)
resource "aws_instance" "web" {
  count = var.ec2_instance_count

  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name != "" ? var.key_name : null
  vpc_security_group_ids = [aws_security_group.web.id]
  subnet_id              = var.public_subnet_ids[count.index % length(var.public_subnet_ids)]

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

# Application Servers (Private Subnets)
resource "aws_instance" "app" {
  count = var.ec2_instance_count

  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name != "" ? var.key_name : null
  vpc_security_group_ids = [aws_security_group.app.id]
  subnet_id              = var.private_subnet_ids[count.index % length(var.private_subnet_ids)]

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