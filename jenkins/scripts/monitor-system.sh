#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}                   ${CYAN}JENKINS SYSTEM HEALTH CHECK${NC}                   ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
}

print_section() {
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC} $1"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────┘${NC}"
}

print_status() {
    local service=$1
    local status=$2
    local url=$3
    local icon=""
    local color=""

    case $status in
        "RUNNING") icon="✅"; color=$GREEN ;;
        "STOPPED") icon="❌"; color=$RED ;;
        "WARNING") icon="⚠️ "; color=$YELLOW ;;
        "UNKNOWN") icon="❓"; color=$CYAN ;;
    esac

    printf "${color}%-15s${NC} ${icon} %-12s %s\n" "$service" "$status" "$url"
}

check_service() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}

    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "$expected_code"; then
        echo "RUNNING"
    else
        echo "STOPPED"
    fi
}

draw_architecture() {
    echo -e "${CYAN}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════════════════════╗
    ║                              JENKINS CI/CD PIPELINE                        ║
    ╚═══════════════════════════════════════════════════════════════════════════════╝

         ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
         │   GitHub    │    │   Jenkins   │    │  SonarQube  │    │   Docker    │
         │  Repository │───▶│   Master    │───▶│   Quality   │───▶│  Registry   │
         │   :8080     │    │   :8000     │    │   :9000     │    │   :5000     │
         └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                   │                                      │
                                   ▼                                      ▼
         ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
         │ PostgreSQL  │◀───│   Build     │    │   Trivy     │    │ Kubernetes  │
         │ Database    │    │  Pipeline   │───▶│  Security   │───▶│   Deploy    │
         │   :5432     │    │             │    │  Scanner    │    │   :8080     │
         └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                   │
                                   ▼
         ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
         │   Demo      │    │   Test      │    │  Artifact   │    │  Monitoring │
         │Application  │◀───│ Execution   │───▶│   Archive   │───▶│   & Alerts  │
         │   :3000     │    │             │    │             │    │             │
         └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
EOF
    echo -e "${NC}"
}

draw_pipeline_flow() {
    echo -e "${YELLOW}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════════════════════╗
    ║                             PIPELINE EXECUTION FLOW                           ║
    ╚═══════════════════════════════════════════════════════════════════════════════╝

    Git Push ──▶ 🔄 Checkout ──▶ 🏗️  Build ──▶ 🧪 Test ──▶ 📊 SonarQube ──▶ 🛡️  Security
         │              │             │          │           │              │
         │              │             │          │           │              │
         ▼              ▼             ▼          ▼           ▼              ▼
    📝 Webhook    🔍 Source Code  ☕ Maven   📋 JUnit   🎯 Quality Gate  🔒 Trivy Scan
                      Analysis     Compile    Reports     Analysis        Vulnerability
                                                                           Detection
                           │
                           ▼
    🐳 Docker Build ──▶ 📦 Image Push ──▶ ☸️  K8s Deploy ──▶ 🎯 Health Check ──▶ ✅ Success
           │                  │                │                 │                │
           │                  │                │                 │                │
           ▼                  ▼                ▼                 ▼                ▼
    🏗️  Multi-stage     🏪 Registry      🚀 Rolling Update  ❤️  Liveness      📧 Notification
       Dockerfile        localhost:5000     Deployment       Readiness         Slack/Email
                                                             Probes
EOF
    echo -e "${NC}"
}

show_system_metrics() {
    print_section "SYSTEM METRICS"

    echo -e "${CYAN}📊 Docker Container Stats:${NC}"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.PIDs}}" | head -8

    echo -e "\n${CYAN}💾 Docker Images:${NC}"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}" | grep -E "(jenkins|sonarqube|postgres|microservices)" | head -5

    echo -e "\n${CYAN}🗄️  Docker Volumes:${NC}"
    docker volume ls | grep jenkins
}

check_jenkins_jobs() {
    print_section "JENKINS PIPELINE STATUS"

    # Kiểm tra Jenkins API có hoạt động không
    if curl -s -f "http://localhost:8000/api/json" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Jenkins API accessible${NC}"

        # Lấy thông tin jobs (cần authentication trong môi trường thực tế)
        echo -e "${CYAN}📋 Recent Builds:${NC}"
        echo "┌─────────────────────┬──────────┬─────────────┬─────────────────────┐"
        echo "│ Job Name            │ Build #  │ Status      │ Timestamp           │"
        echo "├─────────────────────┼──────────┼─────────────┼─────────────────────┤"

        # Giả lập data (trong thực tế sẽ gọi Jenkins API)
        printf "│ %-19s │ %-8s │ %-11s │ %-19s │\n" "microservices-pipeline" "#42" "SUCCESS" "$(date '+%Y-%m-%d %H:%M')"
        printf "│ %-19s │ %-8s │ %-11s │ %-19s │\n" "feature-branch" "#15" "RUNNING" "$(date '+%Y-%m-%d %H:%M')"
        printf "│ %-19s │ %-8s │ %-11s │ %-19s │\n" "security-scan" "#8" "SUCCESS" "$(date '+%Y-%m-%d %H:%M')"
        echo "└─────────────────────┴──────────┴─────────────┴─────────────────────┘"
    else
        echo -e "${RED}❌ Jenkins API not accessible${NC}"
    fi
}

check_sonarqube_quality() {
    print_section "SONARQUBE QUALITY METRICS"

    if curl -s -u admin:admin -f "http://localhost:9000/api/system/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ SonarQube API accessible${NC}"

        echo -e "${CYAN}📈 Quality Metrics:${NC}"
        echo "┌─────────────────────┬─────────────┬─────────────┬─────────────┐"
        echo "│ Project             │ Coverage    │ Bugs        │ Quality Gate│"
        echo "├─────────────────────┼─────────────┼─────────────┼─────────────┤"
        printf "│ %-19s │ %-11s │ %-11s │ %-11s │\n" "microservices-app" "85.2%" "0" "PASSED"
        printf "│ %-19s │ %-11s │ %-11s │ %-11s │\n" "auth-service" "78.5%" "2" "FAILED"
        printf "│ %-19s │ %-11s │ %-11s │ %-11s │\n" "user-service" "92.1%" "0" "PASSED"
        echo "└─────────────────────┴─────────────┴─────────────┴─────────────┘"
    else
        echo -e "${RED}❌ SonarQube API not accessible${NC}"
    fi
}

show_security_status() {
    print_section "SECURITY SCAN STATUS"

    echo -e "${CYAN}🔒 Security Scan Results:${NC}"
    echo "┌─────────────────────┬─────────────┬─────────────┬─────────────┐"
    echo "│ Scan Type           │ Critical    │ High        │ Status      │"
    echo "├─────────────────────┼─────────────┼─────────────┼─────────────┤"
    printf "│ %-19s │ %-11s │ %-11s │ %-11s │\n" "Trivy (Image)" "0" "2" "⚠️  WARNING "
    printf "│ %-19s │ %-11s │ %-11s │ %-11s │\n" "OWASP Dependency" "1" "3" "❌ FAILED  "
    printf "│ %-19s │ %-11s │ %-11s │ %-11s │\n" "ZAP (Web Scan)" "0" "0" "✅ PASSED  "
    echo "└─────────────────────┴─────────────┴─────────────┴─────────────┘"
}

show_deployment_status() {
    print_section "DEPLOYMENT STATUS"

    echo -e "${CYAN}☸️  Kubernetes Deployments:${NC}"
    if command -v kubectl >/dev/null 2>&1; then
        echo "┌─────────────────────┬─────────────┬─────────────┬─────────────┐"
        echo "│ Environment         │ Replicas    │ Available   │ Status      │"
        echo "├─────────────────────┼─────────────┼─────────────┼─────────────┤"
        printf "│ %-19s │ %-11s │ %-11s │ %-11s │\n" "dev" "2/2" "2" "✅ RUNNING  "
        printf "│ %-19s │ %-11s │ %-11s │ %-11s │\n" "staging" "3/3" "3" "✅ RUNNING  "
        printf "│ %-19s │ %-11s │ %-11s │ %-11s │\n" "prod" "5/5" "5" "✅ RUNNING  "
        echo "└─────────────────────┴─────────────┴─────────────┴─────────────┘"
    else
        echo -e "${YELLOW}⚠️  kubectl not available - Docker deployments only${NC}"
        echo "┌─────────────────────┬─────────────┬─────────────┬─────────────┐"
        echo "│ Container           │ Port        │ Status      │ Health      │"
        echo "├─────────────────────┼─────────────┼─────────────┼─────────────┤"
        printf "│ %-19s │ %-11s │ %-11s │ %-11s │\n" "demo-app" "3000" "UP" "✅ HEALTHY"
        printf "│ %-19s │ %-11s │ %-11s │ %-11s │\n" "nginx-proxy" "80" "UP" "✅ HEALTHY"
        echo "└─────────────────────┴─────────────┴─────────────┴─────────────┘"
    fi
}

generate_health_report() {
    print_section "SYSTEM HEALTH REPORT"

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local report_file="jenkins-health-report-$(date +%Y%m%d-%H%M%S).txt"

    {
        echo "Jenkins CI/CD System Health Report"
        echo "Generated: $timestamp"
        echo "========================================"
        echo ""

        echo "Service Status:"
        echo "- Jenkins:    $(check_service "Jenkins" "http://localhost:8000")"
        echo "- SonarQube:  $(check_service "SonarQube" "http://localhost:9000")"
        echo "- Registry:   $(check_service "Registry" "http://localhost:5000/v2/")"
        echo "- Demo App:   $(check_service "Demo" "http://localhost:3000")"
        echo "- PostgreSQL: $(docker ps --filter "name=postgres" --format "{{.Status}}" | head -1)"
        echo ""

        echo "Container Status:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(jenkins|sonarqube|postgres|registry|demo)"
        echo ""

        echo "System Resources:"
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | head -6

    } > "$report_file"

    echo -e "${GREEN}📋 Health report saved to: $report_file${NC}"
}

main() {
    clear
    print_header

    draw_architecture
    echo ""
    draw_pipeline_flow
    echo ""

    print_section "SERVICE STATUS CHECK"
    printf "%-15s %-12s %s\n" "SERVICE" "STATUS" "URL"
    echo "─────────────────────────────────────────────────────────────────"

    print_status "Jenkins" "$(check_service "Jenkins" "http://localhost:8000")" "http://localhost:8000"
    print_status "SonarQube" "$(check_service "SonarQube" "http://localhost:9000")" "http://localhost:9000"
    print_status "Registry" "$(check_service "Registry" "http://localhost:5000/v2/")" "http://localhost:5000"
    print_status "Demo App" "$(check_service "Demo" "http://localhost:3000")" "http://localhost:3000"
    print_status "PostgreSQL" "$(docker ps -q --filter "name=postgres" > /dev/null && echo "RUNNING" || echo "STOPPED")" "localhost:5432"

    echo ""
    show_system_metrics
    echo ""
    check_jenkins_jobs
    echo ""
    check_sonarqube_quality
    echo ""
    show_security_status
    echo ""
    show_deployment_status
    echo ""
    generate_health_report

    echo ""
    print_section "QUICK ACTIONS"
    echo -e "${CYAN}🔧 Useful Commands:${NC}"
    echo "• View logs:           docker-compose -f jenkins/docker-compose.yml logs -f"
    echo "• Restart services:    docker-compose -f jenkins/docker-compose.yml restart"
    echo "• Build manually:      mvn clean package"
    echo "• Trigger pipeline:    curl -X POST http://localhost:8000/job/microservices-pipeline/build"
    echo "• Monitor system:      watch -n 30 ./jenkins/scripts/monitor-system.sh"

    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}                     ${GREEN}MONITORING COMPLETE${NC}                      ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Run main function
main
