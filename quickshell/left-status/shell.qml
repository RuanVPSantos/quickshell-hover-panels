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
    readonly property int railInset: 5
    readonly property var railGeometry: status.rail_geometry || ({ gap_top: 4, gap_bottom: 4, gap_left: 4, rounding: 10 })
    property string hoverScreenName: ""
    property bool edgeHovered: false
    property bool railHovered: false
    property bool statusPanelHovered: false
    property bool trayMenuHovered: false
    readonly property bool railInteractionActive: edgeHovered || railHovered ||
        wifiPanelHovered || bluetoothPanelHovered || notificationsPanelHovered ||
        clockPanelHovered || previewPanelHovered || statusPanelHovered || trayMenuHovered
    readonly property var entries: ["notifications", "network", "bluetooth", "battery", "brightness", "microphone", "volume", "nightlight"]
    property var status: ({ enabled: false })
    property string current: ""
    property bool wifiOpen: false
    property bool bluetoothOpen: false
    property bool notificationsOpen: false
    property bool workspacePreviewOpen: false
    property int previewWorkspaceId: 0
    property string previewScreenName: ""
    property string previewTriggerKey: ""
    property bool previewPanelHovered: false
    property var workspacePreviewData: ({ windows: {}, images: {} })
    property real lastPreviewUpdate: 0
    property string hoverCaptureKey: ""
    property string displayedPreviewKey: ""
    property string displayedPreviewImagePath: ""
    property var trayMenuItem: null
    property var traySubmenu: null
    property bool trayMenuOpen: false
    property string trayMenuScreenName: ""
    property int trayMenuY: 0
    property string wifiScreenName: ""
    property string bluetoothScreenName: ""
    property string notificationsScreenName: ""
    property bool wifiTriggerHovered: false
    property bool wifiPanelHovered: false
    property bool bluetoothTriggerHovered: false
    property bool bluetoothPanelHovered: false
    property bool notificationsTriggerHovered: false
    property bool notificationsPanelHovered: false
    property bool clockOpen: false
    property bool clockTriggerHovered: false
    property bool clockPanelHovered: false
    property string clockScreenName: ""
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

    function railVisibleFor(screenName) {
        return barVisible || (customLayout && hoverScreenName === screenName);
    }

    function closePopouts() {
        current = "";
        wifiOpen = false;
        bluetoothOpen = false;
        notificationsOpen = false;
        clockOpen = false;
        workspacePreviewOpen = false;
        previewTriggerKey = "";
        trayMenuOpen = false;
    }

    onBarVisibleChanged: {
        hoverScreenName = "";
        railCloseDelay.stop();
        if (!barVisible) closePopouts();
    }
    onCustomLayoutChanged: if (!customLayout) hoverScreenName = ""
    onRailInteractionActiveChanged: {
        if (railInteractionActive) railCloseDelay.stop();
        else if (hoverScreenName !== "") railCloseDelay.restart();
    }

    Timer {
        id: railCloseDelay
        interval: 550
        onTriggered: {
            if (!shell.railInteractionActive) {
                shell.hoverScreenName = "";
                shell.closePopouts();
            }
        }
    }

    function openTrayMenu(item, screenName, y) {
        trayMenuItem = item;
        traySubmenu = null;
        trayMenuScreenName = screenName;
        trayMenuY = y;
        trayMenuOpen = true;
        trayMenuCloseDelay.stop();
    }

    QsMenuOpener {
        id: trayRootMenu
        menu: shell.trayMenuItem ? shell.trayMenuItem.menu : null
    }

    QsMenuOpener {
        id: trayChildMenu
        menu: shell.traySubmenu
    }

    Timer {
        id: trayMenuCloseDelay
        interval: 300
        onTriggered: shell.trayMenuOpen = false
    }

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
        id: clockCloseDelay
        interval: 150
        onTriggered: {
            if (!shell.clockTriggerHovered && !shell.clockPanelHovered)
                shell.clockOpen = false;
        }
    }

    Timer {
        id: workspacePreviewCloseDelay
        interval: 220
        onTriggered: {
            if (shell.previewTriggerKey === "" && !shell.previewPanelHovered)
                shell.workspacePreviewOpen = false;
        }
    }

    function previewKey() { return previewScreenName + ":" + previewWorkspaceId; }
    function previewWindows() { return workspacePreviewData.windows[previewKey()] || []; }
    function previewImage() {
        return workspacePreviewOpen && displayedPreviewKey === previewKey()
            ? displayedPreviewImagePath : (workspacePreviewData.images[previewKey()] || "");
    }
    function selectWorkspacePreview(screenName, workspaceId) {
        const key = screenName + ":" + workspaceId;
        displayedPreviewKey = key;
        displayedPreviewImagePath = workspacePreviewData.images[key] || "";
        previewScreenName = screenName;
        previewWorkspaceId = workspaceId;
        workspacePreviewOpen = true;
    }
    function applyPreviewData(output) {
        const data = JSON.parse(output);
        if (data.updatedAt >= lastPreviewUpdate) {
            lastPreviewUpdate = data.updatedAt;
            workspacePreviewData = data;
            if (workspacePreviewOpen && displayedPreviewKey === previewKey() && !displayedPreviewImagePath)
                displayedPreviewImagePath = data.images[displayedPreviewKey] || "";
        }
    }
    function captureHoveredWorkspace() {
        if (!workspacePreviewOpen || workspaceHoverProcess.running) return;
        hoverCaptureKey = previewKey();
        workspaceHoverProcess.running = true;
    }

    Process {
        id: workspaceCaptureProcess
        command: ["python3", shell.configHome + "/quickshell/left-status/workspace_preview.py", "capture"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { shell.applyPreviewData(this.text); }
                catch (error) { console.warn("Workspace capture:", error); }
            }
        }
    }

    Process {
        id: workspaceHoverProcess
        command: ["python3", shell.configHome + "/quickshell/left-status/workspace_preview.py",
                  "capture", shell.hoverCaptureKey.split(":")[0], shell.hoverCaptureKey.split(":")[1] || "0"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { shell.applyPreviewData(this.text); }
                catch (error) { console.warn("Workspace hover capture:", error); }
            }
        }
        onExited: {
            if (shell.workspacePreviewOpen && shell.previewKey() !== shell.hoverCaptureKey)
                Qt.callLater(shell.captureHoveredWorkspace);
        }
    }

    Timer {
        interval: 12000
        running: shell.customLayout && (shell.barVisible || shell.hoverScreenName !== "")
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
                                    hoverScreen: shell.hoverScreenName, railHovered: shell.railHovered,
                                    edgeHovered: shell.edgeHovered, interaction: shell.railInteractionActive,
                                    clockOpen: shell.clockOpen, clockTrigger: shell.clockTriggerHovered,
                                    clockPanel: shell.clockPanelHovered, statusPanel: shell.statusPanelHovered,
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
        case "nightlight": return status.nightlight ? "" : "";
        }
        return "";
    }

    function iconPixelSizeFor(name) {
        // Normalize visible glyph bounds to roughly 18 px, rather than font em size.
        const value = field(name);
        switch (name) {
        case "notifications": return status.dnd ? 16 : 19;
        case "network": return value.connected && value.type === "wifi" ? 19 : 20;
        case "bluetooth": return value.powered ? 19 : 18;
        case "battery": return value.state === "Charging" ? 19 : 21;
        case "brightness": return 24;
        case "microphone": return status.input && status.input.muted ? 16 : 19;
        case "volume": return status.output && status.output.muted ? 24 : 16;
        case "nightlight": return status.nightlight ? 22 : 19;
        }
        return 19;
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
        case "battery": {
            if (!value.present) return "No battery";
            const state = value.state || "Unknown";
            const minutes = value.remaining_minutes;
            if (minutes !== null && minutes !== undefined) {
                const duration = (Math.floor(minutes / 60) ? Math.floor(minutes / 60) + "h " : "") +
                                 (minutes % 60) + "m";
                return state + " · about " + duration +
                       (state === "Charging" ? " until full" : " remaining");
            }
            return state + (state === "Full" ? "" : " · time unavailable");
        }
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
        case "battery": return [{ label: "Saver", id: "profile-saver" }, { label: "Balanced", id: "profile-balanced" },
                                { label: "Desktop", id: "profile-desktop" }, { label: "Power save", id: "profile-powersave" }];
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
        case "profile-powersave": command = ["tuned-adm", "profile", "powersave"]; break;
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
        else if (action === "profile-powersave") next.power_profile = "powersave";
        else return;
        status = next;
        suppressStatusUntil = Date.now() + (action.startsWith("profile-") ? 1800 : 700);
    }

    function selectedAction(action) {
        if (current !== "battery") return false;
        return (action === "profile-saver" && status.power_profile === "balanced-battery") ||
               (action === "profile-balanced" && status.power_profile === "balanced") ||
               (action === "profile-desktop" && status.power_profile === "desktop") ||
               (action === "profile-powersave" && status.power_profile === "powersave");
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
                    if (shell.status.enabled && shell.customLayout && !wallpaperPowerProcess.running)
                        wallpaperPowerProcess.running = true;
                    if (!shell.status.enabled) { shell.current = ""; shell.wifiOpen = false; shell.bluetoothOpen = false; }
                } catch (error) {
                    console.warn("Left status:", error);
                }
            }
        }
    }

    Process {
        id: wallpaperPowerProcess
        command: ["python3", shell.configHome + "/quickshell/left-status/wallpaper_power.py",
                  shell.status.power_profile || ""]
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
            id: leftEdgeTrigger
            required property var modelData
            screen: modelData
            visible: shell.status.enabled && shell.customLayout && !shell.barVisible &&
                     !(Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false)
            implicitWidth: 2
            anchors { left: true; top: true; bottom: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:left-status-trigger"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            onVisibleChanged: if (!visible) shell.edgeHovered = false

            Timer {
                id: railOpenDelay
                interval: 140
                onTriggered: {
                    if (leftEdgeHover.hovered)
                        shell.hoverScreenName = leftEdgeTrigger.modelData.name;
                }
            }

            HoverHandler {
                id: leftEdgeHover
                onHoveredChanged: {
                    shell.edgeHovered = hovered;
                    if (hovered) railOpenDelay.restart();
                    else railOpenDelay.stop();
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: statusRail
            required property var modelData
            readonly property int edgeSpacing: 32
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
            visible: shell.status.enabled && shell.railVisibleFor(modelData.name) && !(monitor?.activeWorkspace?.hasFullscreen ?? false)
            implicitWidth: shell.customLayout ? 46 + shell.railGeometry.gap_left + shell.railGeometry.rounding : 46
            implicitHeight: shell.customLayout ? modelData.height : 336
            anchors.left: true
            margins.left: shell.railInset
            anchors.top: shell.customLayout
            anchors.bottom: !shell.customLayout
            margins.bottom: shell.customLayout ? 0 : 8
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:left-status-icons"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            onVisibleChanged: if (!visible) shell.railHovered = false

            HoverHandler {
                onHoveredChanged: shell.railHovered = hovered
            }

            mask: Region {
                width: 46
                height: statusRail.height
            }

            RailBackground {
                visible: shell.customLayout
                width: parent.width
                y: shell.railGeometry.gap_top
                height: Math.max(1, parent.height - shell.railGeometry.gap_top - shell.railGeometry.gap_bottom)
                cornerRadius: shell.railGeometry.rounding
            }

            Item {
                id: railContent
                width: 46
                height: parent.height

                Rectangle {
                    visible: !shell.customLayout
                    anchors.fill: parent
                    anchors.topMargin: shell.customLayout ? 8 : 0
                    anchors.bottomMargin: shell.customLayout ? 8 : 0
                    radius: 20
                    color: Qt.rgba(0, 0, 0, 0.55)
                    border.color: "#4DFFFFFF"
                    border.width: 1
                }

                Rectangle {
                    id: clockButton
                    visible: shell.customLayout
                    anchors.top: parent.top
                    anchors.topMargin: statusRail.edgeSpacing
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: clockText.implicitWidth
                    height: clockText.implicitHeight
                    radius: 13
                    color: clockMouse.containsMouse ? "#8039323E" : "transparent"

                    Text {
                        id: clockText
                        anchors.centerIn: parent
                        topPadding: 4
                        bottomPadding: 4
                        leftPadding: 8
                        rightPadding: 8
                        text: Qt.formatDateTime(shell.now, "hh\nmm")
                        horizontalAlignment: Text.AlignHCenter
                        color: "#F4F4F6"
                        font.family: "Noto Sans"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        lineHeight: 1.1
                    }

                    MouseArea {
                        id: clockMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: {
                            clockCloseDelay.stop();
                            shell.clockScreenName = statusRail.modelData.name;
                            shell.clockTriggerHovered = true;
                            shell.clockOpen = true;
                        }
                        onExited: {
                            shell.clockTriggerHovered = false;
                            clockCloseDelay.restart();
                        }
                    }
                }

                ListView {
                    visible: shell.customLayout
                    anchors.centerIn: parent
                    width: 34
                    height: Math.min(328, Math.max(48, statusRail.workspaceIds.length * 30 + 8))
                    model: statusRail.workspaceIds
                    clip: true
                    spacing: 2
                    delegate: Rectangle {
                        id: workspaceButton
                        required property int modelData
                        readonly property bool active: modelData === statusRail.monitor?.activeWorkspace?.id
                        width: 34
                        height: 28
                        radius: 10
                        color: workspaceMouse.containsMouse ? "#8039323E" : "transparent"
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
                                shell.selectWorkspacePreview(statusRail.modelData.name, workspaceButton.modelData);
                                shell.previewTriggerKey = shell.previewKey();
                                shell.current = "";
                                shell.wifiOpen = false;
                                shell.bluetoothOpen = false;
                                shell.notificationsOpen = false;
                                shell.captureHoveredWorkspace();
                            }
                            onExited: {
                                if (shell.previewTriggerKey === statusRail.modelData.name + ":" + workspaceButton.modelData) {
                                    shell.previewTriggerKey = "";
                                    workspacePreviewCloseDelay.restart();
                                }
                            }
                            onClicked: {
                                shell.workspacePreviewOpen = false;
                                shell.previewTriggerKey = "";
                                Hyprland.dispatch("workspace " + workspaceButton.modelData);
                            }
                        }
                    }
                }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: shell.customLayout ? 24 : 2
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
                            color: trayMouse.containsMouse ? "#8039323E" : "transparent"
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
                                onEntered: trayMenuCloseDelay.stop()
                                onExited: if (shell.trayMenuOpen) trayMenuCloseDelay.restart()
                                onClicked: mouse => {
                                    const item = trayButton.modelData;
                                    if (mouse.button === Qt.RightButton || item.onlyMenu) {
                                        if (item.hasMenu)
                                            shell.openTrayMenu(item, statusRail.modelData.name,
                                                               trayButton.mapToItem(null, 0, 0).y);
                                        else item.secondaryActivate();
                                    }
                                    else if (mouse.button === Qt.MiddleButton) item.secondaryActivate();
                                    else item.activate();
                                }
                                onWheel: wheel => trayButton.modelData.scroll(wheel.angleDelta.y, false)
                            }
                        }
                    }

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 0
                        Repeater {
                            model: shell.entries
                            delegate: Rectangle {
                                id: statusIcon
                                required property string modelData
                                width: 38
                                height: 30
                                radius: 13
                                color: shell.current === modelData || (modelData === "network" && shell.wifiOpen) ||
                                       (modelData === "bluetooth" && shell.bluetoothOpen) ||
                                       (modelData === "notifications" && shell.notificationsOpen) ? "#A6514354" :
                                       iconMouse.containsMouse ? "#8039323E" : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: shell.iconFor(statusIcon.modelData)
                                    color: shell.current === statusIcon.modelData ? "#ffffff" : "#F4F4F6"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: Math.round(shell.iconPixelSizeFor(statusIcon.modelData) * 0.72)
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
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: clockPopup
            required property var modelData
            screen: modelData
            visible: shell.status.enabled && shell.customLayout && shell.railVisibleFor(modelData.name) &&
                     shell.clockOpen && shell.clockScreenName === modelData.name &&
                     !(Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false)
            implicitWidth: 224
            implicitHeight: 104
            anchors.left: true
            anchors.top: true
            margins.left: 46 + shell.railInset
            margins.top: 22
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:left-status-clock"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            onVisibleChanged: if (!visible) shell.clockPanelHovered = false

            HoverHandler {
                onHoveredChanged: {
                    shell.clockPanelHovered = hovered;
                    if (hovered) clockCloseDelay.stop();
                    else clockCloseDelay.restart();
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 5
                anchors.rightMargin: 5
                anchors.topMargin: 4
                anchors.bottomMargin: 4
                radius: 22
                color: Qt.rgba(0, 0, 0, 0.65)
                border.color: "#4DFFFFFF"
                border.width: 1

                Column {
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Text {
                        text: Qt.locale("pt_BR").toString(shell.now, "dddd")
                        color: "#CFC4D0"
                        font.family: "Noto Sans"
                        font.pixelSize: 15
                    }
                    Text {
                        text: Qt.locale("pt_BR").toString(shell.now, "d 'de' MMMM")
                        color: "#F4F4F6"
                        font.family: "Noto Sans"
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: Qt.locale("pt_BR").toString(shell.now, "yyyy")
                        color: "#CFC4D0"
                        font.family: "Noto Sans"
                        font.pixelSize: 13
                    }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: trayMenuPanel
            required property var modelData
            screen: modelData
            visible: shell.status.enabled && shell.customLayout && shell.railVisibleFor(modelData.name) &&
                     shell.trayMenuOpen && shell.trayMenuScreenName === modelData.name &&
                     !(Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false)
            implicitWidth: 264
            implicitHeight: Math.max(68, Math.min(490, trayMenuList.count * 35 +
                                                      (shell.traySubmenu ? 72 : 42)))
            anchors.left: true
            anchors.top: true
            margins.left: 46 + shell.railInset
            margins.top: Math.max(8, Math.min(modelData.height - implicitHeight - 8,
                                               shell.trayMenuY - implicitHeight + 38))
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:left-status-tray-menu"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            onVisibleChanged: if (!visible) shell.trayMenuHovered = false

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: 19
                color: Qt.rgba(0, 0, 0, 0.82)
                border.color: "#66FFFFFF"
                border.width: 1

                HoverHandler {
                    onHoveredChanged: {
                        shell.trayMenuHovered = hovered;
                        if (hovered) trayMenuCloseDelay.stop();
                        else trayMenuCloseDelay.restart();
                    }
                }

                Rectangle {
                    visible: shell.traySubmenu !== null
                    x: 10; y: 9
                    width: parent.width - 20
                    height: 31
                    radius: 9
                    color: backMouse.containsMouse ? "#804A424A" : "transparent"
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 10
                        text: "‹  Back"
                        color: "#F4F4F6"
                        font.family: "Noto Sans"
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shell.traySubmenu = null
                    }
                }

                ListView {
                    id: trayMenuList
                    x: 10
                    y: shell.traySubmenu ? 42 : 12
                    width: parent.width - 20
                    height: parent.height - y - 10
                    clip: true
                    model: shell.traySubmenu ? trayChildMenu.children : trayRootMenu.children
                    delegate: Rectangle {
                        id: trayMenuRow
                        required property var modelData
                        width: trayMenuList.width
                        height: modelData.isSeparator ? 12 : 34
                        radius: 8
                        color: menuMouse.containsMouse && modelData.enabled &&
                               !modelData.isSeparator ? "#804A424A" : "transparent"

                        Rectangle {
                            visible: trayMenuRow.modelData.isSeparator
                            anchors.centerIn: parent
                            width: parent.width - 14
                            height: 1
                            color: "#665E666A"
                        }
                        Image {
                            x: 9
                            anchors.verticalCenter: parent.verticalCenter
                            width: 17; height: 17
                            source: trayMenuRow.modelData.icon || ""
                            visible: !trayMenuRow.modelData.isSeparator && source !== ""
                            sourceSize.width: 17
                            sourceSize.height: 17
                        }
                        Text {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 32
                            leftPadding: trayMenuRow.modelData.icon ? 22 : 0
                            text: trayMenuRow.modelData.text || ""
                            color: trayMenuRow.modelData.enabled ? "#F4F4F6" : "#8F8990"
                            font.family: "Noto Sans"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: trayMenuRow.modelData.hasChildren
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "›"
                            color: "#D9CEDB"
                            font.pixelSize: 17
                        }
                        MouseArea {
                            id: menuMouse
                            anchors.fill: parent
                            enabled: trayMenuRow.modelData.enabled && !trayMenuRow.modelData.isSeparator
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (trayMenuRow.modelData.hasChildren)
                                    shell.traySubmenu = trayMenuRow.modelData;
                                else {
                                    trayMenuRow.modelData.triggered();
                                    shell.trayMenuOpen = false;
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
            visible: shell.status.enabled && shell.customLayout && shell.railVisibleFor(modelData.name) &&
                     shell.workspacePreviewOpen && shell.previewScreenName === modelData.name &&
                     !(Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false)
            implicitWidth: 342
            implicitHeight: 306
            anchors.left: true
            anchors.top: true
            margins.left: 46 + shell.railInset
            margins.top: Math.max(8, Math.round((modelData.height - 306) / 2))
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:left-status-workspaces"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            onVisibleChanged: if (!visible) shell.previewPanelHovered = false

            HoverHandler {
                onHoveredChanged: {
                    shell.previewPanelHovered = hovered;
                    if (hovered) workspacePreviewCloseDelay.stop();
                    else workspacePreviewCloseDelay.restart();
                }
            }

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
                    id: previewFrame
                    x: 16; y: 43
                    width: parent.width - 32
                    height: 171
                    radius: 12
                    color: "#2B252C"
                    clip: true
                    property int activeImage: -1
                    function activate(slot, file, key) {
                        if (file === workspacePreview.imagePath && key === shell.previewKey())
                            activeImage = slot;
                    }
                    function loadImage() {
                        const file = workspacePreview.imagePath;
                        const key = shell.previewKey();
                        if (!file) { activeImage = -1; return; }
                        if (firstImage.imageFile === file && firstImage.imageKey === key && firstImage.status === Image.Ready) {
                            activeImage = 0;
                            return;
                        }
                        if (secondImage.imageFile === file && secondImage.imageKey === key && secondImage.status === Image.Ready) {
                            activeImage = 1;
                            return;
                        }
                        const next = activeImage === 0 ? secondImage : firstImage;
                        next.imageKey = key;
                        next.imageFile = file;
                    }
                    Connections {
                        target: workspacePreview
                        function onImagePathChanged() { previewFrame.loadImage(); }
                    }
                    Component.onCompleted: loadImage()
                    Image {
                        id: firstImage
                        property string imageFile: ""
                        property string imageKey: ""
                        anchors.fill: parent
                        source: imageFile ? "file://" + imageFile : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: previewFrame.activeImage === 0 && imageKey === shell.previewKey() && status === Image.Ready
                        asynchronous: true
                        onStatusChanged: if (status === Image.Ready) previewFrame.activate(0, imageFile, imageKey)
                    }
                    Image {
                        id: secondImage
                        property string imageFile: ""
                        property string imageKey: ""
                        anchors.fill: parent
                        source: imageFile ? "file://" + imageFile : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: previewFrame.activeImage === 1 && imageKey === shell.previewKey() && status === Image.Ready
                        asynchronous: true
                        onStatusChanged: if (status === Image.Ready) previewFrame.activate(1, imageFile, imageKey)
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: previewFrame.activeImage < 0 ||
                                 (previewFrame.activeImage === 0 ? !firstImage.visible : !secondImage.visible)
                        text: workspacePreview.imagePath ? "Loading preview…" :
                              (workspacePreview.windows.length ? "Preview available after visiting" : "Empty workspace")
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
            visible: shell.status.enabled && shell.railVisibleFor(modelData.name) && shell.current !== "" && !(Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false)
            implicitWidth: 292
            implicitHeight: shell.current === "battery" ? 230 : 204
            anchors.left: true
            anchors.bottom: true
            margins.left: 46 + shell.railInset
            margins.bottom: Math.max(8, 8 + (7 - shell.activeIndex) * 42 - 88)
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:left-status-popout"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            onVisibleChanged: if (!visible) shell.statusPanelHovered = false

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

                HoverHandler {
                    onHoveredChanged: {
                        shell.statusPanelHovered = hovered;
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
                Grid {
                    x: 18; y: shell.current === "battery" ? 131 : 139
                    columns: shell.current === "battery" ? 2 : shell.actionsFor(shell.current).length
                    spacing: 7
                    Repeater {
                        model: shell.actionsFor(shell.current)
                        delegate: Rectangle {
                            id: actionButton
                            required property var modelData
                            readonly property int count: shell.actionsFor(shell.current).length
                            width: count === 4 || count === 2 ? 119 : count === 3 ? 76 : 249
                            height: count === 4 ? 36 : 42
                            radius: 11
                            color: shell.selectedAction(actionButton.modelData.id) ? "#C06A5369" : actionMouse.containsMouse ? "#A6554859" : "#80423746"
                            Text {
                                anchors.centerIn: parent
                                text: actionButton.modelData.label
                                color: "#F4F4F6"
                                font.family: "Noto Sans"
                                font.pixelSize: 12
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
            visible: shell.status.enabled && shell.railVisibleFor(modelData.name) && shell.wifiOpen && shell.wifiScreenName === modelData.name && !(Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false)
            implicitWidth: 368
            implicitHeight: 400
            anchors.left: true
            anchors.bottom: true
            margins.left: 46 + shell.railInset
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
            visible: shell.status.enabled && shell.railVisibleFor(modelData.name) && shell.bluetoothOpen && shell.bluetoothScreenName === modelData.name && !(Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false)
            implicitWidth: 368
            implicitHeight: 400
            anchors.left: true
            anchors.bottom: true
            margins.left: 46 + shell.railInset
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
            visible: shell.status.enabled && shell.railVisibleFor(modelData.name) && shell.notificationsOpen && shell.notificationsScreenName === modelData.name && !(Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false)
            implicitWidth: 368
            implicitHeight: 400
            anchors.left: true
            anchors.bottom: true
            margins.left: 46 + shell.railInset
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
