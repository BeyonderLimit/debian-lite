
#!/usr/bin/env bash

set -Eeuo pipefail

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

log() {
    printf '\n==> %s\n' "$*"
}

require_user() {
    [[ "$EUID" -ne 0 ]] ||
        die "Run as the intended desktop user, without sudo."

    command -v sudo >/dev/null ||
        die "sudo is required. Configure administrative access first."
}

require_debian12() {
    [[ -r /etc/os-release ]] || die "Cannot identify operating system."

    # shellcheck disable=SC1091
    . /etc/os-release

    [[ "${ID:-}" == debian && "${VERSION_ID:-}" == 12 ]] ||
        die "This project targets Debian 12."

    [[ "$(dpkg --print-architecture)" == amd64 ]] ||
        die "This project targets amd64 Surface hardware."
}
