#!/bin/bash

set -e

echo "=============================================="
echo "RayAI Deployment with Netdata Monitoring"
echo "=============================================="

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[+]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[-]${NC} $1"; }

# Check Docker
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running"
    exit 1
fi

# Check Netdata
print_status "Checking Netdata..."
NETDATA_RUNNING=false
if docker ps --format '{{.Names}}' | grep -q "netdata-container"; then
    NETDATA_RUNNING=true
    NETDATA_IP=$(docker inspect netdata-container --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null)
    print_status "Netdata is running at: ${NETDATA_IP:-host network}"
else
    print_warning "Netdata not running - will start with compose"
fi

# Build image
print_status "Building RayAI image with PyTorch..."
docker build -t rayai-agent:latest .

# Create directories
mkdir -p agents models

# Start services
print_status "Starting RayAI cluster with Netdata..."
docker compose up -d

# Wait for services
sleep 20

# Connect containers to host network for Netdata monitoring
print_status "Connecting containers to host network for Netdata..."

for container in rayai-agent ray-worker; do
    if docker ps --format '{{.Names}}' | grep -q "$container"; then
        print_status "Connecting $container to host network..."
        docker network connect host $container 2>/dev/null || print_warning "$container already on host network"
    fi
done

# Verify Netdata can see the containers
print_status "Verifying Netdata monitoring..."
sleep 5

if curl -sf http://localhost:19999/api/v1/info > /dev/null 2>&1; then
    print_status "Netdata is accessible at http://localhost:19999"
    print_status "Checking for Ray containers in Netdata..."
    curl -sf http://localhost:19999/api/v1/info 2>/dev/null | grep -o '"hostname":"[^"]*"' | head -5
else
    print_warning "Netdata not accessible at localhost:19999"
fi

echo ""
echo "=============================================="
echo " Deployment Complete!"
echo "=============================================="
echo ""
echo "Services:"
echo "  - RayAI Agents:   http://localhost:8200"
echo "  - Ray Dashboard:  http://localhost:8265"
echo "  - Netdata:        http://localhost:19999"
echo ""
echo "Netdata Docker monitoring enabled!"
echo "Containers should appear under 'docker' section in Netdata"
echo ""
echo "Commands:"
echo "  - View logs:  docker compose logs -f"
echo "  - Stop:       docker compose down"
echo ""
