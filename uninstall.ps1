#
# OpenClaw (Clawbot) Docker Uninstaller - Windows PowerShell Version
# Removes OpenClaw containers, data, and configuration
#

param(
    [string]$InstallDir = "$env:USERPROFILE\openclaw",
    [string]$ConfigDir = "$env:USERPROFILE\.openclaw",
    [switch]$RemoveImage,
    [switch]$Force
)

# Config
$Image = "ghcr.io/phioranex/openclaw-docker:latest"
$ErrorActionPreference = "Stop"

# Functions
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

# Banner
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║                                                              ║" -ForegroundColor Red
Write-Host "║           OpenClaw Uninstaller                               ║" -ForegroundColor Red
Write-Host "║                                                              ║" -ForegroundColor Red
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Red

if (-not $Force) {
    Write-Warning "This will remove:"
    Write-Host "  - Containers and volumes"
    Write-Host "  - Installation directory: $InstallDir"
    Write-Host "  - Configuration directory: $ConfigDir"
    if ($RemoveImage) {
        Write-Host "  - Docker image: $Image"
    }
    
    $confirm = Read-Host "Are you sure? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "Aborted."
        exit
    }
}

# Determine Docker Compose command
$ComposeCmd = ""
$ComposeExe = ""
$ComposeBaseArgs = @()

if (docker compose version 2>$null) {
    $ComposeCmd = "docker compose"
    $ComposeExe = "docker"
    $ComposeBaseArgs = @("compose")
} elseif (Test-Command docker-compose) {
    $ComposeCmd = "docker-compose"
    $ComposeExe = "docker-compose"
    $ComposeBaseArgs = @()
}

# Stop and remove containers
if (Test-Path "$InstallDir\docker-compose.yml") {
    Write-Step "Stopping and removing containers..."
    Push-Location $InstallDir
    try {
        if ($ComposeExe) {
            & $ComposeExe $ComposeBaseArgs down -v
            Write-Success "Containers and volumes removed"
        } else {
            Write-Warning "Docker Compose not found, skipping container removal"
        }
    } catch {
        Write-Warning "Failed to stop containers: $_"
    } finally {
        Pop-Location
    }
} else {
    Write-Warning "docker-compose.yml not found in $InstallDir, skipping 'docker compose down'"
}

# Remove directories
Write-Step "Removing directories..."

if (Test-Path $InstallDir) {
    Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Success "Removed $InstallDir"
} else {
    Write-Host "  $InstallDir not found" -ForegroundColor DarkGray
}

if (Test-Path $ConfigDir) {
    Remove-Item -Path $ConfigDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Success "Removed $ConfigDir"
} else {
    Write-Host "  $ConfigDir not found" -ForegroundColor DarkGray
}

# Remove Docker image
if ($RemoveImage) {
    Write-Step "Removing Docker image..."
    try {
        docker rmi $Image
        Write-Success "Removed image $Image"
    } catch {
        Write-Warning "Failed to remove image (it might be in use or already removed)"
    }
} else {
    Write-Host ""
    Write-Host "Note: Docker image was kept. Use -RemoveImage to delete it." -ForegroundColor Gray
}

Write-Host ""
Write-Success "Uninstallation complete!"
Write-Host ""
