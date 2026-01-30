#!/bin/bash
#
# OpenClaw (Clawbot) Docker Installer
# One-command setup for OpenClaw on Docker
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/phioranex/clawbot-docker/main/install.sh)
#
# Or with options:
#   bash <(curl -fsSL https://raw.githubusercontent.com/phioranex/clawbot-docker/main/install.sh) --no-start
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Config
INSTALL_DIR="${OPENCLAW_INSTALL_DIR:-$HOME/openclaw}"
IMAGE="ghcr.io/phioranex/clawbot-docker:latest"
REPO_URL="https://github.com/phioranex/clawbot-docker"
COMPOSE_URL="https://raw.githubusercontent.com/phioranex/clawbot-docker/main/docker-compose.yml"

# Detect if we have a TTY (for Docker interactive mode)
if [ -t 0 ]; then
    DOCKER_TTY_FLAG=""
else
    DOCKER_TTY_FLAG="-T"
fi

# Flags
NO_START=false
SKIP_ONBOARD=false
PULL_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-start)
            NO_START=true
            shift
            ;;
        --skip-onboard)
            SKIP_ONBOARD=true
            shift
            ;;
        --pull-only)
            PULL_ONLY=true
            shift
            ;;
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --help|-h)
            echo "OpenClaw (Clawbot) Docker Installer"
            echo ""
            echo "Usage: install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --install-dir DIR   Installation directory (default: ~/openclaw)"
            echo "  --no-start          Don't start the gateway after setup"
            echo "  --skip-onboard      Skip onboarding wizard"
            echo "  --pull-only         Only pull the image, don't set up"
            echo "  --help, -h          Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Functions
print_banner() {
    echo -e "${RED}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║    ____                    _____ _                           ║"
    echo "║   / __ \\\\                  / ____| |                          ║"
    echo "║  | |  | |_ __   ___ _ __ | |    | | __ ___      __           ║"
    echo "║  | |  | | '_ \\\\ / _ \\\\ '_ \\\\| |    | |/ _\\\` \\\\ \\\\ /\\\\ / /           ║"
    echo "║  | |__| | |_) |  __/ | | | |____| | (_| |\\\\ V  V /            ║"
    echo "║   \\\\____/| .__/ \\\\___|_| |_|\\\\_____|_|\\\\__,_| \\\\_/\\\\_/             ║"
    echo "║         | |                                                  ║"
    echo "║         |_|                                                  ║"
    echo "║                                                              ║"
    echo "║              Docker Installer by Phioranex                   ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_step() {
    echo -e "\n${BLUE}▶${NC} ${BOLD}$1${NC}"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

check_command() {
    if command -v "$1" &> /dev/null; then
        log_success "$1 found"
        return 0
    else
        log_error "$1 not found"
        return 1
    fi
}

# Main script
print_banner

log_step "Checking prerequisites..."

# Check Docker
if ! check_command docker; then
    echo -e "\n${RED}Docker is required but not installed.${NC}"
    echo "Install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check Docker Compose
if docker compose version &> /dev/null; then
    log_success "Docker Compose found (plugin)"
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    log_success "Docker Compose found (standalone)"
    COMPOSE_CMD="docker-compose"
else
    log_error "Docker Compose not found"
    echo -e "\n${RED}Docker Compose is required but not installed.${NC}"
    echo "Install Docker Compose: https://docs.docker.com/compose/install/"
    exit 1
fi

# Check Docker is running
if ! docker info &> /dev/null; then
    log_error "Docker is not running"
    echo -e "\n${RED}Please start Docker and try again.${NC}"
    exit 1
fi
log_success "Docker is running"

# Pull only mode
if [ "$PULL_ONLY" = true ]; then
    log_step "Pulling OpenClaw image..."
    docker pull "$IMAGE"
    log_success "Image pulled successfully!"
    echo -e "\n${GREEN}Done!${NC} Run the installer again without --pull-only to complete setup."
    exit 0
fi

log_step "Setting up installation directory..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
log_success "Created $INSTALL_DIR"

log_step "Downloading docker-compose.yml..."
curl -fsSL "$COMPOSE_URL" -o docker-compose.yml
log_success "Downloaded docker-compose.yml"

log_step "Creating data directories..."
mkdir -p ~/.openclaw
mkdir -p ~/.openclaw/workspace
log_success "Created ~/.openclaw (config)"
log_success "Created ~/.openclaw/workspace (workspace)"

log_step "Pulling OpenClaw image..."
docker pull "$IMAGE"
log_success "Image pulled successfully!"

# Onboarding
if [ "$SKIP_ONBOARD" = false ]; then
    log_step "Initializing OpenClaw configuration..."
    echo -e "${YELLOW}Setting up configuration and workspace...${NC}\n"
    
    log_step "Running onboarding wizard..."
    echo -e "${YELLOW}This will configure your AI provider and channels.${NC}"
    echo -e "${YELLOW}Follow the prompts to complete setup.${NC}\n"
    
    # Run onboarding interactively (works with bash process substitution)
    if ! $COMPOSE_CMD run --rm openclaw-cli onboard; then
        log_warning "Onboarding was cancelled or failed"
        echo -e "${YELLOW}You can run it later with:${NC} cd $INSTALL_DIR && $COMPOSE_CMD run --rm openclaw-cli onboard"
    else
        log_success "Onboarding complete!"
    fi
fi

# Start gateway
if [ "$NO_START" = false ]; then
    log_step "Starting OpenClaw gateway..."
    $COMPOSE_CMD up -d openclaw-gateway
    
    # Wait for gateway to be ready
    echo -n "Waiting for gateway to start"
    for i in {1..30}; do
        if curl -s http://localhost:18789/health &> /dev/null; then
            echo ""
            log_success "Gateway is running!"
            break
        fi
        echo -n "."
        sleep 1
    done
    
    if ! curl -s http://localhost:18789/health &> /dev/null; then
        echo ""
        log_warning "Gateway may still be starting. Check logs with: docker logs openclaw-gateway"
    fi
fi

# Success message
echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║              🎉 OpenClaw installed successfully! 🎉           ║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${BOLD}Quick reference:${NC}"
echo -e "  ${CYAN}Dashboard:${NC}      http://localhost:18789"
echo -e "  ${CYAN}Config:${NC}         ~/.openclaw/"
echo -e "  ${CYAN}Workspace:${NC}      ~/.openclaw/workspace/"
echo -e "  ${CYAN}Install dir:${NC}    $INSTALL_DIR"

echo -e "\n${BOLD}Useful commands:${NC}"
echo -e "  ${CYAN}View logs:${NC}      docker logs -f openclaw-gateway"
echo -e "  ${CYAN}Stop:${NC}           cd $INSTALL_DIR && $COMPOSE_CMD down"
echo -e "  ${CYAN}Start:${NC}          cd $INSTALL_DIR && $COMPOSE_CMD up -d openclaw-gateway"
echo -e "  ${CYAN}Restart:${NC}        cd $INSTALL_DIR && $COMPOSE_CMD restart openclaw-gateway"
echo -e "  ${CYAN}CLI:${NC}            cd $INSTALL_DIR && $COMPOSE_CMD run --rm openclaw-cli <command>"
echo -e "  ${CYAN}Update:${NC}         docker pull $IMAGE && cd $INSTALL_DIR && $COMPOSE_CMD up -d"

echo -e "\n${BOLD}Documentation:${NC}  https://docs.openclaw.ai"
echo -e "${BOLD}Support:${NC}        https://discord.gg/clawd"
echo -e "${BOLD}Docker image:${NC}   $REPO_URL"

echo -e "\n${YELLOW}Happy automating! 🤖🦞${NC}\n"
