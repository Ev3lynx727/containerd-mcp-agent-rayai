#!/bin/bash

echo "Pulling Ray image..."
docker pull rayproject/ray:nightly-extra

echo "Building RayAI image..."
docker build -t rayai-agent .

echo "Creating volume..."
docker volume create rayai-data

echo "Creating network..."
docker network create rayai-net

echo "Running container..."
docker run -d --name rayai-container --volume rayai-data:/app/data --network rayai-net -p 8200:8200 -p 8265:8265 rayai-agent

echo "Deployment complete."
echo "RayAI agent running at http://localhost:8200"
echo "Ray dashboard available at http://localhost:8265"