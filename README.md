# windrose-server

Docker image that runs the **Windrose** dedicated server (Windows-only PE binary) under Wine on Linux. Vanilla server, no mods.

## Quickstart

```bash
git clone https://github.com/kalevski/windrose-docker.git
cd windrose-docker
cp .env.example .env
# edit .env (PUID/PGID, server name, port, password, etc.)
docker compose up -d
docker compose logs -f windrose
```

The first boot will:

1. Pull the dedicated server via DepotDownloader (Steam app `4129620`).
2. Briefly launch the server under Wine to generate the default `ServerDescription.json`.
3. Patch the JSON from your environment variables.
4. Start the server for real.

This usually takes 5–10 minutes on first run; the healthcheck has a `5m` start period to match.

## Configuration

All configuration is via environment variables (see [`.env.example`](./.env.example)). The most important ones:

| Variable                          | Default                | Description                                    |
| --------------------------------- | ---------------------- | ---------------------------------------------- |
| `PUID` / `PGID`                   | `1000` / `1000`        | UID/GID owning the `server-files` volume.      |
| `SERVER_NAME`                     | `My Windrose Server`   | Display name in the server browser.            |
| `SERVER_PASSWORD`                 | _(empty)_              | Empty = open server.                           |
| `SERVER_PORT`                     | `7777`                 | UDP/TCP port the server listens on.            |
| `MAX_PLAYERS`                     | `10`                   | Concurrent player cap.                         |
| `USE_DIRECT_CONNECTION`           | `false`                | Direct connection mode (excludes P2P proxy).   |
| `UPDATE_ON_START`                 | `true`                 | Run DepotDownloader on every container start.  |
| `GENERATE_SETTINGS`               | `true`                 | Allow scripts to overwrite `ServerDescription.json` from env vars. |
| `WINEDEBUG`                       | `-all`                 | `fixme-all` for verbose Wine logs.             |
| `NO_COLOR`                        | _(unset)_              | Set to `1` to disable ANSI colours in logs.    |

## Building locally

```bash
# Stable Wine (default)
docker build -t windrose-server .

# Staging Wine + winetricks vcrun2022
docker build --build-arg WINE_VARIANT=staging -t windrose-server:staging .
```

## Volumes & ports

| Path                            | Purpose                                |
| ------------------------------- | -------------------------------------- |
| `/home/steam/server-files`      | Game install + world saves. Persist this. |

| Port      | Protocol | Purpose          |
| --------- | -------- | ---------------- |
| `7777`    | UDP/TCP  | Server traffic.  |

## Tags

Images are published to GitHub Container Registry: `ghcr.io/kalevski/windrose`.

| Tag                                     | Variant                          |
| --------------------------------------- | -------------------------------- |
| `latest`, `vX.Y.Z`, `vX.Y`, `vX`        | `winehq-stable`                  |
| `wine-staging`, `vX.Y.Z-wine-staging`   | `winehq-staging` + `vcrun2022`   |
| `dev`, `dev-wine-staging`               | `main` branch (unstable)         |

Pull:

```bash
docker pull ghcr.io/kalevski/windrose:latest
```

## Development

```bash
# Lint
shellcheck scripts/*.sh

# Mount scripts for live iteration without rebuilds
docker run --rm -it --env-file .env \
  -v "$PWD/scripts:/home/steam/server" \
  -v "$PWD/data:/home/steam/server-files" \
  windrose-server
```

Open improvement work tracked in [`tasks.md`](./tasks.md).

## License

MIT.
