#!/usr/bin/env python3
"""Read a small system snapshot for the Quickshell dashboard."""

import json
import os
import re
import shutil
import time
from pathlib import Path


def cpu_times():
    with open("/proc/stat", encoding="utf-8") as source:
        values = [int(value) for value in source.readline().split()[1:]]
    idle = values[3] + values[4]
    return sum(values), idle


def memory_snapshot():
    with open("/proc/meminfo", encoding="utf-8") as source:
        values = {}
        for line in source:
            key, value = line.split(":", 1)
            values[key] = int(value.strip().split()[0])
    total = values["MemTotal"]
    used = total - values["MemAvailable"]
    return {
        "percent": round(used / total * 100),
        "usedGiB": round(used / 1048576, 1),
        "totalGiB": round(total / 1048576, 1),
    }


def sensor_temperature(name):
    for sensor in Path("/sys/class/hwmon").glob("hwmon*"):
        try:
            if (sensor / "name").read_text().strip() == name:
                return round(int((sensor / "temp1_input").read_text()) / 1000)
        except (OSError, ValueError):
            continue
    return None


def gpu_usage():
    for device in Path("/sys/class/drm").glob("card*/device/gpu_busy_percent"):
        try:
            return max(0, min(100, int(device.read_text())))
        except (OSError, ValueError):
            continue
    return None


def battery_snapshot():
    for device in Path("/sys/class/power_supply").glob("*"):
        try:
            if (device / "type").read_text().strip() == "Battery":
                return {
                    "percent": int((device / "capacity").read_text()),
                    "status": (device / "status").read_text().strip(),
                }
        except (OSError, ValueError):
            continue
    return None


def weather_snapshot():
    cache = Path.home() / ".cache/.weather_cache"
    try:
        lines = cache.read_text(encoding="utf-8").splitlines()
        condition = lines[1].split("  ", 1)[-1].strip()
        temperature = re.search(r"[-+]?\d+°C", lines[2])
        return {
            "location": lines[0].split(",", 1)[0],
            "condition": condition,
            "temperature": temperature.group(0) if temperature else "--°C",
        }
    except (OSError, IndexError):
        return {"location": "", "condition": "Weather unavailable", "temperature": "--°C"}


def uptime_text():
    with open("/proc/uptime", encoding="utf-8") as source:
        minutes = int(float(source.readline().split()[0]) // 60)
    days, remainder = divmod(minutes, 1440)
    hours, minutes = divmod(remainder, 60)
    return f"{days}d {hours}h" if days else f"{hours}h {minutes}m"


start_total, start_idle = cpu_times()
time.sleep(0.15)
end_total, end_idle = cpu_times()
elapsed = max(1, end_total - start_total)
cpu = round((1 - (end_idle - start_idle) / elapsed) * 100)
disk = shutil.disk_usage("/")
memory = memory_snapshot()

print(json.dumps({
    "cpu": max(0, min(100, cpu)),
    "cpuTemp": sensor_temperature("k10temp"),
    "gpu": gpu_usage(),
    "gpuTemp": sensor_temperature("amdgpu"),
    "memory": memory["percent"],
    "memoryUsedGiB": memory["usedGiB"],
    "memoryTotalGiB": memory["totalGiB"],
    "disk": round(disk.used / disk.total * 100),
    "diskUsedGiB": round(disk.used / 1073741824, 1),
    "diskTotalGiB": round(disk.total / 1073741824, 1),
    "battery": battery_snapshot(),
    "weather": weather_snapshot(),
    "uptime": uptime_text(),
    "user": os.environ.get("USER", "user"),
}))
