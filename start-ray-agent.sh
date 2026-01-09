#!/bin/bash

set -e

echo "=============================================="
echo "Starting RayAI Agent with PyTorch"
echo "=============================================="

# Set environment variables
export RAY_DEDUP_LOGS=0
export RAY_NUM_CPUS=${RAY_NUM_CPUS:-4}
export RAY_MEMORY=${RAY_MEMORY:-2147483648}

# Print environment info
echo "Ray CPUs: $RAY_NUM_CPUS"
echo "Ray Memory: $RAY_MEMORY"
echo "Python version: $(python --version)"

# Check for GPU
if command -v nvidia-smi > /dev/null 2>&1; then
    echo "NVIDIA GPUs available:"
    nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv
    export CUDA_VISIBLE_DEVICES=0
else
    echo "No NVIDIA GPUs detected - running on CPU"
fi

# Start Ray head with dashboard
echo "Starting Ray head node with dashboard..."
ray start --head \
    --dashboard-host 0.0.0.0 \
    --port 8265 \
    --num-cpus $RAY_NUM_CPUS \
    --memory $RAY_MEMORY \
    --dashboard-agent-listen-port 52671 \
    &

RAY_PID=$!
echo "Ray head started with PID: $RAY_PID"

# Wait for Ray to initialize
echo "Waiting for Ray to initialize..."
sleep 10

# Check Ray status
for i in {1..30}; do
    if ray health-check --address=localhost:8265 > /dev/null 2>&1; then
        echo "Ray is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Ray failed to start properly"
        exit 1
    fi
    echo "Waiting for Ray... ($i/30)"
    sleep 2
done

# Check if agents directory exists
if [ ! -d "/app/agents" ] || [ -z "$(ls -A /app/agents 2>/dev/null)" ]; then
    echo "No agents found in /app/agents. Creating sample agent..."
    mkdir -p /app/agents
    cat > /app/agents/sample_agent.py << 'EOF'
"""
Sample PyTorch-based RayAI Agent
"""
import ray
from ray import serve
from typing import Dict, List
import torch
import torch.nn as nn
from transformers import AutoModel, AutoTokenizer

@ray.remote
class PyTorchAgent:
    def __init__(self):
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        print(f"Agent initialized on device: {self.device}")
        
        # Load a pre-trained model
        self.tokenizer = AutoTokenizer.from_pretrained("sentence-transformers/all-MiniLM-L6-v2")
        self.model = AutoModel.from_pretrained("sentence-transformers/all-MiniLM-L6-v2")
        self.model.to(self.device)
        self.model.eval()
    
    def predict(self, text: str) -> Dict:
        """Process text input using PyTorch transformer model"""
        inputs = self.tokenizer(text, return_tensors="pt", padding=True, truncation=True, max_length=512)
        inputs = {k: v.to(self.device) for k, v in inputs.items()}
        
        with torch.no_grad():
            outputs = self.model(**inputs)
            embeddings = outputs.last_hidden_state.mean(dim=1)
        
        return {
            "input": text,
            "embedding": embeddings.cpu().numpy().tolist()[0],
            "device": str(self.device),
            "model": "all-MiniLM-L6-v2"
        }
    
    def get_stats(self) -> Dict:
        """Return agent statistics"""
        return {
            "device": str(self.device),
            "cuda_available": torch.cuda.is_available(),
            "model_name": "all-MiniLM-L6-v2"
        }

@serve.deployment(route_prefix="/api")
class RayAIService:
    def __init__(self):
        self.agent = PyTorchAgent.remote()
    
    async def __call__(self, request):
        import json
        data = await request.json()
        text = data.get("text", "")
        
        result = await self.agent.predict.remote(text)
        return json.dumps(result)

# Register and start the service
print("Starting RayAI service...")
serve.start(detached=True)

# Deploy the service
RayAIService.deploy()

print(f"RayAI service deployed successfully!")
print(f"API available at: http://0.0.0.0:8200/api")

# Keep container running
echo "RayAI is running. Press Ctrl+C to stop."
trap "ray stop" EXIT
wait $RAY_PID
EOF
    echo "Sample agent created at /app/agents/sample_agent.py"
fi

# Start RayAI service if rayai is available
if command -v rayai > /dev/null 2>&1; then
    echo "Starting RayAI services..."
    rayai up --port 8200 &
else
    echo "rayai command not found, using custom start script..."
    
    # Start FastAPI server with our PyTorch agent
    cat > /app/agent_server.py << 'EOF'
"""
PyTorch Agent Server using FastAPI and Ray Serve
"""
import os
import ray
from ray import serve
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional
import torch
from transformers import AutoModel, AutoTokenizer
import time

# Initialize Ray
ray.init(address="auto", namespace="rayai")

app = FastAPI(title="RayAI PyTorch Agent")

@ray.remote(num_gpus=0.25 if torch.cuda.is_available() else 0, num_cpus=1)
class PyTorchAgent:
    def __init__(self):
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        print(f"Agent starting on device: {self.device}")
        
        self.tokenizer = AutoTokenizer.from_pretrained("sentence-transformers/all-MiniLM-L6-v2")
        self.model = AutoModel.from_pretrained("sentence-transformers/all-MiniLM-L6-v2")
        self.model.to(self.device)
        self.model.eval()
        
        self.start_time = time.time()
    
    def process(self, text: str) -> dict:
        inputs = self.tokenizer(text, return_tensors="pt", padding=True, truncation=True, max_length=512)
        inputs = {k: v.to(self.device) for k, v in inputs.items()}
        
        with torch.no_grad():
            outputs = self.model(**inputs)
            embeddings = outputs.last_hidden_state.mean(dim=1)
        
        return {
            "input": text,
            "embedding": embeddings.cpu().numpy().tolist()[0],
            "device": str(self.device),
            "model": "all-MiniLM-L6-v2",
            "uptime": time.time() - self.start_time
        }
    
    def health_check(self) -> dict:
        return {
            "status": "healthy",
            "device": str(self.device),
            "cuda_available": torch.cuda.is_available()
        }

# Create actor
agent = PyTorchAgent.remote()

class PredictRequest(BaseModel):
    text: str

class PredictResponse(BaseModel):
    result: dict

@app.post("/predict", response_model=PredictResponse)
async def predict(request: PredictRequest):
    try:
        result = await agent.process.remote(request.text)
        return PredictResponse(result=result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health():
    health_info = await agent.health_check.remote()
    return health_info

@app.get("/stats")
async def stats():
    return {
        "actor": "PyTorchAgent",
        "ray_version": ray.__version__,
        "torch_version": torch.__version__,
        "available_devices": torch.cuda.device_count() if torch.cuda.is_available() else 0
    }

# Run with uvicorn
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8200)
EOF

    # Start the server
    cd /app
    python agent_server.py &
    SERVER_PID=$!
    echo "Agent server started with PID: $SERVER_PID"
fi

# Wait for all processes
echo "All services started. Keeping container running..."
wait
