# =============================================================================
# TrAIding Floor — one-line installer (Windows PowerShell)
# =============================================================================
# Usage (in PowerShell, NOT cmd.exe):
#
#   iwr -useb https://install.traidingfloor.com/install.ps1 | iex
#
#   # Or pin to a non-default channel:
#   & ([ScriptBlock]::Create((iwr -useb https://install.traidingfloor.com/install.ps1))) beta
#   & ([ScriptBlock]::Create((iwr -useb https://install.traidingfloor.com/install.ps1))) v1.4.2
#
# What this does:
#   1. Verifies Docker Desktop is installed and running
#   2. Creates .\traidingfloor in the current directory
#   3. Downloads docker-compose.yml + .env.example into it
#   4. Runs `docker compose pull && docker compose up -d`
#   5. Waits for the dashboard, then opens it in your default browser
#
# Safe to re-run: idempotent. Won't overwrite an existing docker-compose.yml
# or user-data/.env. Audit before piping to iex:
#
#   iwr -useb https://install.traidingfloor.com/install.ps1
#
# Source: https://github.com/traidingfloor/install
# =============================================================================

param(
    [string]$Channel = "latest"
)

$ErrorActionPreference = "Stop"

$InstallDir = if ($env:TF_INSTALL_DIR) { $env:TF_INSTALL_DIR } else { "traidingfloor" }
$BaseUrl    = "https://raw.githubusercontent.com/traidingfloor/install/main"
$ComposeUrl = "$BaseUrl/docker-compose.yml"
$EnvExUrl   = "$BaseUrl/.env.example"
$UpdateUrl  = "$BaseUrl/update.sh"

function Write-Step($msg)  { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "[ok] $msg" -ForegroundColor Green }
function Write-Warn($msg)  { Write-Host "[!]  $msg" -ForegroundColor Yellow }
function Write-Err($msg)   { Write-Host "[X]  $msg" -ForegroundColor Red }
function Write-Hint($msg)  { Write-Host "     $msg" -ForegroundColor DarkGray }

Write-Host ""
Write-Host "  ┌───────────────────────────────────────────────────────────────┐"
Write-Host "  │  TrAIding Floor — one-line installer (Windows)                │"
Write-Host "  │  Self-hosted autonomous AI trading floor (multi-venue)        │"
Write-Host "  │  Hyperliquid native + ccxt (Binance/OKX/KuCoin/Bybit/paper)   │"
Write-Host "  └───────────────────────────────────────────────────────────────┘"
Write-Host ""

# ── 1. Docker present + running? ────────────────────────────────────────────
Write-Step "Checking prerequisites"

$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Err "Docker is not installed."
    Write-Hint "Install Docker Desktop: https://www.docker.com/products/docker-desktop/"
    Write-Hint "Then re-run this command in PowerShell."
    exit 1
}
Write-Ok ("docker found ({0})" -f (docker --version))

try {
    docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "daemon unreachable" }
} catch {
    Write-Err "Docker daemon is not running."
    Write-Hint "Start Docker Desktop from the Start menu, wait for the whale icon"
    Write-Hint "in your system tray to stop animating, then re-run this command."
    exit 1
}
Write-Ok "docker daemon is reachable"

# Compose v2 detection (Docker Desktop on Windows always has v2)
try {
    docker compose version 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "v2 missing" }
    Write-Ok ("compose: {0}" -f (docker compose version --short 2>$null))
} catch {
    Write-Err "'docker compose' v2 is not available."
    Write-Hint "Update Docker Desktop to the latest version."
    exit 1
}

# ── 2. Make install directory ───────────────────────────────────────────────
Write-Step ("Creating install directory: .\{0}" -f $InstallDir)
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Set-Location $InstallDir
Write-Ok ("in {0}" -f (Get-Location).Path)

# ── 3. Download compose file ────────────────────────────────────────────────
Write-Step "Downloading docker-compose.yml"
if (Test-Path docker-compose.yml) {
    Write-Warn "docker-compose.yml already exists, leaving it in place"
    Write-Hint "Delete it and re-run if you want the latest version"
} else {
    Invoke-WebRequest -Uri $ComposeUrl -OutFile docker-compose.yml -UseBasicParsing
    $bytes = (Get-Item docker-compose.yml).Length
    Write-Ok ("saved ($bytes bytes)")
}

# ── 4. Seed user-data/.env from .env.example ────────────────────────────────
Write-Step "Setting up user-data\"
New-Item -ItemType Directory -Force -Path user-data | Out-Null
if (Test-Path user-data\.env) {
    Write-Warn "user-data\.env already exists, leaving it in place"
} else {
    Invoke-WebRequest -Uri $EnvExUrl -OutFile user-data\.env -UseBasicParsing
    $bytes = (Get-Item user-data\.env).Length
    Write-Ok ("seeded user-data\.env from .env.example ($bytes bytes)")
    Write-Hint "Edit user-data\.env to enable optional integrations (LLM, Telegram, Dune)."
}

# ── 5. Drop update.sh helper next to compose ────────────────────────────────
if (-not (Test-Path update.sh)) {
    Invoke-WebRequest -Uri $UpdateUrl -OutFile update.sh -UseBasicParsing
    Write-Ok "installed update.sh helper (runs under Git Bash / WSL)"
}

# ── 6. Pull + up ────────────────────────────────────────────────────────────
Write-Step ("Pulling images from Docker Hub (channel={0})" -f $Channel)
Write-Hint "First run downloads ~350 MB across three layers — takes 1–3 min on a decent connection."
$env:IMAGE_TAG = $Channel
docker compose pull
if ($LASTEXITCODE -ne 0) { Write-Err "docker compose pull failed"; exit 1 }

Write-Step "Starting containers"
docker compose up -d
if ($LASTEXITCODE -ne 0) { Write-Err "docker compose up failed"; exit 1 }

# ── 7. Wait for dashboard ───────────────────────────────────────────────────
Write-Step "Waiting for the dashboard to come up"
$url = "http://localhost"
$max = 60
$tried = 0
$ok = $false
while ($tried -lt $max) {
    try {
        $resp = Invoke-WebRequest -Uri "$url/dashboard" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
        if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 400) {
            $ok = $true
            Write-Ok "dashboard is live"
            break
        }
    } catch {
        # not yet
    }
    Write-Host -NoNewline "."
    Start-Sleep -Seconds 2
    $tried++
}
Write-Host ""
if (-not $ok) {
    Write-Warn ("Dashboard didn't respond within {0}s" -f ($max * 2))
    Write-Hint "Check logs: docker compose logs -f"
    Write-Hint "Check status: docker compose ps"
}

# ── 8. Summary ──────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "================================================================" -ForegroundColor White
Write-Host ("  TrAIding Floor is up. (channel=$Channel)") -ForegroundColor White
Write-Host "================================================================" -ForegroundColor White
Write-Host ""
Write-Host ("  Dashboard:    {0}" -f $url) -ForegroundColor Green
Write-Host ("  Backend API:  {0}:8080" -f $url) -ForegroundColor Green
Write-Host ("  Install dir:  {0}" -f (Get-Location).Path) -ForegroundColor Green
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "   1. Open $url in your browser"
Write-Host "   2. Walk the onboarding wizard — wallet, exchange keys, LLM brain, strategies"
Write-Host "   3. The floor starts in OBSERVE mode — no real trades until you flip strategies live"
Write-Host ""
Write-Host "  Useful commands (from this directory):" -ForegroundColor White
Write-Host "   docker compose ps                  show container status"
Write-Host "   docker compose logs -f             tail all logs"
Write-Host "   docker compose pull;`              "
Write-Host "    docker compose up -d              update to :latest"
Write-Host "   docker compose down                stop containers (data preserved)"
Write-Host ""

# Auto-open the dashboard if it came up cleanly
if ($ok) {
    Start-Process $url
}
