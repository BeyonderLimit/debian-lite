#!/usr/bin/env bash
# Build Touchégg from the pinned tag as a local .deb (removable with apt).
# Touchégg is not packaged in Debian 12.
. "$(dirname "$0")/common.sh"

require_debian12

apt_install git build-essential cmake debhelper fakeroot \
    libudev-dev libinput-dev libpugixml-dev libcairo2-dev libx11-dev \
    libxtst-dev libxrandr-dev libxi-dev libglib2.0-dev libgtk-3-dev

dir=$(checkout "$TOUCHEGG_REPO" "$TOUCHEGG_REV" touchegg)

log "Building Debian package"
(cd "$dir" && dpkg-buildpackage -rfakeroot -us -uc -b)

deb=$(ls -t "$SP5_SRC_DIR"/touchegg_*.deb | head -n1)
log "Installing $deb"
sudo apt-get install -y "$deb"
record touchegg "$dir"

sudo systemctl daemon-reload
sudo systemctl enable --now touchegg.service

FEAT="${XDG_CONFIG_HOME:-$HOME/.config}/surfacepro5-openbox/features"
mkdir -p "$FEAT" && touch "$FEAT/gestures"
log "Gesture feature enabled. The client starts from Openbox autostart on next login."
