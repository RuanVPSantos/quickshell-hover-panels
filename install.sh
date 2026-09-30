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

  for source_file in "$repo_dir/quickshell/$panel/"*.qml "$repo_dir/quickshell/$panel/"*.py; do
    [[ -f "$source_file" ]] || continue
    destination_file="$destination_dir/$(basename -- "$source_file")"
    if [[ -f "$destination_file" ]] && cmp -s -- "$source_file" "$destination_file"; then
      continue
    fi
    backup_file "$destination_file" "quickshell/$panel/$(basename -- "$source_file")"
    install -m 0644 -- "$source_file" "$destination_file"
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

install_panel top-dashboard
install_panel edge-session

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
  append_unique "$rules_file" 'layerrule = match:namespace quickshell:top-dashboard, blur on'
  append_unique "$rules_file" 'layerrule = match:namespace quickshell:top-dashboard, ignore_alpha 0.1'
fi

if command -v hyprctl >/dev/null 2>&1 && hyprctl -j monitors >/dev/null 2>&1; then
  hyprctl reload >/dev/null
  for panel in edge-session top-dashboard; do
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
