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

# Parse arguments
BUILD_LOCAL=false
for arg in "$@"; do
    case $arg in
        --local)
            BUILD_LOCAL=true
            shift
            ;;
        --pull)
            BUILD_LOCAL=false
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--local|--pull]"
            echo "  --local  Build images locally (default)"
            echo "  --pull   Pull images from GHCR"
            exit 0
            ;;
    esac
done

# Check Docker
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running"
    exit 1
fi

# Check Netdata
print_status "Checking Netdata..."
if docker ps --format '{{.Names}}' | grep -q "netdata-container"; then
    print_status "Netdata is running on host network"
else
    print_warning "Netdata not running - will start with compose"
fi

# Build or pull images
if [ "$BUILD_LOCAL" = true ]; then
    print_status "Building RayAI images locally..."
    docker build --network=host -t rayai-agent:latest .
    docker build --network=host -t rayai-worker:latest .

    print_status "Updating compose to use local images..."
    COMPOSE_FILE="docker-compose.yml"
else
    print_status "Pulling images from GHCR..."

    # Login to GHCR if token is available
    if [ -n "$GHCR_TOKEN" ]; then
        echo "$GHCR_TOKEN" | docker login ghcr.io -u "${GITHUB_USER:-$(git config user.name)}" --password-stdin
    elif [ -n "$GITHUB_TOKEN" ]; then
        echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_ACTOR" --password-stdin
    else
        print_warning "No GHCR_TOKEN found - attempting anonymous pull"
    fi

    # Pull images
    docker pull ghcr.io/ev3lynx727/containerd-mcp-agent-rayai/ray-head:latest || print_warning "Failed to pull ray-head"
    docker pull ghcr.io/ev3lynx727/containerd-mcp-agent-rayai/ray-worker:latest || print_warning "Failed to pull ray-worker"

    COMPOSE_FILE="docker-compose.override.yml"
fi

# Create directories
mkdir -p agents models

# Start services
print_status "Starting RayAI cluster with Netdata..."
docker compose -f docker-compose.yml up -d

# Wait for services
sleep 20

# Connect containers to host network for Netdata monitoring
print_status "Connecting containers to host network for Netdata..."

for container in rayai-agent ray-worker; do
    if docker ps --format '{{.Names}}' | grep -q "$container"; then
        print_status "Connecting $container to host network..."
        docker network disconnect host $container 2>/dev/null || true
        docker network connect host $container 2>/dev/null || print_warning "Could not connect $container"
    fi
done

# Verify Netdata can see the containers
print_status "Verifying Netdata monitoring..."
sleep 5

if curl -sf http://localhost:19999/api/v1/info > /dev/null 2>&1; then
    print_status "Netdata is accessible at http://localhost:19999"
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
echo "Image mode: $([ "$BUILD_LOCAL" = true ] && echo "Local build" || echo "GHCR pull")"
echo ""
echo "Commands:"
echo "  - View logs:  docker compose logs -f"
echo "  - Stop:       docker compose down"
echo ""
