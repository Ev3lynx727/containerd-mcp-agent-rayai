# RayAI Agent Container Setup

This project provides a containerized setup for running RayAI agents using the official Ray Docker image. It includes automated deployment scripts and Ray dashboard integration for observability.

## Features

- **RayAI Framework**: Built on RayAI (rayai-labs/agentic-ray) for scalable AI agent execution
- **Ray Dashboard**: Integrated Ray observability dashboard for monitoring cluster metrics and tasks
- **Automated Deployment**: One-command deployment with volume and network setup
- **Docker-based**: Easy deployment using Docker containers

## Ports

- **8200**: RayAI agent services (HTTP API)
- **8265**: Ray dashboard (observability interface)

## Prerequisites

- Docker installed and running
- Internet connection for pulling base images

## Quick Start

1. **Clone or setup this directory** with the provided files:
   - `Dockerfile`
   - `deploy.sh`
   - `start-ray-agent.sh`

2. **Run the deployment script**:
   ```bash
   ./deploy.sh
   ```

   This will:
   - Pull the Ray nightly-extra image
   - Build the custom RayAI image
   - Create Docker volume (`rayai-data`) for data persistence
   - Create Docker network (`rayai-net`) for container networking
   - Start the container with RayAI agents and dashboard

3. **Access the services**:
   - RayAI agents: http://localhost:8200
   - Ray dashboard: http://localhost:8265

## Files Overview

- **`Dockerfile`**: Defines the container image extending `rayproject/ray:nightly-extra`
- **`deploy.sh`**: Automated deployment script for pulling, building, and running the container
- **`start-ray-agent.sh`**: Container startup script that initializes Ray cluster with dashboard and starts RayAI services

## Customization

### Adding Custom Agents

To add your own RayAI agents:

1. Create an `agents/` directory in this project
2. Add your agent files following RayAI structure (see RayAI docs)
3. Rebuild and redeploy:
   ```bash
   ./deploy.sh
   ```

### Modifying Ports

Edit the following files to change ports:
- `start-ray-agent.sh`: Change `--port 8200` for RayAI
- `Dockerfile`: Update EXPOSE directive
- `deploy.sh`: Update port mapping

### Ray Dashboard Configuration

The dashboard is configured in `start-ray-agent.sh` with:
```bash
ray start --head --dashboard-host 0.0.0.0 --port 8265
```

Modify as needed for your requirements.

## Troubleshooting

### Container Won't Start
Check Docker logs:
```bash
docker logs rayai-container
```

### Port Conflicts
Ensure ports 8200 and 8265 are available, or modify the configuration.

### RayAI Initialization Issues
The container will automatically initialize a new RayAI project if no `agents/` directory exists.

## References

- [Ray Documentation](https://docs.ray.io/)
- [Ray Observability Dashboard](https://docs.ray.io/en/latest/ray-observability/getting-started.html)
- [RayAI Framework](https://rayai.com/)
- [RayAI GitHub](https://github.com/rayai-labs/agentic-ray)
- [Ray Docker Images](https://hub.docker.com/r/rayproject/ray)

## License

This setup uses the Apache 2.0 licensed components from Ray and RayAI.