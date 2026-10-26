# Touchscreen and pen: opt-in hardware component

This directory is **independent of the desktop configuration**. Nothing here is run by `install.sh`. Every external component is built from an explicit revision pinned in [`sources.conf`](sources.conf). Its source tree stays in `~/src/surfacepro5/` (override with `SP5_SRC_DIR`) so you can inspect it, patch it and rebuild it.

## What the Surface Pro 5 actually uses

| Piece | Surface Pro 5 (2017) | Notes |
|---|---|---|
| Touch controller | **IPTS** (Intel Precise Touch & Stylus), via the Intel ME, PCI `8086:9d3e` | |
| Kernel driver | **intel-precise-touch** (`ipts.ko`) | Not in the stock Debian kernel; built out-of-tree with DKMS |
| Userspace | **iptsd** | Turns raw heatmaps into multi-touch and pen events through uinput |
| ITHC (`quo/ithc-linux`) | **Not used** | For Lakefield/Tiger Lake and newer devices (Pro 7+, Pro 8, …) |
| `intremap=nosid` | **Not needed** | An ITHC workaround |

Upstream lists Surface Pro 5 touch and pen as "requires linux-surface kernel". This project tries the out-of-tree route on the stock kernel instead. Treat it as **experimental**, and please file a hardware report with `./status.sh` output.

## Build order

```sh
cd script/touchscreen
./build-ipts.sh       # 1. kernel module (DKMS) -> check single touch
./build-iptsd.sh      # 2. iptsd                -> multi-touch + pen
./build-touchegg.sh   # 3. optional gestures (local .deb, removable with apt)
./status.sh           # health check at any time
```

### 1. `build-ipts.sh`

- Installs `dkms`, `build-essential` and `linux-headers-$(uname -r)`.
- Checks out `IPTS_REV` and runs upstream's `make dkms-install`, then `modprobe ipts`.
- DKMS rebuilds the module automatically when Debian ships a new kernel. If a kernel update breaks the build, see [Recovery](../../docs/recovery.md).

Upstream also ships two **kernel patches** in `patches/`. Under the kernel policy they are not applied:

| Patch | Relevance to Surface Pro 5 |
|---|---|
| `0001-mei-me-Add-Icelake-device-ID-for-iTouch` | None. Adds an Ice Lake PCI ID; the SP5 is Kaby Lake |
| `0002-iommu-Use-IOMMU-passthrough-mode-for-IPTS` | Only matters if the Intel IOMMU is active for device `8086:9d3e` |

#### IOMMU

If touch fails and `sudo dmesg | grep DMAR` shows faults like `Request device [00:16.4] … PTE Read access is not set`, the IOMMU is blocking IPTS DMA. On the kernel side you will also see `ipts …: Failed to set memory window: -11` / `Failed to switch modes: -11`, and iptsd crashes seconds after start with `IOCTL 3221374982 failed: …` (3221374982 = `HIDIOCSFEATURE`, the mode switch). The service then cannot recover by restarting: the IOMMU fault makes every probe fail with `EAGAIN`. `./status.sh` prints this diagnosis when it detects the signature. That is the problem patch 0002 fixes inside the kernel. You have two choices, and **this project automates neither**:

1. Add `intel_iommu=off` to `GRUB_CMDLINE_LINUX_DEFAULT` yourself, run `sudo update-grub` and reboot. Keep a note of the change, because it affects the whole system, not only touch.
2. Build a patched kernel. That is outside the scope of this repository.

### Debian kernel vs `ipts` "Failed to process buffer: -22"

Once the IOMMU caveat is fixed, a **newer Debian 12 point release (6.1.0-54 and later)** can hit a second incompatibility. Debian backported HID-core buffer-length checks: instead of zero-padding short reports, the kernel now rejects them with

```
ipts …: Failed to process buffer: -22
hid-generic …: Event data for report 65 was too short (7487 vs 7484)
```

The out-of-tree `ipts` driver synthesizes the raw-data report (ID 65) from only `IPTS_HID_REPORT_DATA_SIZE` bytes, 3 short of what its own report descriptor declares (1 numbered report-ID byte + 2 scan-time bytes + 7485 data bytes = 7488). Every heatmap frame is then dropped and `iptsd` never sees touch data. The `intel-precise-touch` source tree in `~/src/surfacepro5/` ships with a small local patch (`IPTS_HID_REPORT_WIRE_SIZE`) that passes the full 7488-byte buffer, matching what native-HID Surface devices send. If you rebuild the tree from a fresh checkout, re-apply the same three-line change (see `spec-hid.h`, `hid.c` `ipts_hid_handle_frame()`, `resources.c`). `./status.sh` flags the DMAR/IOMMU and the `-22` signatures with their diagnosis.

### 2. `build-iptsd.sh`

- Installs the Debian 12 build dependencies (`meson`, `ninja-build`, `libcli11-dev`, `libeigen3-dev`, `libfmt-dev`, `libinih-dev`, `libmsgsl-dev`, `libspdlog-dev`). Debug and plot tools are turned off, so SDL2, cairomm, glslc, OpenSSL and curl are **not** needed.
- Installs to `/usr/local` with upstream's **udev rule + `iptsd@.service` template**. udev starts one `iptsd@<hidraw>.service` per touch device, at boot and on hot-plug.
- Do **not** write a custom `iptsd.service` with `ExecStart=/usr/local/bin/iptsd` and no argument. iptsd v3 needs the hidraw device path, which the template unit supplies.

Manual test, without the service:

```sh
sudo iptsd-find-hidraw                 # e.g. /dev/hidraw2
sudo systemctl stop 'iptsd@*'
sudo iptsd /dev/hidraw2                # Ctrl+C to stop
```

Configuration: `/etc/iptsd.conf` (installed sample) or drop-ins in `/etc/iptsd.d/`.

### 3. `build-touchegg.sh`

Touchégg is not packaged for Debian 12. The script builds a `.deb` from `TOUCHEGG_REV` with upstream's `debian/` directory, installs it, enables the system daemon (`touchegg.service`) and sets the `gestures` feature flag so Openbox autostart launches the client. The gesture map lives in `config/touchegg/touchegg.conf`.

## Updating a pinned revision

1. Edit the revision in `sources.conf`.
2. Re-run the matching build script. It fetches, checks out the new revision and rebuilds.
3. Record the change in `CHANGELOG.md`.

If a checkout has local modifications, the scripts build your modified tree instead of switching revisions, and print a warning.

## Removal

```sh
./uninstall.sh touchegg    # or: iptsd | ipts | all
```

Source trees in `~/src/surfacepro5/` are left in place.
