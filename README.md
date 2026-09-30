# Quickshell Hover Panels

Two independent panels for Hyprland and Quickshell:

- **Top Dashboard:** opens when the pointer reaches the top center. It has Dashboard, Media and Performance tabs.
- **Edge Session:** opens from the middle of the right edge with lock, suspend, logout, reboot and power controls.
- **Left Status:** an optional status area for the `[LEFT] WestWing` Waybar layout. Hover the bottom icons for network, Bluetooth, battery, brightness, microphone, volume, notifications and night light controls.

The panels use translucent backgrounds and can run alongside any Waybar layout. Inspired by [Caelestia Shell](https://github.com/caelestia-dots/shell); this repository contains its own QML implementation.

Click the media card in Dashboard, or the cover and track details in Media, to focus the player window. Playback buttons retain their own actions. The panel asks the MPRIS player to raise itself and uses Hyprland's window list when the player does not do so. If several windows of the same app are open and the playing one cannot be identified, it leaves the current window focused.

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

When the project is registered in RuanOps, the same actions can be run from anywhere. Without `--apply`, RuanOps shows the plan:

```bash
ruanops install quickshell_panels
ruanops install quickshell_panels --apply
ruanops update quickshell_panels
ruanops update quickshell_panels --apply
```

In `ruanops lazy`, select **Atualizar painéis Quickshell** to see the plan and choose whether to apply the update.

`--update` pulls the latest commit with `git pull --ff-only` and runs the installer again. The installer copies the QML files to `~/.config/quickshell`, adds missing autostart and Top Dashboard blur rules to the Hyprland user configuration, then reloads the two panels if Hyprland is running. Changed local files are backed up under `~/.local/state/quickshell-hover-panels/backups/`. Running it again does not duplicate rules.

The installer does not modify Waybar or delete local assets.

### Optional WestWing status hover

With the `[LEFT] WestWing` Waybar layout selected, run:

```bash
./enable-left-status.sh
```

This saves a backup under `~/.local/state/quickshell-hover-panels/`, removes only WestWing's `modules-right` icons, and starts the matching Quickshell status strip and popouts. Clock and workspaces stay in Waybar. The status strip hides while another Waybar layout is selected, so it will not duplicate that layout's icons. Running the command again is safe. Later `./install.sh --update` or `ruanops lazy` updates all enabled panels, including Left Status.

The network popout has **Other Wi-Fi**, which opens Rofi immediately with NetworkManager's cached list. Select **Rescan networks** there to refresh nearby networks on demand; a password is requested with Zenity when needed. The battery popout offers the installed TuneD profiles (Saver, Balanced and Desktop). Volume and other toggles update their displayed state immediately and confirm it from the system shortly after. The status popout closes promptly when the pointer leaves it.

The Left Status buttons hide on a fullscreen workspace and follow the Waybar visibility shortcut (`Super+Ctrl+Alt+B`). The installer updates the existing Hyprland shortcut and keeps its visibility state in `~/.local/state/quickshell-hover-panels/left-status-visible`.

The popouts use the local `nmcli`, `bluetoothctl`, `brightnessctl`, `wpctl`, `swaync-client`, `tuned-adm`, Rofi, Zenity and the existing Hyprsunset script. Their buttons open settings or change the corresponding setting; hovering alone never changes it. To revert manually, restore the saved WestWing backup, remove `~/.config/quickshell/left-status/enabled`, and restart Waybar and the Quickshell panel.

## Optional animation

The Gardevoir frames used on the original desktop came from a third-party GIF and are not distributed here. The animation component expects **exactly 32 full frames**, numbered `00.png` through `31.png`, at **232 × 232 px** with a transparent background (RGBA). It displays one frame every **100 ms**. Put the files in `~/.config/quickshell/top-dashboard/assets/gardevoir-frames/`; updates preserve them. Without the frames, the dashboard shows a music icon.

To prepare a GIF you have permission to use, start with a source that already has a genuinely transparent background. Optimized GIFs often store only the pixels changed in each frame; `-coalesce` follows the GIF disposal rules to reconstruct complete frames, avoiding trails caused by treating partial updates as full images:

```bash
mkdir -p /tmp/gardevoir-frames
magick input.gif -coalesce -background none -alpha on -resize 232x232 -gravity center \
  -extent 232x232 -scene 0 '/tmp/gardevoir-frames/%02d.png'
```

Check that the output contains 32 PNGs before copying them into the directory above. A white background or white fringe baked into the source GIF needs a properly cut out source; converting white pixels to transparent would also erase the character's white parts. If your GIF has a different frame count or timing, adjust `GardevoirAnimation.qml` (`% 32` and `interval: 100`) to match it.

## Manual controls

```bash
qs ipc -c top-dashboard call dashboard toggle
qs ipc -c edge-session call edgeSession toggle
```

The lock button uses `~/.config/hypr/scripts/LockScreen.sh` when available, then `hyprlock`, then `loginctl lock-session`.
