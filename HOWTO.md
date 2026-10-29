Alternately you can place `install.sh` with an interactive TTY build-out selector. Place them in the root of your `debian-lite` checkout.

The installer dispatches your existing scripts rather than duplicating their implementation. It runs desktop setup and kernel updates with sudo, while keeping theming and touchscreen builds under your normal user account, matching the scripts’ privilege requirements. [raw.githubusercontent](https://raw.githubusercontent.com/BeyonderLimit/debian-lite/main/openbox-setup.sh)

## How to run

From your normal desktop user’s account:

```bash
cd ~/debian-lite
bash -n install.sh
chmod +x install.sh
./install.sh
```

Do not launch the installer with `sudo`; it requests elevated privileges when needed.

The first menu offers:

```text
1) Openbox desktop
2) Openbox desktop + theming
3) Surface Pro 5 touch stack only
4) Kernel update only
5) Custom selection
q) Quit
```

A second prompt lets you keep the profile defaults or replace them with space-separated task numbers. The installer then displays the execution plan and requires you to type `RUN`.

## Execution and safeguards

The selected scripts run sequentially—not concurrently. This avoids launching overlapping package-installation and driver-build tasks.

The generated launcher also:

- Checks selected script syntax and known local dependencies before execution.
- Uses an explicit script allowlist rather than executing every `.sh` file it finds.
- Preserves interactive input for sudo and component-script confirmations.
- Writes a separate log for each task.
- Stops when a task or its logging pipeline returns an error.
- Does not itself reboot, run `autoremove`, or add repositories.
- Rejects kernel updates combined with touchscreen builds in the same run. Your IPTS builder targets the currently running kernel, so upgrading, rebooting, and testing first avoids building solely against the old running kernel. [raw.githubusercontent](https://raw.githubusercontent.com/BeyonderLimit/debian-lite/main/scripts/touchscreen/build-ipts.sh)

## Repository issues accounted for

I inspected the current scripts and deliberately excluded three problematic entry points:

| Script | Reason |
|---|---|
| `openbox-minimal.sh` | Starts with `nu#!/usr/bin/env bash` and resolves its helper directory outside the repository. The launcher uses `openbox-setup.sh` instead.  [raw.githubusercontent](https://raw.githubusercontent.com/BeyonderLimit/debian-lite/main/openbox-minimal.sh) |
| `surface-openbox.sh` | Includes graphical commands, fixed filesystem paths, and external installers, making it unsuitable as a dependable TTY build-out entry point without further repair.  [raw.githubusercontent](https://raw.githubusercontent.com/BeyonderLimit/debian-lite/main/surface-openbox.sh) |
| `install-surface-touchscreen.sh` | Runs a foreground daemon against hard-coded `/dev/hidraw2` and then requests a reboot. The launcher calls the individual touchscreen builders instead.  [raw.githubusercontent](https://raw.githubusercontent.com/BeyonderLimit/debian-lite/main/install-surface-touchscreen.sh) |

The README explains these exclusions, the touchscreen profile’s hardware restrictions, kernel sequencing, logging, and recovery.

The generated `install.sh` passed `bash -n`. It has not been installation-tested on your hardware, and the launcher does not repair or sandbox the component scripts.
