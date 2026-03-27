# ============================================
# Claude Code Docker
# Compliance & security focused Claude Code deployment
# Multi-arch: ARM64 (Apple Silicon) + AMD64
# ============================================

FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Multi-arch support
ARG TARGETARCH

# ============================================
# System Dependencies
# ============================================
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    unzip \
    ca-certificates \
    gnupg \
    build-essential \
    libsecret-1-0 \
    libsecret-1-dev \
    jq \
    openssh-client \
    lsb-release \
    apt-transport-https \
    software-properties-common \
    # Browser dependencies (Playwright/Puppeteer)
    fonts-liberation \
    libasound2t64 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    xdg-utils \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# Google Chrome (AMD64) / Playwright Chromium (ARM64)
# Note: Ubuntu 24.04 chromium-browser is a snap stub that doesn't work in Docker
# ============================================
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
        apt-get update && \
        apt-get install -y --fix-missing ./google-chrome-stable_current_amd64.deb && \
        rm google-chrome-stable_current_amd64.deb && \
        rm -rf /var/lib/apt/lists/* && \
        ln -sf /usr/bin/google-chrome-stable /usr/bin/chromium-browser; \
    else \
        echo "ARM64: Chromium will be installed via Playwright"; \
    fi

# ============================================
# Bun (JavaScript/TypeScript runtime)
# ============================================
RUN curl -fsSL https://bun.sh/install | bash
ENV BUN_INSTALL="/root/.bun"
ENV PATH="$BUN_INSTALL/bin:$PATH"

# ============================================
# Node.js 20
# ============================================
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# ============================================
# Claude Code CLI
# ============================================
RUN npm install -g @anthropic-ai/claude-code

# ============================================
# Python 3 + UV (for MCP servers and security tools)
# ============================================
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 python3-pip python3-venv && \
    rm -rf /var/lib/apt/lists/*
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# ============================================
# Go (needed for security tools like trufflehog)
# ============================================
RUN if [ "$TARGETARCH" = "arm64" ]; then \
        wget -q https://go.dev/dl/go1.23.4.linux-arm64.tar.gz && \
        tar -C /usr/local -xzf go1.23.4.linux-arm64.tar.gz && \
        rm go1.23.4.linux-arm64.tar.gz; \
    else \
        wget -q https://go.dev/dl/go1.23.4.linux-amd64.tar.gz && \
        tar -C /usr/local -xzf go1.23.4.linux-amd64.tar.gz && \
        rm go1.23.4.linux-amd64.tar.gz; \
    fi
ENV PATH="/usr/local/go/bin:/root/go/bin:$PATH"
ENV GOPATH="/root/go"

# ============================================
# GitHub CLI
# ============================================
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && \
    apt-get install -y --no-install-recommends gh && \
    rm -rf /var/lib/apt/lists/*

# ============================================
# AWS CLI v2
# ============================================
RUN if [ "$TARGETARCH" = "arm64" ]; then \
        curl -s "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"; \
    else \
        curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"; \
    fi && \
    unzip -q awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

# ============================================
# Azure CLI
# ============================================
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# ============================================
# Google Cloud CLI
# ============================================
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.asc] https://packages.cloud.google.com/apt cloud-sdk main" \
        | tee /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg \
        | tee /usr/share/keyrings/cloud.google.asc && \
    apt-get update && \
    apt-get install -y --no-install-recommends google-cloud-cli && \
    rm -rf /var/lib/apt/lists/*

# ============================================
# Security & Compliance Tools
# ============================================

# trufflehog - secret scanning
RUN curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh -s -- -b /usr/local/bin

# trivy - vulnerability scanner
RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# checkov - IaC security scanner (isolated via uv)
RUN uv tool install checkov

# ============================================
# Pandoc (document format conversion)
# ============================================
RUN if [ "$TARGETARCH" = "arm64" ]; then \
        wget -q https://github.com/jgm/pandoc/releases/download/3.1.12/pandoc-3.1.12-linux-arm64.tar.gz && \
        tar xzf pandoc-3.1.12-linux-arm64.tar.gz --strip-components 1 -C /usr/local && \
        rm pandoc-3.1.12-linux-arm64.tar.gz; \
    else \
        wget -q https://github.com/jgm/pandoc/releases/download/3.1.12/pandoc-3.1.12-linux-amd64.tar.gz && \
        tar xzf pandoc-3.1.12-linux-amd64.tar.gz --strip-components 1 -C /usr/local && \
        rm pandoc-3.1.12-linux-amd64.tar.gz; \
    fi

# ============================================
# Playwright + Chromium (browser automation)
# ============================================
RUN npx playwright install chromium --with-deps

# Browser path configuration
RUN CHROME_PATH="" && \
    if [ -f /usr/bin/google-chrome-stable ]; then \
        CHROME_PATH="/usr/bin/google-chrome-stable"; \
    else \
        CHROME_PATH=$(find /root/.cache/ms-playwright -name "chrome" -type f 2>/dev/null | head -1); \
    fi && \
    mkdir -p /etc/profile.d && \
    echo "export PUPPETEER_EXECUTABLE_PATH=$CHROME_PATH" > /etc/profile.d/browser.sh && \
    echo "export CHROME_BIN=$CHROME_PATH" >> /etc/profile.d/browser.sh && \
    chmod +x /etc/profile.d/browser.sh
RUN echo 'source /etc/profile.d/browser.sh 2>/dev/null || true' >> /root/.bashrc

# ============================================
# Working Directory + Persistent Storage Dirs
# ============================================
WORKDIR /projects

RUN mkdir -p /root/.claude \
    && mkdir -p /projects \
    && mkdir -p /root/.aws \
    && mkdir -p /root/.azure \
    && mkdir -p /root/.config/gcloud \
    && mkdir -p /data/claude-config \
    && mkdir -p /config

# ============================================
# Environment Configuration
# ============================================
ENV HOME=/root
ENV SHELL=/bin/bash
ENV NODE_OPTIONS="--max-old-space-size=4096"
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

# Ensure /bin/sh is bash (fixes hook spawn errors)
RUN ln -sf /bin/bash /bin/sh || true

# ============================================
# Entrypoint
# ============================================
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["claude"]
