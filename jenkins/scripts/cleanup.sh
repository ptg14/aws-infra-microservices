#!/bin/bash

echo "=== Cleaning up Jenkins CI/CD Environment ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

read -p "Are you sure you want to stop and remove all containers and volumes? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Cleanup cancelled."
    exit 1
fi

print_status "Stopping and removing containers..."
docker-compose down

print_status "Removing volumes..."
docker-compose down -v

print_status "Removing unused Docker images..."
docker image prune -a -f

print_status "Cleanup completed!"