# AWS Infrastructure Deployment với Terraform và GitHub Actions

## 🚀 Hướng dẫn triển khai

### Bước 1: Chuẩn bị môi trường (Sử dụng AWS CloudShell với sudo)

#### 1.1 Truy cập AWS CloudShell
1. Đăng nhập AWS Console
2. Tìm biểu tượng CloudShell (terminal) ở thanh menu trên cùng
3. Click để mở CloudShell - sẽ mất vài phút để khởi động lần đầu

#### 1.2 Cài đặt Terraform trong CloudShell (với sudo)
```bash
# Cập nhật package manager
sudo yum update -y

# Tải và cài đặt Terraform
cd /tmp
wget https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip

# Giải nén
sudo yum install -y unzip
unzip terraform_1.6.6_linux_amd64.zip

# Di chuyển vào system path
sudo mv terraform /usr/local/bin/

# Xác minh cài đặt
terraform version

# Tạo symbolic link nếu cần
sudo ln -sf /usr/local/bin/terraform /usr/bin/terraform
```

#### 1.3 Cài đặt Checkov trong CloudShell (với sudo)
```bash
# Cài đặt pip3 nếu chưa có
sudo yum install -y python3-pip

# Cài đặt Checkov system-wide
sudo pip3 install checkov

# Xác minh cài đặt
checkov --version

# Nếu gặp lỗi PATH, thêm vào profile
echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
source ~/.bashrc
```

#### 1.4 Cài đặt thêm các công cụ hữu ích
```bash
# Cài đặt jq để xử lý JSON
sudo yum install -y jq

# Cài đặt tree để xem cấu trúc thư mục
sudo yum install -y tree

# Cài đặt git (nếu chưa có)
sudo yum install -y git

# Xác minh các cài đặt
jq --version
tree --version
git --version
```

#### 1.5 Kiểm tra cấu hình AWS (CloudShell tự động có credentials)
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

# Option 2: Tạo project mới và upload files
mkdir aws-infra-microservices
cd aws-infra-microservices

# Tạo cấu trúc thư mục
mkdir -p terraform/modules/{vpc,ec2}
mkdir -p .github/workflows
mkdir -p docs

# Xem cấu trúc đã tạo
tree .
```

#### 2.2 Upload files vào CloudShell
```bash
# Option 1: Sử dụng CloudShell UI
# Actions → Upload file để upload từng file
# Hoặc upload zip file và giải nén

# Option 2: Tạo files trực tiếp bằng editor
nano terraform/main.tf
nano terraform/variables.tf
nano terraform/terraform.tfvars

# Option 3: Clone từ existing repository
git clone https://github.com/your-username/aws-infra-microservices.git .
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

# Xác minh table đã được tạo
aws dynamodb describe-table --table-name terraform-state-lock --region us-east-1 --output table --query 'Table.{Name:TableName,Status:TableStatus,Creation:CreationDateTime}'
```

#### 3.3 Cập nhật Terraform backend configuration
```bash
# Chuyển đến thư mục terraform
cd ~/projects/aws-infra-microservices/terraform

# Backup file gốc
cp main.tf main.tf.backup

# Cập nhật bucket name trong main.tf
sed -i "s/your-terraform-state-bucket-name/$BUCKET_NAME/g" main.tf

# Kiểm tra thay đổi
echo "Updated backend configuration:"
grep -A 5 -B 2 "bucket" main.tf
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
cat terraform.tfvars
```

#### 4.2 Khởi tạo và chạy Terraform
```bash
# Đảm bảo đang ở thư mục terraform
cd ~/projects/aws-infra-microservices/terraform

# Khởi tạo Terraform
echo "Initializing Terraform..."
terraform init

# Format code
echo "Formatting Terraform code..."
terraform fmt -recursive

# Validate cấu hình
echo "Validating Terraform configuration..."
terraform validate

# Chạy Checkov security scan
echo "Running Checkov security scan..."
mkdir -p reports
checkov -d . --framework terraform --output cli --output json --output-file-path reports

# Hiển thị kết quả Checkov
echo "Checkov scan results:"
cat reports/results_json.json | jq '.summary'

# Tạo execution plan
echo "Creating Terraform execution plan..."
terraform plan -var-file="terraform.tfvars" -out=tfplan

# Xem plan summary
echo "Plan summary:"
terraform show -json tfplan | jq '.resource_changes[] | {action: .change.actions[0], type: .type, name: .name}'

# Áp dụng cấu hình (cần confirm với 'yes')
echo "Applying Terraform configuration..."
terraform apply tfplan
```

#### 4.3 Xác minh triển khai
```bash
# Hiển thị outputs
echo "=== Terraform Outputs ==="
terraform output

# Liệt kê resources đã tạo
echo "=== Created Resources ==="
terraform state list

# Xác minh resources trong AWS với formatting đẹp
echo "=== VPC Information ==="
aws ec2 describe-vpcs \
  --filters "Name=tag:Project,Values=microservices" \
  --query 'Vpcs[].{VpcId:VpcId,CidrBlock:CidrBlock,State:State,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table

echo "=== EC2 Instances ==="
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=microservices" \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,Type:InstanceType,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table

echo "=== Security Groups ==="
aws ec2 describe-security-groups \
  --filters "Name=tag:Project,Values=microservices" \
  --query 'SecurityGroups[].{GroupId:GroupId,GroupName:GroupName,Description:Description,VpcId:VpcId}' \
  --output table
```

### Bước 5: Thiết lập GitHub Actions (Từ CloudShell)

#### 5.1 Chuẩn bị Git repository
```bash
cd ~/projects/aws-infra-microservices

# Cấu hình git
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Kiểm tra git status
git status

# Nếu chưa có git repository
git init
git remote add origin https://github.com/your-username/aws-infra-microservices.git

# Add và commit tất cả files
git add .
git commit -m "Initial Terraform infrastructure setup with CloudShell"

# Push lên GitHub (sẽ cần GitHub token)
git push -u origin main
```

#### 5.2 Tạo GitHub Personal Access Token
```bash
echo "=== GitHub Token Setup ==="
echo "1. Truy cập: https://github.com/settings/tokens"
echo "2. Click 'Generate new token (classic)'"
echo "3. Chọn scopes: repo, workflow"
echo "4. Copy token và sử dụng làm password khi push"
echo ""
echo "Khi git push yêu cầu credentials:"
echo "Username: your-github-username"
echo "Password: ghp_xxxxxxxxxxxxxxxxxxxx (GitHub PAT)"
```

### Bước 6: Lưu trữ thông tin quan trọng

#### 6.1 Lưu thông tin bucket và cấu hình
```bash
# Lưu thông tin quan trọng với formatting đẹp
cat > ~/aws-infra-info.txt << EOF
===============================================
    AWS Infrastructure Information
===============================================
S3 Bucket: $BUCKET_NAME
DynamoDB Table: terraform-state-lock
Region: us-east-1
Project: microservices
Environment: dev
Created: $(date)

===============================================
    Important Commands
===============================================
# Navigate to project:
cd ~/projects/aws-infra-microservices/terraform

# Quick status check:
~/quick-status.sh

# Check resources:
terraform state list
terraform output

# Update infrastructure:
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"

# Destroy (when needed):
terraform destroy -var-file="terraform.tfvars"

===============================================
    Useful AWS Commands
===============================================
# List all EC2 instances in project:
aws ec2 describe-instances --filters "Name=tag:Project,Values=microservices" --output table

# Check S3 bucket:
aws s3 ls s3://$BUCKET_NAME

# Check DynamoDB table:
aws dynamodb describe-table --table-name terraform-state-lock --output table
EOF

echo "Information saved to ~/aws-infra-info.txt"
cat ~/aws-infra-info.txt
```

#### 6.2 Tạo script tiện ích
```bash
# Tạo script kiểm tra nhanh
cat > ~/quick-status.sh << 'EOF'
#!/bin/bash
echo "=== Terraform Infrastructure Status ==="
cd ~/projects/aws-infra-microservices/terraform

echo "Current workspace: $(terraform workspace show)"
echo "State file location: $(terraform remote config -get)"
echo ""

echo "=== Resources Count ==="
terraform state list | wc -l | xargs echo "Total resources:"

echo ""
echo "=== Recent Resources ==="
terraform state list | head -5
if [ $(terraform state list | wc -l) -gt 5 ]; then
    echo "... and $(($(terraform state list | wc -l) - 5)) more"
fi

echo ""
echo "=== AWS Resources Summary ==="
aws ec2 describe-instances --filters "Name=tag:Project,Values=microservices" --query 'length(Reservations[].Instances[])' --output text | xargs echo "EC2 Instances:"
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=microservices" --query 'length(Vpcs[])' --output text | xargs echo "VPCs:"
EOF

chmod +x ~/quick-status.sh

# Tạo script khởi động nhanh
cat > ~/start-terraform.sh << 'EOF'
#!/bin/bash
cd ~/projects/aws-infra-microservices/terraform
echo "=== AWS Infrastructure Project ==="
echo "Current directory: $(pwd)"
echo "Current workspace: $(terraform workspace show)"
echo ""
echo "=== Quick Commands ==="
echo "terraform plan -var-file='terraform.tfvars'     # Plan changes"
echo "terraform apply -var-file='terraform.tfvars'    # Apply changes"
echo "terraform output                                 # Show outputs"
echo "~/quick-status.sh                                # Quick status"
echo ""
echo "Ready for Terraform operations!"
EOF

chmod +x ~/start-terraform.sh

echo "Utility scripts created:"
echo "- ~/quick-status.sh : Quick infrastructure status"
echo "- ~/start-terraform.sh : Navigate and show help"
```

### Bước 7: Monitoring và Management

#### 7.1 Tạo alias hữu ích
```bash
# Thêm alias vào .bashrc
cat >> ~/.bashrc << 'EOF'

# Terraform aliases
alias tf='terraform'
alias tfp='terraform plan -var-file="terraform.tfvars"'
alias tfa='terraform apply -var-file="terraform.tfvars"'
alias tfo='terraform output'
alias tfs='terraform state list'

# AWS aliases
alias aws-instances='aws ec2 describe-instances --filters "Name=tag:Project,Values=microservices" --output table'
alias aws-vpcs='aws ec2 describe-vpcs --filters "Name=tag:Project,Values=microservices" --output table'
alias aws-sgs='aws ec2 describe-security-groups --filters "Name=tag:Project,Values=microservices" --output table'

# Project aliases
alias infra='cd ~/projects/aws-infra-microservices/terraform'
alias status='~/quick-status.sh'
EOF

source ~/.bashrc

echo "Aliases added! Use: tf, tfp, tfa, tfo, tfs, infra, status"
```

### Bước 8: Dọn dẹp (khi cần)

#### 8.1 Xóa hạ tầng an toàn
```bash
# Tạo script dọn dẹp an toàn
cat > ~/cleanup-infra.sh << 'EOF'
#!/bin/bash
set -e

echo "=== AWS Infrastructure Cleanup ==="
echo "This will destroy all Terraform-managed resources!"
read -p "Are you sure? Type 'yes' to confirm: " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

cd ~/projects/aws-infra-microservices/terraform

echo "=== Current Resources ==="
terraform state list

echo ""
read -p "Proceed with destruction? Type 'DESTROY' to confirm: " confirm2

if [ "$confirm2" != "DESTROY" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo "=== Destroying Infrastructure ==="
terraform destroy -var-file="terraform.tfvars" -auto-approve

echo "=== Cleaning up backend resources ==="
BUCKET_NAME=$(grep bucket main.tf | cut -d'"' -f4)
echo "Cleaning S3 bucket: $BUCKET_NAME"

aws s3 rm s3://$BUCKET_NAME --recursive
aws s3 rb s3://$BUCKET_NAME

echo "Deleting DynamoDB table..."
aws dynamodb delete-table --table-name terraform-state-lock --region us-east-1

echo "=== Cleanup completed ==="
EOF

chmod +x ~/cleanup-infra.sh

echo "Cleanup script created: ~/cleanup-infra.sh"
echo "Use with caution - it will destroy all resources!"
```

## 💡 CloudShell Tips (với sudo)

1. **System-wide installations**: Có thể cài đặt packages system-wide
2. **Package management**: Sử dụng `yum` để cài đặt dependencies
3. **Service management**: Có thể chạy services nếu cần
4. **File permissions**: Có thể thay đổi permissions và ownership
5. **System configuration**: Có thể modify system configs

## 🔧 Advanced Troubleshooting

```bash
# Kiểm tra system resources
free -h
df -h
ps aux | head -10

# Kiểm tra network connectivity
ping -c 3 amazonaws.com
nslookup s3.amazonaws.com

# Kiểm tra AWS CLI configuration
aws configure list
aws sts get-caller-identity --output json | jq

# Terraform debugging
export TF_LOG=INFO
terraform plan -var-file="terraform.tfvars"

# Checkov advanced scan
checkov -d . --framework terraform --check CKV_AWS_20,CKV_AWS_23 --output cli

# System logs
sudo tail -f /var/log/messages
```

## 🔒 Security Enhancements (với sudo)

```bash
# Cài đặt security tools
sudo yum install -y aide tripwire

# Setup fail2ban (nếu có SSH)
sudo yum install -y epel-release
sudo yum install -y fail2ban

# File integrity monitoring
aide --init
sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

# Network security scan
sudo yum install -y nmap
nmap -sS localhost
```

**Lưu ý**: Với quyền sudo, bạn có thể cài đặt và cấu hình nhiều tools hữu ích hơn cho việc quản lý infrastructure!