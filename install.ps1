#
# OpenClaw Docker Installer - Windows PowerShell Version
# One-command setup for OpenClaw on Docker for Windows
#
# Usage:
#   irm https://raw.githubusercontent.com/phioranex/openclaw-docker/main/install.ps1 | iex
#
# Or with options:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/phioranex/openclaw-docker/main/install.ps1))) -NoStart
#

param(
    [string]$InstallDir = "$env:USERPROFILE\openclaw",
    [switch]$NoStart,
    [switch]$SkipOnboard,
    [switch]$PullOnly,
    [switch]$Help
)

# Config
$Image = "ghcr.io/phioranex/openclaw-docker:latest"
$RepoUrl = "https://github.com/phioranex/openclaw-docker"
$ComposeUrl = "https://raw.githubusercontent.com/phioranex/openclaw-docker/main/docker-compose.yml"

# Error handling
$ErrorActionPreference = "Stop"

# Functions
function Write-Banner {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║                                                              ║" -ForegroundColor Red
    Write-Host "║    ____                    _____ _                           ║" -ForegroundColor Red
    Write-Host "║   / __ \                  / ____| |                          ║" -ForegroundColor Red
    Write-Host "║  | |  | |_ __   ___ _ __ | |    | | __ ___      __           ║" -ForegroundColor Red
    Write-Host "║  | |  | | '_ \ / _ \ '_ \| |    | |/ _`` \ \ /\ / /           ║" -ForegroundColor Red
    Write-Host "║  | |__| | |_) |  __/ | | | |____| | (_| |\ V  V /            ║" -ForegroundColor Red
    Write-Host "║   \____/| .__/ \___|_| |_|\_____|_|\__,_| \_/\_/             ║" -ForegroundColor Red
    Write-Host "║         | |                                                  ║" -ForegroundColor Red
    Write-Host "║         |_|                                                  ║" -ForegroundColor Red
    Write-Host "║                                                              ║" -ForegroundColor Red
    Write-Host "║              Docker Installer by Phioranex                   ║" -ForegroundColor Red
    Write-Host "║                                                              ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "▶ $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Show help
if ($Help) {
    Write-Host "OpenClaw Docker Installer - Windows"
    Write-Host ""
    Write-Host "Usage: install.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -InstallDir DIR   Installation directory (default: ~\openclaw)"
    Write-Host "  -NoStart          Don't start the gateway after setup"
    Write-Host "  -SkipOnboard      Skip onboarding wizard"
    Write-Host "  -PullOnly         Only pull the image, don't set up"
    Write-Host "  -Help             Show this help message"
    return
}

# Main script
Write-Banner

Write-Step "Checking prerequisites..."

# Check Docker
if (Test-Command docker) {
    Write-Success "docker found"
} else {
    Write-Error "docker not found"
    Write-Host ""
    Write-Host "Docker is required but not installed." -ForegroundColor Red
    Write-Host "Install Docker Desktop: https://docs.docker.com/desktop/install/windows-install/" -ForegroundColor Yellow
    return
}

# Check Docker Compose
$ComposeCmd = ""
$ComposeExe = ""
$ComposeBaseArgs = @()

if (docker compose version 2>$null) {
    Write-Success "Docker Compose found (plugin)"
    $ComposeCmd = "docker compose"
    $ComposeExe = "docker"
    $ComposeBaseArgs = @("compose")
} elseif (Test-Command docker-compose) {
    Write-Success "Docker Compose found (standalone)"
    $ComposeCmd = "docker-compose"
    $ComposeExe = "docker-compose"
    $ComposeBaseArgs = @()
} else {
    Write-Error "Docker Compose not found"
    Write-Host ""
    Write-Host "Docker Compose is required but not installed." -ForegroundColor Red
    Write-Host "It usually comes with Docker Desktop." -ForegroundColor Yellow
    exit 1
}

# Check Docker is running
try {
    docker info 2>$null | Out-Null
    Write-Success "Docker is running"
} catch {
    Write-Error "Docker is not running"
    Write-Host ""
    Write-Host "Please start Docker Desktop and try again." -ForegroundColor Red
    exit 1
}

# Pull only mode
if ($PullOnly) {
    Write-Step "Pulling OpenClaw image..."
    docker pull $Image
    Write-Success "Image pulled successfully!"
    Write-Host ""
    Write-Host "Done! Run the installer again without -PullOnly to complete setup." -ForegroundColor Green
    exit 0
}

Write-Step "Setting up installation directory..."
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

if (Test-Path ".\docker-compose.yml") {
    Write-Step "Copying local docker-compose.yml..."
    Copy-Item ".\docker-compose.yml" -Destination "$InstallDir\docker-compose.yml" -Force
    if (Test-Path ".\Dockerfile") {
         Copy-Item ".\Dockerfile" -Destination "$InstallDir\Dockerfile" -Force
         Write-Success "Copying local Dockerfile"
    }
    Write-Success "Used local docker-compose.yml"
    $UseLocalBuild = $true
} else {
    Write-Step "Checking installation directory..."
    Set-Location $InstallDir
    Write-Success "Created $InstallDir"
    
    Write-Step "Downloading docker-compose.yml..."
    Invoke-WebRequest -Uri $ComposeUrl -OutFile "docker-compose.yml"
    Write-Success "Downloaded docker-compose.yml"
    $UseLocalBuild = $false
}

Set-Location $InstallDir

Write-Step "Creating data directories..."
$ConfigDir = "$env:USERPROFILE\.openclaw"
$WorkspaceDir = "$env:USERPROFILE\.openclaw\workspace"
New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
New-Item -ItemType Directory -Force -Path $WorkspaceDir | Out-Null
Write-Success "Created $ConfigDir (config)"
Write-Success "Created $WorkspaceDir (workspace)"

if (-not $UseLocalBuild) {
    Write-Step "Pulling OpenClaw image..."
    docker pull $Image
    Write-Success "Image pulled successfully!"
} else {
    Write-Step "Building local images..."
    & $ComposeExe $ComposeBaseArgs build
    Write-Success "Images built successfully!"
}

# Onboarding
if (-not $SkipOnboard) {
    Write-Step "Initializing OpenClaw configuration..."
    Write-Host "Setting up configuration and workspace..." -ForegroundColor Yellow
    Write-Host ""
    
    Write-Step "Running onboarding wizard..."
    Write-Host "This will configure your AI provider and channels." -ForegroundColor Yellow
    Write-Host "Follow the prompts to complete setup." -ForegroundColor Yellow
    Write-Host ""
    
    # Run onboarding
    & $ComposeExe $ComposeBaseArgs run --rm openclaw-cli onboard
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Onboarding wizard was skipped or failed"
        Write-Host "You can run it later with: cd $InstallDir && $ComposeCmd run --rm openclaw-cli onboard" -ForegroundColor Yellow
    } else {
        Write-Success "Onboarding complete!"
    }
}

# Start gateway
if (-not $NoStart) {
    Write-Step "Starting OpenClaw gateway..."
    & $ComposeExe $ComposeBaseArgs up -d openclaw-gateway
    
    # Wait for gateway to be ready
    Write-Host "Waiting for gateway to start" -NoNewline
    for ($i = 0; $i -lt 30; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:18789/health" -TimeoutSec 1 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-Host ""
                Write-Success "Gateway is running!"
                break
            }
        } catch {
            # Continue waiting
        }
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 1
    }
    
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:18789/health" -TimeoutSec 1 -ErrorAction SilentlyContinue
        if ($response.StatusCode -ne 200) {
            throw
        }
    } catch {
        Write-Host ""
        Write-Warning "Gateway may still be starting. Check logs with: docker logs openclaw-gateway"
    }
}

# Success message
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                              ║" -ForegroundColor Green
Write-Host "║              🎉 OpenClaw installed successfully! 🎉           ║" -ForegroundColor Green
Write-Host "║                                                              ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host ""
Write-Host "Quick reference:" -ForegroundColor White
Write-Host "  Dashboard:      http://localhost:18789" -ForegroundColor Cyan
Write-Host "  Config:         $ConfigDir" -ForegroundColor Cyan
Write-Host "  Workspace:      $WorkspaceDir" -ForegroundColor Cyan
Write-Host "  Install dir:    $InstallDir" -ForegroundColor Cyan

Write-Host ""
Write-Host "Useful commands:" -ForegroundColor White
Write-Host "  View logs:      docker logs -f openclaw-gateway" -ForegroundColor Cyan
Write-Host "  Stop:           cd $InstallDir && $ComposeCmd down" -ForegroundColor Cyan
Write-Host "  Start:          cd $InstallDir && $ComposeCmd up -d openclaw-gateway" -ForegroundColor Cyan
Write-Host "  Restart:        cd $InstallDir && $ComposeCmd restart openclaw-gateway" -ForegroundColor Cyan
Write-Host "  CLI:            cd $InstallDir && $ComposeCmd run --rm openclaw-cli <command>" -ForegroundColor Cyan
Write-Host "  Update:         docker pull $Image && cd $InstallDir && $ComposeCmd up -d" -ForegroundColor Cyan

Write-Host ""
Write-Host "Documentation:  https://docs.openclaw.ai" -ForegroundColor White
Write-Host "Support:        https://discord.gg/clawd" -ForegroundColor White
Write-Host "Docker image:   $RepoUrl" -ForegroundColor White

Write-Host ""
Write-Host "Happy automating! 🤖🦞" -ForegroundColor Yellow
Write-Host ""
