#!/usr/bin/env python3
"""Adjust session dimming without changing an active Hyprsunset temperature."""

import fcntl
import os
from pathlib import Path
import subprocess
import sys
import time


def set_gamma(value):
    result = subprocess.run(
        ["hyprctl", "hyprsunset", "gamma", str(value)],
        capture_output=True, text=True, timeout=2,
    )
    return result.returncode == 0 and result.stdout.strip() == "ok"


def apply(value):
    # Serialize slider updates, including startup, to avoid competing CTM clients.
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    with (runtime / "quickshell-extra-dim.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if set_gamma(value):
            return
        running = subprocess.run(
            ["pgrep", "-x", "hyprsunset"], capture_output=True, timeout=2,
        )
        if running.returncode == 0:
            raise RuntimeError("Hyprsunset is running but its controls are unavailable.")
        process = subprocess.Popen(
            ["hyprsunset", "--identity", "--gamma", str(value)],
            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL, start_new_session=True,
        )
        for _ in range(15):
            time.sleep(0.1)
            if process.poll() is not None:
                break
            if set_gamma(value):
                return
        raise RuntimeError("Could not start Hyprsunset dimming.")


def main():
    try:
        if len(sys.argv) != 2:
            raise ValueError("Usage: extra_dim.py PERCENT (20–100)")
        value = int(sys.argv[1])
        if not 20 <= value <= 100:
            raise ValueError("Extra dim must be between 20% and 100%.")
        apply(value)
    except (ValueError, OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(error, file=sys.stderr)
        try:
            subprocess.run(["notify-send", "Extra dim unavailable", str(error)], timeout=2)
        except (OSError, subprocess.TimeoutExpired):
            pass
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
