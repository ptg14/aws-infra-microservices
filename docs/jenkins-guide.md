# Jenkins CI/CD Pipeline cho AWS Microservices

Hướng dẫn toàn diện để triển khai quy trình CI/CD sử dụng Jenkins với tích hợp SonarQube, security scanning, và deployment tự động cho ứng dụng microservices trên Docker và Kubernetes.

## 📋 Tổng quan

Hệ thống này tự động hóa việc triển khai microservices bao gồm:
- **Jenkins Pipeline**: Tự động hóa build, test, và deployment
- **SonarQube Integration**: Phân tích chất lượng mã nguồn và quality gates
- **Security Scanning**: Trivy vulnerability scanner + OWASP ZAP + Dependency Check
- **Docker Containerization**: Multi-stage builds với security best practices
- **Kubernetes Deployment**: Container orchestration với health checks
- **Multi-Environment**: Development, Staging, Production environments

## 🏗️ Kiến trúc Hệ thống

```
Git Push → Jenkins → Build → Unit Tests → SonarQube → Security Scan → Docker Build → K8s Deploy
                              ↓              ↓             ↓              ↓
                       Quality Gate    Trivy + ZAP    Image Scanning  Health Checks
                              ↓              ↓             ↓              ↓
                      Pass/Fail Gate  Security Reports  Vuln Reports   Integration Tests
```

## 📁 Cấu trúc Dự án

```
aws-infra-microservices/
├── jenkins/
│   ├── docker-compose.yml          # Jenkins + SonarQube + services
│   ├── Jenkinsfile                 # Pipeline definition
│   ├── sonar-project.properties    # SonarQube configuration
│   ├── docker/
│   │   └── Dockerfile              # Application Dockerfile
│   ├── k8s/
│   │   ├── deployment.yaml         # Kubernetes deployment
│   │   └── configmap.yaml          # Application configuration
│   └── scripts/
│       ├── setup-jenkins.sh        # Environment setup
│       └── cleanup.sh              # Cleanup script
├── src/                            # Application source code
├── docs/
│   └── jenkins-guide.md            # This guide
└── README.md
```

## 🚀 Hướng dẫn Triển khai

### Bước 1: Chuẩn bị Môi trường

#### 1.1 Kiểm tra Prerequisites
```bash
# Kiểm tra Docker
docker --version
docker-compose --version

# Kiểm tra Git
git --version

# Kiểm tra Java (cho local development)
java -version
mvn --version

# Kiểm tra kubectl (cho Kubernetes deployment)
kubectl version --client

# Kiểm tra trạng thái Jenkins
sudo systemctl status jenkins
```

#### 1.2 Clone Project
```bash
# Clone repository
git clone https://github.com/your-username/aws-infra-microservices.git
cd aws-infra-microservices

# Kiểm tra cấu trúc
tree jenkins/
```

### Bước 2: Khởi động Jenkins Environment

#### 2.1 Cấp quyền và khởi chạy setup script
```bash
# Cấp quyền execute cho scripts
chmod +x jenkins/scripts/*.sh

# Chạy setup script
./jenkins/scripts/setup-jenkins.sh
```

#### 2.2 Theo dõi quá trình khởi động
```bash
# Theo dõi logs
docker-compose -f jenkins/docker-compose.yml logs -f

# Kiểm tra trạng thái containers
docker-compose -f jenkins/docker-compose.yml ps
```

#### 2.3 Truy cập các services
```bash
# Kiểm tra Jenkins (có thể mất vài phút để khởi động)
curl -f http://localhost:8000 || echo "Jenkins đang khởi động..."

# Kiểm tra SonarQube
curl -f http://localhost:9000 || echo "SonarQube đang khởi động..."

# Kiểm tra Demo App
curl -f http://localhost:3000 || echo "Demo app đang khởi động..."
```

### Bước 3: Cấu hình Jenkins

#### 3.1 Hoàn tất Jenkins Setup Wizard
```bash
# Lấy initial admin password
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword

echo "Truy cập http://localhost:8000 và sử dụng password trên"
```

#### 3.2 Cài đặt Plugins cần thiết
Trong Jenkins UI:
1. **Install suggested plugins** khi được hỏi
2. Thêm các plugins quan trọng:
   - SonarQube Scanner
   - Docker Pipeline
   - Kubernetes
   - Blue Ocean (tùy chọn)
   - OWASP Dependency-Check

#### 3.3 Cấu hình SonarQube Server
```bash
# Trong Jenkins: Manage Jenkins → Configure System → SonarQube servers
# Name: SonarQube
# Server URL: http://sonarqube:9000

# Tạo SonarQube token
echo "1. Truy cập http://localhost:9000"
echo "2. Login: admin/admin"
echo "3. Tạo token: My Account → Security → Generate Tokens"
echo "4. Thêm token vào Jenkins: Manage Jenkins → Manage Credentials"
```

#### 3.4 Cấu hình Docker
```bash
# Trong Jenkins: Manage Jenkins → Global Tool Configuration
# Docker installations:
# Name: docker
# Install automatically: ✓
# Add installer: Download from docker.com
```

### Bước 4: Tạo Jenkins Pipeline Job

#### 4.1 Tạo Pipeline Job
```bash
echo "Trong Jenkins UI:"
echo "1. New Item → Pipeline"
echo "2. Tên: microservices-pipeline"
echo "3. Pipeline → Pipeline script from SCM"
echo "4. SCM: Git"
echo "5. Repository URL: https://github.com/your-username/aws-infra-microservices.git"
echo "6. Script Path: jenkins/Jenkinsfile"
```

#### 4.2 Cấu hình Build Triggers
```bash
echo "Build Triggers trong Pipeline configuration:"
echo "• GitHub hook trigger for GITScm polling ✓"
echo "• Poll SCM: H/5 * * * * (kiểm tra mỗi 5 phút)"
```

#### 4.3 Thiết lập Environment Variables
```bash
# Trong Pipeline configuration → Environment variables:
echo "DOCKER_REGISTRY=localhost:5000"
echo "SONARQUBE_SERVER=SonarQube"
echo "K8S_NAMESPACE=default"
```

### Bước 5: Cấu hình SonarQube Project

#### 5.1 Tạo SonarQube Project
```bash
# Truy cập SonarQube UI
echo "1. Truy cập http://localhost:9000"
echo "2. Create Project → Manually"
echo "3. Project key: microservices-app"
echo "4. Display name: Microservices Application"
```

#### 5.2 Cấu hình Quality Gate
```bash
echo "Trong SonarQube:"
echo "1. Quality Gates → Create"
echo "2. Tên: Microservices Gate"
echo "3. Thêm conditions:"
echo "   - Coverage < 80% = FAILED"
echo "   - Duplicated Lines (%) > 3% = FAILED"
echo "   - Maintainability Rating worse than A = FAILED"
echo "   - Reliability Rating worse than A = FAILED"
echo "   - Security Rating worse than A = FAILED"
```

### Bước 6: Chạy Pipeline lần đầu

#### 6.1 Trigger build thủ công
```bash
echo "Trong Jenkins:"
echo "1. Vào Pipeline job: microservices-pipeline"
echo "2. Click 'Build Now'"
echo "3. Theo dõi Console Output"
```

#### 6.2 Theo dõi Pipeline execution
```bash
# Kiểm tra build status
docker-compose -f jenkins/docker-compose.yml logs jenkins | tail -20

# Kiểm tra Docker images được tạo
docker images localhost:5000/microservices-app

# Kiểm tra SonarQube analysis
echo "Truy cập http://localhost:9000/dashboard?id=microservices-app"
```

### Bước 7: Cấu hình Kubernetes Deployment (Tùy chọn)

#### 7.1 Cài đặt Minikube (Local Kubernetes)
```bash
# Cài đặt Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Khởi động Minikube
minikube start --driver=docker

# Kiểm tra cluster
kubectl cluster-info
kubectl get nodes
```

#### 7.2 Cấu hình Jenkins để access Kubernetes
```bash
# Copy kubeconfig
mkdir -p ~/.kube
cp ~/.minikube/ca.crt ~/.kube/
cp ~/.minikube/profiles/minikube/client.crt ~/.kube/
cp ~/.minikube/profiles/minikube/client.key ~/.kube/

# Test kubectl access
kubectl get pods --all-namespaces
```

#### 7.3 Tạo namespaces cho environments
```bash
# Tạo namespaces
kubectl create namespace dev
kubectl create namespace staging
kubectl create namespace prod

# Kiểm tra
kubectl get namespaces
```

### Bước 8: Thiết lập GitHub Webhooks (Tùy chọn)

#### 8.1 Cấu hình GitHub Webhook
```bash
echo "Trong GitHub repository:"
echo "1. Settings → Webhooks → Add webhook"
echo "2. Payload URL: http://your-jenkins-url:8000/github-webhook/"
echo "3. Content type: application/json"
echo "4. Events: Push events, Pull request events"
```

#### 8.2 Test Webhook
```bash
# Tạo commit test
echo "# Test webhook" >> README.md
git add README.md
git commit -m "Test Jenkins webhook"
git push origin main

# Kiểm tra Jenkins có trigger build
echo "Kiểm tra Jenkins UI để xem build có được trigger tự động"
```

## 🔧 Testing Local

### Test Application Build
```bash
# Build ứng dụng locally
cd ~/aws-infra-microservices

# Build với Maven (nếu có pom.xml)
mvn clean compile test

# Build với Docker
docker build -t microservices-app:local -f jenkins/docker/Dockerfile .

# Run container
docker run -d -p 8082:8080 --name test-app microservices-app:local

# Test application
curl http://localhost:8082/
curl http://localhost:8082/actuator/health

# Cleanup
docker stop test-app && docker rm test-app
```

### Test SonarQube Analysis
```bash
# Chạy SonarQube analysis local
mvn sonar:sonar \
  -Dsonar.projectKey=microservices-app \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.login=your-sonarqube-token

# Hoặc với sonar-scanner
sonar-scanner \
  -Dsonar.projectKey=microservices-app \
  -Dsonar.sources=. \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.login=your-sonarqube-token
```

### Test Security Scanning
```bash
# Test Trivy filesystem scan
docker run --rm -v $(pwd):/workspace aquasec/trivy:latest fs /workspace

# Test Trivy image scan
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image microservices-app:local

# Test OWASP Dependency Check (nếu có Maven)
mvn org.owasp:dependency-check-maven:check
```

## 🔍 Troubleshooting

### Các Lỗi Thường Gặp:

#### 1. Jenkins Container không khởi động
```bash
# Kiểm tra logs
docker-compose -f jenkins/docker-compose.yml logs jenkins

# Kiểm tra ports có bị conflict
netstat -tulpn | grep :8080

# Restart containers
docker-compose -f jenkins/docker-compose.yml restart jenkins
```

#### 2. SonarQube Quality Gate Failed
```bash
# Kiểm tra SonarQube logs
docker-compose -f jenkins/docker-compose.yml logs sonarqube

# Xem chi tiết quality gate
echo "Truy cập http://localhost:9000/dashboard?id=microservices-app"

# Tạm thời skip quality gate (trong Jenkinsfile)
# Thêm: waitForQualityGate abortPipeline: false
```

#### 3. Docker Registry Connection Issues
```bash
# Kiểm tra local registry
curl http://localhost:5000/v2/_catalog

# Restart registry
docker-compose -f jenkins/docker-compose.yml restart registry

# Kiểm tra Docker daemon có access registry
docker info | grep -A 5 "Insecure Registries"
```

#### 4. Kubernetes Deployment Issues
```bash
# Kiểm tra cluster status
kubectl cluster-info
kubectl get nodes

# Kiểm tra deployment
kubectl get deployments -n dev
kubectl describe deployment microservices-app -n dev

# Xem pod logs
kubectl logs -l app=microservices-app -n dev

# Debug networking
kubectl get services -n dev
kubectl port-forward service/microservices-app-service 8083:80 -n dev
```

#### 5. Build Failures
```bash
# Kiểm tra build logs trong Jenkins Console Output
echo "Common issues:"
echo "- Missing dependencies: Kiểm tra pom.xml/build.gradle"
echo "- Test failures: Xem test reports"
echo "- Docker build issues: Kiểm tra Dockerfile"
echo "- Resource limitations: Tăng Jenkins executor memory"
```

### Lệnh Debug Hữu ích:

```bash
# Kiểm tra Jenkins system info
docker exec jenkins java -jar /usr/share/jenkins/jenkins.war --version

# Kiểm tra Jenkins plugins
docker exec jenkins ls /var/jenkins_home/plugins/

# Kiểm tra Docker inside Jenkins
docker exec jenkins docker --version
docker exec jenkins docker images

# Kiểm tra SonarQube connectivity
docker exec jenkins curl -f http://sonarqube:9000/api/system/status

# Cleanup build artifacts
docker system prune -f
docker volume prune -f
```

## 📊 Monitoring và Alerts

### Jenkins Monitoring
```bash
# Setup monitoring script
cat > ~/monitor-jenkins.sh << 'EOF'
#!/bin/bash
echo "=== Jenkins System Status ==="
echo "Jenkins URL: http://localhost:8000"
echo "Status: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000)"

echo -e "\n=== Recent Builds ==="
# Sử dụng Jenkins CLI hoặc REST API để lấy build status
curl -s "http://localhost:8000/api/json?tree=jobs[name,lastBuild[number,result,timestamp]]" | \
  jq -r '.jobs[] | "\(.name): Build #\(.lastBuild.number) - \(.lastBuild.result)"'

echo -e "\n=== System Resources ==="
docker stats --no-stream jenkins sonarqube postgres

echo -e "\n=== Docker Images ==="
docker images localhost:5000/microservices-app | head -5
EOF

chmod +x ~/monitor-jenkins.sh
```

### SonarQube Monitoring
```bash
# SonarQube health check
curl -s http://localhost:9000/api/system/health | jq '.'

# Project metrics
curl -s "http://localhost:9000/api/measures/component?component=microservices-app&metricKeys=ncloc,complexity,violations" | jq '.'

# Quality gate status
curl -s "http://localhost:9000/api/qualitygates/project_status?projectKey=microservices-app" | jq '.'
```

### Alerting Setup
```bash
# Simple email notification script
cat > ~/jenkins-alerts.sh << 'EOF'
#!/bin/bash
JENKINS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000)
SONAR_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9000)

if [ $JENKINS_STATUS -ne 200 ]; then
    echo "ALERT: Jenkins is down! Status: $JENKINS_STATUS" | mail -s "Jenkins Alert" admin@company.com
fi

if [ $SONAR_STATUS -ne 200 ]; then
    echo "ALERT: SonarQube is down! Status: $SONAR_STATUS" | mail -s "SonarQube Alert" admin@company.com
fi
EOF

# Thêm vào crontab để chạy mởi 5 phút
# */5 * * * * ~/jenkins-alerts.sh
```

## 💡 Jenkins Tips & Best Practices

### Performance Optimization
```bash
# Tăng Jenkins memory
echo "Trong docker-compose.yml:"
echo "JAVA_OPTS=-Xmx2048m -XX:MaxPermSize=512m"

# Cleanup old builds automatically
echo "Trong Pipeline:"
echo "properties([buildDiscarder(logRotator(numToKeepStr: '10'))])"

# Sử dụng parallel stages
echo "Optimize pipeline với parallel execution để giảm thời gian build"
```

### Security Best Practices
```bash
# Regular backup Jenkins data
docker run --rm -v jenkins_jenkins_home:/source -v $(pwd):/backup alpine \
  tar czf /backup/jenkins-backup-$(date +%Y%m%d).tar.gz -C /source .

# Update Jenkins và plugins thường xuyên
echo "Manage Jenkins → Plugin Manager → Updates"

# Sử dụng credentials store
echo "Manage Jenkins → Manage Credentials để lưu trữ secrets an toàn"
```

### Pipeline Optimization
```bash
# Sử dụng Docker layer caching
echo "Trong Dockerfile:"
echo "# Copy requirements first for better caching"
echo "COPY pom.xml ."
echo "RUN mvn dependency:go-offline"
echo "COPY src ./src"

# Skip redundant stages
echo "Sử dụng when conditions để skip stages không cần thiết"
```

## 🔒 Security Enhancements

### Additional Security Tools
```bash
# Thêm Snyk scanning vào pipeline
echo "stage('Snyk Security Scan') {"
echo "  steps {"
echo "    sh 'npm install -g snyk'"
echo "    sh 'snyk test --json > snyk-report.json || true'"
echo "    archiveArtifacts 'snyk-report.json'"
echo "  }"
echo "}"

# Thêm container security với Clair
echo "stage('Container Security Scan') {"
echo "  steps {"
echo "    sh 'clair-scanner --ip localhost microservices-app:latest'"
echo "  }"
echo "}"
```

### Access Control
```bash
# Setup RBAC trong Jenkins
echo "Manage Jenkins → Configure Global Security"
echo "Authorization: Matrix-based security"
echo "Tạo user groups: developers, admins, viewers"

# Audit logging
echo "Enable audit trail plugin để track user actions"
```

## 🧹 Dọn dẹp

### Dọn dẹp Environment
```bash
# Sử dụng cleanup script
./jenkins/scripts/cleanup.sh

# Hoặc manual cleanup:

# Stop tất cả containers
docker-compose -f jenkins/docker-compose.yml down

# Xóa volumes (cẩn thận - sẽ mất data)
docker-compose -f jenkins/docker-compose.yml down -v

# Xóa images
docker images localhost:5000/microservices-app -q | xargs docker rmi -f

# Clean up Docker system
docker system prune -af
docker volume prune -f
```

### Backup trước khi cleanup
```bash
# Backup Jenkins data
docker run --rm -v jenkins_jenkins_home:/source -v $(pwd):/backup alpine \
  tar czf /backup/jenkins-backup-$(date +%Y%m%d-%H%M%S).tar.gz -C /source .

# Backup SonarQube data
docker run --rm -v jenkins_sonarqube_data:/source -v $(pwd):/backup alpine \
  tar czf /backup/sonarqube-backup-$(date +%Y%m%d-%H%M%S).tar.gz -C /source .

echo "✅ Backups created in current directory"
ls -la *backup*.tar.gz
```

### Restore from backup
```bash
# Restore Jenkins
docker run --rm -v jenkins_jenkins_home:/target -v $(pwd):/backup alpine \
  tar xzf /backup/jenkins-backup-YYYYMMDD-HHMMSS.tar.gz -C /target

# Restore SonarQube
docker run --rm -v jenkins_sonarqube_data:/target -v $(pwd):/backup alpine \
  tar xzf /backup/sonarqube-backup-YYYYMMDD-HHMMSS.tar.gz -C /target

# Restart services
docker-compose -f jenkins/docker-compose.yml restart
```

## 📚 Tài liệu Tham khảo

### Official Documentation
- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [SonarQube Quality Gates](https://docs.sonarqube.org/latest/user-guide/quality-gates/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)

### Security Tools
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [OWASP ZAP User Guide](https://www.zaproxy.org/docs/)
- [OWASP Dependency Check](https://owasp.org/www-project-dependency-check/)

### Additional Resources
- [Jenkins Best Practices](https://www.jenkins.io/doc/book/pipeline/pipeline-best-practices/)
- [SonarQube Administration](https://docs.sonarqube.org/latest/setup/overview/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)

## 🚀 Bước tiếp theo

### Advanced Features
1. **Multi-Branch Pipeline**: Tự động tạo pipeline cho feature branches
2. **GitOps Integration**: Tích hợp với ArgoCD hoặc Flux
3. **Advanced Testing**: Contract testing, performance testing
4. **Multi-Cloud Deployment**: Deploy đến AWS, GCP, Azure
5. **Monitoring Integration**: Prometheus, Grafana, ELK stack
6. **Compliance**: Policy as Code với OPA/Gatekeeper

### Scaling Considerations
1. **Jenkins Cluster**: Master-slave configuration
2. **Database Migration**: PostgreSQL cho SonarQube production
3. **External Registry**: AWS ECR, Docker Hub, Harbor
4. **CI/CD Optimization**: Build cache, parallel execution
5. **Security Hardening**: Secrets management, network segmentation

### Integration Opportunities
1. **Slack/Teams Notifications**: Real-time alerts
2. **Jira Integration**: Issue tracking và deployment correlation
3. **Confluence Documentation**: Auto-generated documentation
4. **Service Mesh**: Istio integration cho advanced traffic management
5. **Observability**: APM tools integration (New Relic, Datadog)

---
