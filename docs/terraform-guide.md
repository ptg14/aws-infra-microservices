# AWS Infrastructure Deployment với Terraform và GitHub Actions

Hướng dẫn toàn diện để triển khai hạ tầng AWS sử dụng Terraform với quy trình CI/CD tự động hóa thông qua GitHub Actions, tích hợp Checkov và TFLint để đảm bảo chất lượng mã.

## 📋 Tổng quan

Hệ thống này tự động hóa việc triển khai hạ tầng AWS bao gồm:
- **Terraform Templates**: Định nghĩa hạ tầng dưới dạng mã (Infrastructure as Code)
- **GitHub Actions**: Tự động hóa quy trình CI/CD
- **Checkov**: Kiểm tra bảo mật và best practices
- **TFLint**: Kiểm tra cú pháp và conventions
- **Remote State Management**: Quản lý state với S3 và DynamoDB

## 🏗️ Kiến trúc Hệ thống

```
GitHub Repository → GitHub Actions → Terraform Plan/Apply → AWS Infrastructure
                         ↓
                  Security & Quality Checks
                  (Checkov + TFLint)
                         ↓
                  S3 Backend + DynamoDB Lock
```

## 📁 Cấu trúc Dự án

```
aws-infra-microservices/
├── terraform/
│   ├── main.tf                 # Terraform main configuration
│   ├── variables.tf            # Variable definitions
│   ├── outputs.tf              # Output definitions
│   ├── terraform.tfvars        # Variable values
│   ├── modules/
│   ├── vpc/
│   │   ├── main.tf             # VPC, subnets, gateways, routing
│   │   ├── variables.tf        # VPC module variables
│   │   └── outputs.tf          # VPC module outputs
│   └── ec2/
│       ├── main.tf             # EC2 instances, security groups
│       ├── variables.tf        # EC2 module variables
│       ├── outputs.tf          # EC2 module outputs
│       ├── user_data_web.sh    # Web server initialization script
│       └── user_data_app.sh    # App server initialization script
├── .github/
│   └── workflows/
│       └── terraform.yml       # GitHub Actions workflow
└── docs/
    └── terraform-guide.md      # This guide
```

## 🚀 Hướng dẫn Triển khai

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

# Cài đặt TFLint
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# Xác minh các cài đặt
jq --version
tree --version
git --version
tflint --version
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

#### 5.3 Cấu hình GitHub Actions Workflow
```bash
# Tạo GitHub Actions workflow
mkdir -p .github/workflows

cat > .github/workflows/terraform.yml << 'EOF'
name: 'Terraform Infrastructure'

on:
  push:
    branches: [ main ]
    paths: [ 'terraform/**' ]
  pull_request:
    branches: [ main ]
    paths: [ 'terraform/**' ]
  workflow_dispatch:

env:
  TF_VERSION: '1.6.6'
  AWS_REGION: 'us-east-1'

jobs:
  terraform:
    name: 'Terraform'
    runs-on: ubuntu-latest
    environment: production

    defaults:
      run:
        shell: bash
        working-directory: ./terraform

    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}

    - name: Terraform Format Check
      id: fmt
      run: terraform fmt -check -recursive

    - name: Terraform Init
      id: init
      run: terraform init

    - name: Terraform Validate
      id: validate
      run: terraform validate

    - name: Setup Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.9'

    - name: Install Checkov
      run: pip install checkov

    - name: Run Checkov
      run: |
        checkov -d . --framework terraform --output cli --output json --output-file-path reports/
        echo "### Checkov Security Scan Results" >> $GITHUB_STEP_SUMMARY
        echo "\`\`\`json" >> $GITHUB_STEP_SUMMARY
        cat reports/results_json.json | jq '.summary' >> $GITHUB_STEP_SUMMARY
        echo "\`\`\`" >> $GITHUB_STEP_SUMMARY

    - name: Terraform Plan
      id: plan
      if: github.event_name == 'pull_request'
      run: terraform plan -no-color -input=false -var-file="terraform.tfvars"
      continue-on-error: true

    - name: Update Pull Request
      uses: actions/github-script@v7
      if: github.event_name == 'pull_request'
      env:
        PLAN: "terraform\n${{ steps.plan.outputs.stdout }}"
      with:
        github-token: ${{ secrets.GITHUB_TOKEN }}
        script: |
          const output = `#### Terraform Format and Style 🖌\`${{ steps.fmt.outcome }}\`
          #### Terraform Initialization ⚙️\`${{ steps.init.outcome }}\`
          #### Terraform Validation 🤖\`${{ steps.validate.outcome }}\`
          #### Terraform Plan 📖\`${{ steps.plan.outcome }}\`

          <details><summary>Show Plan</summary>

          \`\`\`\n
          ${process.env.PLAN}
          \`\`\`

          </details>

          *Pushed by: @${{ github.actor }}, Action: \`${{ github.event_name }}\`*`;

          github.rest.issues.createComment({
            issue_number: context.issue.number,
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: output
          })

    - name: Terraform Plan Status
      if: steps.plan.outcome == 'failure'
      run: exit 1

    - name: Terraform Apply
      if: github.ref == 'refs/heads/main' && github.event_name == 'push'
      run: terraform apply -auto-approve -input=false -var-file="terraform.tfvars"
EOF

echo "✅ GitHub Actions workflow đã được tạo"
```

#### 5.4 Cấu hình GitHub Secrets
```bash
echo "=== GitHub Secrets Setup ==="
echo "Truy cập GitHub repository settings và thêm các secrets sau:"
echo ""
echo "Repository → Settings → Secrets and variables → Actions"
echo ""
echo "Required secrets:"
echo "• AWS_ACCESS_KEY_ID: $(aws configure get aws_access_key_id || echo 'Your AWS Access Key')"
echo "• AWS_SECRET_ACCESS_KEY: $(aws configure get aws_secret_access_key || echo 'Your AWS Secret Key')"
echo ""
echo "Lưu ý: Nên tạo IAM user riêng cho GitHub Actions với quyền hạn tối thiểu"
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

===============================================
    GitHub Actions
===============================================
# Workflow file: .github/workflows/terraform.yml
# Secrets to configure:
#   - AWS_ACCESS_KEY_ID
#   - AWS_SECRET_ACCESS_KEY
#
# Workflow triggers:
#   - Push to main branch (auto-deploy)
#   - Pull request (plan only)
#   - Manual dispatch
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
echo "State file location: $(terraform remote config -get 2>/dev/null || echo 'Remote backend configured')"
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

echo ""
echo "=== GitHub Actions Status ==="
echo "Workflow: .github/workflows/terraform.yml"
echo "Check status: https://github.com/your-username/aws-infra-microservices/actions"
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
echo "git status                                       # Check git status"
echo "git push                                         # Trigger GitHub Actions"
echo ""
echo "=== GitHub Actions ==="
echo "https://github.com/your-username/aws-infra-microservices/actions"
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
alias tff='terraform fmt -recursive'
alias tfv='terraform validate'

# AWS aliases
alias aws-instances='aws ec2 describe-instances --filters "Name=tag:Project,Values=microservices" --output table'
alias aws-vpcs='aws ec2 describe-vpcs --filters "Name=tag:Project,Values=microservices" --output table'
alias aws-sgs='aws ec2 describe-security-groups --filters "Name=tag:Project,Values=microservices" --output table'

# Project aliases
alias infra='cd ~/projects/aws-infra-microservices/terraform'
alias status='~/quick-status.sh'

# Git aliases
alias gs='git status'
alias ga='git add .'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline -10'
EOF

source ~/.bashrc

echo "Aliases added! Use: tf, tfp, tfa, tfo, tfs, tff, tfv, infra, status, gs, ga, gc, gp, gl"
```

#### 7.2 Tạo Pre-commit Hooks
```bash
# Tạo pre-commit hook script
cat > ~/projects/aws-infra-microservices/.git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Terraform pre-commit hook

echo "🔍 Running pre-commit checks..."

# Change to terraform directory
cd terraform

# Format check
echo "📝 Checking Terraform formatting..."
if ! terraform fmt -check -recursive; then
    echo "❌ Terraform formatting issues found. Run 'terraform fmt -recursive' to fix."
    exit 1
fi

# Validation
echo "✅ Validating Terraform configuration..."
if ! terraform validate; then
    echo "❌ Terraform validation failed."
    exit 1
fi

# Checkov scan
echo "🔒 Running security scan..."
if command -v checkov >/dev/null 2>&1; then
    checkov -d . --framework terraform --quiet --compact
    if [ $? -ne 0 ]; then
        echo "❌ Security scan found issues."
        exit 1
    fi
else
    echo "⚠️  Checkov not installed, skipping security scan."
fi

echo "✅ All pre-commit checks passed!"
EOF

chmod +x ~/projects/aws-infra-microservices/.git/hooks/pre-commit

echo "✅ Pre-commit hooks configured"
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
echo "Note: GitHub repository and actions remain unchanged"
EOF

chmod +x ~/cleanup-infra.sh

echo "Cleanup script created: ~/cleanup-infra.sh"
echo "Use with caution - it will destroy all resources!"
```

## 🔧 Testing Local

### Test Terraform Configuration
```bash
# Test cú pháp và validation
terraform fmt -check -recursive
terraform validate

# Test plan với different var files
terraform plan -var-file="terraform.tfvars" -var-file="dev.tfvars"

# Test với different workspaces
terraform workspace new staging
terraform workspace select staging
terraform plan -var-file="staging.tfvars"
terraform workspace select default
```

### Test Checkov Security Scan
```bash
# Test với specific checks
checkov -d . --framework terraform --check CKV_AWS_20,CKV_AWS_23

# Test với custom config
checkov -d . --config-file .checkov.yml

# Test và ignore specific findings
checkov -d . --framework terraform --skip-check CKV_AWS_20
```

### Test TFLint
```bash
# Initialize TFLint
tflint --init

# Run TFLint with specific rules
tflint --enable-rule=terraform_deprecated_interpolation
tflint --enable-rule=terraform_unused_declarations

# Run with custom config
tflint --config=.tflint.hcl
```

## 🔍 Troubleshooting

### Các Lỗi Thường Gặp:

#### 1. Terraform State Lock Issues
```bash
# Lỗi state lock
ERROR: Error acquiring the state lock

# Giải pháp: Force unlock (cẩn thận!)
terraform force-unlock <LOCK_ID>

# Hoặc kiểm tra DynamoDB table
aws dynamodb scan --table-name terraform-state-lock
```

#### 2. GitHub Actions Failures
```bash
# Lỗi AWS credentials
ERROR: Unable to locate credentials

# Giải pháp: Kiểm tra GitHub secrets
# Repository → Settings → Secrets and variables → Actions

# Test credentials locally
aws sts get-caller-identity
```

#### 3. Checkov Security Failures
```bash
# Lỗi security scan
ERROR: CKV_AWS_20: S3 Bucket has an ACL defined which allows public access

# Giải pháp: Update Terraform configuration hoặc skip check
# Add to .checkov.yml:
skip-check:
  - CKV_AWS_20
```

#### 4. Backend Configuration Issues
```bash
# Lỗi backend initialization
ERROR: Backend configuration changed

# Giải pháp: Reconfigure backend
terraform init -reconfigure

# Hoặc migrate state
terraform init -migrate-state
```

### Lệnh Debug Hữu ích:

```bash
# Terraform debugging
export TF_LOG=DEBUG
terraform plan -var-file="terraform.tfvars"

# Check state file
terraform state list
terraform state show <resource_name>

# Validate JSON output
terraform show -json | jq .

# GitHub Actions debugging
# Check workflow runs:
# https://github.com/your-username/aws-infra-microservices/actions

# AWS resource verification
aws ec2 describe-instances --filters "Name=tag:Project,Values=microservices"
aws s3 ls s3://terraform-state-*
aws dynamodb describe-table --table-name terraform-state-lock
```

## 📊 Monitoring và Alerts

### CloudWatch Monitoring
```bash
# Tạo CloudWatch alarm cho Terraform operations
aws cloudwatch put-metric-alarm \
  --alarm-name "Terraform-State-Lock-Alert" \
  --alarm-description "Alert khi state lock quá lâu" \
  --metric-name ItemCount \
  --namespace AWS/DynamoDB \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=TableName,Value=terraform-state-lock
```

### GitHub Actions Monitoring
```bash
# Tạo script kiểm tra GitHub Actions status
cat > ~/check-github-actions.sh << 'EOF'
#!/bin/bash
echo "=== GitHub Actions Status ==="
echo "Repository: aws-infra-microservices"
echo "Workflow: terraform.yml"
echo ""
echo "🔗 Links:"
echo "• Actions: https://github.com/your-username/aws-infra-microservices/actions"
echo "• Workflow: https://github.com/your-username/aws-infra-microservices/actions/workflows/terraform.yml"
echo ""
echo "Recent commits that may trigger workflows:"
git log --oneline -5
EOF

chmod +x ~/check-github-actions.sh
```

## 💡 CloudShell Tips (với sudo)

1. **System-wide installations**: Có thể cài đặt packages system-wide
2. **Package management**: Sử dụng `yum` để cài đặt dependencies
3. **Service management**: Có thể chạy services nếu cần
4. **File permissions**: Có thể thay đổi permissions và ownership
5. **System configuration**: Có thể modify system configs
6. **Persistent storage**: Sử dụng `/tmp` cho temporary files
7. **Environment variables**: Có thể set system-wide env vars

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

# GitHub integration testing
git remote -v
git log --oneline -5
git status
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

# Terraform security best practices
cat > .tfsec.yml << 'EOF'
severity_overrides:
  CKV_AWS_20: LOW
  CKV_AWS_23: MEDIUM

exclude_checks:
  - CKV_AWS_20  # S3 bucket ACL
EOF

# Install tfsec for additional security scanning
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
sudo mv tfsec /usr/local/bin/
```

## 🧹 Dọn dẹp

### Xóa Toàn bộ Infrastructure
```bash
# Sử dụng script đã tạo
~/cleanup-infra.sh

# Hoặc thực hiện thủ công:

# 1. Destroy Terraform resources
cd ~/projects/aws-infra-microservices/terraform
terraform destroy -var-file="terraform.tfvars" -auto-approve

# 2. Clean up S3 bucket
BUCKET_NAME=$(grep bucket main.tf | cut -d'"' -f4)
aws s3 rm s3://$BUCKET_NAME --recursive
aws s3 rb s3://$BUCKET_NAME

# 3. Delete DynamoDB table
aws dynamodb delete-table --table-name terraform-state-lock --region us-east-1

# 4. Clean up GitHub repository (optional)
# Manually delete from GitHub web interface

# 5. Clean up local files
rm -rf ~/projects/aws-infra-microservices
rm ~/aws-infra-info.txt
rm ~/quick-status.sh
rm ~/start-terraform.sh
rm ~/cleanup-infra.sh
```

## 📚 Tài liệu Tham khảo

- [Terraform Documentation](https://www.terraform.io/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Checkov Documentation](https://www.checkov.io/1.Welcome/Quick%20Start.html)
- [TFLint Documentation](https://github.com/terraform-linters/tflint)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

## 🚀 Bước tiếp theo

1. **Multi-Environment Setup**: Tạo workspaces cho dev/staging/prod
2. **Advanced Modules**: Phát triển reusable Terraform modules
3. **Automated Testing**: Terratest cho integration testing
4. **State Management**: Advanced state management strategies
5. **Compliance**: Implement compliance as code với OPA
6. **Monitoring**: Implement infrastructure monitoring với Prometheus
7. **Documentation**: Tự động generate documentation với terraform-docs

---
