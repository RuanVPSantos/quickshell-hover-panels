#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
waybar_config="$config_dir/waybar/config"
westwing="$config_dir/waybar/configs/[LEFT] WestWing"
marker="$config_dir/quickshell/left-status/enabled"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell-hover-panels"

if [[ ! -f "$westwing" || $(readlink -f "$waybar_config") != "$(readlink -f "$westwing")" ]]; then
  echo "Select the [LEFT] WestWing Waybar layout before enabling left status" >&2
  exit 1
fi

python3 - "$westwing" <<'PY'
from pathlib import Path
import re
import sys

if not re.search(r'(?ms)^"modules-right": (?:\[\]|\[.*?^\]),', Path(sys.argv[1]).read_text()):
    raise SystemExit('Waybar modules-right section not found; left original config unchanged')
PY

mkdir -p "$(dirname "$marker")" "$state_dir"
touch "$marker"
"$repo_dir/install.sh" --install

python3 - "$westwing" "$state_dir" <<'PY'
from pathlib import Path
import re
import sys
from datetime import datetime

config = Path(sys.argv[1])
state_dir = Path(sys.argv[2])
source = config.read_text()
match = re.search(r'(?ms)^"modules-right": (?:\[\]|\[.*?^\]),', source)
if match is None:
    raise SystemExit('Waybar modules-right section not found; left original config unchanged')
original = match.group(0)
replacement = '"modules-right": [],'
if original != replacement:
    backup = state_dir / f'WestWing-before-left-status-{datetime.now():%Y%m%d-%H%M%S}.jsonc'
    backup.write_text(source)
    config.write_text(source[:match.start()] + replacement + source[match.end():])
    print(f'Waybar backup: {backup}')
PY

if command -v waybar-msg >/dev/null 2>&1; then
  waybar-msg cmd reload >/dev/null
else
  pkill -SIGUSR2 -x waybar || true
fi
echo "Left status hover enabled for [LEFT] WestWing"
