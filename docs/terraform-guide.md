# AWS Infrastructure Deployment với Terraform và GitHub Actions

## 🚀 Hướng dẫn triển khai

### Bước 1: Chuẩn bị môi trường (Sử dụng AWS CloudShell)

#### 1.1 Truy cập AWS CloudShell
1. Đăng nhập AWS Console
2. Tìm biểu tượng CloudShell (terminal) ở thanh menu trên cùng
3. Click để mở CloudShell - sẽ mất vài phút để khởi động lần đầu

#### 1.2 Cài đặt Terraform trong CloudShell (không cần sudo)
```bash
# Tạo thư mục bin trong home directory
mkdir -p ~/bin

# Tải Terraform binary
cd /tmp
wget https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip

# Giải nén
unzip terraform_1.6.6_linux_amd64.zip

# Di chuyển vào thư mục bin cá nhân
mv terraform ~/bin/

# Thêm vào PATH (tạm thời)
export PATH=$PATH:~/bin

# Thêm vào PATH vĩnh viễn
echo 'export PATH=$PATH:~/bin' >> ~/.bashrc
source ~/.bashrc

# Xác minh cài đặt
terraform version
```

#### 1.3 Cài đặt Checkov trong CloudShell
```bash
# Cài đặt Checkov vào user space (không cần sudo)
pip3 install --user checkov

# Thêm pip user bin vào PATH
export PATH=$PATH:~/.local/bin
echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc

# Xác minh cài đặt
checkov --version
```

#### 1.4 Kiểm tra cấu hình AWS (CloudShell tự động có credentials)
```bash
# Test quyền hiện tại
aws sts get-caller-identity

# Kiểm tra region
aws configure get region

# Nếu cần đặt region mặc định
aws configure set region us-east-1

# Liệt kê regions có sẵn
aws ec2 describe-regions --output table
```

### Bước 2: Chuẩn bị code trong CloudShell

#### 2.1 Clone hoặc upload project
```bash
# Tạo thư mục làm việc
mkdir -p ~/projects
cd ~/projects

# Option 1: Clone từ GitHub (nếu đã có repository)
git clone https://github.com/your-username/aws-infra-microservices.git
cd aws-infra-microservices

# Option 2: Tạo project mới
mkdir aws-infra-microservices
cd aws-infra-microservices

# Tạo cấu trúc thư mục
mkdir -p terraform/modules/{vpc,ec2}
mkdir -p .github/workflows
mkdir -p docs
```

#### 2.2 Upload files vào CloudShell (nếu cần)
```bash
# Trong CloudShell UI, sử dụng Actions → Upload file
# Hoặc tạo files trực tiếp bằng editor

# Sử dụng nano để tạo/chỉnh sửa files
nano terraform/main.tf
nano terraform/variables.tf
nano terraform/terraform.tfvars
```

### Bước 3: Chuẩn bị Terraform Backend

#### 3.1 Tạo S3 Bucket cho Terraform State
```bash
# Tạo bucket với tên unique
BUCKET_NAME="terraform-state-$(date +%s)-$(whoami)"
echo "Bucket name: $BUCKET_NAME"

# Tạo S3 bucket
aws s3 mb s3://$BUCKET_NAME --region us-east-1

# Bật versioning
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# Bật encryption
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "S3 bucket created: $BUCKET_NAME"
```

#### 3.2 Tạo DynamoDB Table cho State Lock
```bash
# Tạo DynamoDB table
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1

# Chờ table được tạo
echo "Waiting for DynamoDB table to be created..."
aws dynamodb wait table-exists --table-name terraform-state-lock --region us-east-1
echo "DynamoDB table created successfully"
```

#### 3.3 Cập nhật Terraform backend configuration
```bash
# Cập nhật main.tf với bucket name thực tế
cd ~/projects/aws-infra-microservices/terraform

# Backup file gốc
cp main.tf main.tf.backup

# Cập nhật bucket name
sed -i "s/your-terraform-state-bucket-name/$BUCKET_NAME/g" main.tf

# Kiểm tra thay đổi
grep "bucket" main.tf
```

### Bước 4: Cấu hình và chạy Terraform

#### 4.1 Cập nhật terraform.tfvars
```bash
# Tạo hoặc cập nhật terraform.tfvars
cat > terraform.tfvars << 'EOF'
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
key_name            = ""  # Để trống nếu không cần SSH
EOF

echo "terraform.tfvars has been created"
```

#### 4.2 Khởi tạo và chạy Terraform
```bash
# Đảm bảo đang ở thư mục terraform
cd ~/projects/aws-infra-microservices/terraform

# Khởi tạo Terraform
terraform init

# Format code
terraform fmt -recursive

# Validate cấu hình
terraform validate

# Chạy Checkov security scan
mkdir -p reports
checkov -d . --framework terraform --output cli --output json --output-file-path reports/checkov-report.json

# Tạo execution plan
terraform plan -var-file="terraform.tfvars" -out=tfplan

# Xem plan
terraform show tfplan

# Áp dụng cấu hình (cần confirm với 'yes')
terraform apply tfplan
```

#### 4.3 Xác minh triển khai
```bash
# Hiển thị outputs
terraform output

# Liệt kê resources đã tạo
terraform state list

# Xác minh resources trong AWS
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=microservices" --output table
aws ec2 describe-instances --filters "Name=tag:Project,Values=microservices" --output table
aws ec2 describe-security-groups --filters "Name=tag:Project,Values=microservices" --output table
```

### Bước 5: Thiết lập GitHub Actions (Từ CloudShell)

#### 5.1 Chuẩn bị Git repository
```bash
# Nếu chưa có repository trên GitHub, tạo trước
# Sau đó clone hoặc init

cd ~/projects/aws-infra-microservices

# Init git nếu chưa có
git init

# Cấu hình git
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Add remote origin
git remote add origin https://github.com/your-username/aws-infra-microservices.git

# Add và commit tất cả files
git add .
git commit -m "Initial Terraform infrastructure setup"

# Push lên GitHub (sẽ cần GitHub token)
git push -u origin main
```

#### 5.2 Tạo GitHub Personal Access Token
```bash
# Cần tạo GitHub PAT để push code
# Truy cập: https://github.com/settings/tokens
# Generate new token với repo permissions

# Khi push, sử dụng:
# Username: your-github-username
# Password: your-personal-access-token
```

### Bước 6: Lưu trữ thông tin quan trọng

#### 6.1 Lưu thông tin bucket và cấu hình
```bash
# Lưu thông tin quan trọng
cat > ~/aws-infra-info.txt << EOF
=== AWS Infrastructure Information ===
S3 Bucket: $BUCKET_NAME
DynamoDB Table: terraform-state-lock
Region: us-east-1
Project: microservices
Environment: dev

=== Important Commands ===
# To access project:
cd ~/projects/aws-infra-microservices/terraform

# To check resources:
terraform state list
terraform output

# To destroy (when needed):
terraform destroy -var-file="terraform.tfvars"
EOF

echo "Information saved to ~/aws-infra-info.txt"
cat ~/aws-infra-info.txt
```

### Bước 7: Quản lý session trong CloudShell

#### 7.1 CloudShell persistence
```bash
# CloudShell home directory (~/) sẽ được giữ lại
# Nhưng /tmp sẽ bị xóa khi session kết thúc

# Đảm bảo lưu PATH trong .bashrc
echo 'export PATH=$PATH:~/bin:~/.local/bin' >> ~/.bashrc

# Tạo script khởi động nhanh
cat > ~/start-terraform.sh << 'EOF'
#!/bin/bash
cd ~/projects/aws-infra-microservices/terraform
echo "=== Current Terraform Workspace ==="
terraform workspace show
echo "=== Terraform State ==="
terraform state list | head -5
echo "..."
echo "=== Ready for Terraform operations ==="
EOF

chmod +x ~/start-terraform.sh

echo "Use ~/start-terraform.sh to quickly navigate to project"
```

### Bước 8: Dọn dẹp (khi cần)

#### 8.1 Xóa hạ tầng
```bash
# Chuyển đến thư mục terraform
cd ~/projects/aws-infra-microservices/terraform

# Xóa hạ tầng
terraform destroy -var-file="terraform.tfvars"

# Xóa S3 bucket và contents
aws s3 rm s3://$BUCKET_NAME --recursive
aws s3 rb s3://$BUCKET_NAME

# Xóa DynamoDB table
aws dynamodb delete-table --table-name terraform-state-lock --region us-east-1
```

## 💡 CloudShell Tips

1. **Session Timeout**: CloudShell sessions timeout sau 20 phút không hoạt động
2. **Storage**: ~/home directory có 1GB persistent storage
3. **Networking**: Có thể truy cập internet và AWS services
4. **Editor**: Sử dụng `nano`, `vim` hoặc upload files qua UI
5. **Backup**: Định kỳ push code lên GitHub để backup

## 🔧 Troubleshooting trong CloudShell

```bash
# Nếu mất PATH
source ~/.bashrc

# Nếu cần reinstall terraform
rm ~/bin/terraform
# Repeat installation steps

# Kiểm tra AWS permissions
aws iam get-user
aws sts get-caller-identity

# Kiểm tra resources
aws ec2 describe-instances --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name}' --output table
```

**Lưu ý**: CloudShell đã có sẵn AWS credentials từ session đăng nhập của bạn, nên không cần cấu hình thêm AWS CLI credentials.