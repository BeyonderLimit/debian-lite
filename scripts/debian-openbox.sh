nu#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/common.sh"

require_user
require_debian12

if dpkg-query -W -f='${Status}' pipewire-pulse 2>/dev/null |
    grep -q 'install ok installed'; then
    die "Existing PipeWire audio detected. Adapt the audio package list before installing."
fi

packages=(
    xorg
    xinit
    x11-xserver-utils
    xserver-xorg-input-libinput
    dbus-x11
    openbox
    obconf
    tint2
    pcmanfm
    chromium
    featherpad
    rofi
    dunst
    jgmenu
    picom
    feh
    lxappearance
    lxterminal
    fonts-dejavu
    adwaita-icon-theme
    libnotify-bin
    brightnessctl
    pulseaudio
    pulseaudio-utils
    alsa-utils
    onboard
    xinput
    python3
    python3-xdg
    polybar
    powertop
    fonts-quicksand
    fonts-cantarell
    fonts-comic-neue
    fonts-jetbrains-mono
)

log "Installing desktop packages"
sudo apt-get update
sudo apt-get install --no-install-recommends "${packages[@]}"
