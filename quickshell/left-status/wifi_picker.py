#!/usr/bin/env python3
"""NetworkManager operations for the Quickshell Wi-Fi picker."""

import json
import subprocess
import sys


def run(*command, timeout=20):
    return subprocess.run(
        command, capture_output=True, text=True, timeout=timeout,
    )


def split_nmcli(line):
    parts = []
    current = []
    escaped = False
    for char in line:
        if escaped:
            current.append(char)
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == ":":
            parts.append("".join(current))
            current = []
        else:
            current.append(char)
    parts.append("".join(current))
    return parts


def networks(rescan=False):
    result = run("nmcli", "-t", "-e", "yes", "-f", "IN-USE,SSID,SIGNAL,SECURITY",
                 "device", "wifi", "list", "--rescan", "yes" if rescan else "no")
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "Could not read Wi-Fi networks")
    found = {}
    for line in result.stdout.splitlines():
        fields = split_nmcli(line)
        if len(fields) != 4 or not fields[1]:
            continue
        active, ssid, signal, security = fields
        try:
            strength = int(signal)
        except ValueError:
            strength = 0
        if ssid not in found or strength > found[ssid]["signal"]:
            found[ssid] = {"ssid": ssid, "active": active == "*", "signal": strength,
                           "secured": security != "--"}
    return sorted(found.values(), key=lambda item: (not item["active"],
                                                     -item["signal"], item["ssid"].casefold()))


def connect():
    request = json.loads(sys.stdin.readline())
    ssid = request["ssid"]
    password = request.get("password", "")
    command = ["nmcli", "-w", "15" if password else "5", "device", "wifi", "connect", ssid]
    if password:
        command.extend(("password", password))
    result = run(*command, timeout=20 if password else 8)
    return {"ok": result.returncode == 0,
            "error": (result.stderr or result.stdout).strip() if result.returncode else ""}


def main():
    try:
        if sys.argv[1:] == ["--list"]:
            output = {"networks": networks()}
        elif sys.argv[1:] == ["--list", "--rescan"]:
            output = {"networks": networks(rescan=True)}
        elif sys.argv[1:] == ["--connect"]:
            output = connect()
        else:
            output = {"error": "Usage: wifi_picker.py --list [--rescan] | --connect"}
        print(json.dumps(output, ensure_ascii=False))
        return 0 if "error" not in output else 1
    except (OSError, subprocess.TimeoutExpired, RuntimeError, ValueError, KeyError) as error:
        print(json.dumps({"error": str(error)}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
