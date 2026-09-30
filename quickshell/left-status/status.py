#!/usr/bin/env python3
"""Small, bounded status snapshot for the left status panel."""

import json
import os
from pathlib import Path
import re
import subprocess


HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))


def run(*args):
    try:
        return subprocess.run(
            args, capture_output=True, text=True, timeout=1.5,
            env={**os.environ, "LC_ALL": "C"},
        ).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return ""


def read(path):
    try:
        return path.read_text().strip()
    except OSError:
        return ""


def battery():
    batteries = sorted((Path("/sys/class/power_supply")).glob("BAT*"))
    if not batteries:
        return {"present": False, "percent": 0, "state": "Unavailable"}
    dev = batteries[0]
    try:
        percent = int(read(dev / "capacity"))
    except ValueError:
        percent = 0
    state = read(dev / "status") or "Unknown"
    return {"present": True, "percent": percent, "state": state}


def network():
    result = {"connected": False, "name": "Disconnected", "type": "", "signal": 0,
              "wifi_enabled": run("nmcli", "radio", "wifi") == "enabled"}
    for line in run("nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status").splitlines():
        parts = line.split(":", 3)
        if len(parts) == 4 and parts[2] == "connected" and parts[1] in ("wifi", "ethernet"):
            result.update(connected=True, name=parts[3].replace("\\:", ":"), type=parts[1])
            if parts[1] == "wifi":
                break
    if result["type"] == "wifi":
        for line in run("nmcli", "-t", "-f", "IN-USE,SIGNAL", "device", "wifi", "list", "--rescan", "no").splitlines():
            if line.startswith("*:"):
                try:
                    result["signal"] = int(line.split(":", 1)[1])
                except ValueError:
                    pass
                break
    return result


def bluetooth():
    info = run("bluetoothctl", "show")
    powered = "Powered: yes" in info
    connected = run("bluetoothctl", "devices", "Connected").splitlines() if powered else []
    return {"powered": powered, "devices": len(connected)}


def audio(target):
    value = run("wpctl", "get-volume", target)
    match = re.search(r"Volume:\s*([0-9.]+)", value)
    return {"percent": round(float(match.group(1)) * 100) if match else 0, "muted": "[MUTED]" in value}


def brightness():
    try:
        current = float(run("brightnessctl", "get"))
        maximum = float(run("brightnessctl", "max"))
        return round(current / maximum * 100) if maximum else 0
    except ValueError:
        return 0


def power_profile():
    match = re.search(r"Current active profile:\s*(\S+)", run("tuned-adm", "active"))
    return match.group(1) if match else ""


def main():
    selected = (CONFIG / "waybar/config").resolve()
    westwing = (CONFIG / "waybar/configs/[LEFT] WestWing").resolve()
    enabled = (CONFIG / "quickshell/left-status/enabled").exists() and selected == westwing
    if not enabled:
        print(json.dumps({"enabled": False}))
        return

    try:
        nightlight = json.loads(run(str(CONFIG / "hypr/scripts/Hyprsunset.sh"), "status"))
    except ValueError:
        nightlight = {}

    data = {
        "enabled": True,
        "battery": battery(),
        "power_profile": power_profile(),
        "network": network(),
        "bluetooth": bluetooth(),
        "output": audio("@DEFAULT_AUDIO_SINK@"),
        "input": audio("@DEFAULT_AUDIO_SOURCE@"),
        "brightness": brightness(),
        "nightlight": nightlight.get("class") == "on",
        "dnd": run("swaync-client", "-D", "-sw").lower() == "true",
    }
    print(json.dumps(data))


if __name__ == "__main__":
    main()
