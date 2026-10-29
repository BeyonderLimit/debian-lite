# Debian Lite

Interactive Debian/Openbox build-out launcher for the existing scripts in this repository.

## Quick start from a TTY

Use your normal desktop account, not a root login. The account needs sudo access.
From a Debian text console, install the download tools if necessary:

```bash
sudo apt-get update
sudo apt-get install git sudo ca-certificates
git clone https://github.com/BeyonderLimit/debian-lite.git
cd debian-lite
```

Place the supplied `install.sh` and this README at the repository root. Review the
scripts you intend to run before giving them sudo access. Then:

```bash
bash -n install.sh
chmod +x install.sh
./install.sh
```

Do not use `sudo ./install.sh`, pipe it to another program, or run it with `sh`.
Use Bash. A local TTY is recommended; an interactive SSH terminal also works, but
retain recovery access before changing networking, drivers, or the kernel.

## Select a build-out

The first menu supplies defaults:

| Build-out | Default tasks |
| --- | --- |
| Openbox desktop | 1 |
| Openbox desktop + theming | 1, 2 |
| Surface Pro 5 touch stack only | 4, 5, 7 |
| Kernel update only | 3 |
| Custom | None; enter task numbers |

The second prompt lets you replace the defaults with space-separated task numbers.
Press Enter to keep the defaults. For example, `1 2` installs the desktop and then
copies its configuration; `4 5 6 7` builds the touchscreen stack with gestures.
Numbers are deduplicated and executed in numerical order, not the order typed.
Read the displayed plan, then type `RUN` to start. Cancellation before that point
runs no component scripts.

The scripts run sequentially, not concurrently: the launcher never starts two
package/build tasks at once. It does not coordinate with unrelated package jobs
already running on the machine. Let other package managers finish first.

## Tasks and privileges

| Task | Existing script | Execution context |
| --- | --- | --- |
| 1: Desktop | `openbox-setup.sh` | sudo/root, desktop username passed explicitly |
| 2: Theming | `openbox-theming.sh` | Normal user |
| 3: Kernel | `kernel-update.sh` | sudo/root; optional `--backports` |
| 4: IPTS module | `scripts/touchscreen/build-ipts.sh` | Normal user; script uses sudo |
| 5: Touch/pen daemon | `scripts/touchscreen/build-iptsd.sh` | Normal user; script uses sudo |
| 6: Gestures | `scripts/touchscreen/build-touchegg.sh` | Normal user; script uses sudo |
| 7: Diagnostics | `scripts/touchscreen/status.sh` | Normal user; script uses sudo |

The theming task can run alone on an existing desktop. It needs the root-level
`openbox/`, `volumeicon/volumeicon`, `dunst/dunstrc`, and `tint2/tint2rc` sources.
The current theming script backs up overwritten files using numbered backups.
Desktop setup optionally reads `xsessionrc` beside its script and configures
`~/.xsession`; an existing `~/.xinitrc` may override session selection.

The launcher changes to the repository root before dispatch. It uses an explicit
allowlist; it never blindly runs every `.sh` file found in the checkout. Add new
tasks only after reviewing their privileges, arguments, dependencies and effects.

## Kernel upgrades and touchscreen builds

Run task 3 separately from tasks 4–6. Reboot into and test the intended kernel
before returning to build the touchscreen stack: the IPTS builder targets the
currently running kernel using `uname -r`, not merely the newest installed kernel.
The launcher rejects a combined kernel/build plan.

The kernel task keeps its own candidate display, simulation and `INSTALL`
confirmation. A zero exit status can also mean that its internal confirmation was
cancelled: inspect its output. Choosing backports only passes `--backports`; the
launcher does not add repositories or override the kernel script's release policy.
It does not determine hardware compatibility or guarantee that a new kernel boots.
Keep a known-working fallback and recovery access; do not automatically autoremove
old kernels.

The touchscreen scripts currently target Surface Pro 5 hardware. Do not choose
this profile merely because a machine has a touchscreen or is another Surface
model. The launcher requires Debian 12 and explicit hardware acknowledgement for
tasks 4–6; this is a conservative launcher policy, not hardware detection.
The module/daemon helpers also need `scripts/touchscreen/common.sh` and
`scripts/touchscreen/sources.conf`. Review the repositories and revisions pinned in
`sources.conf` before building third-party code. Network access is required.
Secure Boot may require module signing/enrolment; this launcher does not do it.
If selecting task 5 without task 4, confirm that IPTS is already installed and works.

The touch profile builds the module and daemon and runs diagnostics. It does not
copy the auto-rotation configuration from the legacy wrapper, install a complete
desktop, or automatically repair hardware-specific faults.

## Legacy entry points deliberately not run

The inspected upstream revision contained these issues. Recheck them if the
repository changes:

- `openbox-minimal.sh` starts with `nu#!/usr/bin/env bash`, computes its helper root
  as the parent of the repository, and sources a helper there. `bash -n` alone does
  not catch the malformed first line as an execution error. Repair and test it
  before adding it to the launcher. The menu uses `openbox-setup.sh` instead; that
  script has a broad optional application list, not a strictly minimal package set.
- `surface-openbox.sh` includes GUI calls, a fixed `~/debian-lite/` location, an
  absolute `/scripts/surface_rotate.sh` source path, external installers and no
  fail-fast setup. It is not a reliable unattended TTY entry point.
- `install-surface-touchscreen.sh` invokes a foreground daemon with a hard-coded
  `/dev/hidraw2` device and then requests an automatic reboot. It is bypassed in
  favour of the individual build/status scripts.

These files are not modified by the launcher. Likewise, selecting tasks 1 and 2
does not resolve differences between the repository's `config/openbox/` tree and
its root-level `openbox/` tree: task 2 uses the latter.

## Logging, interruption and recovery

Each run creates a private, unique directory under:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/debian-lite/
```

Each selected task has its own combined stdout/stderr log. Component input remains
connected to the terminal, so sudo and kernel prompts remain interactive. Sudo
credentials may expire during a long build and prompt again. Logs can contain
hardware details, paths and other sensitive output; review before sharing them.

The launcher stops on the first nonzero task or logging pipeline result. Completed
steps are not rolled back. It does not resume automatically or promise idempotent
builds. After interruption, inspect the log and package state before retrying:

```bash
sudo dpkg --audit
```

Do not delete APT/dpkg lock files to bypass an active package manager. Resolve any
reported package problems and rerun only the necessary tasks. A successful process
exit is not proof that every driver, service or desktop component is working.

The launcher itself never reboots, runs autoremove, edits repository definitions,
or starts a graphical session. Existing child scripts remain trusted executable
code: review them again after pulling updates; this is not a sandbox.

## Start the desktop and validate

After successful desktop setup, log in as the desktop user on a local console:

```bash
startx
```

Do not run `sudo startx`. Check application startup and the Openbox autostart file.
For a kernel change, arrange recovery access and reboot manually when ready:

```bash
sudo systemctl reboot
# After login:
uname -r
```

Test networking, graphics, audio, storage, suspend/resume and, where relevant,
touch/pen input before removing any fallback kernel. Run menu task 7 to inspect the
touch stack; diagnostics report observations, not a guaranteed passing verdict.

## Verification scope

This launcher is designed against the repository scripts reviewed on October 29,
2026. It has a Bash syntax check, but has not been exercised on your machine or
hardware. Test on a recoverable system first. Repository changes may require
updating task definitions and preflight checks.


