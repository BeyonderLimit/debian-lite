
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
