#!/usr/bin/env bash
# Launches the Windrose dedicated server under Wine + Xvfb.
# On first boot, briefly starts the server to generate ServerDescription.json,
# then patches it from environment variables before the real launch.

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

readonly SERVER_FILES="/home/steam/server-files"
readonly SERVER_DESC="${SERVER_FILES}/R5/ServerDescription.json"
readonly SERVER_EXEC="${SERVER_FILES}/R5/Binaries/Win64/WindroseServer-Win64-Shipping.exe"
readonly LOG_FILE="${SERVER_FILES}/R5/Saved/Logs/R5.log"
readonly WINE_BOOT_LOG="${SERVER_FILES}/wine-firstboot.log"
readonly FIRST_BOOT_TIMEOUT="${FIRST_BOOT_TIMEOUT:-180}"

cd "$SERVER_FILES"

log_step "Starting Windrose Dedicated Server"

if [[ ! -f "$SERVER_EXEC" ]]; then
    log_error "Server executable not found at: $SERVER_EXEC"
    log_error "Has the install step run? Check UPDATE_ON_START."
    exit 1
fi

export WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"
export WINEARCH="${WINEARCH:-win64}"
export WINEDEBUG="${WINEDEBUG:--all}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-mscoree,mshtml=}"

dump_wine_boot_log() {
    if [[ -s "$WINE_BOOT_LOG" ]]; then
        log_error "---- last 40 lines of wine first-boot output ($WINE_BOOT_LOG) ----"
        tail -n 40 "$WINE_BOOT_LOG" >&2 || true
        log_error "---- end of wine output ----"
    else
        log_error "No wine output captured — wine produced nothing on stdout/stderr."
    fi
}

generate_default_config() {
    log_step "First boot detected — generating default ServerDescription.json"
    : > "$WINE_BOOT_LOG"
    # Use a fuller WINEDEBUG so we get a real error if wine crashes early.
    WINEDEBUG="${WINE_FIRSTBOOT_DEBUG:-err+all,fixme-all}" \
        xvfb-run --auto-servernum wine "$SERVER_EXEC" -log >>"$WINE_BOOT_LOG" 2>&1 &
    local pid=$!

    local elapsed=0
    while [[ ! -f "$SERVER_DESC" ]] && (( elapsed < FIRST_BOOT_TIMEOUT )); do
        if ! kill -0 "$pid" 2>/dev/null; then
            log_error "Wine process exited before ServerDescription.json was written"
            dump_wine_boot_log
            return 1
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    if [[ ! -f "$SERVER_DESC" ]]; then
        log_error "ServerDescription.json not generated after ${elapsed}s"
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
        wineserver -k 2>/dev/null || true
        dump_wine_boot_log
        return 1
    fi

    log_ok "Default config generated"
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    wineserver -k 2>/dev/null || true
    sleep 2
}

patch_config() {
    log_step "Patching ServerDescription.json from environment"
    local tmp="${SERVER_DESC}.tmp"
    tr -d '\r' < "$SERVER_DESC" | jq \
        --arg     proxy        "${P2P_PROXY_ADDRESS:-127.0.0.1}" \
        --arg     invite       "${INVITE_CODE:-}" \
        --argjson directconn   "${USE_DIRECT_CONNECTION:-false}" \
        --argjson serverport   "${SERVER_PORT:-7777}" \
        --arg     dcproxy      "${DIRECT_CONNECTION_PROXY_ADDRESS:-0.0.0.0}" \
        --arg     region       "${USER_SELECTED_REGION:-}" \
        --arg     name         "${SERVER_NAME:-}" \
        --arg     password     "${SERVER_PASSWORD:-}" \
        --argjson maxplayers   "${MAX_PLAYERS:-10}" \
        '
        .ServerDescription_Persistent.P2pProxyAddress = $proxy
        | (if $invite   != "" then .ServerDescription_Persistent.InviteCode         = $invite   else . end)
        | .ServerDescription_Persistent.UseDirectConnection         = $directconn
        | .ServerDescription_Persistent.DirectConnectionServerPort  = $serverport
        | .ServerDescription_Persistent.DirectConnectionProxyAddress= $dcproxy
        | (if $region   != "" then .ServerDescription_Persistent.UserSelectedRegion = $region   else . end)
        | (if $name     != "" then .ServerDescription_Persistent.ServerName         = $name     else . end)
        | (if $password != ""
            then .ServerDescription_Persistent.IsPasswordProtected = true
                 | .ServerDescription_Persistent.Password           = $password
            else .ServerDescription_Persistent.IsPasswordProtected = false
                 | .ServerDescription_Persistent.Password           = ""
          end)
        | .ServerDescription_Persistent.MaxPlayerCount = $maxplayers
        ' > "$tmp"
    mv "$tmp" "$SERVER_DESC"
    log_ok "Config patched"
}

if [[ "${GENERATE_SETTINGS:-true}" == "true" ]]; then
    if [[ ! -f "$SERVER_DESC" ]]; then
        generate_default_config
    fi
    patch_config
else
    log_info "GENERATE_SETTINGS=false — leaving ServerDescription.json untouched"
fi

log_info "Launching server…"

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

xvfb-run --auto-servernum wine "$SERVER_EXEC" -log 2>&1 &
wine_pid=$!

tail -F "$LOG_FILE" 2>/dev/null &
tail_pid=$!

cleanup() {
    kill "$tail_pid" 2>/dev/null || true
}
trap cleanup EXIT

wait "$wine_pid"
