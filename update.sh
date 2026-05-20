#!/usr/bin/env bash
# =============================================================================
# TrAIding Floor — update.sh
# =============================================================================
# Pulls the latest published images from Docker Hub and recreates the
# containers in place. Your user-data/ directory (keys, trade history,
# beliefs) is host-mounted, so nothing in it is touched by an update.
#
# Usage:
#   ./update.sh              # update to :latest
#   ./update.sh beta         # update to :beta channel
#   ./update.sh v1.4.2       # pin to a specific version
#
# Safe to re-run. Idempotent. Will pick up any compose-file changes you
# made locally (port mappings, optional services).
# =============================================================================
set -euo pipefail

# cd to the directory this script lives in so it works no matter
# where the operator invoked it from.
cd "$(dirname "$0")"

CHANNEL="${1:-latest}"

# Sanity-check Docker is running before we do anything.
if ! docker info >/dev/null 2>&1; then
  echo "[X] Docker is not running. Start Docker Desktop (or 'sudo systemctl start docker')"
  echo "    and re-run this script."
  exit 1
fi

# Sanity-check `docker compose` (v2, the plugin) is on PATH, not just
# the legacy `docker-compose` v1 binary.
if ! docker compose version >/dev/null 2>&1; then
  echo "[X] 'docker compose' v2 is not installed. Install Docker Desktop or"
  echo "    the compose plugin (https://docs.docker.com/compose/install/)."
  exit 1
fi

echo
echo "=========================================="
echo " TrAIding Floor — update (channel=${CHANNEL})"
echo "=========================================="
echo

echo "[1/3] Pulling images from Docker Hub..."
IMAGE_TAG="${CHANNEL}" docker compose pull

echo
echo "[2/3] Recreating containers with new images..."
IMAGE_TAG="${CHANNEL}" docker compose up -d

echo
echo "[3/3] Waiting for the dashboard to come up..."
for i in $(seq 1 30); do
  if curl -fsS -o /dev/null http://localhost/dashboard 2>/dev/null; then
    echo
    echo "[ok] Update complete. Open http://localhost in your browser."
    exit 0
  fi
  sleep 2
done

echo
echo "[!] Containers are up but the dashboard didn't respond within 60s."
echo "    Check the logs: docker compose logs -f"
exit 1
