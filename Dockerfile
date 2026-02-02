# Stage 1: Builder
FROM node:22-bookworm as builder

# Install Bun (required for build)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

# Enable corepack for pnpm
RUN corepack enable

WORKDIR /app

# Clone and build OpenClaw
ARG OPENCLAW_VERSION=main
RUN git clone --depth 1 --branch ${OPENCLAW_VERSION} https://github.com/openclaw/openclaw.git .

# Install dependencies
RUN pnpm install --frozen-lockfile

# Build
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build
# Force pnpm for UI build
RUN npm_config_script_shell=bash pnpm ui:install
RUN npm_config_script_shell=bash pnpm ui:build

# Prune development dependencies
RUN CI=true pnpm prune --prod
RUN rm -rf .git

# Stage 2: Runtime
FROM node:22-slim

LABEL org.opencontainers.image.source="https://github.com/phioranex/openclaw-docker"
LABEL org.opencontainers.image.description="Pre-built OpenClaw Docker image"
LABEL org.opencontainers.image.licenses="MIT"

# Install system dependencies
# build-essential, procps, file are required for Homebrew
RUN apt-get update && apt-get install -y \
    git \
    curl \
    ca-certificates \
    unzip \
    build-essential \
    procps \
    file \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy built application from builder stage
COPY --from=builder /app /app

# Create app user and setup directories
RUN mkdir -p /home/node/.openclaw /home/node/.openclaw/workspace \
    && mkdir -p /home/linuxbrew/.linuxbrew \
    && chown -R node:node /home/node /app /home/linuxbrew

USER node

# Install Homebrew
RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"

ENV NODE_ENV=production
ENV PATH="/app/node_modules/.bin:${PATH}"

# Default command
ENTRYPOINT ["node", "/app/dist/index.js"]
CMD ["--help"]
