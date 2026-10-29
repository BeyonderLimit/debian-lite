#!/usr/bin/env bash
set -Eeuo pipefail

# Install an Openbox-based X11 desktop on Debian.
#
# Usage:
#   sudo bash install-desktop.sh
#   sudo bash install-desktop.sh username
#   As root: bash install-desktop.sh username
#
# Optional: place an xsessionrc file beside this script.
# Existing configuration files are backed up before replacement.

trap 'printf "Error on line %s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

if (( EUID != 0 )); then
    die "Run with sudo or as root."
fi

target_user="${1:-${SUDO_USER:-}}"

[[ -n "$target_user" ]] ||
    die "Specify the desktop user: bash $0 username"

[[ "$target_user" != root ]] ||
    die "Choose a non-root desktop user."

passwd_entry="$(getent passwd "$target_user")" ||
    die "User '$target_user' does not exist."

IFS=: read -r account_name _ target_uid target_gid _ target_home _ \
    <<< "$passwd_entry"

[[ -d "$target_home" ]] ||
    die "Home directory does not exist: $target_home"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
backup_suffix="$(date +%Y%m%d-%H%M%S).$$"

backup_file() {
    local path="$1"

    if [[ -e "$path" || -L "$path" ]]; then
        cp -a -- "$path" "${path}.bak.${backup_suffix}"
    fi
}

apt-get update

# Required packages: fail rather than silently omitting the desktop itself.
required_packages=(
    xinit
    xorg
    openbox
    dbus-user-session
    xterm
)

# Keep the original application's choices. Availability varies by release.
optional_packages=(
    menu
    plank
    arc-theme
    obconf
    conky
    jgmenu
    picom
    tint2
    firefox-esr
    dunst
    mpv
    rofi
    kitty
    fish
    zsh
    rox-filer
    feh
    volumeicon-alsa
    alsa-utils
    pavucontrol
    pulseaudio
    nitrogen
    xbacklight
    pcmanfm
    lxappearance
    lxpanel
    gmrun
    xfce4-terminal
    brightnessctl
    gvfs
    lxterminal
    network-manager
    network-manager-gnome
    nm-tray
    adwaita-qt
    qt5ct
    fonts-quicksand
    fonts-jetbrains-mono
    fonts-hack
    fonts-cantarell
    paper-icon-theme
    papirus-icon-theme
    moka-icon-theme
    greybird-gtk-theme
    featherpad
)

has_candidate() {
    local candidate
    candidate="$(
        LC_ALL=C apt-cache policy "$1" |
            awk '/^[[:space:]]*Candidate:/ { print $2; exit }'
    )"

    [[ -n "$candidate" && "$candidate" != "(none)" ]]
}

for package in "${required_packages[@]}"; do
    has_candidate "$package" ||
        die "Required package '$package' has no installation candidate."
done

packages=("${required_packages[@]}")
skipped=()

for package in "${optional_packages[@]}"; do
    if has_candidate "$package"; then
        packages+=("$package")
    else
        skipped+=("$package")
    fi
done

if (( ${#skipped[@]} > 0 )); then
    printf '\nPackages unavailable in your configured repositories:\n' >&2
    printf '  %s\n' "${skipped[@]}" >&2
fi

apt-get install -y --no-install-recommends "${packages[@]}"

# Copy optional session environment configuration without duplicate appends.
if [[ -f "$script_dir/xsessionrc" ]]; then
    backup_file "$target_home/.xsessionrc"
    rm -f -- "$target_home/.xsessionrc"
    install -o "$target_uid" -g "$target_gid" -m 0644 \
        "$script_dir/xsessionrc" "$target_home/.xsessionrc"
else
    printf '\nNo xsessionrc beside the script; leaving ~/.xsessionrc unchanged.\n'
fi

# Debian's default Xsession startup reads ~/.xsession.
backup_file "$target_home/.xsession"
rm -f -- "$target_home/.xsession"

printf '#!/bin/sh\nexec openbox-session\n' > "$target_home/.xsession"
chown "$target_uid:$target_gid" "$target_home/.xsession"
chmod 0755 "$target_home/.xsession"

if [[ -e "$target_home/.xinitrc" || -L "$target_home/.xinitrc" ]]; then
    printf '\nWARNING: %s/.xinitrc exists and may override Debian Xsession startup.\n' \
        "$target_home"
    printf 'Review it if startx does not launch the configured Openbox session.\n'
fi

printf '\nOpenbox installation complete for %s.\n' "$account_name"
printf 'Log in as that user on a local text console and run: startx\n'
printf 'Do not run startx with sudo.\n'
