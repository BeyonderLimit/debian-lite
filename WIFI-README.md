Yes—we should add a dedicated **Wi-Fi** setup and diagnostic tool, rather than rely on the tray application to repair the networking stack. I created `wifi-config.sh` and an accompanying Wi-Fi README.

Installing `iwd` and `rfkill` is useful, but installing iwd alone does not make NetworkManager use it. NetworkManager defaults to `wpa_supplicant`; using iwd requires an explicit backend setting. Debian 12 documents the iwd backend as experimental, so the tool makes switching optional rather than treating it as a universal fix. [manpages.debian](https://manpages.debian.org/bookworm/network-manager/NetworkManager.conf.5.en.html)

## Why Wi-Fi can stop after desktop installation

Your symptoms suggest a network-management handover problem, but they do not identify one cause conclusively. Two particularly relevant possibilities are:

- The installer configured Wi-Fi in `/etc/network/interfaces` or an included file. With Debian’s ifupdown plugin and `managed=false`, NetworkManager ignores interfaces configured there. A tray application cannot simply override that ownership rule. [manpages.debian](https://manpages.debian.org/bookworm/network-manager/NetworkManager.conf.5.en.html)
- More than one service is trying to control the connection. For example, standalone iwd network configuration can run its own DHCP client, whereas in the proposed arrangement NetworkManager should handle IP configuration. [manpages.debian](https://manpages.debian.org/bookworm/iwd/iwd.config.5.en.html)

The tool starts with diagnostics so you can distinguish these cases from radio blocks, missing firmware, authentication failures, or a device that NetworkManager considers unmanaged. `nmcli` provides device state, radio state, scanning, and connection management without requiring a graphical desktop. [manpages.debian](https://manpages.debian.org/bookworm/network-manager/nmcli.1.en.html)

## What the generated tool provides

Its TTY menu includes:

```text
1) Diagnose hardware, services and NetworkManager
2) Install dependencies
3) Unblock Wi-Fi and enable NetworkManager radio
4) Scan/connect using nmcli
5) Select NetworkManager Wi-Fi backend
6) Restore tool backend configuration
7) Open nmtui connection editor
8) Request management of a Wi-Fi interface (runtime)
q) Quit
```

Dependency installation includes:

```text
network-manager
iwd
rfkill
iw
pciutils
usbutils
python3
wpasupplicant
```

The connection workflow uses `nmcli --ask`, so you enter the password interactively instead of placing it in a shell command argument. NetworkManager can still persist credentials in its normal connection storage. [manpages.debian](https://manpages.debian.org/bookworm/network-manager/nmcli.1.en.html)

## Recommended networking arrangement

Keep one clear division of responsibility:

```text
nm-tray / nmtui / nmcli
          │
          ▼
   NetworkManager
   profiles, IP configuration,
   routes and DNS integration
          │
          ▼
  iwd OR wpa_supplicant
  Wi-Fi authentication/association
```

For the optional iwd backend, the tool writes a dedicated NetworkManager configuration snippet:

```ini
[device]
wifi.backend=iwd
wifi.iwd.autoconnect=false
```

The second setting makes NetworkManager initiate connections instead of delegating autoconnection decisions to iwd. [manpages.debian](https://manpages.debian.org/bookworm/network-manager/NetworkManager.conf.5.en.html)

It also checks that iwd’s standalone network configuration is not enabled. When NetworkManager owns IP configuration, keep this setting false—or absent, which is the default:

```ini
[General]
EnableNetworkConfiguration=false
```

Setting it to true enables iwd’s own address configuration and built-in DHCP client, which is not the arrangement we want here. [manpages.debian](https://manpages.debian.org/bookworm/iwd/iwd.config.5.en.html)

## How to use it

Place the generated script in your repository root and run it from a local console:

```bash
sudo bash wifi-config.sh
```

Recommended order:

1. Run diagnostics.
2. Install dependencies while your initial connection still works.
3. Unblock the radio if necessary.
4. Try scanning and connecting without changing backends.
5. Only then test iwd if appropriate.
6. Reconnect and verify device state, routing, DNS, and actual Internet access separately.

For your existing non-root installer, the dispatch command would be:

```bash
sudo -- bash "$ROOT/wifi-config.sh"
```

Run it as a separate sequential task, not alongside another package-installation task.

## Deliberate safety limits

The tool does not blindly delete `/etc/network/interfaces`, globally enable management of every interface, replace `/etc/resolv.conf`, or mask `wpa_supplicant`. Those changes can disrupt Ethernet, other adapters, or existing networking arrangements. It reports relevant configuration and services for review instead. NetworkManager also has strict unmanaged-device policies that a runtime `managed yes` request cannot override. [manpages.debian](https://manpages.debian.org/bookworm/network-manager/NetworkManager.conf.5.en.html)

Backend changes have a saved copy of the tool’s previous configuration file and a menu option to restore it. This is configuration-file recovery—not a complete rollback of packages, profiles, credentials, or service runtime state.

The generated script passed `bash -n`; it has not been integration-tested on your hardware. If diagnostics show no wireless interface or missing firmware, the next step is identifying the exact adapter and firmware requirement—not repeatedly switching connection backends.
