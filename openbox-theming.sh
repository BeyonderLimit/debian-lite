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
