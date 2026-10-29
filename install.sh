#!/usr/bin/env bash
set -Eeuo pipefail
# Interactive dispatcher; run as the desktop user, not root.
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
(( EUID != 0 )) || die 'Run as your desktop user: bash install.sh (without sudo).'
[[ -t 0 && -t 1 ]] || die 'An interactive terminal is required; do not pipe this script.'
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd -- "$ROOT"
[[ -r /etc/os-release ]] || die 'Cannot identify OS.'
. /etc/os-release
[[ ${ID:-} == debian ]] || die 'Debian is required.'
for tool in sudo bash tee date getent; do
    command -v "$tool" >/dev/null || die "Missing command: $tool"
done
user="$(id -un)"
entry="$(getent passwd "$user")"
IFS=: read -r _ _ _ _ _ account_home _ <<< "$entry"
[[ "$HOME" == "$account_home" ]] || die 'HOME does not match the logged-in account.'
umask 077

# Explicit allowlist: never discover and execute arbitrary repository scripts.
files=('' 'openbox-setup.sh' 'openbox-theming.sh' 'kernel-update.sh'
       'scripts/touchscreen/build-ipts.sh' 'scripts/touchscreen/build-iptsd.sh'
       'scripts/touchscreen/build-touchegg.sh' 'scripts/touchscreen/status.sh')
labels=('' 'Openbox desktop packages and X session' 'User Openbox/tint2/dunst/volumeicon configuration'
        'Kernel metapackages' 'Surface Pro 5 IPTS DKMS module (running kernel)'
        'Surface Pro 5 iptsd touch and pen daemon' 'Optional Touchegg gestures'
        'Touchscreen status report')
selected=()
printf '\nDebian Lite build-out selector\nUser: %s | OS: %s | Kernel: %s\n' \
    "$user" "${PRETTY_NAME:-Debian}" "$(uname -r)"
printf '\n1) Openbox desktop\n2) Openbox desktop + theming\n3) Surface Pro 5 touch stack only\n4) Kernel update only\n5) Custom selection\nq) Quit\n'
read -r -p 'Build-out: ' profile
case "$profile" in
    1) selected=(1) ;;
    2) selected=(1 2) ;;
    3) selected=(4 5 7) ;;
    4) selected=(3) ;;
    5) selected=() ;;
    q|Q) exit 0 ;;
    *) die 'Invalid build-out.' ;;
esac
printf '\nAvailable tasks, executed in the order listed:\n'
for i in {1..7}; do printf '  %s) %s\n' "$i" "${labels[i]}"; done
printf '\nProfile defaults: %s\n' "${selected[*]:-none}"
printf 'Enter replacement task numbers separated by spaces, or Enter for defaults.\n'
read -r -p 'Tasks: ' answer
if [[ -n "$answer" ]]; then read -r -a selected <<< "$answer"; fi
(( ${#selected[@]} )) || die 'No tasks selected.'
declare -A chosen=()
for i in "${selected[@]}"; do
    [[ "$i" =~ ^[1-7]$ ]] || die "Invalid task number: $i"
    chosen[$i]=1
done
selected=()
for i in {1..7}; do [[ ${chosen[$i]:-} ]] && selected+=("$i"); done

# Kernel upgrades and running-kernel module builds belong in separate sessions.
if [[ ${chosen[3]:-} && ( ${chosen[4]:-} || ${chosen[5]:-} || ${chosen[6]:-} ) ]]; then
    die 'Run the kernel upgrade separately, reboot/test, then build touchscreen modules.'
fi
backports=false
if [[ ${chosen[3]:-} ]]; then
    read -r -p 'Explicitly use configured backports? [y/N]: ' answer
    case "$answer" in y|Y) backports=true ;; esac
fi
if [[ ${chosen[4]:-} || ${chosen[5]:-} || ${chosen[6]:-} ]]; then
    [[ ${VERSION_ID:-} == 12 ]] || die 'This launcher restricts the current touchscreen builders to Debian 12.'
    printf '\nThese drivers are Surface Pro 5-specific, not generic Surface support.\n'
    printf 'They download/build third-party source and may require Secure Boot signing.\n'
    read -r -p 'Type SURFACE-PRO-5 to confirm you reviewed your hardware: ' answer
    [[ "$answer" == SURFACE-PRO-5 ]] || die 'Hardware confirmation cancelled.'
    if [[ ${chosen[5]:-} && ! ${chosen[4]:-} ]]; then
        read -r -p 'Type IPTS-READY if a working IPTS module is already installed: ' answer
        [[ "$answer" == IPTS-READY ]] || die 'Install/verify IPTS first.'
    fi
fi

# Validate selected entry points and known local dependencies before any task.
check_file() { [[ -f "$ROOT/$1" && -r "$ROOT/$1" ]] || die "Missing/unreadable file: $1"; }
for i in "${selected[@]}"; do
    check_file "${files[i]}"
    bash -n "$ROOT/${files[i]}" || die "Syntax check failed: ${files[i]}"
done
if [[ ${chosen[2]:-} ]]; then
    [[ -d "$ROOT/openbox" ]] || die 'Missing openbox directory.'
    for f in volumeicon/volumeicon dunst/dunstrc tint2/tint2rc; do check_file "$f"; done
fi
if [[ ${chosen[4]:-} || ${chosen[5]:-} || ${chosen[6]:-} || ${chosen[7]:-} ]]; then
    check_file scripts/touchscreen/common.sh
    check_file scripts/touchscreen/sources.conf
    bash -n "$ROOT/scripts/touchscreen/common.sh"
    bash -n "$ROOT/scripts/touchscreen/sources.conf"
fi
printf '\nExecution plan (sequential, never concurrent):\n'
for i in "${selected[@]}"; do printf '  %s: %s\n' "${labels[i]}" "${files[i]}"; done
printf '\nScripts can change packages, services, drivers and your user configuration.\n'
printf 'Review the local scripts first. No automatic rollback is provided.\n'
read -r -p 'Type RUN to execute this plan: ' answer
[[ "$answer" == RUN ]] || { printf 'Cancelled.\n'; exit 0; }

log_base="${XDG_STATE_HOME:-$HOME/.local/state}"
[[ "$log_base" == /* ]] || die 'XDG_STATE_HOME must be absolute.'
mkdir -p -- "$log_base/debian-lite"
log_dir="$(mktemp -d "$log_base/debian-lite/install-$(date +%Y%m%d-%H%M%S)-XXXXXX")"
printf 'Logs: %s\n' "$log_dir"
sudo -v || die 'Sudo authorization failed.'
trap 'printf "\nInterrupted; partial changes may remain. Logs: %s\n" "$log_dir" >&2; exit 130' INT
trap 'printf "\nTerminated; partial changes may remain. Logs: %s\n" "$log_dir" >&2; exit 143' TERM
for i in "${selected[@]}"; do
    path="$ROOT/${files[i]}"
    case "$i" in
        1) cmd=(sudo -- bash "$path" "$user") ;;
        3)
            cmd=(sudo -- bash "$path")
            if "$backports"; then cmd+=(--backports); fi
            ;;
        *) cmd=(bash "$path") ;;
    esac
    printf '\n>>> %s\n' "${labels[i]}"
    log="$log_dir/task-$i.log"
    # Keep stdin attached to the terminal so nested confirmation prompts work.
    if "${cmd[@]}" 2>&1 | tee "$log"; then
        printf 'Task %s returned exit status 0.\n' "$i"
    else
        rc=$?
        printf 'Task/logging failed (status %s). Stopping. Log: %s\n' "$rc" "$log" >&2
        exit "$rc"
    fi
done
printf '\nAll selected tasks returned success. This is not a hardware validation.\n'
printf 'Logs: %s\n' "$log_dir"
printf 'No reboot requested by this launcher. Test before rebooting or cleaning kernels.\n'
