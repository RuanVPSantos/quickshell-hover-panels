# Quickshell Hover Panels

Two independent panels for Hyprland and Quickshell:

- **Top Dashboard:** opens when the pointer reaches the top center. It has Dashboard, Media and Performance tabs.
- **Edge Session:** opens from the middle of the right edge with lock, suspend, logout, reboot and power controls.

The panels use translucent backgrounds and can run alongside any Waybar layout. Inspired by [Caelestia Shell](https://github.com/caelestia-dots/shell); this repository contains its own QML implementation.

## Requirements

Linux with Hyprland, Quickshell (`qs`), Python 3, Font Awesome 6 Free and Noto Sans. The dashboard reads `/proc`, `/sys`, MPRIS players and, when present, `~/.cache/.weather_cache`.

## Install and update

```bash
git clone https://github.com/RuanVPSantos/quickshell-hover-panels.git
cd quickshell-hover-panels
./install.sh
```

Later, from the same checkout:

```bash
./install.sh --update
```

`--update` pulls the latest commit with `git pull --ff-only` and runs the installer again. The installer copies the QML files to `~/.config/quickshell`, adds missing autostart and Top Dashboard blur rules to the Hyprland user configuration, then reloads the two panels if Hyprland is running. Changed local files are backed up under `~/.local/state/quickshell-hover-panels/backups/`. Running it again does not duplicate rules.

The installer does not modify Waybar or delete local assets.

## Optional animation

The Gardevoir frames used on the original desktop came from a third-party GIF and are not distributed here. If you already have them, keep the 32 PNG files named `00.png` through `31.png` in `~/.config/quickshell/top-dashboard/assets/gardevoir-frames/`; updates preserve them. Without the frames, the dashboard shows a music icon.

## Manual controls

```bash
qs ipc -c top-dashboard call dashboard toggle
qs ipc -c edge-session call edgeSession toggle
```

The lock button uses `~/.config/hypr/scripts/LockScreen.sh` when available, then `hyprlock`, then `loginctl lock-session`.
