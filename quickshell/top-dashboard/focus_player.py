#!/usr/bin/env python3
"""Focus the Hyprland window associated with an MPRIS player, when unambiguous."""

import json
import re
import subprocess
import sys


def normalize(value):
    return re.sub(r"[^a-z0-9]", "", value.casefold())


def player_names(desktop_entry, identity, dbus_name):
    # Short desktop IDs such as "zen" are still useful as class suffixes.
    desktop_id = normalize(desktop_entry.removesuffix(".desktop"))
    names = {desktop_id}
    prefix = "org.mpris.MediaPlayer2."
    if dbus_name.startswith(prefix):
        names.add(normalize(dbus_name[len(prefix):].split(".", 1)[0]))
    names.add(normalize(identity))
    return {name for name in names if len(name) >= 4 or name == desktop_id and len(name) >= 3}


def choose_window(clients, desktop_entry, identity, dbus_name, track_title):
    names = player_names(desktop_entry, identity, dbus_name)
    if not names:
        return None

    matches = []
    for client in clients:
        if client.get("mapped") is False or client.get("hidden") is True:
            continue
        classes = [normalize(client.get(key) or "") for key in ("class", "initialClass")]
        if any(app == name or app.endswith(name) or name.endswith(app)
               for app in classes if len(app) >= 4 for name in names):
            matches.append(client)

    if len(matches) == 1:
        return matches[0]

    if len(matches) > 1 and len(track_title.strip()) >= 5:
        title = track_title.casefold().strip()
        titled = [client for client in matches if title in (client.get("title") or "").casefold()]
        if len(titled) == 1:
            return titled[0]

    return None


def main():
    if len(sys.argv) != 5:
        return 2
    try:
        result = subprocess.run(
            ["hyprctl", "-j", "clients"], capture_output=True, text=True,
            timeout=2, check=True,
        )
        clients = json.loads(result.stdout)
        selected = choose_window(clients, *sys.argv[1:])
        if selected is None:
            return 0
        address = selected.get("address", "")
        if not re.fullmatch(r"0x[0-9a-fA-F]+", address):
            return 1
        subprocess.run(
            ["hyprctl", "dispatch", "focuswindow", f"address:{address}"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2, check=True,
        )
        return 0
    except (OSError, ValueError, subprocess.SubprocessError):
        return 1


if __name__ == "__main__":
    sys.exit(main())
