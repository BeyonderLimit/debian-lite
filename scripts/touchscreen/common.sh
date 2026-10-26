# shellcheck shell=bash
# Shared helpers for the touchscreen build scripts. Sourced, not executed.

set -euo pipefail

HW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sources.conf
. "$HW_DIR/sources.conf"

SP5_SRC_DIR="${SP5_SRC_DIR:-$HOME/src/surfacepro5}"
STATE_DIR="${SP5_STATE_DIR:-$HOME/.local/state/surfacepro5-openbox}"
mkdir -p "$SP5_SRC_DIR" "$STATE_DIR"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "Run as your normal user; sudo is used only where needed."

require_debian12() {
    . /etc/os-release
    if [ "${ID:-}" != "debian" ] || [ "${VERSION_ID:-}" != "12" ]; then
        warn "Expected Debian 12, found ${PRETTY_NAME:-unknown}. Continuing."
    fi
}

apt_install() {
    log "Installing build dependencies: $*"
    sudo apt-get install -y --no-install-recommends "$@"
}

# checkout <repo-url> <revision> <dir-name>  -> prints the checkout path
checkout() {
    local url=$1 rev=$2 name=$3 dir="$SP5_SRC_DIR/$3"
    if [ ! -d "$dir/.git" ]; then
        log "Cloning $name" >&2
        git clone --quiet "$url" "$dir" >&2
    fi
    git -C "$dir" fetch --quiet --tags origin >&2
    if [ -n "$(git -C "$dir" status --porcelain)" ]; then
        warn "$dir has local changes; building them on top of the current checkout." >&2
    else
        git -C "$dir" -c advice.detachedHead=false checkout --quiet "$rev" >&2
    fi
    log "$name at $(git -C "$dir" describe --tags --always) ($(git -C "$dir" rev-parse --short HEAD))" >&2
    echo "$dir"
}

record() {  # record <component> <dir>
    git -C "$2" rev-parse HEAD > "$STATE_DIR/$1.rev"
    date -Iseconds >> "$STATE_DIR/$1.rev"
}
