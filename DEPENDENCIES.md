# MazyShell Dependencies

This document lists runtime and optional dependencies for the MazyShell Quickshell configuration.

---

## Core runtime

| Dependency | Purpose |
|------------|--------|
| **Quickshell** | Shell runtime; requires `UseQApplication` (Qt application mode). |
| **Qt 6** | QtQuick, QtQuick.Layouts, QtQuick.Dialogs, QtQuick.Effects, QtCore. |
| **Wayland** | Compositor must support **layer-shell** (used for bar, sidebar, wallpaper, corners). |

---

## Quickshell modules (built-in / plugins)

| Module | Purpose |
|--------|--------|
| `Quickshell` | Root, Variants, screen model, `sh()` helper. |
| `Quickshell.Io` | `Process`, `StdioCollector` for running scripts and CLI tools. |
| `Quickshell.Wayland` | `PanelWindow` (layer-shell panels). |
| `Quickshell.Services.SystemTray` | System tray on the bar. |
| `Quickshell.Services.UPower` | Battery status and display device (bar + Power suite). |

Optional (graceful fallback if missing):

- **PowerProfiles** (Quickshell service) — Used in PowerSuite to show performance degradation reason; UI hides if undefined.

---

## Script backends (by feature)

Scripts live under `scripts/` and are invoked by QML. Paths in code use `$HOME/.config/quickshell/MazyShell/scripts/`; adjust if your install path differs.

### Audio (`scripts/audioctl.sh`)

| Dependency | Required | Notes |
|------------|----------|--------|
| **wpctl** | Yes | PipeWire `wireplumber` (usually `wireplumber` package). |
| `sed`, `awk`, `head` | Yes | Coreutils / POSIX. |

### Bluetooth (`scripts/bluetoothctl.sh`)

| Dependency | Required | Notes |
|------------|----------|--------|
| **bluetoothctl** | Yes | Part of **bluez**. |
| `awk` | Yes | For parsing output. |

### Network (`scripts/networkctl.sh`)

| Dependency | Required | Notes |
|------------|----------|--------|
| **nmcli** | Yes | **NetworkManager** CLI. |
| **ip** | Yes | **iproute2** (default route, interface info). |
| **iw** | No | WiFi SSID via `iw dev … link`; falls back to nmcli. |
| `awk`, `sed`, `grep`, `timeout`, `readlink`, `basename`, `printf`, `cat` | Yes | Coreutils / POSIX. |

### Power profiles (`scripts/powerctl.sh`)

| Dependency | Required | Notes |
|------------|----------|--------|
| **powerprofilesctl** | Yes | **power-profiles-daemon**. |
| **asusctl** | No | Optional; syncs profile on Asus Zephyrus (e.g. ROG) if present. |
| `grep`, `tr`, `head` | Yes | Coreutils. |

### Brightness & blue light (`scripts/visualctl.sh`)

| Dependency | Required | Notes |
|------------|----------|--------|
| **brightnessctl** | Yes | For brightness get/set. |
| **hyprsunset** | No | Blue light filter; suite works without it (toggle disabled). |
| `awk`, `tr`, `pgrep`, `pkill` | Yes | Coreutils / procps. |

### VPN – WireGuard (`scripts/vpnctl.sh`)

| Dependency | Required | Notes |
|------------|----------|--------|
| **wg** | Yes | **wireguard-tools** (show interfaces). |
| **wg-quick** | Yes | Bring up/down interfaces (invoked with `sudo`). |
| **curl** | No | Used for public IP check (`ifconfig.me`). |
| **nano** | No | Used by “Edit config” (VPNSuite); overridable via `termCmd` in QML. |
| `sudo`, `sed`, `tr`, `awk`, `ip` | Yes | For config path, interface listing, optional IP. |

### dGPU / hybrid graphics (`scripts/dgpuctl.sh`)

| Dependency | Required | Notes |
|------------|----------|--------|
| **supergfxctl** | Yes | For mode status and switch (Integrated/Hybrid); **supergfxctl** (e.g. from AUR/community). |
| **rofi** | No | Only for “Launch app with dGPU” (DGPUSuite); `dgpuctl.sh app` runs `rofi -show drun` with NVIDIA env. |
| **NVIDIA Vulkan ICD** | Optional | `/usr/share/vulkan/icd.d/nvidia_icd.json` for dGPU app launch. |
| `awk`, `tr`, `head`, `pkill` | Yes | Coreutils / procps. |

---

## Compositor / workspace backends

**Workspaces** (bar) and **App launcher** (focused monitor) support:

| Backend | Used for | Binary |
|---------|----------|--------|
| **niri** | Workspaces + optional focused-output for launcher | `niri` |
| **Hyprland** | Workspaces | `hyprctl` |

- **Workspaces**: Requires **Python 3** to run the inline script that queries `niri` or `hyprctl`. If neither compositor is available (or python3 is missing), workspaces show as “none” / empty.
- **App launcher**: Focused monitor can be detected via `niri msg focused-output` when available; otherwise fallback behavior applies.

---

## App launcher (sidebar)

| Dependency | Required | Notes |
|------------|----------|--------|
| **Python 3** | Yes | Used to scan `.desktop` files and resolve icons. |
| **XDG desktop files** | Yes | `~/.local/share/applications`, `/usr/share/applications`, etc. |
| **gsettings** | No | GNOME setting for icon theme (`org.gnome.desktop.interface`); defaults to `Adwaita` if missing. |
| **niri** | No | Used for focused-output name when available. |
| **sed**, **head** | Yes | Used in shell snippet for monitor name. |

---

## Optional UI / shortcuts (sidebar buttons)

These are launched by Buttons.qml / suites via `sh()` or script; not required for shell to run.

| Dependency | Purpose |
|------------|--------|
| **kitty** | Terminal for: WiFi UI (`kitty nmtui`), processes UI (`kitty -e btop`), VPN edit (`kitty -e nano …`). |
| **nmtui** | NetworkManager TUI (WiFi button). |
| **btop** | Process monitor (resource button). |
| **nano** | Default editor for VPN config edit (overridable in VPNSuite `termCmd`). |

---

## Persistence

| What | Where |
|------|--------|
| **Wallpaper path** | **QtCore Settings** (category `MazyShell`, key `wallpaperPath`). Stored in **config**, not cache — typically under `~/.config/` in a file determined by the Quickshell/Qt app name. |
| **App usage** (launcher) | `~/.cache/quickshell/app-usage.json` — recent app ordering. |
| **Icon cache** (launcher) | `~/.cache/quickshell/icon-cache.json` — resolved icon paths for desktop entries. |

---

## Summary table (system packages, by distro)

| Feature | Arch (example) | Fedora / Debian (example) |
|---------|----------------|---------------------------|
| Audio | `wireplumber` | `wireplumber` |
| Bluetooth | `bluez` | `bluez` |
| Network | `networkmanager` | `network-manager` |
| Power | `power-profiles-daemon` | `power-profiles-daemon` |
| Brightness | `brightnessctl` | `brightnessctl` |
| Blue light | `hyprsunset` (optional) | — |
| VPN | `wireguard-tools` | `wireguard-tools` |
| dGPU | `supergfxctl` | As available (e.g. AUR, COPR) |
| Workspaces | `python`, `niri` or `hyprland` | `python3`, compositor |
| Launcher | `python`, optional `glib2` (gsettings) | same |

All script dependencies assume a POSIX shell (`bash`), `coreutils`, and common tools (`sed`, `awk`, `grep`, etc.); these are standard on modern Linux.
