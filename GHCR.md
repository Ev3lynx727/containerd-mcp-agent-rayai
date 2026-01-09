# GitHub Container Registry (GHCR) Setup

This project uses GHCR for hosting RayAI container images.

## Images

| Image | Registry | Description |
|-------|----------|-------------|
| ray-head | `ghcr.io/ev3lynx727/containerd-mcp-agent-rayai/ray-head:latest` | Ray head node with PyTorch |
| ray-worker | `ghcr.io/ev3lynx727/containerd-mcp-agent-rayai/ray-worker:latest` | Ray worker nodes |

## Pulling Images

```bash
# Login to GHCR
echo $GHCR_TOKEN | docker login ghcr.io -u $GITHUB_USER --password-stdin

# Pull ray-head
docker pull ghcr.io/ev3lynx727/containerd-mcp-agent-rayai/ray-head:latest

# Pull ray-worker
docker pull ghcr.io/ev3lynx727/containerd-mcp-agent-rayai/ray-worker:latest
```

## GitHub Actions

The CI/CD pipeline automatically builds and pushes images on:

- Push to `main` branch
- Push to `feature/*` branches
- Pull requests to `main`
- Manual workflow dispatch

### Workflow: `.github/workflows/docker-publish.yml`

1. **Build ray-head** - Builds and pushes to `ghcr.io/.../ray-head:latest`
2. **Build ray-worker** - Builds and pushes to `ghcr.io/.../ray-worker:latest`
3. **Update compose** - Updates `docker-compose.yml` with latest image tags

### Required Secrets

Configure these in GitHub repository settings:

| Secret | Description |
|--------|-------------|
| `GHCR_TOKEN` | GitHub Personal Access Token with `read:packages`, `write:packages` scopes |

### Creating GHCR Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token with scopes:
   - `read:packages`
   - `write:packages`
   - `delete:packages` (optional)
3. Copy the token
4. Add to repository secrets: Settings → Secrets and variables → Actions → New repository secret
5. Name: `GHCR_TOKEN`, Value: [paste token]

## Image Tags

Images are tagged with:

- `latest` - Latest commit on main branch
- `sha-[short_sha]` - Specific commit SHA
- `branch-[branch_name]` - Feature branches

## Updating Images

```bash
# Pull latest images
docker compose pull

# Or specify version
docker pull ghcr.io/ev3lynx727/containerd-mcp-agent-rayai/ray-head:sha-abc1234

# Restart with new images
docker compose down
docker compose up -d
```

## Local Development

For local builds (bypassing GHCR):

```bash
# Build locally
docker build -t rayai-agent:latest .

# Update compose to use local image
# (temporarily change image: to build: in docker-compose.yml)
```
