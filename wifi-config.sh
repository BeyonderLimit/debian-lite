#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
export SYSTEMD_PAGER=cat
export PAGER=cat
umask 077

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
(( EUID == 0 )) || die 'Run: sudo bash wifi-config.sh'
[[ -t 0 && -t 1 ]] || die 'Use an interactive local terminal.'
[[ -z ${SSH_CONNECTION:-} && -z ${SSH_CLIENT:-} ]] || die 'Use a local console, not SSH.'
. /etc/os-release
[[ ${ID:-} == debian ]] || die 'Debian is required.'
[[ -d /run/systemd/system ]] || die 'This tool requires systemd.'
trap 'printf "Command failed on line %s. Inspect the output; partial changes may remain.\n" "$LINENO" >&2' ERR
CONF=/etc/NetworkManager/conf.d/90-debian-lite-wifi.conf
BASE=/var/lib/debian-lite/wifi-backups

confirm() {
    local answer
    printf '\n%s\n' "$1"
    read -r -p 'Type APPLY to continue: ' answer
    [[ "$answer" == APPLY ]]
}
need_nm() { command -v nmcli >/dev/null || die 'Install dependencies using option 2 first.'; }
choose_interface() {
    need_nm
    local n
    local -a devices=()
    for n in /sys/class/net/*; do
        [[ -d "$n/wireless" ]] && devices+=("${n##*/}")
    done
    (( ${#devices[@]} )) || die 'No wireless interface found; inspect driver/firmware diagnostics.'
    printf '\nWireless interfaces:\n'
    printf '  %s\n' "${devices[@]}"
    read -r -p 'Interface (exact name): ' IFACE
    for n in "${devices[@]}"; do [[ "$IFACE" == "$n" ]] && return 0; done
    die 'Select an interface from the list.'
}
diagnostics() {
    printf '\nKernel: %s | OS: %s\n' "$(uname -r)" "${PRETTY_NAME:-Debian}"
    ip -br link || true
    ip route || true
    command -v rfkill >/dev/null && rfkill list || true
    command -v lspci >/dev/null && lspci -nnk || true
    command -v lsusb >/dev/null && lsusb || true
    if command -v nmcli >/dev/null; then
        nmcli general status || true
        nmcli radio || true
        nmcli -f DEVICE,TYPE,STATE,CONNECTION device status || true
        nmcli -f GENERAL,IP4,IP6 device show || true
        NetworkManager --print-config || true
    fi
    printf '\nPotential competing network services\n'
    systemctl list-units --all --no-pager \
        'NetworkManager.service' 'iwd.service' 'wpa_supplicant*.service' \
        'systemd-networkd.service' 'networking.service' 'dhcpcd*.service' || true
    printf '\nifupdown configuration files (contents may contain secrets; not printed)\n'
    find /etc/network -maxdepth 2 -type f -print 2>/dev/null || true
    printf '\nResolver target\n'
    ls -l /etc/resolv.conf || true
    printf '\nRecent network service messages\n'
    journalctl -b -u NetworkManager -u iwd -u wpa_supplicant -n 100 --no-pager || true
    printf '\nKernel wireless/firmware messages\n'
    journalctl -b -k --no-pager | grep -Ei 'firmware|wifi|wlan|80211|iwlwifi|ath|brcm|mwifiex|rtw|rtl' | tail -n 100 || true
}
install_deps() {
    confirm 'Install network-manager, iwd, rfkill, iw, pciutils, usbutils, python3 and wpasupplicant? This requires an existing connection or cached packages. Package installation may start services.' || return 0
    apt-get -o APT::Update::Error-Mode=any update
    apt-get --no-remove install network-manager iwd rfkill iw pciutils usbutils python3 wpasupplicant
}
backend() {
    need_nm
    command -v python3 >/dev/null || die 'Install dependencies first.'
    printf '\n1) wpa_supplicant (NetworkManager default)\n2) iwd (optional/experimental on Debian 12)\n'
    read -r -p 'Backend: ' b
    case "$b" in
        1) backend_name=wpa_supplicant; command -v wpa_supplicant >/dev/null || die 'Install dependencies.' ;;
        2) backend_name=iwd; command -v iwctl >/dev/null || die 'Install dependencies.' ;;
        *) die 'Invalid backend.' ;;
    esac
    if [[ "$backend_name" == iwd ]]; then
        # Refuse a standalone iwd DHCP setup instead of rewriting unrelated settings.
        python3 - <<'PY'
import configparser
from pathlib import Path
p=Path('/etc/iwd/main.conf')
c=configparser.ConfigParser(interpolation=None)
if p.exists():
    with p.open() as f: c.read_file(f)
if c.getboolean('General','EnableNetworkConfiguration',fallback=False):
    raise SystemExit('iwd DHCP is enabled. Back up /etc/iwd/main.conf and set '
                     '[General] EnableNetworkConfiguration=false before using iwd with NetworkManager.')
PY
    fi
    printf '\nReview option 1 first. Remove only Wi-Fi stanzas from ifupdown after backing them up,\n'
    printf 'and resolve standalone wpa_supplicant@INTERFACE/dhcpcd/networkd ownership manually.\n'
    printf 'This operation does not edit those files, disable competing services, or migrate credentials.\n'
    confirm "Set NetworkManager backend to $backend_name and restart NetworkManager? ALL NetworkManager connections may drop. Existing profiles may need credentials again." || return 0
    install -d -m 0700 "$BASE"
    backup="$(mktemp -d "$BASE/change-XXXXXXXX")"
    if [[ -e "$CONF" || -L "$CONF" ]]; then
        [[ -f "$CONF" && ! -L "$CONF" ]] || die 'Refusing nonregular/symlink tool configuration.'
        cp -a -- "$CONF" "$backup/previous.conf"
    else
        touch "$backup/previously-absent"
    fi
    printf 'Backup for this backend change: %s\n' "$backup"
    install -d -m 0755 /etc/NetworkManager/conf.d
    tmp="$(mktemp /etc/NetworkManager/conf.d/.debian-lite-wifi.XXXXXXXX)"
    printf '[device]\nwifi.backend=%s\n' "$backend_name" > "$tmp"
    if [[ "$backend_name" == iwd ]]; then
        printf 'wifi.iwd.autoconnect=false\n' >> "$tmp"
    fi
    chmod 0644 "$tmp"
    mv -f -- "$tmp" "$CONF"
    # Do not disable/mask supplicant globally: other interfaces may need it.
    if [[ "$backend_name" == iwd ]]; then systemctl start iwd; fi
    systemctl restart NetworkManager
    printf '\nBackend requested. Verify the effective config and reconnect using option 4.\n'
    NetworkManager --print-config
    nmcli device status
    printf 'No service enable/disable state was changed. Service start/restart is not a connectivity test.\n'
}
restore_backend() {
    need_nm
    [[ -d "$BASE" ]] || die 'No backend snapshots.'
    printf '\nAvailable snapshots:\n'
    find "$BASE" -mindepth 1 -maxdepth 1 -type d -printf '%f\n'
    read -r -p 'Snapshot name (change-... only): ' name
    [[ "$name" =~ ^change-[A-Za-z0-9]+$ ]] || die 'Invalid snapshot name.'
    backup="$BASE/$name"
    [[ -d "$backup" && ! -L "$backup" ]] || die 'Unknown snapshot.'
    confirm 'Restore ONLY the tool backend configuration and restart NetworkManager? Connections may drop. Package/profile/service state is not rolled back.' || return 0
    if [[ -f "$backup/previous.conf" ]]; then
        [[ ! -L "$CONF" ]] || die 'Refusing symlink destination.'
        cp -a -- "$backup/previous.conf" "$CONF"
    elif [[ -f "$backup/previously-absent" ]]; then
        rm -f -- "$CONF"
    else
        die 'Snapshot incomplete.'
    fi
    systemctl restart NetworkManager
    printf 'Backend file restored. Other network configuration was not restored.\n'
}
connect_wifi() {
    choose_interface
    nmcli --wait 20 device wifi list ifname "$IFACE" --rescan yes
    printf '\nUse an existing enterprise profile via nmtui (option 7).\n'
    read -r -p 'SSID (exact name; empty to cancel): ' ssid
    [[ -n "$ssid" ]] || return 0
    read -r -p 'Hidden network? [y/N]: ' hidden
    args=(--ask --wait 90 device wifi connect "$ssid" ifname "$IFACE")
    case "$hidden" in y|Y) args+=(hidden yes);; esac
    nmcli "${args[@]}"
    printf '\nConnected profile/device state:\n'
    nmcli -f GENERAL,IP4,IP6 device show "$IFACE"
    printf 'An association/IP address does not prove DNS or Internet access.\n'
}
while true; do
    printf '\nDebian Lite Wi-Fi configuration\n'
    printf '1) Diagnose hardware, services and NetworkManager\n2) Install dependencies\n'
    printf '3) Unblock Wi-Fi and enable NetworkManager radio\n4) Scan/connect using nmcli\n'
    printf '5) Select NetworkManager Wi-Fi backend\n6) Restore tool backend configuration\n'
    printf '7) Open nmtui connection editor\n8) Request management of a Wi-Fi interface (runtime)\nq) Quit\n'
    read -r -p 'Selection: ' choice
    case "$choice" in
        1) diagnostics ;;
        2) install_deps ;;
        3)
            need_nm
            command -v rfkill >/dev/null || die 'Install dependencies first.'
            if confirm 'Unblock WLAN in software and turn on the NetworkManager Wi-Fi radio?'; then
                rfkill unblock wlan
                nmcli radio wifi on
                rfkill list
            fi ;;
        4) connect_wifi ;;
        5) backend ;;
        6) restore_backend ;;
        7) command -v nmtui >/dev/null || die 'Install network-manager first.'; nmtui ;;
        8)
            choose_interface
            if confirm "Ask NetworkManager to manage $IFACE at runtime? This cannot override all unmanaged-device policies."; then
                nmcli device set "$IFACE" managed yes
                nmcli device show "$IFACE"
            fi ;;
        q|Q) exit 0 ;;
        *) printf 'Invalid selection.\n' ;;
    esac
done
