import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

ShellRoot {
    id: shell

    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
    readonly property bool barVisible: visibilityState.text().trim() !== "hidden"
    readonly property var entries: ["notifications", "network", "bluetooth", "battery", "brightness", "microphone", "volume", "nightlight"]
    property var status: ({ enabled: false })
    property string current: ""
    property real suppressStatusUntil: 0
    readonly property int activeIndex: Math.max(0, entries.indexOf(current))

    FileView {
        id: visibilityState
        path: shell.stateHome + "/quickshell-hover-panels/left-status-visible"
        watchChanges: true
        onFileChanged: reload()
    }

    onBarVisibleChanged: if (!barVisible) current = ""

    function field(name) { return status[name] || {}; }

    function iconFor(name) {
        const value = field(name);
        switch (name) {
        case "notifications": return status.dnd ? "" : "";
        case "network": return value.connected ? (value.type === "wifi" ? "󰤨" : "󰌘") : "󰌙";
        case "bluetooth": return value.powered ? "" : "󰂳";
        case "battery": return !value.present ? "󰂎" : value.state === "Charging" ? "" : value.percent > 80 ? "󰁹" : value.percent > 40 ? "󰁽" : "󰁻";
        case "brightness": return "";
        case "microphone": return status.input && status.input.muted ? "" : "";
        case "volume": return status.output && status.output.muted ? "󰖁" : "";
        case "nightlight": return status.nightlight ? "" : "☀";
        }
        return "";
    }

    function titleFor(name) {
        return ({ notifications: "Notifications", network: "Network", bluetooth: "Bluetooth",
                  battery: "Battery", brightness: "Brightness", microphone: "Microphone",
                  volume: "Volume", nightlight: "Night light" })[name] || "";
    }

    function summaryFor(name) {
        const value = field(name);
        switch (name) {
        case "notifications": return status.dnd ? "Do Not Disturb is on" : "Notifications are on";
        case "network": return value.connected ? value.name : "Disconnected";
        case "bluetooth": return value.powered ? (value.devices ? value.devices + " device" + (value.devices === 1 ? "" : "s") + " connected" : "Ready to connect") : "Bluetooth is off";
        case "battery": return value.present ? value.percent + "%" : "No battery detected";
        case "brightness": return status.brightness + "%";
        case "microphone": return status.input ? (status.input.muted ? "Muted" : status.input.percent + "%") : "Unavailable";
        case "volume": return status.output ? (status.output.muted ? "Muted" : status.output.percent + "%") : "Unavailable";
        case "nightlight": return status.nightlight ? "On" : "Off";
        }
        return "";
    }

    function detailFor(name) {
        const value = field(name);
        switch (name) {
        case "notifications": return "Open the notification center or change DND.";
        case "network": return value.connected ? (value.type === "wifi" ? "Wi-Fi · " + value.signal + "% signal" : "Ethernet connected") : "Check Wi-Fi or open network settings.";
        case "bluetooth": return "Manage paired devices and Bluetooth power.";
        case "battery": return value.present ? (value.state || "Unknown") + " · " + (status.power_profile || "Unknown") + " profile" : "No battery";
        case "brightness": return "Adjust the laptop display.";
        case "microphone": return "Control your microphone input.";
        case "volume": return "Control speaker output.";
        case "nightlight": return "Reduce blue light from the display.";
        }
        return "";
    }

    function percentFor(name) {
        if (name === "battery") return field(name).percent || 0;
        if (name === "brightness") return status.brightness || 0;
        if (name === "microphone") return field("input").percent || 0;
        if (name === "volume") return field("output").percent || 0;
        if (name === "network" && field(name).type === "wifi") return field(name).signal || 0;
        return -1;
    }

    function actionsFor(name) {
        switch (name) {
        case "notifications": return [{ label: "Open", id: "notifications-open" }, { label: status.dnd ? "Disable DND" : "Enable DND", id: "dnd" }];
        case "network": return [{ label: "Other Wi-Fi", id: "wifi-picker" }, { label: "Settings", id: "network-settings" }, { label: field(name).wifi_enabled ? "Wi-Fi off" : "Wi-Fi on", id: "wifi" }];
        case "bluetooth": return [{ label: "Devices", id: "bluetooth-settings" }, { label: field(name).powered ? "Turn off" : "Turn on", id: "bluetooth-power" }];
        case "battery": return [{ label: "Saver", id: "profile-saver" }, { label: "Balanced", id: "profile-balanced" }, { label: "Desktop", id: "profile-desktop" }];
        case "brightness": return [{ label: "−10%", id: "brightness-down" }, { label: "+10%", id: "brightness-up" }];
        case "microphone": return [{ label: field("input").muted ? "Unmute" : "Mute", id: "microphone-mute" }, { label: "Mixer", id: "mixer" }];
        case "volume": return [{ label: "−5%", id: "volume-down" }, { label: field("output").muted ? "Unmute" : "Mute", id: "volume-mute" }, { label: "+5%", id: "volume-up" }];
        case "nightlight": return [{ label: status.nightlight ? "Turn off" : "Turn on", id: "nightlight-toggle" }];
        }
        return [];
    }

    function runAction(action) {
        let command = [];
        switch (action) {
        case "notifications-open": command = ["swaync-client", "-t", "-sw"]; break;
        case "dnd": command = ["swaync-client", "-d", "-sw"]; break;
        case "network-settings": command = ["nm-connection-editor"]; break;
        case "wifi-picker": command = ["python3", configHome + "/quickshell/left-status/wifi_picker.py"]; break;
        case "wifi": command = ["nmcli", "radio", "wifi", field("network").wifi_enabled ? "off" : "on"]; break;
        case "bluetooth-settings": command = ["blueman-manager"]; break;
        case "bluetooth-power": command = ["bluetoothctl", "power", field("bluetooth").powered ? "off" : "on"]; break;
        case "profile-saver": command = ["tuned-adm", "profile", "balanced-battery"]; break;
        case "profile-balanced": command = ["tuned-adm", "profile", "balanced"]; break;
        case "profile-desktop": command = ["tuned-adm", "profile", "desktop"]; break;
        case "brightness-down": command = ["brightnessctl", "set", "10%-"]; break;
        case "brightness-up": command = ["brightnessctl", "set", "+10%"]; break;
        case "microphone-mute": command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]; break;
        case "volume-down": command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"]; break;
        case "volume-mute": command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]; break;
        case "volume-up": command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%+"]; break;
        case "mixer": command = ["pavucontrol"]; break;
        case "nightlight-toggle": command = [configHome + "/hypr/scripts/Hyprsunset.sh", "toggle"]; break;
        }
        if (command.length) {
            optimistic(action);
            Quickshell.execDetached(command);
            quickRefresh.restart();
        }
    }

    function optimistic(action) {
        const next = Object.assign({}, status);
        const network = Object.assign({}, field("network"));
        const bluetooth = Object.assign({}, field("bluetooth"));
        const input = Object.assign({}, field("input"));
        const output = Object.assign({}, field("output"));
        if (action === "dnd") next.dnd = !status.dnd;
        else if (action === "wifi") { network.wifi_enabled = !network.wifi_enabled; if (!network.wifi_enabled) network.connected = false; next.network = network; }
        else if (action === "bluetooth-power") { bluetooth.powered = !bluetooth.powered; next.bluetooth = bluetooth; }
        else if (action === "brightness-down") next.brightness = Math.max(0, (status.brightness || 0) - 10);
        else if (action === "brightness-up") next.brightness = Math.min(100, (status.brightness || 0) + 10);
        else if (action === "microphone-mute") { input.muted = !input.muted; next.input = input; }
        else if (action === "volume-mute") { output.muted = !output.muted; next.output = output; }
        else if (action === "volume-down") { output.percent = Math.max(0, (output.percent || 0) - 5); next.output = output; }
        else if (action === "volume-up") { output.percent = Math.min(100, (output.percent || 0) + 5); next.output = output; }
        else if (action === "nightlight-toggle") next.nightlight = !status.nightlight;
        else if (action === "profile-saver") next.power_profile = "balanced-battery";
        else if (action === "profile-balanced") next.power_profile = "balanced";
        else if (action === "profile-desktop") next.power_profile = "desktop";
        else return;
        status = next;
        suppressStatusUntil = Date.now() + (action.startsWith("profile-") ? 1800 : 700);
    }

    function selectedAction(action) {
        if (current !== "battery") return false;
        return (action === "profile-saver" && status.power_profile === "balanced-battery") ||
               (action === "profile-balanced" && status.power_profile === "balanced") ||
               (action === "profile-desktop" && status.power_profile === "desktop");
    }

    function closeSoon() { closeDelay.restart(); }

    Timer {
        id: closeDelay
        interval: 90
        onTriggered: shell.current = ""
    }

    Timer {
        id: quickRefresh
        interval: 450
        onTriggered: {
            if (!statusProcess.running) statusProcess.running = true;
        }
    }

    Process {
        id: statusProcess
        command: ["python3", shell.configHome + "/quickshell/left-status/status.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text.trim()) return;
                try {
                    if (Date.now() < shell.suppressStatusUntil) {
                        quickRefresh.restart();
                        return;
                    }
                    shell.status = JSON.parse(this.text);
                    if (!shell.status.enabled) shell.current = "";
                } catch (error) {
                    console.warn("Left status:", error);
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!statusProcess.running) statusProcess.running = true;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: shell.status.enabled && shell.barVisible && !(Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false)
            implicitWidth: 46
            implicitHeight: 336
            anchors.left: true
            anchors.bottom: true
            margins.bottom: 8
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:left-status-icons"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Column {
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                    model: shell.entries
                    delegate: Rectangle {
                        id: statusIcon
                        required property string modelData
                        width: 38
                        height: 38
                        radius: 13
                        color: shell.current === modelData ? "#75566570" : iconMouse.containsMouse ? "#554C4552" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: shell.iconFor(statusIcon.modelData)
                            color: shell.current === statusIcon.modelData ? "#ffffff" : "#e3bbd0"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 17
                        }

                        MouseArea {
                            id: iconMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                closeDelay.stop();
                                shell.current = statusIcon.modelData;
                            }
                            onExited: shell.closeSoon()
                            onClicked: {
                                closeDelay.stop();
                                shell.current = statusIcon.modelData;
                            }
                        }
                    }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: shell.status.enabled && shell.barVisible && shell.current !== "" && !(Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false)
            implicitWidth: 292
            implicitHeight: 204
            anchors.left: true
            anchors.bottom: true
            margins.left: 46
            margins.bottom: Math.max(8, 8 + (7 - shell.activeIndex) * 42 - 88)
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:left-status-popout"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 5
                anchors.rightMargin: 5
                anchors.topMargin: 4
                anchors.bottomMargin: 4
                radius: 20
                color: Qt.rgba(0.05, 0.045, 0.06, 0.84)
                border.color: "#66FFFFFF"
                border.width: 1

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) closeDelay.stop();
                        else shell.closeSoon();
                    }
                }

                Text {
                    x: 18; y: 17
                    text: shell.titleFor(shell.current)
                    color: "#f8f3f7"
                    font.family: "Noto Sans"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
                Text {
                    x: 18; y: 50
                    width: parent.width - 36
                    text: shell.summaryFor(shell.current)
                    color: "#ffffff"
                    font.family: "Noto Sans"
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    x: 18; y: 84
                    width: parent.width - 36
                    text: shell.detailFor(shell.current)
                    color: "#cfc2d0"
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
                Rectangle {
                    x: 18; y: 111
                    width: parent.width - 36; height: 5
                    radius: 3
                    color: "#584e5b"
                    visible: shell.percentFor(shell.current) >= 0
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(100, shell.percentFor(shell.current))) / 100
                        height: parent.height
                        radius: 3
                        color: "#e6c5d7"
                    }
                }
                Row {
                    x: 18; y: 139
                    spacing: 7
                    Repeater {
                        model: shell.actionsFor(shell.current)
                        delegate: Rectangle {
                            id: actionButton
                            required property var modelData
                            readonly property int count: shell.actionsFor(shell.current).length
                            width: count === 3 ? 76 : count === 2 ? 119 : 249
                            height: 42
                            radius: 11
                            color: shell.selectedAction(actionButton.modelData.id) || actionMouse.containsMouse ? "#785f75" : "#514452"
                            Text {
                                anchors.centerIn: parent
                                text: actionButton.modelData.label
                                color: "#f8f3f7"
                                font.family: "Noto Sans"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                            MouseArea {
                                id: actionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: shell.runAction(actionButton.modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
