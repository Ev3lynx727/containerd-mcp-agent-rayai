# RayAI Orchestration Setup

## Quick Start

### 1. Build and Deploy with Docker Compose

```bash
# Deploy the entire stack
./deploy.sh

# Or manually:
docker compose up -d
```

### 2. Access Services

| Service | URL | Description |
|---------|-----|-------------|
| RayAI API | http://localhost:8200 | AI Agent HTTP API |
| Ray Dashboard | http://localhost:8265 | Cluster monitoring |
| Netdata | http://localhost:19999 | Real-time monitoring |

### 3. Stop Services

```bash
docker compose down
docker compose down -v  # Also remove volumes
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Docker Compose                        │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─────────────┐    ┌─────────────────┐                 │
│  │ ray-head    │◄──►│   ray-worker  x2 │                │
│  │ (GPU)       │    │   (GPU)          │                │
│  └─────────────┘    └─────────────────┘                 │
│        │                     │                          │
│        └──────────┬──────────┘                          │
│                   ▼                                     │
│         ┌──────────────────┐                            │
│         │  netdata-agent   │                            │
│         │  (monitoring)    │                            │
│         └──────────────────┘                            │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## PyTorch Integration

The Dockerfile includes:
- PyTorch 2.1.0 with CUDA support
- Transformers, Accelerate, PEFT
- Sentence transformers for embeddings
- vLLM for efficient inference
- LangChain integration

### Using PyTorch in Your Agents

```python
import torch
from transformers import AutoModel, AutoTokenizer

class MyAgent:
    def __init__(self):
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.model = AutoModel.from_pretrained("model_name").to(self.device)

    def predict(self, input_data):
        # Your PyTorch inference code
        pass
```

## GPU Support

For GPU acceleration, ensure NVIDIA Container Toolkit is installed:

```bash
# Ubuntu
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/libnvidia-container/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
```

## Scaling Workers

Add more workers in `docker-compose.yml`:

```yaml
services:
  ray-worker:
    # ... existing config ...
    deploy:
      replicas: 4  # Increase this
```

## Custom Agents

1. Place your agents in the `agents/` directory
2. Ensure they're importable as Python modules
3. Restart the service: `docker compose restart ray-head`

## Monitoring with Netdata

This project uses **Netdata** for real-time monitoring.

### Key Features

- Real-time metrics with sub-second resolution
- Zero-configuration Docker monitoring
- Built-in alerting
- Low resource footprint (~2% CPU)

### Accessing Metrics

1. **Dashboard**: http://localhost:19999
2. **Docker Containers**: Navigate to `docker_local.containers_state`
3. **CPU/Memory**: Use `system.cpu` and `ram.` charts
4. **GPU Metrics**: Available if NVIDIA drivers are detected

### API Access

```bash
# Get all charts
curl http://localhost:19999/api/v1/charts

# Get specific chart data
curl http://localhost:19999/api/v1/data?chart=system.cpu

# Get container metrics
curl http://localhost:19999/api/v1/data?chart=docker_local.containers_state
```

### Ray-Specific Metrics

After deployment, access Ray metrics through Netdata:

| Metric | Netdata Chart | Description |
|--------|---------------|-------------|
| CPU Usage | `system.cpu` | Per-core CPU utilization |
| Memory | `ram.` | Used/available/cached memory |
| Disk I/O | `disk.*` | Read/write operations |
| Network | `net.*` | Traffic by interface |
| Docker | `docker_local.*` | Container states & resources |

## Troubleshooting

```bash
# View logs
docker compose logs -f ray-head
docker compose logs -f ray-worker

# Check GPU usage
docker exec -it ray-head nvidia-smi

# Restart a service
docker compose restart ray-head

# Check Ray status
docker exec -it ray-head ray status

# Check Netdata status
docker logs netdata-collector

# Test Netdata API
curl http://localhost:19999/api/v1/info
```
