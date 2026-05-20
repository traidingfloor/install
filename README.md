# TrAIding Floor — install

Self-hosted autonomous AI trading floor. Multi-venue (Hyperliquid native plus
any ccxt exchange — Binance, OKX, KuCoin, Bybit) with a paper-trading
sandbox. Multi-agent system (Head Trader, Risk Officer, Market Analyst) with
a live operator dashboard. **Keys never leave your machine.**

This repo contains only the bits an operator needs: a Docker compose file
and a few helper scripts. The actual source code lives in a separate private
repo; you don't need it to run.

## Install (one minute)

```bash
mkdir traidingfloor && cd traidingfloor
curl -fsSL https://raw.githubusercontent.com/traidingfloor/install/main/docker-compose.yml -o docker-compose.yml
docker compose up -d
```

Then open <http://localhost> in your browser. The onboarding wizard fires
automatically and walks you through 11 steps (wallet connect, exchange API
keys, LLM brain, strategy roster). Takes about 5 minutes.

## Update

```bash
./update.sh
```

Or by hand:

```bash
docker compose pull && docker compose up -d
```

The pull only downloads changed layers — usually a few megabytes, not a
full re-install. Your `user-data/` directory (keys, trade history, beliefs)
is mounted from the host so nothing in it is touched by an update.

## Stop / start / wipe

```bash
docker compose stop      # pause everything; keeps containers + data
docker compose start     # resume
docker compose down      # remove containers (data on host stays put)
rm -rf user-data/        # nuclear: wipe all your data + start over
```

## Switch update channels

The compose file defaults to the `latest` tag (stable). To track the
bleeding-edge `beta` channel:

```bash
IMAGE_TAG=beta docker compose pull
IMAGE_TAG=beta docker compose up -d
```

Or pin to a specific version:

```bash
IMAGE_TAG=v1.4.2 docker compose up -d
```

## Optional services

The Telegram alert watcher is shipped commented out in the compose file.
To enable it: uncomment the `traiding-watcher:` block and add these two
lines to `user-data/.env`:

```
TELEGRAM_BOT_TOKEN=...
TELEGRAM_CHAT_ID=...
```

Then `docker compose up -d` to bring the new container online.

## Prereqs

- Docker 24+ with Compose v2 (`docker compose`, not `docker-compose`)
- A web browser
- 4 GB RAM, 2 GB disk for the images
- Network access to your chosen exchange's REST + WebSocket APIs

That's it. No Python, no Node, no toolchain on your host.

## Troubleshooting

**"port 80 already in use"** — change the port mapping in `docker-compose.yml`
from `127.0.0.1:80:3000` to `127.0.0.1:3000:3000` and open
<http://localhost:3000>.

**"the onboarding wizard doesn't appear"** — confirm both containers are
healthy: `docker compose ps`. The `traiding-floor` container has a 30-second
start-period so the dashboard may show a connection error for the first
half-minute.

**"I broke my .env, want to start the wizard fresh"** —
`rm user-data/.env && docker compose restart`. The wizard re-fires on next
load because it triggers when `.env` is missing.

**"docker compose pull says unauthorized"** — the images are public; this
usually means an old Docker Hub credential is interfering. Try
`docker logout` and retry.

## Where's the source?

The source code is in a private repo. The images you're pulling are built
from that repo by CI on every merge to main. If you want feature requests,
bug reports, or to read the changelog, see <https://traidingfloor.com>.

## License

The compose file and scripts in this install repo are MIT-licensed. The
images themselves are closed-source.
