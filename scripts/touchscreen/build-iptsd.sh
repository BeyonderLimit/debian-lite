#!/usr/bin/env bash
# Build and install iptsd (multi-touch + pen) from the pinned revision.
# Uses iptsd's own udev rule + iptsd@.service template: udev starts one
# instance per matching hidraw device. No custom unit file is needed.
. "$(dirname "$0")/common.sh"

require_debian12

lsmod | grep -q '^ipts ' || warn "ipts module not loaded — run build-ipts.sh first."

# Debian 12 packages for every iptsd dependency (meson falls back to wraps
# if any is too old). Debug/plot tools are disabled, so no SDL2/cairomm.
apt_install git build-essential meson ninja-build cmake pkg-config udev \
    libcli11-dev libeigen3-dev libfmt-dev libinih-dev libmsgsl-dev libspdlog-dev

dir=$(checkout "$IPTSD_REPO" "$IPTSD_REV" iptsd)

log "Configuring (prefix /usr/local, debug tools off)"
rm -rf "$dir/build"
(cd "$dir" && meson setup build --prefix=/usr/local -Ddebug_tools=[] -Dwerror=false)

log "Compiling"
ninja -C "$dir/build"

log "Installing (sudo)"
sudo ninja -C "$dir/build" install
record iptsd "$dir"

sudo systemctl daemon-reload
sudo udevadm control --reload-rules

log "Detected IPTS hidraw device(s):"
sudo /usr/local/bin/iptsd-find-hidraw || warn "No device found — is the ipts module loaded?"

log "Triggering udev to start iptsd@ instances"
sudo udevadm trigger --subsystem-match=hidraw --action=add
sleep 2
systemctl list-units 'iptsd@*' --no-legend || true

log "Done. Test now; it also starts automatically on every boot."
log "Uninstall with: hardware/touchscreen/uninstall.sh iptsd"
