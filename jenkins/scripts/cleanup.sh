#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_warning "This will stop and remove all Jenkins CI/CD containers and volumes!"
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Cleanup cancelled."
    exit 0
fi

print_status "Stopping and removing containers..."
docker-compose -f jenkins/docker-compose.yml down -v

print_status "Removing Docker images..."
docker rmi $(docker images "localhost:5000/microservices-app" -q) 2>/dev/null || true
docker rmi $(docker images "microservices-app" -q) 2>/dev/null || true

print_status "Pruning unused Docker resources..."
docker system prune -f

print_status "Removing temporary files..."
rm -rf target/ build/ .sonar/ trivy-*.* zap-report.json

print_success "Cleanup completed!"
print_status "To restart the environment, run: ./jenkins/scripts/setup-jenkins.sh"