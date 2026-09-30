import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

ShellRoot {
    id: shell

    property bool opened: false
    property bool triggerHovered: false
    property bool panelHovered: false
    property int activeTab: 0
    property date now: new Date()
    property int monthOffset: 0
    property var metrics: ({ cpu: 0, memory: 0, disk: 0 })
    property var manualPlayer: null
    readonly property var player: manualPlayer && Mpris.players.values.includes(manualPlayer) ? manualPlayer : (Mpris.players.values.find(p => p.isPlaying) || Mpris.players.values[0] || null)
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property var weekNames: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property var calendarCells: makeCalendar(now, monthOffset)

    function makeCalendar(base, offset) {
        const first = new Date(base.getFullYear(), base.getMonth() + offset, 1);
        const leading = (first.getDay() + 6) % 7;
        const cells = [];
        for (let i = 0; i < 42; i++) {
            const day = new Date(first.getFullYear(), first.getMonth(), i - leading + 1);
            cells.push({
                day: day.getDate(),
                inMonth: day.getMonth() === first.getMonth(),
                today: day.getFullYear() === base.getFullYear() && day.getMonth() === base.getMonth() && day.getDate() === base.getDate()
            });
        }
        return cells;
    }

    function displayedMonth() {
        return new Date(now.getFullYear(), now.getMonth() + monthOffset, 1);
    }

    IpcHandler {
        target: "dashboard"
        function toggle(): void { shell.opened = !shell.opened; }
        function open(): void { shell.opened = true; }
        function close(): void { shell.opened = false; }
        function showTab(index: int): void {
            if (index >= 0 && index <= 2) {
                shell.activeTab = index;
                shell.opened = true;
            }
        }
    }

    Timer {
        id: openDelay
        interval: 140
        onTriggered: shell.opened = true
    }

    Timer {
        id: dismissTimer
        interval: 180
        onTriggered: {
            if (!shell.triggerHovered && !shell.panelHovered)
                shell.opened = false;
        }
    }

    Timer {
        id: bridgeTimer
        interval: 400
        onTriggered: shell.scheduleClose()
    }

    function scheduleClose() {
        if (!triggerHovered && !panelHovered)
            dismissTimer.restart();
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: shell.now = new Date()
    }

    Process {
        id: statsProcess
        command: ["sh", "-c", "exec python3 \"${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/top-dashboard/metrics.py\""]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    shell.metrics = JSON.parse(this.text);
                } catch (error) {
                    console.warn("Dashboard metrics:", error);
                }
            }
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: shell.opened
        triggeredOnStart: true
        onTriggered: {
            if (!statsProcess.running)
                statsProcess.running = true;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            implicitWidth: 220
            implicitHeight: 9
            anchors.top: true
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:top-dashboard-trigger"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            HoverHandler {
                onHoveredChanged: {
                    shell.triggerHovered = hovered;
                    if (hovered) {
                        bridgeTimer.stop();
                        dismissTimer.stop();
                        openDelay.restart();
                    } else {
                        openDelay.stop();
                        bridgeTimer.restart();
                    }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: popup
            required property var modelData
            screen: modelData
            visible: shell.opened
            implicitWidth: 880
            implicitHeight: 470
            anchors.top: true
            margins.top: 16
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:top-dashboard"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                id: panel
                anchors.fill: parent
                radius: 26
                color: Qt.rgba(0, 0, 0, 0.55)
                border.color: "#4DFFFFFF"
                border.width: 1

                HoverHandler {
                    onHoveredChanged: {
                        shell.panelHovered = hovered;
                        if (hovered) {
                            bridgeTimer.stop();
                            dismissTimer.stop();
                        } else {
                            shell.scheduleClose();
                        }
                    }
                }

                Row {
                    x: 18; y: 10
                    spacing: 0
                    Repeater {
                        model: ["DASHBOARD", "MEDIA", "PERFORMANCE"]
                        delegate: Rectangle {
                            id: tabButton
                            required property int index
                            required property string modelData
                            width: (popup.width - 36) / 3
                            height: 34
                            color: "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: tabButton.modelData
                                color: shell.activeTab === tabButton.index ? "#f3e6f0" : tabMouse.containsMouse ? "#e6d7e5" : "#b7a8b9"
                                font.family: "Noto Sans"
                                font.pixelSize: 12
                                font.weight: shell.activeTab === tabButton.index ? Font.DemiBold : Font.Normal
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 90; height: 2
                                radius: 1
                                color: "#e3cee0"
                                visible: shell.activeTab === tabButton.index
                            }
                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: shell.activeTab = tabButton.index
                            }
                        }
                    }
                }

                OverviewTab {
                    x: 18; y: 56
                    width: popup.width - 36
                    height: popup.height - 76
                    visible: shell.activeTab === 0
                    now: shell.now
                    monthNames: shell.monthNames
                    weekNames: shell.weekNames
                    calendarCells: shell.calendarCells
                    monthOffset: shell.monthOffset
                    metrics: shell.metrics
                    player: shell.player
                    onPreviousMonth: shell.monthOffset--
                    onNextMonth: shell.monthOffset++
                }

                MediaTab {
                    x: 18; y: 56
                    width: popup.width - 36; height: popup.height - 76
                    visible: shell.activeTab === 1
                    player: shell.player
                    players: Mpris.players.values
                    onSelectPlayer: selected => shell.manualPlayer = selected
                }

                PerformanceTab {
                    x: 18; y: 56
                    width: popup.width - 36; height: popup.height - 76
                    visible: shell.activeTab === 2
                    metrics: shell.metrics
                }
            }
        }
    }
}
