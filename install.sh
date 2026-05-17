#!/usr/bin/env bash
# =============================================================================
# TrAIding Floor — one-line installer
# =============================================================================
# Usage (on Mac or Linux, or Windows via Git Bash / WSL):
#
#   curl -fsSL https://raw.githubusercontent.com/traidingfloor/install/main/install.sh | sh
#
# What this does:
#   1. Verifies Docker is installed and the daemon is running
#   2. Creates ./traidingfloor in the current directory
#   3. Downloads docker-compose.yml from the public install repo
#   4. Runs `docker compose pull && docker compose up -d`
#      (~1.1 GB image pull on first run, takes 1-3 min)
#   5. Waits for the dashboard to respond, prints the URL
#
# Safe to re-run: idempotent. Won't overwrite existing docker-compose.yml.
# No system modifications. Audit before piping to sh:
#
#   curl -fsSL https://raw.githubusercontent.com/traidingfloor/install/main/install.sh
#
# Source: https://github.com/traidingfloor/install
# =============================================================================

set -euo pipefail

# Colors only when stdout is a TTY
if [ -t 1 ]; then
  C_GREEN="\033[32m"; C_RED="\033[31m"; C_YEL="\033[33m"
  C_DIM="\033[2m";    C_BOLD="\033[1m"; C_R="\033[0m"
else
  C_GREEN=""; C_RED=""; C_YEL=""; C_DIM=""; C_BOLD=""; C_R=""
fi

say()  { printf "${C_BOLD}==>${C_R} %s\n" "$*"; }
ok()   { printf "${C_GREEN}\xE2\x9C\x93${C_R}  %s\n" "$*"; }
warn() { printf "${C_YEL}!${C_R}  %s\n" "$*"; }
err()  { printf "${C_RED}\xE2\x9C\x97${C_R}  %s\n" "$*" >&2; }
hint() { printf "   ${C_DIM}%s${C_R}\n" "$*"; }

INSTALL_DIR="${TF_INSTALL_DIR:-traidingfloor}"
COMPOSE_URL="https://raw.githubusercontent.com/traidingfloor/install/main/docker-compose.yml"

cat <<'BANNER'

  +---------------------------------------------------------------+
  |  TrAIding Floor - one-line installer                          |
  |  Autonomous AI trading floor for Hyperliquid                  |
  +---------------------------------------------------------------+

BANNER

# --- 1. Docker present? -----------------------------------------------------
say "Checking prerequisites"

if ! command -v docker >/dev/null 2>&1; then
  err "Docker is not installed."
  hint "Install Docker Desktop: https://www.docker.com/products/docker-desktop/"
  hint "Then re-run this script."
  exit 1
fi
ok "docker found ($(docker --version | head -c 80))"

if ! docker info >/dev/null 2>&1; then
  err "Docker daemon is not running."
  hint "Start Docker Desktop (Mac/Windows) or 'sudo systemctl start docker' (Linux)."
  hint "Then re-run this script."
  exit 1
fi
ok "docker daemon is reachable"

# Detect compose v2 vs legacy v1
if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
  warn "Using legacy docker-compose v1 - consider upgrading to Docker Desktop v2."
else
  err "Neither 'docker compose' nor 'docker-compose' is available."
  hint "Update Docker Desktop, or install docker-compose-plugin on Linux."
  exit 1
fi
ok "compose: $($COMPOSE version --short 2>/dev/null || echo unknown)"

# --- 2. Make install directory ---------------------------------------------
say "Creating install directory: ./$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
ok "in $(pwd)"

# --- 3. Download compose file ----------------------------------------------
say "Downloading docker-compose.yml"
if [ -f docker-compose.yml ]; then
  warn "docker-compose.yml already exists, leaving it in place"
  hint "Delete it and re-run if you want the latest version"
else
  curl -fsSL "$COMPOSE_URL" -o docker-compose.yml
  ok "saved ($(wc -c < docker-compose.yml | tr -d ' ') bytes)"
fi

# --- 4. Pull + up ----------------------------------------------------------
say "Pulling images (first run downloads ~1.1 GB, takes 1-3 min on a decent connection)"
$COMPOSE pull

say "Starting containers"
$COMPOSE up -d

# --- 5. Wait for dashboard --------------------------------------------------
say "Waiting for the dashboard to come up"
URL="http://localhost"
MAX=60
TRIED=0
while [ $TRIED -lt $MAX ]; do
  if curl -fsS -o /dev/null "$URL/dashboard" 2>/dev/null; then
    ok "dashboard is live"
    break
  fi
  printf "."
  sleep 2
  TRIED=$((TRIED + 1))
done
echo ""
if [ $TRIED -ge $MAX ]; then
  warn "Dashboard didn't respond within $(( MAX * 2 ))s"
  hint "Check logs:   $COMPOSE logs -f"
  hint "Check status: $COMPOSE ps"
fi

# --- 6. Summary -------------------------------------------------------------
echo ""
printf "${C_BOLD}================================================================${C_R}\n"
printf "${C_BOLD}  TrAIding Floor is up.${C_R}\n"
printf "${C_BOLD}================================================================${C_R}\n"
echo ""
printf "  Dashboard:    ${C_GREEN}%s${C_R}\n" "$URL"
printf "  Backend API:  ${C_GREEN}%s:8080${C_R}\n" "$URL"
printf "  Install dir:  ${C_GREEN}%s${C_R}\n" "$(pwd)"
echo ""
printf "  ${C_BOLD}Next steps:${C_R}\n"
echo  "    1. Open $URL in your browser"
echo  "    2. Walk through the onboarding wizard"
echo  "       (optional: add API keys for live trading on Hyperliquid)"
echo  "    3. The floor starts in OBSERVE mode -- no real trades until you"
echo  "       flip strategies live"
echo  ""
printf "  ${C_BOLD}Useful commands (from $(pwd)):${C_R}\n"
echo  "    $COMPOSE ps              show container status"
echo  "    $COMPOSE logs -f         tail all logs"
echo  "    $COMPOSE pull && $COMPOSE up -d   update to latest images"
echo  "    $COMPOSE down            stop containers (data preserved)"
echo  ""
