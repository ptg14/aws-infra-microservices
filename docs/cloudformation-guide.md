
Hướng dẫn toàn diện để triển khai hạ tầng AWS sử dụng CloudFormation với quy trình CI/CD tự động hóa thông qua AWS CodePipeline, tích hợp cfn-lint và TaskCat để đảm bảo chất lượng mã.

## 📋 Tổng quan

Hệ thống này tự động hóa việc triển khai hạ tầng AWS bao gồm:
- **CloudFormation Templates**: Định nghĩa hạ tầng dưới dạng mã
- **AWS CodePipeline**: Tự động hóa quy trình CI/CD
- **AWS CodeBuild**: Thực hiện validation và testing
- **CFN-Lint**: Kiểm tra cú pháp và best practices
- **TaskCat**: Testing templates trên nhiều regions

## 🏗️ Kiến trúc Hệ thống

```
CodeCommit → CodePipeline → CodeBuild (cfn-lint + TaskCat) → CloudFormation Deploy
                                ↓
                         Quality Gate Checks
```

## 📁 Cấu trúc Dự án

```
aws-infra-microservices/
├── cloudformation/
│   ├── infrastructure.yaml      # Template chính
│   ├── buildspec.yml           # Build instructions
│   └── .taskcat.yml           # TaskCat configuration
├── docs/
│   └── cloudformation-guide.md # File hướng dẫn này
└── README.md
```

## 🚀 Hướng dẫn Triển khai

### Bước 1: Chuẩn bị Môi trường

#### 1.1 Kiểm tra AWS CLI
```bash
# Xác nhận đã cấu hình AWS CLI
aws sts get-caller-identity

# Kiểm tra region hiện tại
aws configure get region

# Đặt region mặc định nếu cần
aws configure set region us-east-1
```

#### 1.2 Cài đặt Công cụ Hỗ trợ (Tùy chọn)
```bash
# Cài đặt cfn-lint để test local
pip install cfn-lint

# Cài đặt taskcat để test local
pip install taskcat

# Xác minh cài đặt
cfn-lint --version
taskcat --version
```

### Bước 2: Tạo Tài nguyên AWS Cần thiết

#### 2.1 Tạo S3 Bucket cho Artifacts
```bash
# Tạo bucket với tên unique
BUCKET_NAME="cloudformation-artifacts-$(date +%s)"
echo "Tên bucket: $BUCKET_NAME"

# Tạo S3 bucket
aws s3 mb s3://$BUCKET_NAME --region us-east-1

# Bật versioning
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# Bật mã hóa
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

# Chặn public access
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "✅ S3 bucket đã được tạo: $BUCKET_NAME"
```

#### 2.2 Tạo CodeCommit Repository
```bash
# Tạo CodeCommit repository
aws codecommit create-repository \
  --repository-name aws-infra-microservices \
  --repository-description "AWS Infrastructure cho Microservices"

# Lấy thông tin repository
aws codecommit get-repository \
  --repository-name aws-infra-microservices

echo "✅ CodeCommit repository đã được tạo"
```

#### 2.3 Tạo IAM Service Roles

**Tạo CodeBuild Service Role:**
```bash
# Tạo trust policy cho CodeBuild
cat > codebuild-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Tạo CodeBuild service role
aws iam create-role \
  --role-name CodeBuildServiceRole \
  --assume-role-policy-document file://codebuild-trust-policy.json

# Tạo custom policy cho CodeBuild
cat > codebuild-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:ValidateTemplate"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Tạo và gắn policy
aws iam create-policy \
  --policy-name CodeBuildCustomPolicy \
  --policy-document file://codebuild-policy.json

aws iam attach-role-policy \
  --role-name CodeBuildServiceRole \
  --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/CodeBuildCustomPolicy

# Gắn thêm managed policies
aws iam attach-role-policy \
  --role-name CodeBuildServiceRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

echo "✅ CodeBuild Service Role đã được tạo"
```

**Tạo CodePipeline Service Role:**
```bash
# Tạo trust policy cho CodePipeline
cat > codepipeline-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Tạo CodePipeline service role
aws iam create-role \
  --role-name CodePipelineServiceRole \
  --assume-role-policy-document file://codepipeline-trust-policy.json

# Tạo custom policy cho CodePipeline
cat > codepipeline-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetBucketVersioning",
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::$BUCKET_NAME",
        "arn:aws:s3:::$BUCKET_NAME/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codecommit:CancelUploadArchive",
        "codecommit:GetBranch",
        "codecommit:GetCommit",
        "codecommit:GetRepository",
        "codecommit:ListBranches",
        "codecommit:ListRepositories"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:CreateStack",
        "cloudformation:DeleteStack",
        "cloudformation:DescribeStacks",
        "cloudformation:UpdateStack",
        "cloudformation:CreateChangeSet",
        "cloudformation:DeleteChangeSet",
        "cloudformation:DescribeChangeSet",
        "cloudformation:ExecuteChangeSet",
        "cloudformation:SetStackPolicy",
        "cloudformation:ValidateTemplate"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": "arn:aws:iam::*:role/CloudFormationServiceRole"
    }
  ]
}
EOF

# Tạo và gắn policy
aws iam create-policy \
  --policy-name CodePipelineCustomPolicy \
  --policy-document file://codepipeline-policy.json

aws iam attach-role-policy \
  --role-name CodePipelineServiceRole \
  --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/CodePipelineCustomPolicy

echo "✅ CodePipeline Service Role đã được tạo"
```

**Tạo CloudFormation Service Role:**
```bash
# Tạo trust policy cho CloudFormation
cat > cloudformation-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudformation.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Tạo CloudFormation service role
aws iam create-role \
  --role-name CloudFormationServiceRole \
  --assume-role-policy-document file://cloudformation-trust-policy.json

# Gắn PowerUser policy (hoặc tạo custom policy với quyền cụ thể)
aws iam attach-role-policy \
  --role-name CloudFormationServiceRole \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess

echo "✅ CloudFormation Service Role đã được tạo"
```

### Bước 3: Đẩy Code lên CodeCommit

#### 3.1 Cấu hình Git cho CodeCommit
```bash
# Cấu hình Git credentials helper
git config --global credential.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true

# Clone repository
git clone https://git-codecommit.us-east-1.amazonaws.com/v1/repos/aws-infra-microservices
cd aws-infra-microservices

echo "✅ Repository đã được clone"
```

#### 3.2 Thêm CloudFormation Files
```bash
# Tạo cấu trúc thư mục
mkdir -p cloudformation docs

# Copy các files CloudFormation (thay thế path phù hợp)
cp ../infrastructure.yaml cloudformation/
cp ../buildspec.yml cloudformation/
cp ../.taskcat.yml cloudformation/

# Tạo file README.md nếu chưa có
cat > README.md << EOF
# AWS Infrastructure với CloudFormation

Dự án triển khai hạ tầng AWS sử dụng CloudFormation và CodePipeline.

## Cấu trúc
- \`cloudformation/\`: CloudFormation templates và configuration
- \`docs/\`: Tài liệu hướng dẫn

## Triển khai
Hạ tầng sẽ được tự động triển khai khi push code lên main branch.
EOF

# Add và commit files
git add .
git commit -m "Initial CloudFormation infrastructure với cfn-lint và taskcat"
git push origin main

echo "✅ Code đã được đẩy lên CodeCommit"
```

### Bước 4: Tạo CodeBuild Project

```bash
# Tạo CodeBuild project configuration
cat > codebuild-project.json << EOF
{
  "name": "microservices-infrastructure-build",
  "description": "Build project cho microservices infrastructure với cfn-lint và taskcat",
  "source": {
    "type": "CODECOMMIT",
    "location": "https://git-codecommit.us-east-1.amazonaws.com/v1/repos/aws-infra-microservices",
    "buildspec": "cloudformation/buildspec.yml"
  },
  "artifacts": {
    "type": "S3",
    "location": "$BUCKET_NAME",
    "packaging": "ZIP"
  },
  "environment": {
    "type": "LINUX_CONTAINER",
    "image": "aws/codebuild/amazonlinux2-x86_64-standard:4.0",
    "computeType": "BUILD_GENERAL1_SMALL",
    "environmentVariables": [
      {
        "name": "ARTIFACTS_BUCKET",
        "value": "$BUCKET_NAME"
      },
      {
        "name": "AWS_DEFAULT_REGION",
        "value": "us-east-1"
      }
    ]
  },
  "serviceRole": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/CodeBuildServiceRole",
  "timeoutInMinutes": 60
}
EOF

# Tạo project
aws codebuild create-project --cli-input-json file://codebuild-project.json

echo "✅ CodeBuild project đã được tạo"
```

### Bước 5: Tạo CodePipeline

```bash
# Tạo CodePipeline configuration
cat > codepipeline.json << EOF
{
  "pipeline": {
    "name": "microservices-infrastructure-pipeline",
    "roleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/CodePipelineServiceRole",
    "artifactStore": {
      "type": "S3",
      "location": "$BUCKET_NAME"
    },
    "stages": [
      {
        "name": "Source",
        "actions": [
          {
            "name": "SourceAction",
            "actionTypeId": {
              "category": "Source",
              "owner": "AWS",
              "provider": "CodeCommit",
              "version": "1"
            },
            "configuration": {
              "RepositoryName": "aws-infra-microservices",
              "BranchName": "main"
            },
            "outputArtifacts": [
              {
                "name": "SourceOutput"
              }
            ]
          }
        ]
      },
      {
        "name": "Build",
        "actions": [
          {
            "name": "BuildAction",
            "actionTypeId": {
              "category": "Build",
              "owner": "AWS",
              "provider": "CodeBuild",
              "version": "1"
            },
            "configuration": {
              "ProjectName": "microservices-infrastructure-build"
            },
            "inputArtifacts": [
              {
                "name": "SourceOutput"
              }
            ],
            "outputArtifacts": [
              {
                "name": "BuildOutput"
              }
            ]
          }
        ]
      },
      {
        "name": "Deploy",
        "actions": [
          {
            "name": "DeployAction",
            "actionTypeId": {
              "category": "Deploy",
              "owner": "AWS",
              "provider": "CloudFormation",
              "version": "1"
            },
            "configuration": {
              "ActionMode": "CREATE_UPDATE",
              "StackName": "microservices-infrastructure",
              "TemplatePath": "BuildOutput::packaged-template.yaml",
              "ParameterOverrides": "BuildOutput::parameters.json",
              "Capabilities": "CAPABILITY_IAM",
              "RoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/CloudFormationServiceRole"
            },
            "inputArtifacts": [
              {
                "name": "BuildOutput"
              }
            ]
          }
        ]
      }
    ]
  }
}
EOF

# Tạo pipeline
aws codepipeline create-pipeline --cli-input-json file://codepipeline.json

echo "✅ CodePipeline đã được tạo"
```

### Bước 6: Kiểm tra và Xác thực

#### 6.1 Theo dõi Pipeline Execution
```bash
# Kiểm tra trạng thái pipeline
aws codepipeline get-pipeline-state --name microservices-infrastructure-pipeline

# Lấy chi tiết execution
aws codepipeline list-pipeline-executions --pipeline-name microservices-infrastructure-pipeline

echo "🔍 Kiểm tra pipeline trong AWS Console: CodePipeline > microservices-infrastructure-pipeline"
```

#### 6.2 Kiểm tra CloudFormation Stack
```bash
# Kiểm tra trạng thái stack
aws cloudformation describe-stacks --stack-name microservices-infrastructure

# Liệt kê stack resources
aws cloudformation list-stack-resources --stack-name microservices-infrastructure

echo "🔍 Kiểm tra stack trong AWS Console: CloudFormation > microservices-infrastructure"
```

#### 6.3 Xem Build Reports
```bash
# Liệt kê CodeBuild builds
aws codebuild list-builds-for-project --project-name microservices-infrastructure-build

# Lấy chi tiết build gần nhất
BUILD_ID=$(aws codebuild list-builds-for-project --project-name microservices-infrastructure-build --query 'ids[0]' --output text)
aws codebuild batch-get-builds --ids $BUILD_ID

echo "🔍 Kiểm tra builds trong AWS Console: CodeBuild > microservices-infrastructure-build"
```

### Bước 7: Tạo Script Tiện ích

```bash
# Tạo script kiểm tra nhanh
cat > ~/check-pipeline.sh << 'EOF'
#!/bin/bash
echo "=== AWS Infrastructure Pipeline Status ==="

# Pipeline status
echo "📋 Pipeline Status:"
aws codepipeline get-pipeline-state --name microservices-infrastructure-pipeline \
  --query 'stageStates[].[stageName,latestExecution.status]' \
  --output table

# CloudFormation stack status
echo ""
echo "☁️ CloudFormation Stack Status:"
aws cloudformation describe-stacks --stack-name microservices-infrastructure \
  --query 'Stacks[0].{StackName:StackName,Status:StackStatus,Created:CreationTime}' \
  --output table

# Recent builds
echo ""
echo "🔨 Recent Builds:"
aws codebuild list-builds-for-project --project-name microservices-infrastructure-build \
  --query 'ids[:3]' --output table

echo ""
echo "🌐 AWS Console Links:"
echo "• Pipeline: https://console.aws.amazon.com/codesuite/codepipeline/pipelines/microservices-infrastructure-pipeline/view"
echo "• CloudFormation: https://console.aws.amazon.com/cloudformation/home#/stacks/stackinfo?stackId=microservices-infrastructure"
echo "• CodeBuild: https://console.aws.amazon.com/codesuite/codebuild/projects/microservices-infrastructure-build"
EOF

chmod +x ~/check-pipeline.sh

# Tạo script dọn dẹp
cat > ~/cleanup-pipeline.sh << 'EOF'
#!/bin/bash
echo "=== AWS Infrastructure Cleanup ==="
echo "⚠️  CẢNH BÁO: Script này sẽ xóa toàn bộ infrastructure!"
read -p "Bạn có chắc chắn muốn tiếp tục? Gõ 'yes' để xác nhận: " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Hủy cleanup"
    exit 0
fi

echo "🗑️ Xóa CloudFormation stack..."
aws cloudformation delete-stack --stack-name microservices-infrastructure

echo "🗑️ Xóa CodePipeline..."
aws codepipeline delete-pipeline --name microservices-infrastructure-pipeline

echo "🗑️ Xóa CodeBuild project..."
aws codebuild delete-project --name microservices-infrastructure-build

echo "🗑️ Xóa S3 bucket contents..."
BUCKET_NAME=$(aws s3 ls | grep cloudformation-artifacts | awk '{print $3}')
if [ ! -z "$BUCKET_NAME" ]; then
    aws s3 rm s3://$BUCKET_NAME --recursive
    aws s3 rb s3://$BUCKET_NAME
    echo "✅ S3 bucket đã được xóa: $BUCKET_NAME"
fi

echo "✅ Cleanup hoàn tất!"
echo "ℹ️  Lưu ý: IAM roles vẫn được giữ lại để tái sử dụng"
EOF

chmod +x ~/cleanup-pipeline.sh

echo "✅ Scripts tiện ích đã được tạo:"
echo "• ~/check-pipeline.sh - Kiểm tra trạng thái pipeline"
echo "• ~/cleanup-pipeline.sh - Dọn dẹp toàn bộ infrastructure"
```

## 🔧 Testing Local (Tùy chọn)

### Test CFN-Lint
```bash
# Test cú pháp CloudFormation template
cfn-lint cloudformation/infrastructure.yaml

# Test với các rules cụ thể
cfn-lint --ignore-checks W2001 W2030 cloudformation/infrastructure.yaml

# Test tất cả files trong thư mục
cfn-lint cloudformation/*.yaml
```

### Test TaskCat
```bash
# Chạy TaskCat test
taskcat test run --config cloudformation/.taskcat.yml

# Test với regions cụ thể
taskcat test run --config cloudformation/.taskcat.yml --regions us-east-1

# Dọn dẹp test resources
taskcat test clean --config cloudformation/.taskcat.yml
```

## 🔍 Troubleshooting

### Các Lỗi Thường Gặp:

#### 1. CFN-Lint Errors
```bash
# Lỗi cú pháp template
ERROR: Template format error: ...

# Giải pháp: Kiểm tra YAML syntax
yamllint cloudformation/infrastructure.yaml
```

#### 2. TaskCat Failures
```bash
# Lỗi parameters không hợp lệ
ERROR: Parameter validation failed

# Giải pháp: Kiểm tra .taskcat.yml configuration
cat cloudformation/.taskcat.yml
```

#### 3. IAM Permission Issues
```bash
# Lỗi quyền truy cập
ERROR: User is not authorized to perform: ...

# Giải pháp: Kiểm tra IAM roles và policies
aws iam get-role --role-name CodeBuildServiceRole
```

#### 4. Resource Limits
```bash
# Lỗi vượt quá giới hạn tài nguyên
ERROR: Resource limit exceeded

# Giải pháp: Kiểm tra AWS service quotas
aws service-quotas list-service-quotas --service-code ec2
```

### Lệnh Debug Hữu ích:

```bash
# Kiểm tra CloudFormation events
aws cloudformation describe-stack-events --stack-name microservices-infrastructure

# Xem CodeBuild logs chi tiết
BUILD_ID=$(aws codebuild list-builds-for-project --project-name microservices-infrastructure-build --query 'ids[0]' --output text)
aws logs get-log-events --log-group-name /aws/codebuild/microservices-infrastructure-build --log-stream-name $BUILD_ID

# Kiểm tra Pipeline execution history
aws codepipeline list-pipeline-executions --pipeline-name microservices-infrastructure-pipeline --max-items 5
```

## 📊 Monitoring và Alerts

### CloudWatch Monitoring
```bash
# Tạo CloudWatch alarm cho pipeline failures
aws cloudwatch put-metric-alarm \
  --alarm-name "Pipeline-Failure-Alert" \
  --alarm-description "Alert khi pipeline bị lỗi" \
  --metric-name PipelineExecutionFailure \
  --namespace AWS/CodePipeline \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold
```

### SNS Notifications (Tùy chọn)
```bash
# Tạo SNS topic cho notifications
aws sns create-topic --name infrastructure-alerts

# Subscribe email
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT_ID:infrastructure-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com
```

## 🧹 Dọn dẹp

### Xóa Toàn bộ Infrastructure
```bash
# Sử dụng script đã tạo
~/cleanup-pipeline.sh

# Hoặc thực hiện thủ công:

# 1. Xóa CloudFormation stack
aws cloudformation delete-stack --stack-name microservices-infrastructure

# 2. Chờ stack được xóa hoàn toàn
aws cloudformation wait stack-delete-complete --stack-name microservices-infrastructure

# 3. Xóa CodePipeline
aws codepipeline delete-pipeline --name microservices-infrastructure-pipeline

# 4. Xóa CodeBuild project
aws codebuild delete-project --name microservices-infrastructure-build

# 5. Xóa S3 bucket
BUCKET_NAME=$(aws s3 ls | grep cloudformation-artifacts | awk '{print $3}')
aws s3 rm s3://$BUCKET_NAME --recursive
aws s3 rb s3://$BUCKET_NAME

# 6. Xóa CodeCommit repository (tùy chọn)
aws codecommit delete-repository --repository-name aws-infra-microservices

# 7. Xóa IAM roles (tùy chọn)
aws iam detach-role-policy --role-name CodeBuildServiceRole --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
aws iam detach-role-policy --role-name CodeBuildServiceRole --policy-arn arn:aws:iam::ACCOUNT_ID:policy/CodeBuildCustomPolicy
aws iam delete-role --role-name CodeBuildServiceRole

aws iam detach-role-policy --role-name CodePipelineServiceRole --policy-arn arn:aws:iam::ACCOUNT_ID:policy/CodePipelineCustomPolicy
aws iam delete-role --role-name CodePipelineServiceRole

aws iam detach-role-policy --role-name CloudFormationServiceRole --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
aws iam delete-role --role-name CloudFormationServiceRole

# 8. Xóa IAM policies
aws iam delete-policy --policy-arn arn:aws:iam::ACCOUNT_ID:policy/CodeBuildCustomPolicy
aws iam delete-policy --policy-arn arn:aws:iam::ACCOUNT_ID:policy/CodePipelineCustomPolicy
```

## 📚 Tài liệu Tham khảo

- [AWS CloudFormation Documentation](https://docs.aws.amazon.com/cloudformation/)
- [AWS CodePipeline User Guide](https://docs.aws.amazon.com/codepipeline/)
- [AWS CodeBuild User Guide](https://docs.aws.amazon.com/codebuild/)
- [CFN-Lint Documentation](https://github.com/aws-cloudformation/cfn-lint)
- [TaskCat Documentation](https://aws-quickstart.github.io/taskcat/)

## 🚀 Bước tiếp theo

1. **Implement GitOps**: Tích hợp với ArgoCD hoặc Flux
2. **Add Monitoring**: Prometheus + Grafana setup
3. **Multi-Environment**: Tạo pipelines cho dev/staging/prod
4. **Advanced Testing**: Integration và E2E tests
5. **Cross-Region Deployment**: Multi-region failover setup

---