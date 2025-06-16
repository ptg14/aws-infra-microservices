#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}[CLEANUP]${NC} $1"
}

print_header "=== AWS Infra Microservices Jenkins Project Cleanup ==="
print_warning "⚠️  CẢNH BÁO: Script này sẽ xóa HOÀN TOÀN dự án Jenkins bao gồm:"
echo "   • Tất cả containers và images"
echo "   • Tất cả volumes và data (Jenkins, SonarQube, PostgreSQL)"
echo "   • Network configurations"
echo "   • Local Docker registry"
echo "   • Build artifacts và reports"
echo "   • Kubernetes deployments (nếu có)"
echo "   • Temporary files và cache"
echo ""
print_error "   ⚠️  KHÔNG THỂ KHÔI PHỤC SAU KHI XÓA!"
echo ""

read -p "Bạn có chắc chắn muốn tiếp tục? Gõ 'YES' để xác nhận: " -r
if [[ ! $REPLY == "YES" ]]; then
    print_status "Cleanup đã bị hủy."
    exit 0
fi

echo ""
print_header "Bắt đầu quá trình cleanup..."

# Function to safely run commands
safe_run() {
    if eval "$1" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# 1. Stop and remove all containers
print_status "1. Dừng và xóa tất cả containers..."
if [ -f "jenkins/docker-compose.yml" ]; then
    safe_run "docker-compose -f jenkins/docker-compose.yml down -v --remove-orphans"
    print_success "   ✓ Docker Compose containers đã được dừng và xóa"
else
    print_warning "   ⚠️  Không tìm thấy docker-compose.yml"
fi

# Stop any remaining containers
print_status "   Dừng các containers còn lại..."
safe_run "docker stop jenkins sonarqube postgres registry demo-app adminer 2>/dev/null" && print_success "   ✓ Containers đã được dừng"

# 2. Remove all project-related images
print_status "2. Xóa tất cả Docker images liên quan..."
safe_run "docker rmi \$(docker images 'localhost:5000/microservices-app' -q) 2>/dev/null" && print_success "   ✓ Xóa microservices-app images"
safe_run "docker rmi \$(docker images 'microservices-app' -q) 2>/dev/null" && print_success "   ✓ Xóa local microservices-app images"
safe_run "docker rmi \$(docker images 'jenkins/jenkins' -q) 2>/dev/null" && print_success "   ✓ Xóa Jenkins images"
safe_run "docker rmi \$(docker images 'sonarqube' -q) 2>/dev/null" && print_success "   ✓ Xóa SonarQube images"
safe_run "docker rmi \$(docker images 'postgres' -q) 2>/dev/null" && print_success "   ✓ Xóa PostgreSQL images"
safe_run "docker rmi \$(docker images 'registry' -q) 2>/dev/null" && print_success "   ✓ Xóa Registry images"
safe_run "docker rmi \$(docker images 'adminer' -q) 2>/dev/null" && print_success "   ✓ Xóa Adminer images"

# 3. Remove all volumes
print_status "3. Xóa tất cả Docker volumes..."
safe_run "docker volume rm jenkins_jenkins_home 2>/dev/null" && print_success "   ✓ Xóa Jenkins volume"
safe_run "docker volume rm jenkins_sonarqube_data 2>/dev/null" && print_success "   ✓ Xóa SonarQube volume"
safe_run "docker volume rm jenkins_sonarqube_logs 2>/dev/null" && print_success "   ✓ Xóa SonarQube logs volume"
safe_run "docker volume rm jenkins_sonarqube_extensions 2>/dev/null" && print_success "   ✓ Xóa SonarQube extensions volume"
safe_run "docker volume rm jenkins_postgres_data 2>/dev/null" && print_success "   ✓ Xóa PostgreSQL volume"
safe_run "docker volume rm jenkins_registry_data 2>/dev/null" && print_success "   ✓ Xóa Registry volume"

# 4. Remove networks
print_status "4. Xóa Docker networks..."
safe_run "docker network rm jenkins_jenkins-network 2>/dev/null" && print_success "   ✓ Xóa Jenkins network"
safe_run "docker network rm jenkins_default 2>/dev/null" && print_success "   ✓ Xóa default network"

# 5. Clean up Kubernetes deployments (if any)
print_status "5. Dọn dẹp Kubernetes deployments..."
if command -v kubectl >/dev/null 2>&1; then
    safe_run "kubectl delete deployment microservices-app -n dev 2>/dev/null" && print_success "   ✓ Xóa deployment trong namespace dev"
    safe_run "kubectl delete deployment microservices-app -n staging 2>/dev/null" && print_success "   ✓ Xóa deployment trong namespace staging"
    safe_run "kubectl delete deployment microservices-app -n prod 2>/dev/null" && print_success "   ✓ Xóa deployment trong namespace prod"
    safe_run "kubectl delete service microservices-app-service -n dev 2>/dev/null" && print_success "   ✓ Xóa service trong namespace dev"
    safe_run "kubectl delete service microservices-app-service -n staging 2>/dev/null" && print_success "   ✓ Xóa service trong namespace staging"
    safe_run "kubectl delete service microservices-app-service -n prod 2>/dev/null" && print_success "   ✓ Xóa service trong namespace prod"
    safe_run "kubectl delete configmap app-config -n dev 2>/dev/null" && print_success "   ✓ Xóa configmap trong namespace dev"
    safe_run "kubectl delete configmap app-config -n staging 2>/dev/null" && print_success "   ✓ Xóa configmap trong namespace staging"
    safe_run "kubectl delete configmap app-config -n prod 2>/dev/null" && print_success "   ✓ Xóa configmap trong namespace prod"
else
    print_warning "   ⚠️  kubectl không được cài đặt, bỏ qua Kubernetes cleanup"
fi

# 6. Remove build artifacts and reports
print_status "6. Xóa build artifacts và reports..."
safe_run "rm -rf target/" && print_success "   ✓ Xóa Maven target directory"
safe_run "rm -rf build/" && print_success "   ✓ Xóa Gradle build directory"
safe_run "rm -rf .sonar/" && print_success "   ✓ Xóa SonarQube cache"
safe_run "rm -rf node_modules/" && print_success "   ✓ Xóa Node modules"
safe_run "rm -f trivy-*.* 2>/dev/null" && print_success "   ✓ Xóa Trivy reports"
safe_run "rm -f zap-report.json 2>/dev/null" && print_success "   ✓ Xóa ZAP reports"
safe_run "rm -f dependency-check-report.html 2>/dev/null" && print_success "   ✓ Xóa Dependency Check reports"
safe_run "rm -f jacoco.exec 2>/dev/null" && print_success "   ✓ Xóa JaCoCo reports"
safe_run "rm -rf test-results/ 2>/dev/null" && print_success "   ✓ Xóa test results"

# 7. Clean up temporary and cache files
print_status "7. Xóa temporary files và cache..."
safe_run "rm -rf /tmp/trivy-cache 2>/dev/null" && print_success "   ✓ Xóa Trivy cache"
safe_run "rm -rf ~/.m2/repository/temp-repo-* 2>/dev/null" && print_success "   ✓ Xóa Maven temp repositories"
safe_run "rm -rf ~/.gradle/caches/build-cache-* 2>/dev/null" && print_success "   ✓ Xóa Gradle build cache"

# 8. Remove Jenkins backup files (if any)
print_status "8. Xóa backup files..."
safe_run "rm -f jenkins-backup-*.tar.gz 2>/dev/null" && print_success "   ✓ Xóa Jenkins backup files"
safe_run "rm -f sonarqube-backup-*.tar.gz 2>/dev/null" && print_success "   ✓ Xóa SonarQube backup files"

# 9. Clean up Docker system
print_status "9. Dọn dẹp Docker system..."
safe_run "docker system prune -af --volumes" && print_success "   ✓ Docker system prune hoàn tất"

# 10. Remove any remaining dangling resources
print_status "10. Xóa tài nguyên còn sót lại..."
safe_run "docker container prune -f" && print_success "   ✓ Container prune hoàn tất"
safe_run "docker image prune -af" && print_success "   ✓ Image prune hoàn tất"
safe_run "docker volume prune -f" && print_success "   ✓ Volume prune hoàn tất"
safe_run "docker network prune -f" && print_success "   ✓ Network prune hoàn tất"

# 11. Optional: Remove project directory
echo ""
print_warning "Tùy chọn: Xóa toàn bộ thư mục dự án"
read -p "Bạn có muốn xóa luôn thư mục dự án aws-infra-microservices? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd ..
    safe_run "rm -rf aws-infra-microservices" && print_success "   ✓ Thư mục dự án đã được xóa"
else
    print_status "   Thư mục dự án được giữ lại"
fi

echo ""
print_header "=== CLEANUP HOÀN TẤT ==="
print_success "✅ Dự án Jenkins đã được xóa hoàn toàn!"
print_status "📊 Tóm tắt đã xóa:"
echo "   • Tất cả containers và images"
echo "   • Tất cả volumes và persistent data"
echo "   • Network configurations"
echo "   • Build artifacts và reports"
echo "   • Kubernetes deployments"
echo "   • Cache và temporary files"
echo ""
print_status "🔄 Để tạo lại môi trường mới:"
echo "   1. git clone https://github.com/your-username/aws-infra-microservices.git"
echo "   2. cd aws-infra-microservices"
echo "   3. ./jenkins/scripts/setup-jenkins.sh"
echo ""
print_warning "💡 Lưu ý: Tất cả cấu hình và data đã bị xóa vĩnh viễn"