#!/usr/bin/env bash
# =============================================================================
# TrAIding Floor — one-line installer (Mac / Linux / Git Bash / WSL)
# =============================================================================
# Usage:
#
#   curl -fsSL https://install.traidingfloor.com/install.sh | sh
#
#   # Or pin to a non-default channel:
#   curl -fsSL https://install.traidingfloor.com/install.sh | sh -s -- beta
#   curl -fsSL https://install.traidingfloor.com/install.sh | sh -s -- v1.4.2
#
#   # Or set a custom install dir:
#   TF_INSTALL_DIR=/srv/floor curl -fsSL https://install.traidingfloor.com/install.sh | sh
#
# What this does:
#   1. Verifies Docker is installed and the daemon is running
#   2. Creates ./traidingfloor in the current directory (or $TF_INSTALL_DIR)
#   3. Downloads docker-compose.yml + .env.example into it
#   4. Runs `docker compose pull && docker compose up -d`
#   5. Waits for the dashboard to respond on http://localhost
#
# Safe to re-run: idempotent. Won't overwrite an existing docker-compose.yml
# or user-data/.env. Audit before piping to sh:
#
#   curl -fsSL https://install.traidingfloor.com/install.sh
#
# Source: https://github.com/traidingfloor/install
# =============================================================================

set -euo pipefail

# ── 0. Colors only when stdout is a TTY ─────────────────────────────────────
if [ -t 1 ]; then
  C_GREEN="\033[32m"; C_RED="\033[31m"; C_YEL="\033[33m"
  C_DIM="\033[2m"; C_BOLD="\033[1m"; C_R="\033[0m"
else
  C_GREEN=""; C_RED=""; C_YEL=""; C_DIM=""; C_BOLD=""; C_R=""
fi

say()  { printf "${C_BOLD}==>${C_R} %s\n" "$*"; }
ok()   { printf "${C_GREEN}\xE2\x9C\x93${C_R} %s\n" "$*"; }
warn() { printf "${C_YEL}!${C_R} %s\n" "$*"; }
err()  { printf "${C_RED}\xE2\x9C\x97${C_R} %s\n" "$*" >&2; }
hint() { printf "  ${C_DIM}%s${C_R}\n" "$*"; }

INSTALL_DIR="${TF_INSTALL_DIR:-traidingfloor}"
CHANNEL="${1:-latest}"
BASE_URL="https://raw.githubusercontent.com/traidingfloor/install/main"
COMPOSE_URL="${BASE_URL}/docker-compose.yml"
ENVEX_URL="${BASE_URL}/.env.example"
UPDATE_URL="${BASE_URL}/update.sh"

cat <<'BANNER'

  ┌───────────────────────────────────────────────────────────────┐
  │  TrAIding Floor — one-line installer                          │
  │  Self-hosted autonomous AI trading floor (multi-venue)        │
  │  Hyperliquid native + ccxt (Binance/OKX/KuCoin/Bybit/paper)   │
  └───────────────────────────────────────────────────────────────┘

BANNER

# ── 1. Docker present + running? ────────────────────────────────────────────
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
  warn "Using legacy docker-compose v1 — consider upgrading to Docker Desktop v2."
else
  err "Neither 'docker compose' nor 'docker-compose' is available."
  hint "Update Docker Desktop, or install docker-compose-plugin on Linux."
  exit 1
fi
ok "compose: $($COMPOSE version --short 2>/dev/null || echo unknown)"

# ── 2. Make install directory ───────────────────────────────────────────────
say "Creating install directory: ./$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
ok "in $(pwd)"

# ── 3. Download compose file ────────────────────────────────────────────────
say "Downloading docker-compose.yml"
if [ -f docker-compose.yml ]; then
  warn "docker-compose.yml already exists, leaving it in place"
  hint "Delete it and re-run if you want the latest version"
else
  curl -fsSL "$COMPOSE_URL" -o docker-compose.yml
  ok "saved ($(wc -c < docker-compose.yml | tr -d ' ') bytes)"
fi

# ── 4. Seed user-data/.env from .env.example ────────────────────────────────
say "Setting up user-data/"
mkdir -p user-data
if [ -f user-data/.env ]; then
  warn "user-data/.env already exists, leaving it in place"
else
  curl -fsSL "$ENVEX_URL" -o user-data/.env
  ok "seeded user-data/.env from .env.example ($(wc -c < user-data/.env | tr -d ' ') bytes)"
  hint "Edit user-data/.env to enable optional integrations (LLM, Telegram, Dune)."
fi

# ── 5. Drop update.sh helper next to compose ────────────────────────────────
if [ ! -f update.sh ]; then
  curl -fsSL "$UPDATE_URL" -o update.sh
  chmod +x update.sh
  ok "installed update.sh helper"
fi

# ── 6. Pull + up ────────────────────────────────────────────────────────────
say "Pulling images from Docker Hub (channel=${CHANNEL})"
hint "First run downloads ~350 MB across three layers — takes 1–3 min on a decent connection."
IMAGE_TAG="$CHANNEL" $COMPOSE pull

say "Starting containers"
IMAGE_TAG="$CHANNEL" $COMPOSE up -d

# ── 7. Wait for dashboard ───────────────────────────────────────────────────
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
  hint "Check logs: $COMPOSE logs -f"
  hint "Check status: $COMPOSE ps"
fi

# ── 8. Summary ──────────────────────────────────────────────────────────────
echo ""
printf "${C_BOLD}================================================================${C_R}\n"
printf "${C_BOLD}  TrAIding Floor is up. (channel=%s)${C_R}\n" "$CHANNEL"
printf "${C_BOLD}================================================================${C_R}\n"
echo ""
printf "  Dashboard:    ${C_GREEN}%s${C_R}\n" "$URL"
printf "  Backend API:  ${C_GREEN}%s:8080${C_R}\n" "$URL"
printf "  Install dir:  ${C_GREEN}%s${C_R}\n" "$(pwd)"
echo ""
printf "  ${C_BOLD}Next steps:${C_R}\n"
echo "   1. Open $URL in your browser"
echo "   2. Walk the onboarding wizard — wallet, exchange keys, LLM brain, strategy roster"
echo "   3. The floor starts in OBSERVE mode — no real trades until you flip strategies live"
echo ""
printf "  ${C_BOLD}Useful commands (from $(pwd)):${C_R}\n"
echo "   ./update.sh                       update to :latest"
echo "   ./update.sh beta                  switch to :beta channel"
echo "   $COMPOSE ps                       show container status"
echo "   $COMPOSE logs -f                  tail all logs"
echo "   $COMPOSE down                     stop containers (data preserved)"
echo ""
