#!/usr/bin/env python3
"""Freeze the current video wallpaper only while TuneD uses powersave."""

import hashlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path


def run(*command, timeout=8):
    return subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                          timeout=timeout, check=False).returncode == 0


def active_video():
    return run("pgrep", "-x", "mpvpaper")


def main(profile):
    cache = Path.home() / ".cache/hypr-wallpaper"
    state = cache / "quickshell-power-frame.json"
    try:
        saved = json.loads(state.read_text())
    except (OSError, ValueError):
        saved = None

    if profile != "powersave":
        if not saved:
            return
        frame = saved.get("frame", "")
        query = subprocess.run(["swww", "query"], capture_output=True, text=True,
                               timeout=4, check=False)
        if query.returncode == 0 and frame in query.stdout and not active_video():
            script = Path.home() / ".config/hypr/UserScripts/WallpaperVideoMode.sh"
            if script.is_file() and run(str(script), "apply-video", timeout=12):
                state.unlink(missing_ok=True)
        else:
            # A wallpaper chosen manually while powersave was active wins.
            state.unlink(missing_ok=True)
        return

    if not active_video():
        return
    video_state = cache / "video_path"
    try:
        video = Path(video_state.read_text().strip()).expanduser().resolve(strict=True)
    except (OSError, ValueError):
        return
    if video.suffix.lower() not in (".mp4", ".mkv", ".mov", ".webm"):
        return
    cache.mkdir(mode=0o700, parents=True, exist_ok=True)
    digest = hashlib.sha256(f"{video}:{video.stat().st_mtime_ns}".encode()).hexdigest()[:16]
    frame = cache / f"quickshell-power-frame-{digest}.jpg"
    if not frame.is_file():
        temporary = cache / f".{frame.stem}-{os.getpid()}.jpg"
        try:
            if not run("ffmpeg", "-v", "error", "-nostdin", "-ss", "1", "-i", str(video),
                       "-frames:v", "1", "-q:v", "3", "-y", str(temporary), timeout=20):
                return
            temporary.replace(frame)
        finally:
            temporary.unlink(missing_ok=True)
    if not run("swww", "query"):
        subprocess.Popen(["swww-daemon", "--format", "xrgb"],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
        for _ in range(10):
            if run("swww", "query", timeout=1):
                break
            time.sleep(0.2)
    if not run("swww", "img", str(frame), "--transition-type", "none", timeout=8):
        return
    state.write_text(json.dumps({"frame": str(frame), "video": str(video)}))
    run("pkill", "-x", "mpvpaper")


if __name__ == "__main__":
    if len(sys.argv) == 2:
        main(sys.argv[1])
