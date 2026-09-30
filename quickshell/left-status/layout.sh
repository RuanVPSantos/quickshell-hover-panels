#!/usr/bin/env bash
set -euo pipefail

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell-hover-panels"
layout_file="$state_dir/layout"
visibility_file="$state_dir/left-status-visible"
waybar_config="$config_dir/waybar/config"
waybar_layouts="$config_dir/waybar/configs"
empty_config="$config_dir/waybar/empty-left.jsonc"
empty_style="$config_dir/waybar/empty-left.css"

start_reservation() {
  pkill -x waybar 2>/dev/null || true
  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl dispatch exec "waybar -c $empty_config -s $empty_style" >/dev/null
  else
    waybar -c "$empty_config" -s "$empty_style" >/dev/null 2>&1 &
  fi
}

stop_swaync() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user stop swaync.service >/dev/null 2>&1 || true
  fi
  pkill -x swaync 2>/dev/null || true
}

start_swaync() {
  if pgrep -x swaync >/dev/null 2>&1; then return; fi
  if command -v systemctl >/dev/null 2>&1 && systemctl --user start swaync.service >/dev/null 2>&1; then
    return
  fi
  swaync >/dev/null 2>&1 &
}

restart_left() {
  qs kill -c left-status >/dev/null 2>&1 || true
  for ((attempt=0; attempt<30; attempt++)); do
    if ! qs list -c left-status -j 2>/dev/null | grep -q '"id"'; then break; fi
    sleep 0.1
  done
  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl dispatch exec 'qs -c left-status -n -d' >/dev/null
  else
    qs -c left-status -n -d >/dev/null 2>&1 &
  fi
}

activate() {
  mkdir -p -- "$state_dir"
  printf 'quickshell\n' > "$layout_file"
  printf 'visible\n' > "$visibility_file"
  stop_swaync
  start_reservation
  restart_left
}

use_waybar() {
  local name="${1:?Waybar layout name required}"
  local chosen="$waybar_layouts/$name"
  if [[ ! -f "$chosen" || "$name" == */* ]]; then
    echo "Unknown Waybar layout: $name" >&2
    return 1
  fi
  mkdir -p -- "$state_dir"
  printf 'waybar\n' > "$layout_file"
  ln -sfn -- "$chosen" "$waybar_config"
  restart_left
  start_swaync
  pkill -x waybar 2>/dev/null || true
  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl dispatch exec waybar >/dev/null
  else
    waybar >/dev/null 2>&1 &
  fi
}

choose() {
  local current choice selected_row=0 index
  current="$(basename -- "$(readlink -f -- "$waybar_config")")"
  if [[ -f "$layout_file" && "$(<"$layout_file")" == quickshell ]]; then
    current="Quickshell · Three sides"
  fi
  mapfile -t layouts < <(find -L "$waybar_layouts" -maxdepth 1 -type f -printf '%f\n' | sort)
  for index in "${!layouts[@]}"; do
    if [[ "${layouts[index]}" == "$current" ]]; then
      selected_row=$((index + 1))
      break
    fi
  done
  choice="$(printf '%s\n' 'Quickshell · Three sides' "${layouts[@]}" | rofi -dmenu -i -p 'Layout' -config "$config_dir/rofi/config-waybar-layout.rasi" -selected-row "$selected_row")" || return 0
  [[ -n "$choice" ]] || return 0
  if [[ "$choice" == 'Quickshell · Three sides' ]]; then
    activate
  else
    use_waybar "$choice"
  fi
}

case "${1:-}" in
  activate) activate ;;
  waybar) use_waybar "${2:-}" ;;
  menu) choose ;;
  sync)
    if [[ -f "$layout_file" && "$(<"$layout_file")" == quickshell ]]; then
      stop_swaync
      start_reservation
    elif command -v hyprctl >/dev/null 2>&1; then
      start_swaync
      hyprctl dispatch exec waybar >/dev/null
    else
      start_swaync
      waybar >/dev/null 2>&1 &
    fi
    ;;
  *) echo "Usage: $0 {activate|waybar NAME|menu|sync}" >&2; exit 2 ;;
esac
