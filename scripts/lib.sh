#!/usr/bin/env bash
# Shared helpers: structured logging + Steam install via DepotDownloader.

set -o pipefail

readonly C_RESET=$'\033[0m'
readonly C_INFO=$'\033[0;37m'
readonly C_OK=$'\033[1;32m'
readonly C_WARN=$'\033[1;33m'
readonly C_ERR=$'\033[1;31m'
readonly C_STEP=$'\033[1;36m'

_log() {
    local color="$1" tag="$2" msg="$3"
    if [[ "${NO_COLOR:-}" == "1" ]]; then
        printf '[%s] %s\n' "$tag" "$msg"
    else
        printf '%s[%s] %s%s\n' "$color" "$tag" "$msg" "$C_RESET"
    fi
}

log_info()    { _log "$C_INFO" "INFO" "$1"; }
log_ok()      { _log "$C_OK"   " OK " "$1"; }
log_warn()    { _log "$C_WARN" "WARN" "$1"; }
log_error()   { _log "$C_ERR"  "ERR " "$1" >&2; }
log_step()    { _log "$C_STEP" "STEP" "$1"; }

require_env() {
    local name="$1"
    if [[ -z "${!name:-}" ]]; then
        log_error "required env var '$name' is not set"
        exit 1
    fi
}

steam_install() {
    local app_id="${1:?app id required}"
    local target="${2:?target dir required}"
    log_step "Installing Steam app ${app_id} into ${target}"
    /opt/depotdownloader/DepotDownloader \
        -app "$app_id" \
        -dir "$target" \
        -validate
    log_ok "Steam app ${app_id} install complete"
}

graceful_shutdown() {
    local timeout="${1:-30}"
    log_step "Initiating graceful shutdown (timeout ${timeout}s)"

    local pid
    pid="$(pgrep -f wineserver64 | head -1 || true)"

    if [[ -z "$pid" ]]; then
        log_warn "wineserver process not found"
        return 1
    fi

    kill -SIGTERM "$pid"
    local elapsed=0
    while (( elapsed < timeout )) && kill -0 "$pid" 2>/dev/null; do
        sleep 1
        elapsed=$((elapsed + 1))
    done

    if kill -0 "$pid" 2>/dev/null; then
        log_warn "wineserver did not exit in ${timeout}s, forcing"
        wineserver -k 2>/dev/null || true
        return 1
    fi

    log_ok "Server shutdown gracefully"
    return 0
}
