#!/usr/bin/env python3
"""Live Hyprland window list and small, private snapshots of visible workspaces."""

import json
import fcntl
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image, ImageOps


def hypr_json(what):
    try:
        return json.loads(subprocess.check_output(["hyprctl", "-j", what], timeout=2))
    except (OSError, subprocess.SubprocessError, ValueError):
        return []


def main():
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", tempfile.gettempdir()))
    directory = runtime / "quickshell-workspace-previews"
    try:
        directory.mkdir(mode=0o700, exist_ok=True)
    except OSError:
        directory = Path(tempfile.gettempdir()) / f"quickshell-workspace-previews-{os.getuid()}"
        directory.mkdir(mode=0o700, exist_ok=True)
    directory.chmod(0o700)
    # Captures from the refresh timer and a hover can overlap. Keep the
    # manifest and its image files in one consistent generation.
    with (directory / "capture.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        capture(directory)


def capture(directory):
    manifest_path = directory / "manifest.json"
    try:
        manifest = json.loads(manifest_path.read_text())
    except (OSError, ValueError):
        manifest = {}

    monitors = hypr_json("monitors")
    clients = hypr_json("clients")
    if len(sys.argv) > 1 and sys.argv[1] == "capture":
        requested = len(sys.argv) > 3
        selected_monitor = sys.argv[2] if requested else ""
        try:
            selected_id = int(sys.argv[3]) if requested else 0
        except ValueError:
            selected_id = 0
        for monitor in monitors:
            workspace = monitor.get("activeWorkspace") or {}
            workspace_id = selected_id if requested else workspace.get("id", 0)
            name = monitor.get("name", "")
            if (workspace_id < 1 or not re.fullmatch(r"[\w.-]+", name) or
                    (requested and name != selected_monitor)):
                continue
            key = f"{name}:{workspace_id}"
            snapshot = directory / f"{name}-{workspace_id}-{os.getpid()}-{time.time_ns()}.jpg"
            candidates = [client for client in clients
                          if (client.get("workspace") or {}).get("id") == workspace_id
                          and client.get("monitor") == monitor.get("id")
                          and client.get("mapped") and not client.get("hidden")
                          and client.get("stableId")]
            if not candidates:
                manifest.pop(key, None)
                continue
            try:
                scale = 0.25
                canvas = Image.new("RGB", (round(monitor["width"] * scale),
                                            round(monitor["height"] * scale)), "#17151c")
                # Hyprland's focus history puts the front window first. Draw it last.
                candidates.sort(key=lambda item: item.get("focusHistoryID", 99999), reverse=True)
                rendered = 0
                with tempfile.TemporaryDirectory(dir=directory) as scratch:
                    for index, client in enumerate(candidates):
                        window_file = Path(scratch) / f"{index}.jpg"
                        result = subprocess.run(
                            ["grim", "-T", client["stableId"], "-s", str(scale),
                             "-t", "jpeg", "-q", "72", str(window_file)],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4,
                        )
                        if result.returncode or not window_file.exists():
                            continue
                        with Image.open(window_file) as source:
                            size = client.get("size", [0, 0])
                            target_size = (max(1, round(size[0] * scale)),
                                           max(1, round(size[1] * scale)))
                            window_image = ImageOps.fit(source.convert("RGB"), target_size)
                            pos = client.get("at", [0, 0])
                            origin = (round((pos[0] - monitor["x"]) * scale),
                                      round((pos[1] - monitor["y"]) * scale))
                            canvas.paste(window_image, origin)
                            rendered += 1
                if not rendered:
                    raise OSError("no windows could be captured")
                canvas.save(snapshot, "JPEG", quality=72)
                snapshot.chmod(0o600)
                manifest[key] = str(snapshot)
            except (OSError, subprocess.SubprocessError):
                snapshot.unlink(missing_ok=True)
        temp = manifest_path.with_suffix(".tmp")
        temp.write_text(json.dumps(manifest))
        temp.chmod(0o600)
        temp.replace(manifest_path)
        # An old cached image can be loading when a hover capture replaces it.
        # Keep the newest two generations for each workspace even when that
        # first image was captured long ago.
        cutoff = time.time() - 60
        current = set(manifest.values())
        recent = set()
        for key in manifest:
            name, workspace_id = key.rsplit(":", 1)
            snapshots = directory.glob(f"{name}-{workspace_id}-*.jpg")
            recent.update(sorted(snapshots, key=lambda path: path.stat().st_mtime,
                                 reverse=True)[:2])
        for old in directory.glob("*.jpg"):
            if str(old) not in current and old not in recent and old.stat().st_mtime < cutoff:
                old.unlink(missing_ok=True)

    windows = {}
    for client in clients:
        workspace_id = (client.get("workspace") or {}).get("id", 0)
        if workspace_id < 1 or not client.get("mapped", False) or client.get("hidden", False):
            continue
        name = next((m.get("name", "") for m in monitors if m.get("id") == client.get("monitor")), "")
        key = f"{name}:{workspace_id}"
        windows.setdefault(key, []).append({
            "class": (client.get("class") or "Window")[:60],
            "title": (client.get("title") or "Untitled")[:160],
        })
    print(json.dumps({"windows": windows, "images": manifest, "updatedAt": time.time()}))


if __name__ == "__main__":
    main()
