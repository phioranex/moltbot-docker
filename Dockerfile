FROM node:22-bookworm

LABEL org.opencontainers.image.source="https://github.com/phioranex/clawbot-docker"
LABEL org.opencontainers.image.description="Pre-built OpenClaw (Clawbot) Docker image"
LABEL org.opencontainers.image.licenses="MIT"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    ca-certificates \
    unzip \
    && rm -rf /var/lib/apt/lists/*

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
# Force pnpm for UI build (Bun may fail on ARM/Synology architectures)
RUN npm_config_script_shell=bash pnpm ui:install
RUN npm_config_script_shell=bash pnpm ui:build

# Clean up build artifacts to reduce image size
RUN rm -rf .git node_modules/.cache

# Create app user (node already exists in base image)
RUN mkdir -p /home/node/.openclaw /home/node/.openclaw/workspace \
    && chown -R node:node /home/node /app

USER node

WORKDIR /home/node

ENV NODE_ENV=production
ENV PATH="/app/node_modules/.bin:${PATH}"

# Default command
ENTRYPOINT ["node", "/app/dist/index.js"]
CMD ["--help"]
