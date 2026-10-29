
Yes—but the safe approach is to detect the system architecture and use Debian’s kernel **metapackages**, rather than hard-coding a kernel version. For a typical 64-bit Intel/AMD PC, these are `linux-image-amd64` and `linux-headers-amd64`; they track Debian’s kernel and corresponding headers. [packages.debian](https://packages.debian.org/bookworm-backports/linux-image-amd64)

There is an important limitation: scanning hardware cannot guarantee that a newer kernel will work correctly. Package selection and dependency checks do not prove that Wi-Fi, graphics, suspend, storage, or third-party drivers will function after reboot. Debian also cautions that backports receive less extensive testing than stable packages. [backports.debian](https://backports.debian.org/Instructions/)

## Recommended replacement

Keep kernel upgrades separate from desktop installation and theming. This script:

- Detects Debian release and package architecture.
- Reports hardware using diagnostic tools already installed.
- Uses APT’s candidate selection, respecting configured repositories and pinning.
- Supports an explicit backports option.
- Shows a simulated installation before requesting confirmation.
- Prevents package removals during installation.
- Marks the running packaged kernel as manually installed to help preserve a fallback.
- Does not automatically reboot or run `autoremove`.

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

# Usage:
#   sudo bash upgrade-kernel.sh
#   sudo bash upgrade-kernel.sh --backports
#
# Default: use APT's normal candidates.
# --backports: explicitly target the matching backports suite.
#
# This script does not add repositories or guarantee hardware compatibility.

trap 'printf "Error on line %s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

(( EUID == 0 )) || die "Run this script with sudo or as root."

use_backports=false
case "${1:-}" in
    "") ;;
    --backports) use_backports=true ;;
    *) die "Usage: bash $0 [--backports]" ;;
esac

(( $# <= 1 )) || die "Too many arguments."

[[ -r /etc/os-release ]] || die "Cannot identify the operating system."
. /etc/os-release

[[ "${ID:-}" == debian ]] ||
    die "This script supports Debian, not derivatives."

codename="${VERSION_CODENAME:-}"
[[ -n "$codename" ]] || die "Cannot determine Debian release codename."

arch="$(dpkg --print-architecture)"

# Deliberately restrict automatic selection to these common generic flavours.
case "$arch" in
    amd64)
        image_meta=linux-image-amd64
        headers_meta=linux-headers-amd64
        ;;
    arm64)
        image_meta=linux-image-arm64
        headers_meta=linux-headers-arm64
        ;;
    *)
        die "Architecture '$arch' needs an explicitly chosen kernel flavour."
        ;;
esac

running_kernel="$(uname -r)"

printf '\nSystem information\n'
printf '  Distribution: %s\n' "${PRETTY_NAME:-Debian}"
printf '  Architecture: %s\n' "$arch"
printf '  Running kernel: %s\n' "$running_kernel"

if command -v lscpu >/dev/null 2>&1; then
    printf '\nCPU information\n'
    lscpu
fi

if command -v lspci >/dev/null 2>&1; then
    printf '\nPCI hardware and current drivers\n'
    lspci -nnk
fi

if command -v lsusb >/dev/null 2>&1; then
    printf '\nUSB hardware\n'
    lsusb
fi

if command -v dkms >/dev/null 2>&1; then
    printf '\nCurrent DKMS status\n'
    dkms status
fi

if command -v mokutil >/dev/null 2>&1; then
    printf '\nSecure Boot status\n'
    mokutil --sb-state || true
fi

printf '\nBoot filesystem space\n'
df -h /boot /

# Avoid proceeding with an already-incomplete package transaction.
audit="$(dpkg --audit)"
if [[ -n "$audit" ]]; then
    printf '%s\n' "$audit" >&2
    die "Resolve the package problems above before upgrading the kernel."
fi

# APT's Error-Mode=any makes repository refresh failures fatal.
apt-get -o APT::Update::Error-Mode=any update

target_options=()

if "$use_backports"; then
    # As of October 2026, bookworm-backports is past its support cutoff.
    # Do not automatically opt into that unsupported suite.
    case "$codename" in
        trixie)
            suite="${codename}-backports"
            ;;
        bookworm)
            die "bookworm-backports support ended August 9, 2026. \
Do not use it as a maintained upgrade channel."
            ;;
        *)
            die "Backports support for '$codename' must be reviewed manually."
            ;;
    esac

    # Fail if the suite was not already configured; do not add it silently.
    apt-cache -t "$suite" policy "$image_meta" "$headers_meta"
    target_options=(-t "$suite")
fi

printf '\nKernel package candidates and repository priorities\n'
apt-cache "${target_options[@]}" policy "$image_meta" "$headers_meta"

packages=("$image_meta" "$headers_meta")

printf '\nSimulated installation — review all changes carefully\n'
apt-get --simulate --no-remove \
    "${target_options[@]}" install "${packages[@]}"

printf '\nThis cannot verify hardware compatibility before reboot.\n'
printf 'Keep a working boot-menu fallback and recovery access.\n'

read -r -p 'Type INSTALL to continue: ' reply
[[ "$reply" == INSTALL ]] || {
    printf 'Cancelled.\n'
    exit 0
}

# Preserve the currently running kernel if it has the standard Debian name.
running_package="linux-image-${running_kernel}"
if dpkg-query -W -f='${Status}\n' "$running_package" 2>/dev/null |
    grep -qx 'install ok installed'
then
    apt-mark manual "$running_package"
else
    printf '\nWARNING: Could not identify the running kernel as %s.\n' \
        "$running_package"
    printf 'Verify that you have a bootable fallback before rebooting.\n'
fi

# No -y: retain APT's final interactive confirmation.
# --no-remove: abort rather than remove packages to resolve dependencies.
apt-get --no-remove \
    "${target_options[@]}" install "${packages[@]}"

printf '\nInstalled kernel metapackages\n'
dpkg-query -W -f='${Package} ${Version}\n' "${packages[@]}"

if command -v dkms >/dev/null 2>&1; then
    printf '\nDKMS status after installation — inspect for missing modules\n'
    dkms status
fi

printf '\nKernel package installation completed.\n'
printf 'The currently running kernel is still: %s\n' "$(uname -r)"
printf 'Review installation output, driver status, and boot configuration.\n'
printf 'Reboot manually when ready: systemctl reboot\n'
printf 'After reboot, check the active kernel with: uname -r\n'
printf 'Do not remove your previous working kernel until testing is complete.\n'
```

The metapackage mechanism selects the kernel package and matching headers; explicitly targeting backports follows Debian’s documented `apt-get -t <suite>` workflow. The default mode instead leaves selection to your existing APT policy—it does not indiscriminately choose the highest version in every repository. [packages.debian](https://packages.debian.org/bookworm-backports/linux-image-amd64)

## Important for your Debian 12 example

Your hard-coded `+deb12` package names suggest Debian 12. As of October 29, 2026, Debian’s published support cutoff for `bookworm-backports`—August 9, 2026—has already passed. A package still being present in a repository does not make that repository a maintained kernel-update channel. [backports.debian](https://backports.debian.org/Instructions/)

Consequently:

- Do not automatically add Debian 13 repositories to Debian 12 just to obtain a newer kernel.
- Do not interpret “APT has a candidate” as “this is newer than my running kernel” or “this is supported.” On a system already running a newer backports or custom kernel, the normal Debian 12 metapackage may track an older kernel series. Debian’s package listings distinguish the Bookworm kernel metapackage from its backports counterpart. [packages.debian](https://packages.debian.org/bookworm-backports/linux-image-amd64)
- If you need a maintained newer kernel, plan a supported distribution upgrade rather than silently mixing releases.

## What to remove from your original script

Remove the three version-specific entries:

```bash
linux-headers-6.12.111+deb12-amd64
linux-image-6.12.111+deb12-amd64
linux-source-6.12
```

Use the image and headers metapackages instead. The headers support external module builds; installing the complete kernel source is a separate development task, not the mechanism for tracking kernel updates. [packages.debian](https://packages.debian.org/bookworm-backports/linux-image-amd64)

Also remove:

```bash
sudo apt autoremove -y && sudo reboot now
```

A successful package transaction is not a successful hardware test. Keep the old kernel, reboot deliberately, and test storage, networking, graphics, audio, and suspend before doing cleanup. Preserving the earlier kernel provides a recovery path if the new one fails. [reddit](https://www.reddit.com/r/debian/comments/1gy1lh4/upgrading_debian_system_with_custom_kernel/)

# Theme Configuration

under **sudo**, `$USER` usually becomes `root`, so `/home/$USER` points to `/home/root`, not your desktop user’s home directory. [sudo](https://www.sudo.ws/docs/man/1.8.30/sudoers.man/)

Your script also:
- Uses `mkdir` without `-p`, so missing parent directories or existing directories cause errors.
- Looks for source files relative to the current working directory, not the script’s directory.
- Uses `openbox/*.*`, which misses extensionless files such as `autostart`.
- Prints “configured” even if earlier commands fail.

## Corrected script

This version runs as your desktop user. If you accidentally launch it with `sudo`, it switches back to the invoking user before copying anything.

Existing configuration files are backed up before being overwritten.

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

trap 'printf "Error on line %s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

script_path="$(readlink -f -- "${BASH_SOURCE[0]}")"
script_dir="$(dirname -- "$script_path")"

# These are user configuration files: do not install them as root.
if (( EUID == 0 )); then
    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != root ]]; then
        exec sudo -H -u "$SUDO_USER" -- bash "$script_path"
    fi

    die "Run this script as your desktop user, not directly as root."
fi

[[ -n "${HOME:-}" && -d "$HOME" ]] ||
    die "HOME is unset or is not an existing directory."

config_home="${XDG_CONFIG_HOME:-"$HOME/.config"}"

[[ "$config_home" == /* ]] ||
    die "XDG_CONFIG_HOME must be an absolute path."

# Validate sources before changing any configuration.
[[ -d "$script_dir/openbox" ]] ||
    die "Missing source directory: $script_dir/openbox"

for source_file in \
    volumeicon/volumeicon \
    dunst/dunstrc \
    tint2/tint2rc
do
    [[ -f "$script_dir/$source_file" ]] ||
        die "Missing source file: $script_dir/$source_file"
done

printf 'Creating configuration directories...\n'

mkdir -p -- \
    "$config_home/openbox" \
    "$config_home/volumeicon" \
    "$config_home/tint2" \
    "$config_home/dunst"

printf 'Copying configuration files...\n'

# GNU cp --backup=numbered preserves overwritten files as .~1~, .~2~, etc.
# Copy the directory contents, including extensionless and hidden files.
cp -R --backup=numbered -- \
    "$script_dir/openbox/." "$config_home/openbox/"

cp --backup=numbered -- \
    "$script_dir/volumeicon/volumeicon" \
    "$config_home/volumeicon/volumeicon"

cp --backup=numbered -- \
    "$script_dir/dunst/dunstrc" \
    "$config_home/dunst/dunstrc"

cp --backup=numbered -- \
    "$script_dir/tint2/tint2rc" \
    "$config_home/tint2/tint2rc"

printf '\nOpenbox configuration installed for %s.\n' "$(id -un)"
printf 'Destination: %s\n' "$config_home"
```

The script uses GNU Coreutils’ directory creation and copying commands; these are standard Debian utilities. [wiki.debian](https://wiki.debian.org/coreutils)

## Expected directory layout

Keep the script alongside your configuration directories:

```text
desktop-config/
├── configure-theme.sh
├── openbox/
│   ├── autostart
│   ├── rc.xml
│   └── menu.xml
├── volumeicon/
│   └── volumeicon
├── dunst/
│   └── dunstrc
└── tint2/
    └── tint2rc
```

Run it as your normal desktop user:

```bash
bash configure-theme.sh
```

**One Note:** This configuration deployment cannot verify the contents of your theme files. If the script completes yet the appearance remains wrong, the next thing to inspect is the copied `openbox/rc.xml` and `openbox/autostart`, along with any error output from the applications they launch.
