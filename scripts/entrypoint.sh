#!/usr/bin/env bash
# Container entrypoint. Runs as root: aligns the steam UID/GID with PUID/PGID,
# triggers an install/update (if requested), then drops to the steam user to
# launch the dedicated server.

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

readonly SERVER_FILES="/home/steam/server-files"
readonly OWNER_MARKER="${SERVER_FILES}/.last_owner"

require_env PUID
require_env PGID

usermod  -o -u "$PUID" steam >/dev/null
groupmod -o -g "$PGID" steam >/dev/null

if [[ -f /etc/motd ]]; then
    cat /etc/motd
fi

# chown is expensive on large worlds — only run on first boot or if PUID/PGID changed.
current_owner="${PUID}:${PGID}"
last_owner="$( [[ -f "$OWNER_MARKER" ]] && cat "$OWNER_MARKER" || echo "" )"
if [[ "$current_owner" != "$last_owner" ]]; then
    log_step "Aligning ownership of server-files to ${current_owner}"
    chown -R steam:steam "$SERVER_FILES"
    echo "$current_owner" > "$OWNER_MARKER"
    chown steam:steam "$OWNER_MARKER"
else
    log_info "Ownership unchanged, skipping recursive chown"
fi
chown steam:steam /home/steam

if [[ "${UPDATE_ON_START:-true}" == "true" ]]; then
    steam_install 4129620 "$SERVER_FILES"
else
    log_warn "UPDATE_ON_START=false — skipping server update"
fi

# Forward signals to the wineserver so docker stop terminates cleanly.
shutdown_handler() {
    graceful_shutdown 30 || true
    [[ -n "${child_pid:-}" ]] && wait "$child_pid" 2>/dev/null || true
}
trap shutdown_handler SIGTERM SIGINT

# Vanilla server env passthrough.
export INVITE_CODE="${INVITE_CODE:-}"
export USE_DIRECT_CONNECTION="${USE_DIRECT_CONNECTION:-false}"
export SERVER_PORT="${SERVER_PORT:-7777}"
export DIRECT_CONNECTION_PROXY_ADDRESS="${DIRECT_CONNECTION_PROXY_ADDRESS:-0.0.0.0}"
export USER_SELECTED_REGION="${USER_SELECTED_REGION:-}"
export SERVER_NAME="${SERVER_NAME:-Windrose Server}"
export SERVER_PASSWORD="${SERVER_PASSWORD:-}"
export MAX_PLAYERS="${MAX_PLAYERS:-10}"
export P2P_PROXY_ADDRESS="${P2P_PROXY_ADDRESS:-127.0.0.1}"
export GENERATE_SETTINGS="${GENERATE_SETTINGS:-true}"

readonly forwarded_env="INVITE_CODE,USE_DIRECT_CONNECTION,SERVER_PORT,\
DIRECT_CONNECTION_PROXY_ADDRESS,USER_SELECTED_REGION,SERVER_NAME,\
SERVER_PASSWORD,MAX_PLAYERS,P2P_PROXY_ADDRESS,GENERATE_SETTINGS,NO_COLOR,\
WINEDEBUG"

su - steam -w "$forwarded_env" -c \
    "cd /home/steam/server && ./server.sh" &
child_pid=$!
wait "$child_pid"
