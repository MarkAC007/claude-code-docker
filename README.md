# Claude Code Docker

A Docker image for running [Claude Code](https://docs.anthropic.com/en/docs/claude-code) in a containerised environment with compliance and security tooling. Supports both interactive and headless (server) modes.

## What's Included

**Core Runtime:** Ubuntu 24.04, Node.js 20, Bun, Python 3 + UV, Go, Claude Code CLI

**Cloud CLIs:** AWS CLI v2, Azure CLI, Google Cloud CLI (gcloud)

**Security Tools:** trufflehog (secret scanning), trivy (vulnerability scanning), checkov (IaC security)

**Browser Automation:** Playwright + Chromium, Google Chrome (AMD64)

**Dev Tools:** GitHub CLI, Pandoc, Git, jq, openssh-client

**Multi-arch:** ARM64 (Apple Silicon) and AMD64 (Intel/cloud)

## Quick Start

```bash
# Clone the repo
git clone https://github.com/your-org/claude-code-docker.git
cd claude-code-docker

# Configure
cp .env.example .env
# Edit .env and set your ANTHROPIC_API_KEY

# Build
docker compose build

# Run interactively
docker compose run --rm claude-code
```

## Modes

### Interactive (default)

Launches directly into a Claude Code session:

```bash
docker compose run --rm claude-code
```

### Server Mode

Long-running background container. Send commands via `docker exec`:

```bash
# Start server
docker compose --profile server up -d

# Interactive session
docker exec -it claude-code-server claude

# Headless command
docker exec claude-code-server claude -p "analyse this codebase for security issues"

# Fully autonomous
docker exec claude-code-server claude -p "run trivy scan" --dangerously-skip-permissions

# Stop
docker compose --profile server down
```

## Authentication

### API Key (recommended for headless)

Set `ANTHROPIC_API_KEY` in your `.env` file or pass it directly:

```bash
ANTHROPIC_API_KEY=sk-ant-xxx docker compose run --rm claude-code
```

### OAuth (interactive)

Run `claude` interactively to complete OAuth flow. Credentials persist in the `claude-config` volume across container restarts.

## Volumes

| Volume | Container Path | Purpose |
|--------|---------------|---------|
| `claude-config` | `/data/claude-config` | Persistent Claude Code config, credentials, settings, MCP configs, history |
| `projects` | `/projects` | Working directory for repositories |

### Mounting Host Directories

```yaml
# In docker-compose.yml, replace the named volume:
volumes:
  - ~/projects:/projects                        # All projects
  - ~/my-repo:/projects/my-repo                 # Single repo
  - ~/.aws:/root/.aws:ro                        # AWS credentials
  - ~/.azure:/root/.azure:ro                    # Azure credentials
  - ~/.config/gcloud:/root/.config/gcloud:ro    # GCP credentials
```

## Custom Configuration

Mount files to `/config/` (read-only) to auto-load them on startup:

| File | Destination | Purpose |
|------|------------|---------|
| `/config/CLAUDE.md` | `/projects/CLAUDE.md` | Project instructions for Claude Code |
| `/config/settings.json` | `~/.claude/.claude/settings.json` | Claude Code settings |
| `/config/mcp.json` | `~/.claude/.mcp.json` | MCP server configuration |

```yaml
volumes:
  - ./config:/config:ro
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `ANTHROPIC_API_KEY` | Yes | Anthropic API key |
| `GITHUB_TOKEN` | No | GitHub PAT for gh CLI |
| `GIT_USER_NAME` | No | Git commit identity |
| `GIT_USER_EMAIL` | No | Git commit identity |
| `CLAUDE_CODE_MODEL` | No | Model override |
| `AWS_ACCESS_KEY_ID` | No | AWS credentials |
| `AWS_SECRET_ACCESS_KEY` | No | AWS credentials |
| `AWS_DEFAULT_REGION` | No | AWS region |

## Resource Limits

Default: 12GB memory limit, 4GB reservation. Adjust in `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      memory: 16G
    reservations:
      memory: 8G
```

## License

MIT
