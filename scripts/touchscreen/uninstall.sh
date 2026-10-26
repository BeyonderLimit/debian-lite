#!/usr/bin/env bash
# uninstall.sh [ipts|iptsd|touchegg|all] — remove the opt-in touch components.
# Source checkouts in $SP5_SRC_DIR are left in place.
. "$(dirname "$0")/common.sh"

what=${1:-all}

un_touchegg() {
    log "Removing Touchégg"
    sudo systemctl disable --now touchegg.service 2>/dev/null || true
    sudo apt-get remove -y touchegg || true
    rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/surfacepro5-openbox/features/gestures"
    rm -f "$STATE_DIR/touchegg.rev"
}

un_iptsd() {
    log "Removing iptsd"
    for u in $(systemctl list-units 'iptsd@*' --no-legend --plain | awk '{print $1}'); do
        sudo systemctl stop "$u" || true
    done
    if [ -d "$SP5_SRC_DIR/iptsd/build" ]; then
        sudo ninja -C "$SP5_SRC_DIR/iptsd/build" uninstall || true
    else
        warn "No iptsd build dir; remove /usr/local/bin/iptsd* and the iptsd udev rule manually."
    fi
    sudo systemctl daemon-reload
    sudo udevadm control --reload-rules
    rm -f "$STATE_DIR/iptsd.rev"
}

un_ipts() {
    log "Removing IPTS DKMS module"
    sudo modprobe -r ipts 2>/dev/null || true
    if [ -d "$SP5_SRC_DIR/intel-precise-touch" ]; then
        (cd "$SP5_SRC_DIR/intel-precise-touch" && sudo make dkms-uninstall) || true
    fi
    rm -f "$STATE_DIR/ipts.rev"
}

case "$what" in
    touchegg) un_touchegg ;;
    iptsd)    un_iptsd ;;
    ipts)     un_ipts ;;
    all)      un_touchegg; un_iptsd; un_ipts ;;
    *)        die "usage: $0 [ipts|iptsd|touchegg|all]" ;;
esac
log "Done."
