# Sửa public subnet để không auto-assign public IP
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false  # Thay đổi từ true thành false

  tags = {
    Name        = "${var.project}-${var.environment}-public-subnet-${count.index + 1}"
    Type        = "Public"
    Project     = var.project
    Environment = var.environment
  }
}

# Thêm default security group restriction
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  # Không có ingress rules
  # Không có egress rules

  tags = {
    Name        = "${var.project}-${var.environment}-default-sg"
    Project     = var.project
    Environment = var.environment
  }
}

# Thêm VPC Flow Logs (tùy chọn - có thể cần IAM role)
resource "aws_flow_log" "vpc_flow_log" {
  iam_role_arn    = var.flow_log_role_arn  # Cần tạo variable này
  log_destination = var.flow_log_destination  # S3 bucket hoặc CloudWatch
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = {
    Name        = "${var.project}-${var.environment}-vpc-flow-log"
    Project     = var.project
    Environment = var.environment
  }
}