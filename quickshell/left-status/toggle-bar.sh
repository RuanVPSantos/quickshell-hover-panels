#!/usr/bin/env bash
set -euo pipefail

state_file="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell-hover-panels/left-status-visible"
mkdir -p -- "$(dirname -- "$state_file")"

if [[ -f "$state_file" && "$(<"$state_file")" == hidden ]]; then
  printf 'visible\n' > "$state_file"
else
  printf 'hidden\n' > "$state_file"
fi

pkill -SIGUSR1 -x waybar || true
