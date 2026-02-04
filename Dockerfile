FROM node:22-bookworm

LABEL org.opencontainers.image.source="https://github.com/phioranex/clawbot-docker"
LABEL org.opencontainers.image.description="Pre-built OpenClaw (Clawbot) Docker image"
LABEL org.opencontainers.image.licenses="MIT"

# Install system dependencies (including Homebrew prerequisites)
RUN apt-get update && apt-get install -y \
    git \
    curl \
    ca-certificates \
    unzip \
    build-essential \
    procps \
    file \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install Bun (required for build)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

# Install Homebrew (required for first-party skills)
# Create linuxbrew user and install Homebrew as that user
RUN useradd -m -s /bin/bash linuxbrew && \
    echo 'linuxbrew ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    mkdir -p /home/linuxbrew/.linuxbrew && \
    chown -R linuxbrew:linuxbrew /home/linuxbrew/.linuxbrew
# Download and install Homebrew manually
RUN mkdir -p /home/linuxbrew/.linuxbrew/Homebrew && \
    git clone --depth 1 https://github.com/Homebrew/brew /home/linuxbrew/.linuxbrew/Homebrew && \
    chown -R linuxbrew:linuxbrew /home/linuxbrew/.linuxbrew && \
    ln -s /home/linuxbrew/.linuxbrew/Homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew || true && \
    mkdir -p /home/linuxbrew/.linuxbrew/bin && \
    ln -s /home/linuxbrew/.linuxbrew/Homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
ENV HOMEBREW_NO_AUTO_UPDATE=1
ENV HOMEBREW_NO_INSTALL_CLEANUP=1

# Enable corepack for pnpm
RUN corepack enable

WORKDIR /app

# Clone and build OpenClaw - always fetch latest from main branch
ARG OPENCLAW_VERSION=main
RUN git clone --depth 1 --branch ${OPENCLAW_VERSION} https://github.com/openclaw/openclaw.git . && \
    echo "Building OpenClaw from branch: ${OPENCLAW_VERSION}" && \
    git rev-parse HEAD > /app/openclaw-commit.txt

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
    && chown -R node:node /home/node /app \
    && chmod -R 755 /home/node/.openclaw \
    && chown -R node:node /home/linuxbrew/.linuxbrew 2>/dev/null || true

USER node

WORKDIR /home/node

ENV NODE_ENV=production
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/app/node_modules/.bin:${PATH}"
ENV HOMEBREW_NO_AUTO_UPDATE=1
ENV HOMEBREW_NO_INSTALL_CLEANUP=1

# Default command
ENTRYPOINT ["node", "/app/dist/index.js"]
CMD ["--help"]
