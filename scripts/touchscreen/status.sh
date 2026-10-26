#!/usr/bin/env bash
# status.sh — quick health check of the touchscreen stack.
. "$(dirname "$0")/common.sh"

echo "Kernel:        $(uname -r)"
echo "IPTS PCI:      $(lspci -nn 2>/dev/null | grep -i '8086:9d3e' || echo 'not found')"
echo "ipts module:   $(lsmod | grep -q '^ipts ' && echo loaded || echo 'NOT loaded')"
echo "DKMS:          $(dkms status ipts 2>/dev/null || echo none)"
echo "iptsd binary:  $(command -v iptsd || echo 'not installed')"
echo "iptsd units:"; systemctl list-units 'iptsd@*' --no-legend --plain | sed 's/^/  /' || true
echo "touchegg:      $(systemctl is-active touchegg 2>/dev/null || echo 'not installed')"
for c in ipts iptsd touchegg; do
    [ -f "$STATE_DIR/$c.rev" ] && echo "built $c:   $(head -n1 "$STATE_DIR/$c.rev")"
done
if [ -n "${DISPLAY:-}" ] && command -v xinput >/dev/null; then
    echo "X input devices (touch/pen):"
    xinput list --name-only | grep -Ei 'touch|stylus|pen|ipts' | sed 's/^/  /' || echo "  none"
fi
echo "Recent kernel messages:"
sudo dmesg | grep -Ei 'ipts|DMAR' | tail -n 8 | sed 's/^/  /' || true

# IOMMU fault == the one failure mode that iptsd restarts cannot fix.
# Signature from real SP5 logs:
#   DMAR: [DMA Read NO_PASID] Request device [00:16.4] fault addr 0x0
#        [fault reason 0x06] PTE Read access is not set
#   ipts ...: Failed to set memory window: -11 / switch modes: -11
#   iptsd:   IOCTL 3221374982 (= HIDIOCSFEATURE, set_mode) failed: EAGAIN
if sudo dmesg 2>/dev/null | grep -qE 'DMAR.*Request device \[00:16\.4\].*PTE Read access is not set'; then
    echo "DIAGNOSIS: the Intel IOMMU is blocking IPTS DMA (device 00:16.4)."
    echo "  Touch cannot work until the documented workaround is applied:"
    echo "  intel_iommu=off on the kernel command line, then reboot."
    echo "  See hardware/touchscreen/README.md (IOMMU section)."
fi

# Debian's hardened HID core rejects the short synthesized data report that
# the unpatched ipts driver produces:
#   ipts ...: Failed to process buffer: -22
#   hid-generic ...: Event data for report 65 was too short (7487 vs 7484)
if sudo dmesg 2>/dev/null | grep -qE 'Failed to process buffer: -22'; then
    echo "DIAGNOSIS: the ipts module is dropping every data frame against"
    echo "  Debian's buffer-length HID checks (see the '-22' section in"
    echo "  hardware/touchscreen/README.md). Rebuild with the"
    echo "  IPTS_HID_REPORT_WIRE_SIZE patch from ~/src/surfacepro5/."
fi
