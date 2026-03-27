#!/bin/bash
set -e

echo "============================================"
echo "  Claude Code Docker"
echo "  Compliance & Security Tooling"
echo "============================================"
echo ""

# ============================================
# Persistent Claude Code home
# Symlink ~/.claude -> /data/claude-config
# ============================================
if [ -d /data/claude-config ]; then
    if [ -e /root/.claude ] || [ -L /root/.claude ]; then
        rm -rf /root/.claude
    fi
    ln -s /data/claude-config /root/.claude
    echo "[ok] Claude home: ~/.claude -> /data/claude-config (persistent)"
else
    mkdir -p /root/.claude
    echo "[info] No persistent volume at /data/claude-config"
    echo "       Using ephemeral ~/.claude (data lost on container restart)"
fi

# ============================================
# Custom configuration overrides
# Mount files to /config/ to auto-load them
# ============================================
if [ -f /config/CLAUDE.md ]; then
    cp /config/CLAUDE.md /projects/CLAUDE.md 2>/dev/null || true
    echo "[ok] Custom CLAUDE.md loaded from /config/"
fi

if [ -f /config/settings.json ]; then
    mkdir -p /root/.claude/.claude
    cp /config/settings.json /root/.claude/.claude/settings.json 2>/dev/null || true
    echo "[ok] Custom settings.json loaded from /config/"
fi

if [ -f /config/mcp.json ]; then
    cp /config/mcp.json /root/.claude/.mcp.json 2>/dev/null || true
    echo "[ok] Custom MCP config loaded from /config/"
fi

# ============================================
# Authentication
# ============================================
echo ""
echo "--- Authentication ---"
if [ -n "$ANTHROPIC_API_KEY" ]; then
    echo "[ok] ANTHROPIC_API_KEY is set"
elif [ -f /root/.claude/.credentials.json ]; then
    echo "[ok] OAuth credentials found (persisted)"
else
    echo "[warn] No authentication configured"
    echo "       Set ANTHROPIC_API_KEY or run 'claude' to authenticate via OAuth"
fi

# ============================================
# Git configuration
# ============================================
if [ -n "$GIT_USER_NAME" ]; then
    git config --global user.name "$GIT_USER_NAME"
    echo "[ok] Git user.name: $GIT_USER_NAME"
fi
if [ -n "$GIT_USER_EMAIL" ]; then
    git config --global user.email "$GIT_USER_EMAIL"
    echo "[ok] Git user.email: $GIT_USER_EMAIL"
fi
if [ -n "$GITHUB_TOKEN" ]; then
    echo "[ok] GITHUB_TOKEN is set"
fi

# ============================================
# Browser detection
# ============================================
echo ""
echo "--- Browser ---"
if [ -f /usr/bin/google-chrome-stable ]; then
    export PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome-stable
    export CHROME_BIN=/usr/bin/google-chrome-stable
    echo "[ok] Google Chrome: $(/usr/bin/google-chrome-stable --version 2>/dev/null || echo 'installed')"
else
    PLAYWRIGHT_CHROME=$(find /root/.cache/ms-playwright -name "chrome" -type f 2>/dev/null | head -1)
    if [ -n "$PLAYWRIGHT_CHROME" ]; then
        export PUPPETEER_EXECUTABLE_PATH="$PLAYWRIGHT_CHROME"
        export CHROME_BIN="$PLAYWRIGHT_CHROME"
        echo "[ok] Playwright Chromium"
    else
        echo "[warn] No browser found"
    fi
fi

# ============================================
# Cloud CLIs
# ============================================
echo ""
echo "--- Cloud CLIs ---"
echo "AWS CLI:    $(aws --version 2>/dev/null | cut -d' ' -f1 || echo 'not found')"
echo "Azure CLI:  $(az version 2>/dev/null | jq -r '.["azure-cli"]' 2>/dev/null || echo 'not found')"
echo "gcloud:     $(gcloud version 2>/dev/null | head -1 || echo 'not found')"

# ============================================
# Tool versions
# ============================================
echo ""
echo "--- Core Tools ---"
echo "Claude Code: $(claude --version 2>/dev/null || echo 'not found')"
echo "Node.js:     $(node --version 2>/dev/null)"
echo "npm:         $(npm --version 2>/dev/null)"
echo "Bun:         $(bun --version 2>/dev/null)"
echo "Python:      $(python3 --version 2>/dev/null)"
echo "UV:          $(uv --version 2>/dev/null)"
echo "Go:          $(go version 2>/dev/null | cut -d' ' -f3 || echo 'not found')"
echo "GitHub CLI:  $(gh --version 2>/dev/null | head -1 || echo 'not found')"
echo "Pandoc:      $(pandoc --version 2>/dev/null | head -1 || echo 'not found')"

echo ""
echo "--- Security Tools ---"
echo "trufflehog:  $(trufflehog --version 2>/dev/null || echo 'not found')"
echo "trivy:       $(trivy --version 2>/dev/null | head -1 || echo 'not found')"
echo "checkov:     $(checkov --version 2>/dev/null || echo 'not found')"

echo ""
echo "--- Volumes ---"
echo "Claude config: /data/claude-config"
echo "Projects:      /projects"
echo "Custom config: /config (optional, read-only)"

echo ""
echo "--- Usage ---"
echo "Interactive:  claude"
echo "Headless:     claude -p 'your prompt here'"
echo "With perms:   claude -p 'prompt' --dangerously-skip-permissions"
echo "============================================"
echo ""

# Execute CMD (default: claude for interactive, sleep infinity for server)
exec "$@"
