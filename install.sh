#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}"
backup_dir="$state_dir/quickshell-hover-panels/backups/$(date +%Y%m%d-%H%M%S)-$$"

case "${1:-}" in
  ""|--install) ;;
  --update)
    if [[ ! -d "$repo_dir/.git" ]]; then
      echo "--update requires a Git checkout" >&2
      exit 1
    fi
    git -C "$repo_dir" pull --ff-only
    exec "$repo_dir/install.sh" --install
    ;;
  *)
    echo "Usage: $0 [--install|--update]" >&2
    exit 2
    ;;
esac

for command_name in qs python3; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing dependency: $command_name" >&2
    exit 1
  fi
done
if ! python3 -c 'import PIL' >/dev/null 2>&1; then
  echo 'Missing dependency: Python Pillow (python3-pillow)' >&2
  exit 1
fi
if ! command -v grim >/dev/null 2>&1; then
  echo 'Missing dependency: grim' >&2
  exit 1
fi

backup_file() {
  local source_file="$1" relative_path="$2"
  if [[ -f "$source_file" && ! -e "$backup_dir/$relative_path" ]]; then
    mkdir -p "$backup_dir/$(dirname -- "$relative_path")"
    cp -p -- "$source_file" "$backup_dir/$relative_path"
  fi
}

install_panel() {
  local panel="$1" source_file destination_file
  local destination_dir="$config_dir/quickshell/$panel"
  mkdir -p "$destination_dir"

  for source_file in "$repo_dir/quickshell/$panel/"*.qml "$repo_dir/quickshell/$panel/"*.py "$repo_dir/quickshell/$panel/"*.sh; do
    [[ -f "$source_file" ]] || continue
    destination_file="$destination_dir/$(basename -- "$source_file")"
    if [[ -f "$destination_file" ]] && cmp -s -- "$source_file" "$destination_file"; then
      continue
    fi
    backup_file "$destination_file" "quickshell/$panel/$(basename -- "$source_file")"
    if [[ "$source_file" == *.sh ]]; then
      install -m 0755 -- "$source_file" "$destination_file"
    else
      install -m 0644 -- "$source_file" "$destination_file"
    fi
    echo "Installed $destination_file"
  done
}

append_unique() {
  local file="$1" line="$2"
  if ! grep -Fqx -- "$line" "$file" 2>/dev/null; then
    backup_file "$file" "hypr/$(basename -- "$file")"
    printf '\n%s\n' "$line" >> "$file"
    echo "Added Hyprland rule: $line"
  fi
}

replace_line() {
  local file="$1" old="$2" new="$3" backup_path="$4"
  if [[ -f "$file" ]] && grep -Fqx -- "$old" "$file"; then
    backup_file "$file" "$backup_path"
    python3 - "$file" "$old" "$new" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
lines = path.read_text().splitlines(keepends=True)
path.write_text("".join(sys.argv[3] + line[len(sys.argv[2]):] if line.rstrip("\n") == sys.argv[2]
                        else line for line in lines))
PY
    echo "Updated $file"
  fi
}

install_panel top-dashboard
install_panel edge-session
install_panel left-status
for asset in empty-left.jsonc empty-left.css; do
  destination="$config_dir/waybar/$asset"
  mkdir -p -- "$(dirname -- "$destination")"
  if [[ ! -f "$destination" ]] || ! cmp -s -- "$repo_dir/waybar/$asset" "$destination"; then
    backup_file "$destination" "waybar/$asset"
    install -m 0644 -- "$repo_dir/waybar/$asset" "$destination"
    echo "Installed $destination"
  fi
done

state_file="$state_dir/quickshell-hover-panels/left-status-visible"
mkdir -p -- "$(dirname -- "$state_file")"
if [[ ! -f "$state_dir/quickshell-hover-panels/notifications.json" ]]; then
  printf '[]\n' > "$state_dir/quickshell-hover-panels/notifications.json"
fi
if [[ ! -f "$state_dir/quickshell-hover-panels/dnd" ]]; then
  printf 'off\n' > "$state_dir/quickshell-hover-panels/dnd"
fi
if [[ ! -f "$state_file" ]]; then
  printf 'visible\n' > "$state_file"
fi
keybind_file="$config_dir/hypr/configs/Keybinds.conf"
replace_line "$keybind_file" 'bindd = $mainMod CTRL ALT, B, toggle waybar on/off, exec, pkill -SIGUSR1 waybar' 'bindd = $mainMod CTRL ALT, B, toggle waybar on/off, exec, $HOME/.config/quickshell/left-status/toggle-bar.sh' 'hypr/Keybinds.conf'
replace_line "$keybind_file" 'bindd = $mainMod ALT, B, waybar layout menu, exec, $scriptsDir/WaybarLayout.sh' 'bindd = $mainMod ALT, B, layout menu, exec, $HOME/.config/quickshell/left-status/layout.sh menu' 'hypr/Keybinds.conf'
replace_line "$config_dir/hypr/configs/Startup_Apps.conf" 'exec-once = waybar' 'exec-once = $HOME/.config/quickshell/left-status/layout.sh sync' 'hypr/Startup_Apps.conf'
replace_line "$config_dir/hypr/configs/Startup_Apps.conf" 'exec-once = swaync' '# SwayNC starts only with a Waybar layout' 'hypr/Startup_Apps.conf'
replace_line "$config_dir/hypr/scripts/Refresh.sh" 'waybar &' 'if [[ ! -f "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell-hover-panels/layout" || "$(<"${XDG_STATE_HOME:-$HOME/.local/state}/quickshell-hover-panels/layout")" != quickshell ]]; then waybar & fi' 'hypr/Refresh.sh'
replace_line "$config_dir/hypr/scripts/Refresh.sh" 'swaync >/dev/null 2>&1 &' 'if [[ ! -f "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell-hover-panels/layout" || "$(<"${XDG_STATE_HOME:-$HOME/.local/state}/quickshell-hover-panels/layout")" != quickshell ]]; then swaync >/dev/null 2>&1 & fi' 'hypr/Refresh.sh'
replace_line "$config_dir/hypr/scripts/Refresh.sh" 'swaync-client --reload-config' 'if pgrep -x swaync >/dev/null 2>&1; then swaync-client --reload-config; fi' 'hypr/Refresh.sh'

# The animation frames are user-supplied. Updating the code never removes them.
hypr_dir="$config_dir/hypr"
if [[ -f "$hypr_dir/hyprland.conf" ]]; then
  startup_file="$hypr_dir/hyprland.conf"
  rules_file="$hypr_dir/hyprland.conf"
  if [[ -f "$hypr_dir/UserConfigs/Startup_Apps.conf" ]]; then
    startup_file="$hypr_dir/UserConfigs/Startup_Apps.conf"
  fi
  if [[ -f "$hypr_dir/UserConfigs/WindowRules.conf" ]]; then
    rules_file="$hypr_dir/UserConfigs/WindowRules.conf"
  fi
  append_unique "$startup_file" 'exec-once = qs -c edge-session -n -d'
  append_unique "$startup_file" 'exec-once = qs -c top-dashboard -n -d'
  append_unique "$startup_file" 'exec-once = qs -c left-status -n -d'
  append_unique "$rules_file" 'layerrule = match:namespace quickshell:left-status-popout, blur on'
  append_unique "$rules_file" 'layerrule = match:namespace quickshell:left-status-popout, ignore_alpha 0.1'
  append_unique "$rules_file" 'layerrule = match:namespace quickshell:left-status-popout, no_anim on'
  append_unique "$rules_file" 'layerrule = match:namespace quickshell:left-status-workspaces, blur on'
  append_unique "$rules_file" 'layerrule = match:namespace quickshell:left-status-workspaces, ignore_alpha 0.1'
  append_unique "$rules_file" 'layerrule = match:namespace quickshell:left-status-workspaces, no_anim on'
  append_unique "$rules_file" 'layerrule = match:namespace quickshell:left-status-tray-menu, blur on'
  append_unique "$rules_file" 'layerrule = match:namespace quickshell:left-status-tray-menu, ignore_alpha 0.1'
  append_unique "$rules_file" 'layerrule = match:namespace quickshell:left-status-tray-menu, no_anim on'
  append_unique "$rules_file" 'layerrule = match:namespace quickshell:left-status-wifi, blur on'
  append_unique "$rules_file" 'layerrule = match:namespace quickshell:left-status-wifi, ignore_alpha 0.1'
  append_unique "$rules_file" 'layerrule = match:namespace quickshell:left-status-wifi, no_anim on'
  append_unique "$rules_file" 'layerrule = match:namespace quickshell:left-status-bluetooth, blur on'
  append_unique "$rules_file" 'layerrule = match:namespace quickshell:left-status-bluetooth, ignore_alpha 0.1'
  append_unique "$rules_file" 'layerrule = match:namespace quickshell:left-status-bluetooth, no_anim on'
  append_unique "$rules_file" 'layerrule = match:namespace quickshell:left-status-notifications, blur on'
  append_unique "$rules_file" 'layerrule = match:namespace quickshell:left-status-notifications, ignore_alpha 0.1'
  append_unique "$rules_file" 'layerrule = match:namespace quickshell:left-status-notifications, no_anim on'
  append_unique "$rules_file" 'layerrule = match:namespace quickshell:top-dashboard, blur on'
  append_unique "$rules_file" 'layerrule = match:namespace quickshell:top-dashboard, ignore_alpha 0.1'
fi

if command -v hyprctl >/dev/null 2>&1 && hyprctl -j monitors >/dev/null 2>&1; then
  hyprctl reload >/dev/null
  "$config_dir/quickshell/left-status/layout.sh" sync
  panels=(edge-session top-dashboard left-status)
  for panel in "${panels[@]}"; do
    if qs kill -c "$panel" >/dev/null 2>&1; then
      # IPC acknowledges the request before the process finishes exiting.
      # Starting with -n too soon can silently leave the panel stopped.
      for ((attempt=0; attempt<30; attempt++)); do
        if ! qs list -c "$panel" -j 2>/dev/null | grep -q '"id"'; then
          break
        fi
        sleep 0.1
      done
    fi
    hyprctl dispatch exec "qs -c $panel -n -d" >/dev/null
    for ((attempt=0; attempt<30; attempt++)); do
      if qs list -c "$panel" -j 2>/dev/null | grep -q '"id"'; then
        break
      fi
      sleep 0.1
    done
    if ((attempt == 30)); then
      echo "Failed to start Quickshell panel: $panel" >&2
      exit 1
    fi
  done
  echo "Panels reloaded in the current Hyprland session"
else
  echo "Files installed; the panels will start on the next Hyprland login"
fi

if [[ -d "$backup_dir" ]]; then
  echo "Previous files backed up to $backup_dir"
fi
