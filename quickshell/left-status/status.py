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
    remaining_minutes = None
    if state in ("Charging", "Discharging"):
        energy_now = read_number(dev / "energy_now")
        energy_full = read_number(dev / "energy_full")
        power_now = read_number(dev / "power_now")
        if energy_now is None or energy_full is None or power_now is None:
            energy_now = read_number(dev / "charge_now")
            energy_full = read_number(dev / "charge_full")
            power_now = read_number(dev / "current_now")
        if energy_now is not None and energy_full is not None and power_now and power_now > 0:
            amount = energy_now if state == "Discharging" else energy_full - energy_now
            if 0 <= amount <= energy_full:
                minutes = round(amount * 60 / power_now)
                if 1 <= minutes <= 24 * 60:
                    remaining_minutes = max(1, round(minutes / 5) * 5)
    return {"present": True, "percent": percent, "state": state,
            "remaining_minutes": remaining_minutes}


def read_number(path):
    try:
        return int(read(path))
    except ValueError:
        return None


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


def extra_dim():
    try:
        value = float(run("hyprctl", "hyprsunset", "gamma"))
        return max(20, min(100, round(value)))
    except ValueError:
        return 100


def power_profile():
    match = re.search(r"Current active profile:\s*(\S+)", run("tuned-adm", "active"))
    return match.group(1) if match else ""


def rail_geometry():
    geometry = {"gap_top": 4, "gap_bottom": 4, "gap_left": 4, "rounding": 10}
    try:
        gaps = json.loads(run("hyprctl", "-j", "getoption", "general:gaps_out"))
        values = [max(0, int(value)) for value in gaps.get("custom", "").split()]
        if len(values) == 1:
            values *= 4
        if len(values) == 4:
            geometry.update(gap_top=values[0], gap_bottom=values[2], gap_left=values[3])
    except (ValueError, TypeError, AttributeError):
        pass
    try:
        rounding = json.loads(run("hyprctl", "-j", "getoption", "decoration:rounding"))
        geometry["rounding"] = max(0, int(rounding["int"]))
    except (ValueError, TypeError, KeyError):
        pass
    return geometry


def main():
    layout_state = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "quickshell-hover-panels/layout"
    custom = read(layout_state) == "quickshell"
    selected = (CONFIG / "waybar/config").resolve()
    westwing = (CONFIG / "waybar/configs/[LEFT] WestWing").resolve()
    enabled = custom or ((CONFIG / "quickshell/left-status/enabled").exists() and selected == westwing)
    if not enabled:
        print(json.dumps({"enabled": False, "layout": "off"}))
        return

    try:
        nightlight = json.loads(run(str(CONFIG / "hypr/scripts/Hyprsunset.sh"), "status"))
    except ValueError:
        nightlight = {}

    data = {
        "enabled": True,
        "layout": "custom" if custom else "legacy",
        "rail_geometry": rail_geometry() if custom else None,
        "battery": battery(),
        "power_profile": power_profile(),
        "network": network(),
        "bluetooth": bluetooth(),
        "output": audio("@DEFAULT_AUDIO_SINK@"),
        "input": audio("@DEFAULT_AUDIO_SOURCE@"),
        "brightness": brightness(),
        "extra_dim": extra_dim(),
        "nightlight": nightlight.get("class") == "on",
        "dnd": (read(layout_state.parent / "dnd") == "on") if custom
               else run("swaync-client", "-D", "-sw").lower() == "true",
    }
    print(json.dumps(data))


if __name__ == "__main__":
    main()
