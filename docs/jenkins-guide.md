# AWS Infrastructure Microservices with Jenkins CI/CD

## 📋 Overview

This project demonstrates a complete CI/CD pipeline using Jenkins for microservices deployment with:
- **Jenkins Pipeline**: Automated build, test, and deployment
- **SonarQube Integration**: Code quality analysis
- **Security Scanning**: Trivy vulnerability scanner
- **Docker Containerization**: Application packaging
- **Kubernetes Deployment**: Container orchestration
- **Infrastructure as Code**: Terraform for AWS resources

## 🏗️ Architecture

```
Git Push → Jenkins → Build → Test → SonarQube → Security Scan → Docker Build → K8s Deploy
                                     ↓
                              Quality Gate Check
```

## 📁 Project Structure

```
aws-infra-microservices/
├── jenkins/
│   ├── Jenkinsfile                 # Pipeline configuration
│   ├── sonar-project.properties    # SonarQube settings
│   ├── docker/
│   │   └── Dockerfile             # Application Docker image
│   └── k8s/
│       ├── deployment.yaml        # Kubernetes deployment
│       └── configmap.yaml         # Configuration
├── terraform/                     # Infrastructure as Code
├── scripts/
│   ├── setup-jenkins.sh          # Environment setup
│   └── cleanup.sh                # Environment cleanup
├── docker-compose.yml             # Local development
├── pom.xml                       # Maven configuration
└── src/                          # Application source code
```

# 🚀 Quick Start

## Prerequisites

- Docker and Docker Compose
- Git
- Java 11+ (for local development)
- kubectl (for Kubernetes deployment)

## Setup

1. **Clone the repository:**
```bash
git clone <your-repo-url>
cd aws-infra-microservices
```

2. **Start the CI/CD environment:**
```bash
chmod +x scripts/setup-jenkins.sh
./scripts/setup-jenkins.sh
```

3. **Access the services:**
- Jenkins: http://localhost:8080
- SonarQube: http://localhost:9000 (admin/admin)
- Demo App: http://localhost:8081

## Jenkins Configuration

### 1. Initial Setup
1. Access Jenkins at http://localhost:8080
2. Use the initial admin password from the setup script output
3. Install suggested plugins plus:
   - Pipeline
   - Docker Pipeline
   - SonarQube Scanner
   - Kubernetes
   - Credentials Plugin

### 2. Configure Tools
Go to **Manage Jenkins** → **Global Tool Configuration**:

- **Maven**: Maven-3.8.0 (auto-install)
- **JDK**: JDK-11 (auto-install)
- **SonarQube Scanner**: Latest (auto-install)
- **Docker**: Docker (auto-install)

### 3. Configure SonarQube
1. In SonarQube (http://localhost:9000), generate a token
2. In Jenkins: **Manage Jenkins** → **Configure System** → **SonarQube servers**
   - Name: SonarQube
   - Server URL: http://sonarqube:9000
   - Token: Add from Credentials

### 4. Add Credentials
**Manage Jenkins** → **Credentials** → **Global** → **Add Credentials**:

- **Docker Hub**: Username/Password (ID: docker-hub-credentials)
- **SonarQube Token**: Secret text (ID: sonarqube-token)
- **Kubernetes Config**: Secret file (ID: kubernetes-config)

### 5. Create Pipeline Job
1. **New Item** → **Pipeline**
2. **Pipeline Definition**: Pipeline script from SCM
3. **SCM**: Git
4. **Repository URL**: Your repository URL
5. **Script Path**: jenkins/Jenkinsfile

## Pipeline Stages

1. **Checkout**: Get source code from Git
2. **Build**: Compile application (Maven/Gradle)
3. **Unit Tests**: Run automated tests
4. **Code Quality Analysis**: SonarQube scan
5. **Quality Gate**: Enforce quality standards
6. **Security Scan**: Trivy filesystem scan
7. **Build Docker Image**: Create container image
8. **Docker Security Scan**: Container vulnerability scan
9. **Push Docker Image**: Push to registry (for main/develop branches)
10. **Deploy**: Deploy to Kubernetes (environment-specific)

## Security Features

### Code Quality
- SonarQube integration for code quality metrics
- Quality gates to prevent deployment of poor-quality code
- Test coverage tracking

### Security Scanning
- **Trivy**: Filesystem vulnerability scanning
- **Docker Security**: Container image vulnerability scanning
- **Non-root containers**: Security best practices

### Access Control
- Jenkins credentials management
- Kubernetes RBAC (when configured)
- Docker registry authentication

## Local Development

### Build and Test Locally
```bash
# Build with Maven
mvn clean compile

# Run tests
mvn test

# Run SonarQube analysis (requires local SonarQube)
mvn sonar:sonar

# Build Docker image
docker build -t microservices-app:local -f jenkins/docker/Dockerfile .

# Run container
docker run -p 8080:8080 microservices-app:local
```

### Start Full Environment
```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

## Kubernetes Deployment

### Local Kubernetes (Minikube/K3s)
```bash
# Start Minikube
minikube start

# Create namespaces
kubectl create namespace dev
kubectl create namespace prod

# Deploy application
kubectl apply -f jenkins/k8s/ --namespace=dev

# Check deployment
kubectl get pods -n dev
kubectl get services -n dev
```

### Access Application
```bash
# Port forward to access locally
kubectl port-forward service/microservices-app-service 8080:80 -n dev

# Or setup ingress
kubectl apply -f jenkins/k8s/
```

## Monitoring and Troubleshooting

### Jenkins
- **Build Logs**: Check console output for each build
- **Pipeline Visualization**: Blue Ocean plugin
- **System Logs**: Manage Jenkins → System Log

### SonarQube
- **Quality Gates**: Project → Quality Gates
- **Security Hotspots**: Project → Security Hotspots
- **Code Coverage**: Project → Coverage

### Docker
```bash
# Check running containers
docker ps

# View container logs
docker logs <container-name>

# Execute into container
docker exec -it <container-name> /bin/bash
```

### Kubernetes
```bash
# Check pods
kubectl get pods -n <namespace>

# View pod logs
kubectl logs <pod-name> -n <namespace>

# Describe pod
kubectl describe pod <pod-name> -n <namespace>

# Check services
kubectl get services -n <namespace>
```

## Best Practices

### Code Quality
- Maintain minimum test coverage (configure in SonarQube)
- Fix critical security vulnerabilities
- Follow coding standards

### Security
- Regularly update base Docker images
- Scan for vulnerabilities in dependencies
- Use non-root containers
- Rotate credentials regularly

### CI/CD
- Use feature branches for development
- Require code review before merging
- Automated testing at all levels
- Gradual rollout for production deployments

## Cleanup

To remove all containers and volumes:
```bash
chmod +x scripts/cleanup.sh
./scripts/cleanup.sh
```

## Troubleshooting

### Common Issues

#### Jenkins Connection Issues
```bash
# Check Jenkins logs
docker logs jenkins

# Restart Jenkins
docker restart jenkins
```

#### SonarQube Connection Issues
```bash
# Check SonarQube status
docker ps | grep sonar

# Check SonarQube logs
docker logs sonarqube
```

#### Docker Permission Issues
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Restart session or reboot
```

#### Kubernetes Connection Issues
```bash
# Check cluster status
kubectl cluster-info

# Check node status
kubectl get nodes

# Verify kubeconfig
kubectl config view
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.