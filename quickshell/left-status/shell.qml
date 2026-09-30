import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import Quickshell.Wayland

ShellRoot {
    id: shell

    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
    readonly property bool barVisible: visibilityState.text().trim() !== "hidden"
    readonly property bool customLayout: status.layout === "custom"
    readonly property var entries: ["notifications", "network", "bluetooth", "battery", "brightness", "microphone", "volume", "nightlight"]
    property var status: ({ enabled: false })
    property string current: ""
    property bool wifiOpen: false
    property bool bluetoothOpen: false
    property bool notificationsOpen: false
    property bool workspacePreviewOpen: false
    property int previewWorkspaceId: 0
    property string previewScreenName: ""
    property bool previewTriggerHovered: false
    property bool previewPanelHovered: false
    property var workspacePreviewData: ({ windows: {}, images: {} })
    property string wifiScreenName: ""
    property string bluetoothScreenName: ""
    property string notificationsScreenName: ""
    property bool wifiTriggerHovered: false
    property bool wifiPanelHovered: false
    property bool bluetoothTriggerHovered: false
    property bool bluetoothPanelHovered: false
    property bool notificationsTriggerHovered: false
    property bool notificationsPanelHovered: false
    property var notifications: []
    property var liveNotifications: ({})
    property var toast: null
    property bool historyLoaded: false
    property var pendingLevels: ({})
    property date now: new Date()
    property real suppressStatusUntil: 0
    readonly property int activeIndex: Math.max(0, entries.indexOf(current))

    FileView {
        id: visibilityState
        path: shell.stateHome + "/quickshell-hover-panels/left-status-visible"
        watchChanges: true
        onFileChanged: reload()
    }

    onBarVisibleChanged: if (!barVisible) { current = ""; wifiOpen = false; bluetoothOpen = false; notificationsOpen = false; workspacePreviewOpen = false; }

    FileView {
        id: notificationHistory
        path: shell.stateHome + "/quickshell-hover-panels/notifications.json"
        onLoaded: {
            if (shell.historyLoaded) return;
            shell.historyLoaded = true;
            try {
                const saved = JSON.parse(text());
                shell.notifications = Array.isArray(saved) ? saved : [];
            }
            catch (error) { shell.notifications = []; }
        }
    }

    FileView {
        id: dndState
        path: shell.stateHome + "/quickshell-hover-panels/dnd"
        watchChanges: true
        onFileChanged: reload()
    }

    Loader {
        active: shell.customLayout
        sourceComponent: NotificationServer {
            persistenceSupported: true
            bodySupported: true
            actionsSupported: true
            onNotification: notification => {
                notification.tracked = true;
                shell.captureNotification(notification);
            }
        }
    }

    function captureNotification(notification) {
        if (notification.transient) return;
        const key = Date.now().toString() + "-" + notification.id;
        const item = { key: key, app: notification.appName || "Notification",
                       summary: notification.summary || "", body: notification.body || "" };
        liveNotifications[key] = notification;
        notifications = [item].concat(notifications).slice(0, 50);
        notificationHistory.setText(JSON.stringify(notifications));
        if (dndState.text().trim() !== "on") {
            toast = item;
            toastTimer.restart();
        }
    }

    function dismissNotification(key) {
        if (liveNotifications[key]) liveNotifications[key].dismiss();
        delete liveNotifications[key];
        notifications = notifications.filter(item => item.key !== key);
        notificationHistory.setText(JSON.stringify(notifications));
    }

    function clearNotifications() {
        Object.values(liveNotifications).forEach(notification => notification.dismiss());
        liveNotifications = ({});
        notifications = [];
        toast = null;
        notificationHistory.setText("[]");
    }

    function activateNotification(key) {
        const notification = liveNotifications[key];
        if (notification && notification.actions.length > 0)
            notification.actions[0].invoke();
    }

    Timer {
        id: toastTimer
        interval: 5000
        onTriggered: shell.toast = null
    }

    Timer {
        id: wifiCloseDelay
        interval: 100
        onTriggered: {
            if (!shell.wifiTriggerHovered && !shell.wifiPanelHovered)
                shell.wifiOpen = false;
        }
    }

    Timer {
        id: bluetoothCloseDelay
        interval: 100
        onTriggered: {
            if (!shell.bluetoothTriggerHovered && !shell.bluetoothPanelHovered)
                shell.bluetoothOpen = false;
        }
    }

    Timer {
        id: notificationsCloseDelay
        interval: 110
        onTriggered: {
            if (!shell.notificationsTriggerHovered && !shell.notificationsPanelHovered)
                shell.notificationsOpen = false;
        }
    }

    Timer {
        id: workspacePreviewCloseDelay
        interval: 100
        onTriggered: {
            if (!shell.previewTriggerHovered && !shell.previewPanelHovered)
                shell.workspacePreviewOpen = false;
        }
    }

    function previewKey() { return previewScreenName + ":" + previewWorkspaceId; }
    function previewWindows() { return workspacePreviewData.windows[previewKey()] || []; }
    function previewImage() { return workspacePreviewData.images[previewKey()] || ""; }

    Process {
        id: workspaceCaptureProcess
        command: ["python3", shell.configHome + "/quickshell/left-status/workspace_preview.py", "capture"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { shell.workspacePreviewData = JSON.parse(this.text); }
                catch (error) { console.warn("Workspace capture:", error); }
            }
        }
    }

    Process {
        id: workspaceHoverProcess
        command: ["python3", shell.configHome + "/quickshell/left-status/workspace_preview.py",
                  "capture", shell.previewScreenName, shell.previewWorkspaceId.toString()]
        stdout: StdioCollector {
            onStreamFinished: {
                try { shell.workspacePreviewData = JSON.parse(this.text); }
                catch (error) { console.warn("Workspace hover capture:", error); }
            }
        }
    }

    Timer {
        interval: 12000
        running: shell.customLayout && shell.barVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!shell.workspacePreviewOpen && !workspaceCaptureProcess.running &&
                !(Hyprland.focusedMonitor?.activeWorkspace?.hasFullscreen ?? false))
                workspaceCaptureProcess.running = true;
        }
    }

    IpcHandler {
        target: "leftStatus"
        function refresh(): void {
            if (!statusProcess.running) statusProcess.running = true;
        }
        function openWifi(): void {
            shell.current = "";
            shell.wifiScreenName = Hyprland.focusedMonitor?.name || Quickshell.screens[0]?.name || "";
            shell.wifiOpen = true;
        }
        function openBluetooth(): void {
            shell.current = "";
            shell.bluetoothScreenName = Hyprland.focusedMonitor?.name || Quickshell.screens[0]?.name || "";
            shell.bluetoothOpen = true;
        }
        function openNotifications(): void {
            shell.current = "";
            shell.notificationsScreenName = Hyprland.focusedMonitor?.name || Quickshell.screens[0]?.name || "";
            shell.notificationsOpen = true;
        }
        function clearNotifications(): void {
            shell.clearNotifications();
        }
        function debugState(): string {
            return JSON.stringify({ enabled: shell.status.enabled, layout: shell.status.layout,
                                    visible: shell.barVisible, current: shell.current,
                                    wifiOpen: shell.wifiOpen, trigger: shell.wifiTriggerHovered,
                                    panel: shell.wifiPanelHovered, screen: shell.wifiScreenName });
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: shell.now = new Date()
    }

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

    function stageLevel(name, requested) {
        if (name !== "brightness" && name !== "volume" && name !== "microphone") return;
        const value = Math.round(Math.max(name === "brightness" ? 5 : 0, Math.min(100, requested)));
        const next = Object.assign({}, status);
        if (name === "brightness") next.brightness = value;
        else {
            const key = name === "volume" ? "output" : "input";
            next[key] = Object.assign({}, field(key), { percent: value, muted: false });
        }
        status = next;
        pendingLevels[name] = value;
        suppressStatusUntil = Date.now() + 850;
        levelDebounce.restart();
    }

    function flushLevels() {
        levelDebounce.stop();
        const pending = pendingLevels;
        pendingLevels = ({});
        for (const name of Object.keys(pending)) {
            const value = pending[name];
            if (name === "brightness") Quickshell.execDetached(["brightnessctl", "set", value + "%"]);
            else {
                const target = name === "volume" ? "@DEFAULT_AUDIO_SINK@" : "@DEFAULT_AUDIO_SOURCE@";
                Quickshell.execDetached(["wpctl", "set-volume", target, (value / 100).toFixed(2)]);
                Quickshell.execDetached(["wpctl", "set-mute", target, "0"]);
            }
        }
        if (Object.keys(pending).length) quickRefresh.restart();
    }

    Timer {
        id: levelDebounce
        interval: 70
        onTriggered: shell.flushLevels()
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

    function runAction(action, screen) {
        if (action === "wifi-picker") {
            current = "";
            wifiScreenName = screen.name;
            wifiOpen = true;
            wifiCloseDelay.stop();
            return;
        }
        let command = [];
        switch (action) {
        case "notifications-open": command = ["swaync-client", "-t", "-sw"]; break;
        case "dnd": command = ["swaync-client", "-d", "-sw"]; break;
        case "network-settings": command = ["nm-connection-editor"]; break;
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
                    if (!shell.status.enabled) { shell.current = ""; shell.wifiOpen = false; shell.bluetoothOpen = false; }
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
            id: statusRail
            required property var modelData
            readonly property var monitor: Hyprland.monitorFor(modelData)
            readonly property var workspaceIds: {
                const ids = [1, 2, 3, 4, 5];
                Hyprland.workspaces.values.forEach(workspace => {
                    if (workspace.id > 5 && workspace.monitor?.name === monitor?.name)
                        ids.push(workspace.id);
                });
                return ids.sort((a, b) => a - b);
            }
            readonly property var trayItems: SystemTray.items.values.filter(item => {
                const name = (item.id + " " + item.title).toLowerCase();
                return !name.includes("blueman") && !name.includes("networkmanager") &&
                       !name.includes("nm_applet") && !name.includes("nm-applet");
            })
            screen: modelData
            visible: shell.status.enabled && shell.barVisible && !(monitor?.activeWorkspace?.hasFullscreen ?? false)
            implicitWidth: 46
            implicitHeight: shell.customLayout ? modelData.height : 336
            anchors.left: true
            anchors.top: shell.customLayout
            anchors.bottom: !shell.customLayout
            margins.bottom: shell.customLayout ? 0 : 8
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:left-status-icons"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: shell.customLayout ? 8 : 0
                anchors.bottomMargin: shell.customLayout ? 8 : 0
                radius: 20
                color: Qt.rgba(0, 0, 0, 0.55)
                border.color: "#4DFFFFFF"
                border.width: 1
            }

            Text {
                visible: shell.customLayout
                anchors.top: parent.top
                anchors.topMargin: 20
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(shell.now, "hh\nmm")
                horizontalAlignment: Text.AlignHCenter
                color: "#F4F4F6"
                font.family: "Noto Sans"
                font.pixelSize: 15
                font.weight: Font.DemiBold
                lineHeight: 1.1
            }

            ListView {
                visible: shell.customLayout
                anchors.centerIn: parent
                width: 34
                height: Math.min(328, Math.max(48, statusRail.workspaceIds.length * 38 + 8))
                model: statusRail.workspaceIds
                clip: true
                spacing: 4
                delegate: Rectangle {
                    id: workspaceButton
                    required property int modelData
                    readonly property bool active: modelData === statusRail.monitor?.activeWorkspace?.id
                    width: 34
                    height: 34
                    radius: 10
                    color: workspaceMouse.containsMouse ? "#4039323E" : "transparent"
                    Rectangle {
                        anchors.centerIn: parent
                        width: workspaceButton.active ? 11 : 9
                        height: width
                        radius: width / 2
                        color: workspaceButton.active ? "#e4d3e1" : "transparent"
                        border.color: "#e4d3e1"
                        border.width: workspaceButton.active ? 0 : 1.5
                    }
                    MouseArea {
                        id: workspaceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            workspacePreviewCloseDelay.stop();
                            shell.previewWorkspaceId = workspaceButton.modelData;
                            shell.previewScreenName = statusRail.modelData.name;
                            shell.previewTriggerHovered = true;
                            shell.workspacePreviewOpen = true;
                            shell.current = "";
                            shell.wifiOpen = false;
                            shell.bluetoothOpen = false;
                            shell.notificationsOpen = false;
                            if (!workspaceHoverProcess.running) workspaceHoverProcess.running = true;
                        }
                        onExited: {
                            shell.previewTriggerHovered = false;
                            workspacePreviewCloseDelay.restart();
                        }
                        onClicked: {
                            shell.workspacePreviewOpen = false;
                            Hyprland.dispatch("workspace " + workspaceButton.modelData);
                        }
                    }
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: shell.customLayout ? 12 : 2
                spacing: 10

                ListView {
                    id: trayList
                    visible: shell.customLayout && statusRail.trayItems.length > 0
                    width: 38
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: visible ? Math.min(statusRail.trayItems.length * 42, Math.max(42, statusRail.height / 2 - 350)) : 0
                    clip: true
                    spacing: 4
                    model: statusRail.trayItems
                    delegate: Rectangle {
                        id: trayButton
                        required property var modelData
                        width: 38
                        height: 38
                        radius: 13
                        color: trayMouse.containsMouse ? "#4039323E" : "transparent"
                        Image {
                            id: trayImage
                            anchors.centerIn: parent
                            width: 21
                            height: 21
                            source: trayButton.modelData.icon
                            sourceSize.width: 21
                            sourceSize.height: 21
                            fillMode: Image.PreserveAspectFit
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: trayImage.status !== Image.Ready
                            text: "󰀻"
                            color: "#F4F4F6"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 17
                        }
                        MouseArea {
                            id: trayMouse
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                const item = trayButton.modelData;
                                if (mouse.button === Qt.RightButton || item.onlyMenu)
                                    item.secondaryActivate();
                                else if (mouse.button === Qt.MiddleButton) item.secondaryActivate();
                                else item.activate();
                            }
                            onWheel: wheel => trayButton.modelData.scroll(wheel.angleDelta.y, false)
                        }
                    }
                }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4
                    Repeater {
                        model: shell.entries
                        delegate: Rectangle {
                            id: statusIcon
                            required property string modelData
                            width: 38
                            height: 38
                            radius: 13
                            color: shell.current === modelData || (modelData === "network" && shell.wifiOpen) ||
                                   (modelData === "bluetooth" && shell.bluetoothOpen) ||
                                   (modelData === "notifications" && shell.notificationsOpen) ? "#514354" :
                                   iconMouse.containsMouse ? "#4039323E" : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: shell.iconFor(statusIcon.modelData)
                                color: shell.current === statusIcon.modelData ? "#ffffff" : "#F4F4F6"
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
                                    if (statusIcon.modelData === "network") {
                                        wifiCloseDelay.stop();
                                        shell.wifiTriggerHovered = true;
                                        shell.wifiScreenName = statusRail.modelData.name;
                                        shell.current = "";
                                        shell.bluetoothOpen = false;
                                        shell.notificationsOpen = false;
                                        shell.wifiOpen = true;
                                    } else if (statusIcon.modelData === "bluetooth") {
                                        bluetoothCloseDelay.stop();
                                        shell.bluetoothTriggerHovered = true;
                                        shell.bluetoothScreenName = statusRail.modelData.name;
                                        shell.current = "";
                                        shell.wifiOpen = false;
                                        shell.notificationsOpen = false;
                                        shell.bluetoothOpen = true;
                                    } else if (statusIcon.modelData === "notifications") {
                                        shell.wifiOpen = false;
                                        shell.bluetoothOpen = false;
                                        shell.current = "";
                                        if (shell.customLayout) {
                                            notificationsCloseDelay.stop();
                                            shell.notificationsTriggerHovered = true;
                                            shell.notificationsScreenName = statusRail.modelData.name;
                                            shell.notificationsOpen = true;
                                        } else Quickshell.execDetached(["swaync-client", "-op", "-sw"]);
                                    } else {
                                        shell.wifiOpen = false;
                                        shell.bluetoothOpen = false;
                                        shell.notificationsOpen = false;
                                        shell.current = statusIcon.modelData;
                                    }
                                }
                                onExited: {
                                    if (statusIcon.modelData === "network") {
                                        shell.wifiTriggerHovered = false;
                                        wifiCloseDelay.restart();
                                    } else if (statusIcon.modelData === "bluetooth") {
                                        shell.bluetoothTriggerHovered = false;
                                        bluetoothCloseDelay.restart();
                                    } else if (statusIcon.modelData === "notifications") {
                                        shell.notificationsTriggerHovered = false;
                                        notificationsCloseDelay.restart();
                                    } else shell.closeSoon();
                                }
                                onClicked: {
                                    closeDelay.stop();
                                    if (statusIcon.modelData === "network") {
                                        shell.wifiScreenName = statusRail.modelData.name;
                                        shell.wifiOpen = true;
                                    } else if (statusIcon.modelData === "bluetooth") {
                                        shell.bluetoothScreenName = statusRail.modelData.name;
                                        shell.bluetoothOpen = true;
                                    } else if (statusIcon.modelData === "notifications") {
                                        if (shell.customLayout) {
                                            shell.notificationsScreenName = statusRail.modelData.name;
                                            shell.notificationsOpen = true;
                                        } else Quickshell.execDetached(["swaync-client", "-op", "-sw"]);
                                    } else shell.current = statusIcon.modelData;
                                }
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
            id: workspacePreview
            required property var modelData
            readonly property var windows: shell.previewWindows()
            readonly property string imagePath: shell.previewImage()
            screen: modelData
            visible: shell.status.enabled && shell.customLayout && shell.barVisible &&
                     shell.workspacePreviewOpen && shell.previewScreenName === modelData.name &&
                     !(Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false)
            implicitWidth: 342
            implicitHeight: 306
            anchors.left: true
            anchors.top: true
            margins.left: 46
            margins.top: Math.max(8, Math.round((modelData.height - 306) / 2))
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:left-status-workspaces"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 5
                anchors.rightMargin: 5
                anchors.topMargin: 4
                anchors.bottomMargin: 4
                radius: 23
                color: Qt.rgba(0, 0, 0, 0.55)
                border.color: "#4DFFFFFF"
                border.width: 1

                HoverHandler {
                    onHoveredChanged: {
                        shell.previewPanelHovered = hovered;
                        if (hovered) workspacePreviewCloseDelay.stop();
                        else workspacePreviewCloseDelay.restart();
                    }
                }

                Text {
                    x: 17; y: 14
                    text: "Workspace " + shell.previewWorkspaceId
                    color: "#F4F4F6"
                    font.family: "Noto Sans"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 17
                    y: 17
                    text: workspacePreview.windows.length + (workspacePreview.windows.length === 1 ? " window" : " windows")
                    color: "#CFC4D0"
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                }

                Rectangle {
                    x: 16; y: 43
                    width: parent.width - 32
                    height: 171
                    radius: 12
                    color: "#2B252C"
                    border.color: "#664D4650"
                    border.width: 1
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: workspacePreview.imagePath ? "file://" + workspacePreview.imagePath : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                        asynchronous: true
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !workspacePreview.imagePath
                        text: workspacePreview.windows.length ? "Preview available after visiting" : "Empty workspace"
                        color: "#B6AAB8"
                        font.family: "Noto Sans"
                        font.pixelSize: 12
                    }
                }

                Column {
                    x: 17; y: 223
                    width: parent.width - 34
                    spacing: 5
                    Repeater {
                        model: workspacePreview.windows.slice(0, 3)
                        delegate: Text {
                            required property var modelData
                            width: parent.width
                            text: "•  " + modelData.class + "  ·  " + modelData.title
                            color: "#EEE8EF"
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                    Text {
                        visible: workspacePreview.windows.length > 3
                        text: "+" + (workspacePreview.windows.length - 3) + " more"
                        color: "#B6AAB8"
                        font.family: "Noto Sans"
                        font.pixelSize: 11
                    }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: statusPopup
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
                radius: 26
                color: Qt.rgba(0, 0, 0, 0.55)
                border.color: "#4DFFFFFF"
                border.width: 1

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 10
                    radius: 18
                    color: "#3D2D2831"
                    border.color: "#80463D48"
                    border.width: 1
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) closeDelay.stop();
                        else shell.closeSoon();
                    }
                }

                Text {
                    x: 18; y: 17
                    text: shell.titleFor(shell.current)
                    color: "#f0e3ed"
                    font.family: "Noto Sans"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
                Text {
                    x: 18; y: 50
                    width: parent.width - 36
                    text: shell.summaryFor(shell.current)
                    color: "#F4F4F6"
                    font.family: "Noto Sans"
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    x: 18; y: 84
                    width: parent.width - 36
                    text: shell.detailFor(shell.current)
                    color: "#c7b8c8"
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
                Rectangle {
                    x: 18; y: 111
                    width: parent.width - 36; height: 5
                    radius: 3
                    color: "#5b4f5d"
                    visible: shell.percentFor(shell.current) >= 0 &&
                             shell.current !== "brightness" && shell.current !== "volume" && shell.current !== "microphone"
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(100, shell.percentFor(shell.current))) / 100
                        height: parent.height
                        radius: 3
                        color: "#e3cde0"
                    }
                }
                Controls.Slider {
                    id: levelSlider
                    x: 18; y: 101
                    width: parent.width - 36
                    height: 27
                    visible: shell.current === "brightness" || shell.current === "volume" || shell.current === "microphone"
                    from: shell.current === "brightness" ? 5 : 0
                    to: 100
                    value: shell.percentFor(shell.current)
                    onMoved: shell.stageLevel(shell.current, value)
                    onPressedChanged: if (!pressed) shell.flushLevels()
                    background: Rectangle {
                        x: 0
                        y: (levelSlider.height - height) / 2
                        width: levelSlider.width
                        height: 6
                        radius: 3
                        color: "#5b4f5d"
                        Rectangle {
                            width: parent.width * levelSlider.visualPosition
                            height: parent.height
                            radius: 3
                            color: "#f2eaf1"
                        }
                    }
                    handle: Rectangle {
                        x: levelSlider.leftPadding + levelSlider.visualPosition * (levelSlider.availableWidth - width)
                        y: (levelSlider.height - height) / 2
                        width: 16
                        height: 16
                        radius: 8
                        color: levelSlider.pressed ? "#ffffff" : "#f2eaf1"
                        border.color: "#ab91a8"
                        border.width: 1
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
                            color: shell.selectedAction(actionButton.modelData.id) ? "#6a5369" : actionMouse.containsMouse ? "#554859" : "#423746"
                            Text {
                                anchors.centerIn: parent
                                text: actionButton.modelData.label
                                color: "#F4F4F6"
                                font.family: "Noto Sans"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                            MouseArea {
                                id: actionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: shell.runAction(actionButton.modelData.id, statusPopup.modelData)
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
            id: wifiPanel
            required property var modelData
            screen: modelData
            visible: shell.status.enabled && shell.barVisible && shell.wifiOpen && shell.wifiScreenName === modelData.name && !(Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false)
            implicitWidth: 368
            implicitHeight: 400
            anchors.left: true
            anchors.bottom: true
            margins.left: 46
            margins.bottom: 8
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:left-status-wifi"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            onVisibleChanged: {
                if (visible) wifiPicker.open();
                else shell.wifiPanelHovered = false;
            }

            WifiPicker {
                id: wifiPicker
                anchors.fill: parent
                anchors.margins: 4
                helperPath: shell.configHome + "/quickshell/left-status/wifi_picker.py"
                wifiEnabled: shell.field("network").wifi_enabled ?? false
                onDismissed: shell.wifiOpen = false
                onConnected: quickRefresh.restart()
                onHoverChanged: hovered => {
                    shell.wifiPanelHovered = hovered;
                    if (hovered) wifiCloseDelay.stop();
                    else wifiCloseDelay.restart();
                }
                onSettingsRequested: {
                    shell.wifiOpen = false;
                    shell.runAction("network-settings", wifiPanel.modelData);
                }
                onToggleWifiRequested: {
                    shell.wifiOpen = false;
                    shell.runAction("wifi", wifiPanel.modelData);
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bluetoothPanel
            required property var modelData
            screen: modelData
            visible: shell.status.enabled && shell.barVisible && shell.bluetoothOpen && shell.bluetoothScreenName === modelData.name && !(Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false)
            implicitWidth: 368
            implicitHeight: 400
            anchors.left: true
            anchors.bottom: true
            margins.left: 46
            margins.bottom: 8
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:left-status-bluetooth"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            onVisibleChanged: if (!visible) shell.bluetoothPanelHovered = false

            BluetoothPicker {
                anchors.fill: parent
                anchors.margins: 4
                onHoverChanged: hovered => {
                    shell.bluetoothPanelHovered = hovered;
                    if (hovered) bluetoothCloseDelay.stop();
                    else bluetoothCloseDelay.restart();
                }
                onSettingsRequested: {
                    shell.bluetoothOpen = false;
                    shell.runAction("bluetooth-settings", bluetoothPanel.modelData);
                }
                onPowerChanged: quickRefresh.restart()
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: notificationsWindow
            required property var modelData
            screen: modelData
            visible: shell.status.enabled && shell.barVisible && shell.notificationsOpen && shell.notificationsScreenName === modelData.name && !(Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false)
            implicitWidth: 368
            implicitHeight: 400
            anchors.left: true
            anchors.bottom: true
            margins.left: 46
            margins.bottom: 8
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:left-status-notifications"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            onVisibleChanged: if (!visible) shell.notificationsPanelHovered = false

            NotificationPanel {
                anchors.fill: parent
                anchors.margins: 4
                items: shell.notifications
                dnd: dndState.text().trim() === "on"
                onClearRequested: shell.clearNotifications()
                onDismissRequested: key => shell.dismissNotification(key)
                onActionRequested: key => shell.activateNotification(key)
                onDndRequested: {
                    const enabled = dndState.text().trim() !== "on";
                    dndState.setText(enabled ? "on\n" : "off\n");
                    shell.status = Object.assign({}, shell.status, { dnd: enabled });
                }
                onHoverChanged: hovered => {
                    shell.notificationsPanelHovered = hovered;
                    if (hovered) notificationsCloseDelay.stop();
                    else notificationsCloseDelay.restart();
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: shell.customLayout && shell.toast !== null &&
                     modelData.name === (Hyprland.focusedMonitor?.name || Quickshell.screens[0]?.name) &&
                     !(Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false)
            implicitWidth: 322
            implicitHeight: 86
            anchors.right: true
            anchors.top: true
            margins.right: 12
            margins.top: 12
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:notification-toast"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                radius: 18
                color: Qt.rgba(0, 0, 0, 0.67)
                border.color: "#4DFFFFFF"
                border.width: 1
                Text {
                    x: 15; y: 10
                    width: parent.width - 30
                    text: shell.toast?.app || "Notification"
                    color: "#b7a8b9"
                    font.family: "Noto Sans"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
                Text {
                    x: 15; y: 29
                    width: parent.width - 30
                    text: shell.toast?.summary || ""
                    color: "#F4F4F6"
                    font.family: "Noto Sans"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    x: 15; y: 52
                    width: parent.width - 30
                    text: shell.toast?.body || ""
                    color: "#c7b8c8"
                    font.family: "Noto Sans"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }
    }
}
