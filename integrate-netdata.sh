#!/bin/bash

echo "=============================================="
echo "Netdata Integration for RayAI"
echo "=============================================="

NETDATA_CONTAINER="netdata-container"

# Check if netdata is running
if ! docker ps --format '{{.Names}}' | grep -q "$NETDATA_CONTAINER"; then
    echo "[!] Netdata container not running"
    echo "    Start it with: docker run -d --name netdata-container -p 19999:19999 -v /proc:/host/proc:ro -v /var/run/docker.sock:/var/run/docker.sock:ro netdata/netdata:latest"
    exit 1
fi

echo "[+] Netdata is running"

# Connect Ray containers to host network for monitoring
RAY_CONTAINERS=$(docker ps --format '{{.Names}}' | grep -E "rayai|ray-worker" || true)

if [ -z "$RAY_CONTAINERS" ]; then
    echo "[!] No Ray containers found running"
    echo "    Deploy RayAI first with: ./deploy.sh"
    exit 1
fi

echo "[+] Connecting Ray containers to host network for Netdata..."

for container in $RAY_CONTAINERS; do
    echo "    - Connecting $container..."
    docker network disconnect host $container 2>/dev/null || true
    docker network connect host $container 2>/dev/null || echo "      (already connected)"
done

echo ""
echo "[+] Waiting for Netdata to detect containers..."
sleep 5

# Test Netdata API
echo ""
echo "[+] Netdata Info:"
curl -sf http://localhost:19999/api/v1/info 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(f\"  Version: {data.get('version', 'unknown')}\")
    print(f\"  Hosts: {data.get('mirrored_hosts', [])}\")
except: print('  Could not parse Netdata info')
" 2>/dev/null || echo "  Could not fetch Netdata info"

echo ""
echo "[+] Checking Docker metrics in Netdata..."
curl -sf http://localhost:19999/api/v1/data?chart=docker.container_mem 2>/dev/null | head -c 500 || echo "  Docker charts not yet available"

echo ""
echo "=============================================="
echo " Netdata Dashboard: http://localhost:19999"
echo "=============================================="
echo ""
echo "To view Ray container metrics:"
echo "  1. Open http://localhost:19999"
echo "  2. Look for 'docker' in the menu"
echo "  3. Select your Ray containers"
echo ""
