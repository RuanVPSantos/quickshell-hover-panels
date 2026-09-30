#!/usr/bin/env python3
"""Choose a nearby Wi-Fi network with Rofi and connect through NetworkManager."""

import subprocess
import sys


def run(*command, input_text=None, timeout=20):
    return subprocess.run(
        command, input=input_text, capture_output=True, text=True, timeout=timeout,
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
        return []
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
        if ssid not in found or strength > found[ssid][1]:
            found[ssid] = (active == "*", strength, security)
    return sorted(((ssid, *details) for ssid, details in found.items()),
                  key=lambda item: (not item[1], -item[2], item[0].casefold()))


def dialog(message, kind="error"):
    run("zenity", f"--{kind}", "--title=Wi-Fi", f"--text={message}", timeout=120)


def main():
    choices = networks()
    while True:
        labels = [f"{'●' if active else '○'}  {ssid}   {signal}%{'  ·  Secured' if security != '--' else ''}"
                  for ssid, active, signal, security in choices]
        labels.append("⟳  Rescan networks")
        selected = run("rofi", "-dmenu", "-i", "-p", "Wi-Fi", "-format", "i",
                       input_text="\n".join(labels) + "\n", timeout=120)
        if selected.returncode or not selected.stdout.strip().isdigit():
            return 0
        index = int(selected.stdout.strip())
        if index == len(choices):
            choices = networks(rescan=True)
            continue
        if index >= len(choices):
            return 1
        break
    ssid, active, _, security = choices[index]
    if active:
        return 0

    connected = run("nmcli", "-w", "5", "device", "wifi", "connect", ssid, timeout=7)
    if connected.returncode == 0:
        return 0
    if security == "--":
        dialog(f"Could not connect to {ssid}.\n{connected.stderr.strip()}")
        return 1

    password = run("zenity", "--password", "--title=Wi-Fi password",
                   f"--text=Password for {ssid}", timeout=120)
    if password.returncode:
        return 0
    connected = run("nmcli", "-w", "15", "device", "wifi", "connect", ssid,
                    "password", password.stdout.rstrip("\n"), timeout=20)
    if connected.returncode:
        dialog(f"Could not connect to {ssid}.\n{connected.stderr.strip()}")
        return 1
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"Wi-Fi picker: {error}", file=sys.stderr)
        sys.exit(1)
