#!/bin/bash

# Start Ray head with dashboard in background
echo "Starting Ray head node with dashboard..."
ray start --head --dashboard-host 0.0.0.0 --port 8265 &
RAY_PID=$!

# Wait for Ray to initialize
sleep 5

# Check if agents directory exists
if [ ! -d "agents" ]; then
  echo "No agents directory found. Initializing new RayAI project..."
  rayai init .
fi

echo "Starting RayAI services..."
rayai up --port 8200

# Keep container running
wait $RAY_PID