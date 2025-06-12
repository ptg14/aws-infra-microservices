# Jenkins CI/CD Pipeline cho Microservices

Hướng dẫn triển khai Jenkins CI/CD pipeline để tự động hóa quy trình build, test và deploy ứng dụng microservices với tích hợp SonarQube và security scanning.

## 📋 Tổng quan

Pipeline Jenkins này bao gồm:
- **Build & Test**: Maven build và unit tests tự động
- **SonarQube Integration**: Kiểm tra chất lượng mã nguồn
- **Security Scanning**: Trivy vulnerability scanner
- **Docker Build**: Tạo và push Docker images
- **Multi-Platform Deploy**: Kubernetes và AWS ECS deployment
- **Notification**: Slack notifications

## 🏗️ Kiến trúc Pipeline

```
Git Push → Jenkins → Build → Test → SonarQube → Security Scan → Docker Build → Deploy
                                     ↓
                              Quality Gate Check
```

## 📁 Cấu trúc Files

```
jenkins/
├── Jenkinsfile                 # Pipeline configuration
├── sonar-project.properties    # SonarQube settings
└── README.md                   # File này
```

## 🚀 Hướng dẫn triển khai

### Bước 1: Setup Jenkins Server trên AWS

#### 1.1 Tạo EC2 Instance cho Jenkins
```bash
# Tạo security group cho Jenkins
aws ec2 create-security-group \
  --group-name jenkins-sg \
  --description "Security group for Jenkins server" \
  --vpc-id vpc-xxxxxxxx

# Thêm rules cho Jenkins
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxx \
  --protocol tcp \
  --port 8080 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxx \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

# Launch EC2 instance
aws ec2 run-instances \
  --image-id ami-0c02fb55956c7d316 \
  --instance-type t3.medium \
  --key-name your-key-pair \
  --security-group-ids sg-xxxxxxxx \
  --subnet-id subnet-xxxxxxxx \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Jenkins-Server}]'
```

#### 1.2 Cài đặt Jenkins
```bash
# SSH vào EC2 instance
ssh -i your-key.pem ec2-user@<jenkins-server-ip>

# Update system
sudo yum update -y

# Install Java 11
sudo yum install -y java-11-openjdk-devel

# Add Jenkins repository
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key

# Install Jenkins
sudo yum install -y jenkins

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

#### 1.3 Cài đặt Docker
```bash
# Install Docker
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker

# Add jenkins user to docker group
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

#### 1.4 Cài đặt kubectl
```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify installation
kubectl version --client
```

### Bước 2: Cấu hình Jenkins

#### 2.1 Initial Setup
```bash
# Access Jenkins UI
http://your-jenkins-server:8080

# Enter admin password và cài đặt suggested plugins
# Tạo admin user
```

#### 2.2 Cài đặt Required Plugins
Vào **Manage Jenkins** → **Manage Plugins** → **Available** và cài đặt:
- Pipeline
- Docker Pipeline
- Kubernetes
- SonarQube Scanner
- GitHub Integration
- Credentials Plugin
- Slack Notification Plugin

#### 2.3 Cấu hình Global Tools
Vào **Manage Jenkins** → **Global Tool Configuration**:

**Maven Configuration:**
```
Name: Maven-3.8.0
Install automatically: ✓
Version: 3.8.0
```

**JDK Configuration:**
```
Name: JDK-11
Install automatically: ✓
Version: OpenJDK 11
```

**SonarQube Scanner:**
```
Name: SonarQube Scanner
Install automatically: ✓
Version: Latest
```

### Bước 3: Setup SonarQube Server

#### 3.1 Tạo SonarQube bằng Docker
```bash
# Create network
docker network create sonarqube

# Run PostgreSQL
docker run -d --name sonarqube-db \
  --network sonarqube \
  -e POSTGRES_USER=sonar \
  -e POSTGRES_PASSWORD=sonar \
  -e POSTGRES_DB=sonarqube \
  -v postgresql_data:/var/lib/postgresql/data \
  postgres:13

# Run SonarQube
docker run -d --name sonarqube \
  --network sonarqube \
  -p 9000:9000 \
  -e SONAR_JDBC_URL=jdbc:postgresql://sonarqube-db:5432/sonarqube \
  -e SONAR_JDBC_USERNAME=sonar \
  -e SONAR_JDBC_PASSWORD=sonar \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_logs:/opt/sonarqube/logs \
  -v sonarqube_extensions:/opt/sonarqube/extensions \
  sonarqube:latest
```

#### 3.2 Cấu hình SonarQube
```bash
# Access SonarQube
http://your-sonarqube-server:9000

# Default login: admin/admin
# Change password khi đăng nhập lần đầu

# Generate token:
# Administration → Security → Users → Tokens → Generate
```

#### 3.3 Cấu hình SonarQube trong Jenkins
Vào **Manage Jenkins** → **Configure System** → **SonarQube servers**:
```
Name: SonarQube
Server URL: http://your-sonarqube-server:9000
Server authentication token: [Add từ Credentials]
```

### Bước 4: Cấu hình Credentials

#### 4.1 Docker Hub Credentials
```bash
# Manage Jenkins → Credentials → Global → Add Credentials
Type: Username with password
ID: docker-hub-credentials
Username: your-docker-username
Password: your-docker-password
```

#### 4.2 SonarQube Token
```bash
Type: Secret text
ID: sonarqube-token
Secret: your-sonarqube-token
```

#### 4.3 Kubernetes Config
```bash
Type: Secret file
ID: kubernetes-config
File: your-kubeconfig-file
```

#### 4.4 AWS Credentials
```bash
Type: AWS Credentials
ID: aws-credentials
Access Key ID: your-aws-access-key
Secret Access Key: your-aws-secret-key
```

#### 4.5 Slack Token (Optional)
```bash
Type: Secret text
ID: slack-token
Secret: your-slack-bot-token
```

### Bước 5: Tạo Jenkins Pipeline

#### 5.1 Tạo Pipeline Job
```bash
# Jenkins Dashboard → New Item
# Tên: microservices-pipeline
# Type: Pipeline
# OK
```

#### 5.2 Cấu hình Pipeline
**Pipeline Definition:**
```
Pipeline script from SCM
```

**SCM Configuration:**
```
SCM: Git
Repository URL: https://github.com/your-repo/aws-infra-microservices.git
Credentials: [Add GitHub credentials nếu private repo]
Branch: */main
Script Path: jenkins/Jenkinsfile
```

**Build Triggers:**
```
☑ GitHub hook trigger for GITScm polling
☑ Poll SCM: H/5 * * * *
```

### Bước 6: Cấu hình Kubernetes Cluster

#### 6.1 Tạo EKS Cluster (nếu chưa có)
```bash
# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Create EKS cluster
eksctl create cluster \
  --name microservices-cluster \
  --region us-east-1 \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 4 \
  --managed
```

#### 6.2 Cấu hình kubectl
```bash
# Update kubeconfig
aws eks update-kubeconfig \
  --region us-east-1 \
  --name microservices-cluster

# Verify connection
kubectl get nodes

# Copy kubeconfig for Jenkins
cp ~/.kube/config /tmp/kubeconfig-jenkins
```

### Bước 7: Customization Pipeline

#### 7.1 Cập nhật Docker Image Name
Sửa file [`jenkins/Jenkinsfile`](jenkins/Jenkinsfile):
```groovy
environment {
    DOCKER_IMAGE = 'your-dockerhub-username/microservice-app'  # Thay đổi này
    // ...existing code...
}
```

#### 7.2 Cập nhật Kubernetes Manifests
Sửa file [`kubernetes/deployment.yaml`](kubernetes/deployment.yaml):
```yaml
# ...existing code...
containers:
- name: microservice-app
  image: your-dockerhub-username/microservice-app:latest  # Thay đổi này
  # ...existing code...
```

#### 7.3 Cấu hình SonarQube Properties
File [`jenkins/sonar-project.properties`](jenkins/sonar-project.properties) đã được cấu hình sẵn:
```properties
sonar.projectKey=microservices-app
sonar.projectName=Microservices Application
sonar.projectVersion=1.0
sonar.sources=src/main
sonar.tests=src/test
```

### Bước 8: Test Pipeline

#### 8.1 Chạy Pipeline lần đầu
```bash
# Jenkins Dashboard → microservices-pipeline → Build Now
# Monitor logs để kiểm tra từng stage
```

#### 8.2 Trigger tự động
```bash
# Push code để trigger pipeline
git add .
git commit -m "Update application code"
git push origin main

# Pipeline sẽ tự động chạy
```

### Bước 9: Monitoring và Validation

#### 9.1 Kiểm tra Jenkins Logs
```bash
# View pipeline logs trong Jenkins UI
# Check console output cho từng stage
```

#### 9.2 Verify SonarQube Analysis
```bash
# Access SonarQube dashboard
http://your-sonarqube-server:9000

# Check project: microservices-app
# Review code quality metrics
```

#### 9.3 Verify Kubernetes Deployment
```bash
# Check deployments
kubectl get deployments

# Check pods
kubectl get pods

# Check services
kubectl get services

# Get application URL
kubectl get service microservice-app
```

#### 9.4 Verify Docker Images
```bash
# Check Docker Hub cho pushed images
# Or check local registry nếu sử dụng
docker images | grep microservice-app
```

## 🔧 Advanced Configuration

### Multi-Environment Deployment

#### Staging Environment
```groovy
stage('Deploy to Staging') {
    when {
        branch 'develop'
    }
    steps {
        script {
            withKubeConfig([credentialsId: 'kubernetes-config']) {
                sh """
                    kubectl apply -f kubernetes/deployment.yaml -n staging
                    kubectl apply -f kubernetes/service.yaml -n staging
                """
            }
        }
    }
}
```

#### Production Environment
```groovy
stage('Deploy to Production') {
    when {
        branch 'main'
    }
    steps {
        input message: 'Deploy to Production?', ok: 'Deploy'
        script {
            withKubeConfig([credentialsId: 'kubernetes-config']) {
                sh """
                    kubectl apply -f kubernetes/deployment.yaml -n production
                    kubectl apply -f kubernetes/service.yaml -n production
                """
            }
        }
    }
}
```

### Blue-Green Deployment
```groovy
stage('Blue-Green Deploy') {
    steps {
        script {
            def currentColor = sh(
                script: "kubectl get service microservice-app -o jsonpath='{.spec.selector.version}'",
                returnStdout: true
            ).trim()

            def newColor = currentColor == 'blue' ? 'green' : 'blue'

            sh """
                sed -i 's/version: v1/version: ${newColor}/' kubernetes/deployment.yaml
                kubectl apply -f kubernetes/deployment.yaml
                kubectl patch service microservice-app -p '{"spec":{"selector":{"version":"${newColor}"}}}'
            """
        }
    }
}
```

### Rollback Strategy
```groovy
stage('Rollback') {
    when {
        expression { params.ROLLBACK == true }
    }
    steps {
        script {
            sh """
                kubectl rollout undo deployment/microservice-app
                kubectl rollout status deployment/microservice-app
            """
        }
    }
}
```

## 🔒 Security Best Practices

### 1. Secure Credentials Management
```bash
# Sử dụng Jenkins Credentials Plugin
# Không hardcode sensitive data
# Rotate credentials định kỳ
```

### 2. Docker Security
```bash
# Scan images với Trivy
# Use non-root users in containers
# Keep base images updated
```

### 3. Kubernetes Security
```bash
# Use RBAC
# Network policies
# Pod security policies
```

### 4. SonarQube Security Rules
```properties
# Enable security hotspot detection
sonar.security.hotspots.enabled=true
# Set quality gate thresholds
sonar.qualitygate.wait=true
```

## 🐛 Troubleshooting

### Common Issues

#### 1. Jenkins Connection Issues
```bash
# Check Jenkins service
sudo systemctl status jenkins

# Check ports
netstat -tlnp | grep 8080

# Check logs
sudo tail -f /var/log/jenkins/jenkins.log
```

#### 2. Docker Permission Issues
```bash
# Add jenkins user to docker group
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins

# Test docker access
sudo -u jenkins docker ps
```

#### 3. Kubernetes Connection Issues
```bash
# Verify kubeconfig
kubectl config current-context

# Test connection
kubectl get nodes

# Check credentials in Jenkins
```

#### 4. SonarQube Connection Issues
```bash
# Check SonarQube status
docker ps | grep sonarqube

# Check SonarQube logs
docker logs sonarqube

# Test API connection
curl http://your-sonarqube-server:9000/api/system/status
```

#### 5. Pipeline Failures
```bash
# Check Jenkins console output
# Verify all credentials are configured
# Check tool configurations
# Verify script syntax
```

### Debug Commands
```bash
# Jenkins CLI
java -jar jenkins-cli.jar -s http://localhost:8080/ help

# Pipeline validation
# Use Jenkins → Pipeline → Pipeline Syntax để validate

# Docker debugging
docker run --rm -it your-image:tag /bin/bash

# Kubernetes debugging
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

## 📊 Monitoring và Metrics

### Jenkins Metrics
```bash
# Performance monitoring
# Build success/failure rates
# Build duration trends
# Resource utilization
```

### SonarQube Metrics
```bash
# Code coverage trends
# Technical debt ratio
# Security vulnerabilities
# Code duplications
```

### Application Metrics
```bash
# Kubernetes metrics
kubectl top nodes
kubectl top pods

# Application health checks
curl http://your-app/actuator/health
```

## 🧹 Maintenance

### Regular Tasks
```bash
# 1. Update Jenkins plugins monthly
# 2. Clean up old build artifacts
# 3. Rotate credentials quarterly
# 4. Update base Docker images
# 5. Review and update security scans
```

### Backup Strategy
```bash
# Jenkins configuration backup
sudo tar -czf jenkins-backup.tar.gz /var/lib/jenkins/

# SonarQube database backup
docker exec sonarqube-db pg_dump -U sonar sonarqube > sonarqube-backup.sql
```

## 📚 Additional Resources

- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [SonarQube Documentation](https://docs.sonarqube.org/)
- [Trivy Security Scanner](https://github.com/aquasecurity/trivy)
- [Kubernetes Deployment Guide](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

## 🚀 Next Steps

1. **Implement GitOps**: Sử dụng ArgoCD hoặc Flux
2. **Add Monitoring**: Prometheus + Grafana
3. **Service Mesh**: Istio integration
4. **Automated Testing**: Integration và E2E tests
5. **Multi-Region Deployment**: Cross-region failover

---

**Lưu ý**: Thay thế tất cả placeholder values (như `your-docker-username`, `your-sonarqube-server`, etc.) bằng values thực tế của bạn trước khi triển khai.