# =============================================================================
# OpenClaw/Clawbot Production Dockerfile
# =============================================================================
# Multi-stage build with security hardening and best practices
# Based on: https://github.com/openclaw/openclaw
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Build Stage
# -----------------------------------------------------------------------------
FROM node:22-bookworm AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

# Enable corepack for pnpm
RUN corepack enable

WORKDIR /app

# Clone OpenClaw repository
RUN git clone --depth 1 https://github.com/openclaw/openclaw.git .

# Cache dependencies unless package metadata changes
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc* ./
RUN pnpm install --frozen-lockfile || pnpm install

# Build the application
RUN pnpm build
RUN pnpm ui:install || true
RUN pnpm ui:build || true

# -----------------------------------------------------------------------------
# Stage 2: Production Runtime
# -----------------------------------------------------------------------------
FROM node:22-bookworm-slim AS runtime

# Build arguments for customization
ARG OPENCLAW_DOCKER_APT_PACKAGES=""
ARG TARGETARCH=amd64

# Labels for container metadata
LABEL org.opencontainers.image.title="OpenClaw Gateway"
LABEL org.opencontainers.image.description="AI Agent Gateway with best practices"
LABEL org.opencontainers.image.source="https://github.com/openclaw/openclaw"
LABEL org.opencontainers.image.vendor="Clawbot"
LABEL maintainer="clawbot"

# Install base system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    git \
    socat \
    jq \
    procps \
    dumb-init \
    # FFmpeg for media processing
    ffmpeg \
    # Build tools (optional, for skills that need compilation)
    build-essential \
    # Python for some skills
    python3 \
    python3-pip \
    # Additional packages from build arg
    ${OPENCLAW_DOCKER_APT_PACKAGES} \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# -----------------------------------------------------------------------------
# Install Required Binaries for Skills
# -----------------------------------------------------------------------------

# Gmail CLI (gog) - for email automation
RUN curl -L https://github.com/steipete/gog/releases/latest/download/gog_Linux_x86_64.tar.gz \
    | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/gog || true

# Google Places CLI (goplaces) - for location services
RUN curl -L https://github.com/steipete/goplaces/releases/latest/download/goplaces_Linux_x86_64.tar.gz \
    | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/goplaces || true

# WhatsApp CLI (wacli) - for WhatsApp integration
RUN curl -L https://github.com/steipete/wacli/releases/latest/download/wacli_Linux_x86_64.tar.gz \
    | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/wacli || true

# Himalaya CLI (email IMAP) - for advanced email workflows
RUN curl -L https://github.com/sostrovsky/himalaya/releases/latest/download/himalaya-linux-amd64 \
    -o /usr/local/bin/himalaya && chmod +x /usr/local/bin/himalaya || true

# -----------------------------------------------------------------------------
# User and Directory Setup
# -----------------------------------------------------------------------------

# Create non-root user for security
RUN groupadd --gid 1000 node || true \
    && useradd --uid 1000 --gid 1000 -m node || true

# Create OpenClaw directories
RUN mkdir -p /home/node/.openclaw \
    && mkdir -p /home/node/.openclaw/workspace \
    && mkdir -p /home/node/.openclaw/agents \
    && mkdir -p /home/node/.openclaw/sandboxes \
    && chown -R node:node /home/node

# Enable corepack for pnpm
RUN corepack enable

WORKDIR /app

# Copy built application from builder stage
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --from=builder --chown=node:node /app/package.json ./
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/ui ./ui

# -----------------------------------------------------------------------------
# Environment Configuration
# -----------------------------------------------------------------------------

ENV NODE_ENV=production
ENV HOME=/home/node
ENV TERM=xterm-256color
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# OpenClaw specific environment
ENV OPENCLAW_GATEWAY_PORT=18789
ENV OPENCLAW_GATEWAY_BIND=lan
ENV XDG_CONFIG_HOME=/home/node/.config

# Extend PATH for custom tools
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# -----------------------------------------------------------------------------
# Security Hardening
# -----------------------------------------------------------------------------

# Remove unnecessary packages and clean up
RUN apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/*

# Switch to non-root user
USER node

# -----------------------------------------------------------------------------
# Runtime Configuration
# -----------------------------------------------------------------------------

# Expose Gateway port
EXPOSE 18789

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${OPENCLAW_GATEWAY_PORT}/health || exit 1

# Use dumb-init for proper signal handling
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# Default command: start the gateway
CMD ["node", "dist/index.js", "gateway", "--bind", "lan", "--port", "18789"]
