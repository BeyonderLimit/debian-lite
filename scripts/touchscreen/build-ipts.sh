#!/usr/bin/env bash
# Build and install the IPTS kernel module via DKMS for the running Debian kernel.
# DKMS rebuilds it automatically on Debian kernel updates.
. "$(dirname "$0")/common.sh"

require_debian12

if ! lspci -nn 2>/dev/null | grep -qi '8086:9d3e'; then
    warn "PCI device 8086:9d3e (Surface Pro 5 IPTS/ME) not found. Is this a Surface Pro 5?"
fi

apt_install git build-essential dkms "linux-headers-$(uname -r)" pciutils

dir=$(checkout "$IPTS_REPO" "$IPTS_REV" intel-precise-touch)

cat <<'NOTE'

  Kernel patches shipped by intel-precise-touch (patches/):
    0001 mei-me: Icelake iTouch device ID  -> not needed on Surface Pro 5 (Kaby Lake)
    0002 iommu: passthrough quirk for IPTS -> only matters if Intel IOMMU is active
  Per this project's kernel policy they are NOT applied. If dmesg later shows
  DMAR faults for device 00:16.4, read docs/touchscreen.md ("IOMMU").

NOTE

if dkms status ipts 2>/dev/null | grep -q .; then
    log "Removing previously installed ipts DKMS module"
    (cd "$dir" && sudo make dkms-uninstall) || true
fi

log "Building and installing via DKMS"
(cd "$dir" && sudo make dkms-install)

log "Loading module"
sudo modprobe ipts || die "modprobe ipts failed — see: sudo dmesg | grep -i ipts"
record ipts "$dir"

sleep 2
sudo dmesg | grep -i ipts | tail -n 10 || true
log "Done. Single touch may already work; multi-touch and pen need build-iptsd.sh."
