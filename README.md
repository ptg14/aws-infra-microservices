# AWS Infrastructure & Microservices CI/CD Project

## 📋 Tổng quan
Dự án toàn diện về triển khai hạ tầng AWS và quy trình CI/CD cho ứng dụng microservices với ba phương pháp chính: Terraform + GitHub Actions, CloudFormation + AWS CodePipeline, và Jenkins CI/CD Pipeline.

### 1. Terraform + GitHub Actions 🔧
- **Infrastructure as Code**: Triển khai hạ tầng AWS (VPC, Route Tables, NAT Gateway, EC2, Security Groups) bằng Terraform
- **CI/CD Automation**: Tự động hóa deployment với GitHub Actions workflows
- **Security & Compliance**: Tích hợp Checkov để kiểm tra security best practices và compliance
- **Remote State Management**: Quản lý Terraform state với S3 backend và DynamoDB locking

### 2. CloudFormation + AWS CodePipeline ☁️
- **AWS Native IaC**: Sử dụng CloudFormation templates để triển khai cùng một bộ hạ tầng AWS
- **Quality Assurance**: Tích hợp cfn-lint và TaskCat để validate CloudFormation templates
- **Native CI/CD**: AWS CodePipeline kết hợp với CodeBuild cho automated build và deployment
- **Source Control**: Sử dụng AWS CodeCommit làm source repository

### 3. Jenkins CI/CD Pipeline 🚀
- **Microservices CI/CD**: Jenkins automation cho build, test và deploy ứng dụng microservices
- **Container & Orchestration**: Deployment lên Docker và Kubernetes environments
- **Code Quality**: Tích hợp SonarQube để đánh giá chất lượng code
- **Security Integration**: Bao gồm security scanning với Trivy, OWASP ZAP, và Snyk (tùy chọn)

## 🛠️ Công nghệ & Công cụ

### Infrastructure as Code
- **Terraform**: HashiCorp Terraform cho multi-cloud IaC
- **CloudFormation**: AWS native infrastructure templates
- **Modules**: Reusable infrastructure components

### CI/CD Platforms
- **GitHub Actions**: Cloud-native CI/CD với workflows
- **AWS CodePipeline**: Fully managed continuous delivery service
- **Jenkins**: Open-source automation server với extensive plugin ecosystem

### Quality & Security Tools
- **Checkov**: Infrastructure security scanning cho Terraform
- **cfn-lint**: CloudFormation template validation
- **TaskCat**: CloudFormation testing framework
- **SonarQube**: Code quality và security analysis
- **Trivy**: Container vulnerability scanning
- **OWASP ZAP**: Dynamic application security testing

### Container & Orchestration
- **Docker**: Containerization platform
- **Kubernetes**: Container orchestration
- **Docker Registry**: Container image storage

## 📁 Cấu trúc Dự án

```
aws-infra-microservices/
├── terraform/              # Terraform Infrastructure
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── vpc/
│       └── ec2/
├── cloudformation/          # CloudFormation Templates
│   ├── infrastructure.yaml
│   ├── buildspec.yml
│   └── .taskcat.yml
├── jenkins/                 # Jenkins CI/CD Setup
│   ├── docker-compose.yml
│   ├── Jenkinsfile
│   ├── docker/
│   └── k8s/
├── .github/                 # GitHub Actions Workflows
│   └── workflows/
│       └── terraform.yml
└── docs/                    # Documentation
    ├── terraform-guide.md
    ├── cloudformation-guide.md
    └── jenkins-guide.md
```

## 🎯 Mục tiêu Dự án

1. **Infrastructure Automation**: Tự động hóa việc triển khai và quản lý hạ tầng AWS
2. **Multi-Platform CI/CD**: So sánh và triển khai với nhiều platform CI/CD khác nhau
3. **Security Integration**: Tích hợp security scanning và compliance checking
4. **Best Practices**: Áp dụng DevOps và Infrastructure as Code best practices
5. **Microservices Deployment**: Triển khai và quản lý ứng dụng microservices

## 🚀 Tính năng Chính

- ✅ **Multi-Cloud Ready**: Terraform templates có thể mở rộng cho nhiều cloud provider
- ✅ **Security First**: Tích hợp multiple security scanning tools
- ✅ **Automated Testing**: Infrastructure và application testing automation
- ✅ **GitOps Workflow**: Git-based deployment workflows
- ✅ **Monitoring Ready**: Chuẩn bị sẵn cho monitoring và alerting integration
- ✅ **Documentation**: Comprehensive documentation cho từng approach

## 📚 Tài liệu

Mỗi phương pháp triển khai có tài liệu chi tiết riêng:

- [`terraform-guide.md`](docs/terraform-guide.md) - Hướng dẫn Terraform + GitHub Actions
- [`cloudformation-guide.md`](docs/cloudformation-guide.md) - Hướng dẫn CloudFormation + CodePipeline
- [`jenkins-guide.md`](docs/jenkins-guide.md) - Hướng dẫn Jenkins CI/CD Pipeline

---
