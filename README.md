# TrAIding Floor — one-line install

Autonomous AI trading floor for Hyperliquid. Multi-agent system (Head Trader,
Risk Officer, Market Analyst) with a live operator dashboard, Dune Analytics
intel, and Telegram alerts.

## Install

Requires [Docker](https://www.docker.com/products/docker-desktop) (Desktop on Mac/Windows, daemon on Linux).

```bash
mkdir traidingfloor && cd traidingfloor
curl -fsSL https://raw.githubusercontent.com/traidingfloor/install/main/docker-compose.yml -o docker-compose.yml
docker compose up -d
```

Dashboard opens at <http://localhost>. First run downloads ~3 images
(~30 seconds on a fast connection). The onboarding wizard takes you the rest
of the way.

## Optional integrations

Enable the LLM reviewer, Dune intel feed, or Telegram alerts by writing a
`user-data/.env` file. The template lists every supported variable:

```bash
mkdir -p user-data
curl -fsSL https://raw.githubusercontent.com/traidingfloor/install/main/.env.example -o user-data/.env
# Edit user-data/.env in your editor, then:
docker compose restart
```

See [`.env.example`](.env.example) for the full list.

## Update

```bash
docker compose pull && docker compose up -d
```

## Stop

```bash
docker compose down       # stop containers, data preserved in ./user-data/
docker compose down -v    # also drop named volumes (user-data is on host, so safe)
```

## What's running

| Container | Port | Role |
|---|---|---|
| `traiding-floor` | 8080 | FastAPI backend + agent loop |
| `traiding-floor-web` | 80 | Next.js operator dashboard |
| `traiding-watcher` | — | 24/7 Telegram alert sidecar |
| `traiding-dune-intel` | — | Dune Analytics intel feeder |

If port 80 is already taken, edit `docker-compose.yml` and change the
`"80:3000"` mapping on `traiding-floor-web` to a free port like `"3000:3000"`.

## Source

Source code is closed. Images are built and published from a private repo
via GitHub Actions and are mirrored to Docker Hub:

- <https://hub.docker.com/r/traidingfloor/traiding-floor>
- <https://hub.docker.com/r/traidingfloor/traiding-floor-web>
- <https://hub.docker.com/r/traidingfloor/traiding-watcher>

## Issues

File install / config issues at <https://github.com/traidingfloor/install/issues>.
