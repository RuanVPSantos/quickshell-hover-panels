# Operations

## Status

```bash
ruanops project-status quickshell_panels
qs list --all
```

The expected session has one `top-dashboard` and one `edge-session` instance.

## Health and logs

```bash
qs ipc -c top-dashboard show
qs ipc -c edge-session show
qs log -c top-dashboard --tail 50
qs log -c edge-session --tail 50
hyprctl configerrors
```

## Update

From the project checkout, review `git status` and then run `./install.sh --update`.
The script pulls with fast-forward only, backs up changed local files, copies the
two panel configs and restarts their current Hyprland instances. No VPS, DNS,
secret or remote deployment is involved.

## Recovery

Backups are stored in `~/.local/state/quickshell-hover-panels/backups/`. Restore
the previous QML files to `~/.config/quickshell` and restart the two `qs`
instances if an update needs to be rolled back. Keep the optional animation
frames in place; the installer does not touch them.

Publishing to GitHub and installing changes on another machine require the
operator's approval.
