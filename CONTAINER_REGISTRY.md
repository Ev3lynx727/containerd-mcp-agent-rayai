# Container Registry Setup

This project uses Docker Hub for hosting RayAI container images.

## Images

| Image | Registry | Description |
|-------|----------|-------------|
| ray-head | `docker.io/ev3lynx727/containerd-mcp-agent-rayai/ray-head:latest` | Ray head node with PyTorch |
| ray-worker | `docker.io/ev3lynx727/containerd-mcp-agent-rayai/ray-worker:latest` | Ray worker nodes |

## Pulling Images

```bash
# Login to Docker Hub (optional for public images)
echo $DOCKERHUB_TOKEN | docker login -u $DOCKERHUB_USER --password-stdin

# Pull ray-head
docker pull docker.io/ev3lynx727/containerd-mcp-agent-rayai/ray-head:latest

# Pull ray-worker
docker pull docker.io/ev3lynx727/containerd-mcp-agent-rayai/ray-worker:latest
```

## GitHub Actions

The CI/CD pipeline automatically builds and pushes images on:

- Push to `main` branch
- Push to `feature/*` branches
- Pull requests to `main`
- Manual workflow dispatch

### Workflow: `.github/workflows/docker-publish.yml`

1. **Build ray-head** - Builds and pushes to `docker.io/.../ray-head:latest`
2. **Build ray-worker** - Builds and pushes to `docker.io/.../ray-worker:latest`
3. **Update compose** - Updates `docker-compose.yml` with latest image tags

### Optional Secrets

For private images, configure:

| Secret | Description |
|--------|-------------|
| `DOCKERHUB_TOKEN` | Docker Hub access token (or use GitHub token) |

For public images (default), no secrets required - uses GitHub token automatically.

## Image Tags

Images are tagged with:

- `latest` - Latest commit on main branch
- `sha-[short_sha]` - Specific commit SHA

## Updating Images

```bash
# Pull latest images
docker compose pull

# Or specify version
docker pull docker.io/ev3lynx727/containerd-mcp-agent-rayai/ray-head:latest

# Restart with new images
docker compose down
docker compose up -d
```

## Local Development

For local builds (bypassing Docker Hub):

```bash
# Build locally
docker build -t rayai-agent:latest .

# Use docker-compose override
docker compose -f docker-compose.yml -f docker-compose.override.yml up -d
```

### Local Override File

```yaml
# docker-compose.override.yml
services:
  ray-head:
    build: .
    image: rayai-agent:latest

  ray-worker:
    build: .
    image: rayai-worker:latest
```
