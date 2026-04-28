<div align="center">

# 🧭 windrose-server

**Dockerized [Windrose](https://store.steampowered.com/app/4129620) dedicated server — Windows binary running under Wine on Linux.**

[![Build & Publish](https://github.com/kalevski/windrose-docker/actions/workflows/build-publish.yml/badge.svg)](https://github.com/kalevski/windrose-docker/actions/workflows/build-publish.yml)
[![GHCR](https://img.shields.io/badge/ghcr.io-kalevski%2Fwindrose--server-2496ED?logo=docker&logoColor=white)](https://github.com/kalevski/windrose-docker/pkgs/container/windrose-server)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](#-license)
[![Wine](https://img.shields.io/badge/Wine-stable%20%7C%20staging-722F37?logo=wine&logoColor=white)](https://www.winehq.org/)
[![Platform](https://img.shields.io/badge/platform-linux%2Famd64-blue?logo=linux&logoColor=white)](#)

</div>

---

## ✨ Features

- 🪟 **Wine-powered** — runs the official Windows-only `WindroseServer-Win64-Shipping.exe` on Linux.
- 📦 **Auto-install / auto-update** — pulls the dedicated server via [DepotDownloader](https://github.com/SteamRE/DepotDownloader) (Steam app `4129620`).
- ⚙️ **Env-driven config** — `ServerDescription.json` is generated on first boot, then patched from environment variables.
- 🎨 **Two flavors** — `winehq-stable` (default) and `winehq-staging` + `vcrun2022`.
- 🛡️ **Unprivileged runtime** — drops to a non-root `steam` user; UID/GID match `PUID`/`PGID`.
- 🩺 **Healthcheck** — `pgrep` on the server process, with a 5-minute start grace.
- 🛑 **Graceful shutdown** — SIGTERM is forwarded to `wineserver`; falls back to `wineserver -k` after 30 s.
- 🪵 **Live log tail** — `R5.log` streamed to container stdout.

---

## 🚀 Quickstart

```bash
docker run -d \
  --name windrose \
  -p 7777:7777/udp -p 7777:7777/tcp \
  -e PUID=1000 -e PGID=1000 \
  -e SERVER_NAME="My Windrose Server" \
  -e SERVER_PASSWORD="changeme" \
  -e MAX_PLAYERS=10 \
  -v windrose-data:/home/steam/server-files \
  ghcr.io/kalevski/windrose-server:latest

docker logs -f windrose
```

First boot will:

1. 📥 Pull the dedicated server via DepotDownloader.
2. 🌀 Briefly launch under Wine to generate the default `ServerDescription.json`.
3. 🔧 Patch the JSON from your environment variables.
4. 🟢 Start the server for real.

⏱️ Expect **5–10 minutes** the first time — the healthcheck has a matching `5m` start period.

---

## 🐙 docker compose

```yaml
services:
  windrose:
    image: ghcr.io/kalevski/windrose-server:latest
    container_name: windrose
    restart: unless-stopped
    ports:
      - "7777:7777/udp"
      - "7777:7777/tcp"
    environment:
      PUID: "1000"
      PGID: "1000"
      SERVER_NAME: "My Windrose Server"
      SERVER_PASSWORD: ""
      MAX_PLAYERS: "10"
    volumes:
      - ./data:/home/steam/server-files
```

---

## ⚙️ Configuration

All configuration is via environment variables. Required ones marked with 🔑.

### 👤 Runtime

| Variable | Default | Description |
| --- | --- | --- |
| 🔑 `PUID` | — | UID owning `/home/steam/server-files`. |
| 🔑 `PGID` | — | GID owning `/home/steam/server-files`. |
| `UPDATE_ON_START` | `true` | Run DepotDownloader on every container start. |
| `GENERATE_SETTINGS` | `true` | Allow scripts to overwrite `ServerDescription.json` from env. |
| `FIRST_BOOT_TIMEOUT` | `120` | Seconds to wait for the default config to be written. |

### 🎮 Server

| Variable | Default | Description |
| --- | --- | --- |
| `SERVER_NAME` | `Windrose Server` | Display name in the server browser. |
| `SERVER_PASSWORD` | _(empty)_ | Empty = open server. Sets `IsPasswordProtected` automatically. |
| `SERVER_PORT` | `7777` | UDP/TCP port the server listens on. |
| `MAX_PLAYERS` | `10` | Concurrent player cap. |
| `INVITE_CODE` | _(empty)_ | Optional pre-set invite code. |
| `USER_SELECTED_REGION` | _(empty)_ | Optional region hint. |

### 🌐 Networking

| Variable | Default | Description |
| --- | --- | --- |
| `USE_DIRECT_CONNECTION` | `false` | `true` = direct connect (skip P2P proxy). |
| `DIRECT_CONNECTION_PROXY_ADDRESS` | `0.0.0.0` | Bind address used when direct connection is on. |
| `P2P_PROXY_ADDRESS` | `127.0.0.1` | Address advertised for P2P proxy mode. |

### 🍷 Wine / logging

| Variable | Default | Description |
| --- | --- | --- |
| `WINEDEBUG` | `-all` | Set `fixme-all` (or similar) for verbose Wine logs. |
| `NO_COLOR` | _(unset)_ | Set to `1` to strip ANSI colors from container logs. |

> 💡 Field mappings live in [`scripts/server.sh`](./scripts/server.sh) — every variable above maps 1:1 to a key in `ServerDescription_Persistent`.

---

## 💾 Volumes & ports

| Path | Purpose |
| --- | --- |
| `/home/steam/server-files` | 🎯 Game install + world saves. **Persist this.** |

| Port | Protocol | Purpose |
| --- | --- | --- |
| `7777` | UDP/TCP | Server traffic (override with `SERVER_PORT`). |

---

## 🏷️ Image tags

Published to GitHub Container Registry: **`ghcr.io/kalevski/windrose-server`**.

| Tag | Source | Variant |
| --- | --- | --- |
| `latest` | release | `winehq-stable` |
| `vX.Y.Z`, `vX.Y`, `vX` | release | `winehq-stable` |
| `wine-staging` | release | `winehq-staging` + `vcrun2022` |
| `vX.Y.Z-wine-staging`, `vX.Y-wine-staging`, `vX-wine-staging` | release | `winehq-staging` + `vcrun2022` |
| `dev` | push to `main` | `winehq-stable` (unstable) |
| `dev-wine-staging` | push to `main` | `winehq-staging` (unstable) |

```bash
docker pull ghcr.io/kalevski/windrose-server:latest
# or staging Wine
docker pull ghcr.io/kalevski/windrose-server:wine-staging
```

---

## 🔨 Building locally

```bash
# Stable Wine (default)
docker build -t windrose-server .

# Staging Wine + winetricks vcrun2022
docker build --build-arg WINE_VARIANT=staging -t windrose-server:staging .
```

Build args:

| Arg | Default | Description |
| --- | --- | --- |
| `WINE_VARIANT` | `stable` | `stable` or `staging`. |
| `DEPOT_DOWNLOADER_VERSION` | `3.4.0` | DepotDownloader release pinned at build time. |

---

## 🧪 Development

```bash
# Lint shell scripts (CI runs the same)
shellcheck scripts/*.sh

# Mount scripts for live iteration without rebuilds
docker run --rm -it --env-file .env \
  -e PUID=1000 -e PGID=1000 \
  -p 7777:7777/udp -p 7777:7777/tcp \
  -v "$PWD/scripts:/home/steam/server" \
  -v "$PWD/data:/home/steam/server-files" \
  windrose-server
```

Layout:

```
├── Dockerfile              # Debian + Wine + .NET 8 + DepotDownloader
├── motd                    # Banner printed at container start
├── scripts/
│   ├── entrypoint.sh       # Aligns PUID/PGID, runs install/update, drops to steam
│   ├── server.sh           # First-boot config gen + jq patch + Xvfb/Wine launch
│   └── lib.sh              # Logging + DepotDownloader + graceful shutdown helpers
└── .github/workflows/
    └── build-publish.yml   # GHCR publish for stable + staging variants
```

---

## 📜 License

MIT — see [`LICENSE`](./LICENSE) (or the SPDX header in [`Dockerfile`](./Dockerfile)).
