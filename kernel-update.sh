#!/usr/bin/env bash
set -Eeuo pipefail

# Usage:
#   sudo bash upgrade-kernel.sh
#   sudo bash upgrade-kernel.sh --backports
#
# Default: use APT's normal candidates.
# --backports: explicitly target the matching backports suite.
#
# This script does not add repositories or guarantee hardware compatibility.

trap 'printf "Error on line %s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

(( EUID == 0 )) || die "Run this script with sudo or as root."

use_backports=false
case "${1:-}" in
    "") ;;
    --backports) use_backports=true ;;
    *) die "Usage: bash $0 [--backports]" ;;
esac

(( $# <= 1 )) || die "Too many arguments."

[[ -r /etc/os-release ]] || die "Cannot identify the operating system."
. /etc/os-release

[[ "${ID:-}" == debian ]] ||
    die "This script supports Debian, not derivatives."

codename="${VERSION_CODENAME:-}"
[[ -n "$codename" ]] || die "Cannot determine Debian release codename."

arch="$(dpkg --print-architecture)"

# Deliberately restrict automatic selection to these common generic flavours.
case "$arch" in
    amd64)
        image_meta=linux-image-amd64
        headers_meta=linux-headers-amd64
        ;;
    arm64)
        image_meta=linux-image-arm64
        headers_meta=linux-headers-arm64
        ;;
    *)
        die "Architecture '$arch' needs an explicitly chosen kernel flavour."
        ;;
esac

running_kernel="$(uname -r)"

printf '\nSystem information\n'
printf '  Distribution: %s\n' "${PRETTY_NAME:-Debian}"
printf '  Architecture: %s\n' "$arch"
printf '  Running kernel: %s\n' "$running_kernel"

if command -v lscpu >/dev/null 2>&1; then
    printf '\nCPU information\n'
    lscpu
fi

if command -v lspci >/dev/null 2>&1; then
    printf '\nPCI hardware and current drivers\n'
    lspci -nnk
fi

if command -v lsusb >/dev/null 2>&1; then
    printf '\nUSB hardware\n'
    lsusb
fi

if command -v dkms >/dev/null 2>&1; then
    printf '\nCurrent DKMS status\n'
    dkms status
fi

if command -v mokutil >/dev/null 2>&1; then
    printf '\nSecure Boot status\n'
    mokutil --sb-state || true
fi

printf '\nBoot filesystem space\n'
df -h /boot /

# Avoid proceeding with an already-incomplete package transaction.
audit="$(dpkg --audit)"
if [[ -n "$audit" ]]; then
    printf '%s\n' "$audit" >&2
    die "Resolve the package problems above before upgrading the kernel."
fi

# APT's Error-Mode=any makes repository refresh failures fatal.
apt-get -o APT::Update::Error-Mode=any update

target_options=()

if "$use_backports"; then
    # As of October 2026, bookworm-backports is past its support cutoff.
    # Do not automatically opt into that unsupported suite.
    case "$codename" in
        trixie)
            suite="${codename}-backports"
            ;;
        bookworm)
            die "bookworm-backports support ended August 9, 2026. \
Do not use it as a maintained upgrade channel."
            ;;
        *)
            die "Backports support for '$codename' must be reviewed manually."
            ;;
    esac

    # Fail if the suite was not already configured; do not add it silently.
    apt-cache -t "$suite" policy "$image_meta" "$headers_meta"
    target_options=(-t "$suite")
fi

printf '\nKernel package candidates and repository priorities\n'
apt-cache "${target_options[@]}" policy "$image_meta" "$headers_meta"

packages=("$image_meta" "$headers_meta")

printf '\nSimulated installation — review all changes carefully\n'
apt-get --simulate --no-remove \
    "${target_options[@]}" install "${packages[@]}"

printf '\nThis cannot verify hardware compatibility before reboot.\n'
printf 'Keep a working boot-menu fallback and recovery access.\n'

read -r -p 'Type INSTALL to continue: ' reply
[[ "$reply" == INSTALL ]] || {
    printf 'Cancelled.\n'
    exit 0
}

# Preserve the currently running kernel if it has the standard Debian name.
running_package="linux-image-${running_kernel}"
if dpkg-query -W -f='${Status}\n' "$running_package" 2>/dev/null |
    grep -qx 'install ok installed'
then
    apt-mark manual "$running_package"
else
    printf '\nWARNING: Could not identify the running kernel as %s.\n' \
        "$running_package"
    printf 'Verify that you have a bootable fallback before rebooting.\n'
fi

# No -y: retain APT's final interactive confirmation.
# --no-remove: abort rather than remove packages to resolve dependencies.
apt-get --no-remove \
    "${target_options[@]}" install "${packages[@]}"

printf '\nInstalled kernel metapackages\n'
dpkg-query -W -f='${Package} ${Version}\n' "${packages[@]}"

if command -v dkms >/dev/null 2>&1; then
    printf '\nDKMS status after installation — inspect for missing modules\n'
    dkms status
fi

printf '\nKernel package installation completed.\n'
printf 'The currently running kernel is still: %s\n' "$(uname -r)"
printf 'Review installation output, driver status, and boot configuration.\n'
printf 'Reboot manually when ready: systemctl reboot\n'
printf 'After reboot, check the active kernel with: uname -r\n'
printf 'Do not remove your previous working kernel until testing is complete.\n'
