# SolClaw Agent Container
# Runs Claude Agent SDK in isolated Linux VM with browser automation

# Stage 1: Node.js 22 binaries (Debian-based, no apt needed here)
FROM node:22-slim AS node-base

# Stage 2: Ubuntu 20.04 runtime (archive.ubuntu.com is accessible)
FROM ubuntu:20.04

# Copy Node.js 22 binaries and modules from node-base
COPY --from=node-base /usr/local/bin/node /usr/local/bin/node
COPY --from=node-base /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
 && chmod +x /usr/local/bin/npm /usr/local/bin/npx

# Create node user to match the official node image
RUN groupadd --gid 1000 node \
 && useradd --uid 1000 --gid node --shell /bin/bash --create-home node

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/UTC /etc/localtime && echo UTC > /etc/timezone

# Install system dependencies for Chromium
RUN apt-get update && apt-get install -y -q --no-install-recommends \
    chromium-browser \
    fonts-liberation \
    fonts-noto-color-emoji \
    libgbm1 \
    libnss3 \
    libatk-bridge2.0-0 \
    libgtk-3-0 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libasound2 \
    libpangocairo-1.0-0 \
    libcups2 \
    libdrm2 \
    libxshmfence1 \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set Chromium path for agent-browser (Ubuntu uses chromium-browser)
ENV AGENT_BROWSER_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Disable strict SSL for npm (environment uses SSL inspection proxy)
RUN npm config set strict-ssl false

# Install agent-browser, claude-code, and tsx globally (before NODE_OPTIONS is set)
RUN npm install -g agent-browser @anthropic-ai/claude-code tsx

# Create app directory
WORKDIR /app

# Copy package files first for better caching
COPY agent-runner/package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY agent-runner/ ./

# Copy Solana transaction auto-logging preload script
COPY solana-tx-preload.cjs /app/solana-tx-preload.cjs

# Build TypeScript
RUN npm run build

# Symlink global tsx into local node_modules so the entrypoint can resolve it from /app/
RUN ln -s $(npm root -g)/tsx node_modules/tsx

# ESM interop for all node processes (safe, no tsx dependency)
ENV NODE_OPTIONS="--experimental-require-module --require /app/solana-tx-preload.cjs"

# Create workspace and IPC directories
RUN mkdir -p /workspace/group /workspace/global /workspace/extra /data/ipc/messages /data/ipc/tasks /data/ipc/input /data/ipc/transactions

# Backward-compat symlink: legacy scripts may still reference /workspace/ipc
RUN ln -sf /data/ipc /workspace/ipc

# Create entrypoint script
# Secrets are passed via stdin JSON — temp file is deleted immediately after Node reads it
# Follow-up messages arrive via IPC files in /data/ipc/input/
RUN printf '#!/bin/bash\nset -e\ncd /app && npx tsc --outDir /tmp/dist 2>&1 >&2\nln -s /app/node_modules /tmp/dist/node_modules\nchmod -R a-w /tmp/dist\ncat > /tmp/input.json\nnode --import tsx /tmp/dist/index.js < /tmp/input.json\n' > /app/entrypoint.sh && chmod +x /app/entrypoint.sh

# Set ownership to node user (non-root) for writable directories
RUN chown -R node:node /workspace /data && chmod 777 /home/node

# Switch to non-root user (required for --dangerously-skip-permissions)
USER node

# Set working directory to group workspace
WORKDIR /workspace/group

# Entry point reads JSON from stdin, outputs JSON to stdout
ENTRYPOINT ["/app/entrypoint.sh"]
