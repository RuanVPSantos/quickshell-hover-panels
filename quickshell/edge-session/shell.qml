import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: shell
    property bool openedByShortcut: false

    IpcHandler {
        target: "edgeSession"
        function toggle(): void { shell.openedByShortcut = !shell.openedByShortcut; }
        function close(): void { shell.openedByShortcut = false; }
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: instance
            required property var modelData
            readonly property int railWidth: 52
            readonly property int railHeight: 244

            property bool panelOpen: false
            property bool showWindow: false
            property bool triggerHovered: false
            property bool railHovered: false
            property int hoveredButton: -1
            property int pendingIndex: -1
            readonly property bool expanded: panelOpen || shell.openedByShortcut

            onExpandedChanged: {
                if (expanded) {
                    hideWindow.stop();
                    showWindow = true;
                } else {
                    hideWindow.restart();
                }
            }

            function scheduleClose(): void {
                if (!triggerHovered && !railHovered && hoveredButton < 0 && !shell.openedByShortcut)
                    closeDelay.restart();
            }

            function runAction(action, actionIndex): void {
                if (action.confirm && pendingIndex !== actionIndex) {
                    pendingIndex = actionIndex;
                    confirmTimeout.restart();
                    return;
                }

                pendingIndex = -1;
                confirmTimeout.stop();
                panelOpen = false;
                shell.openedByShortcut = false;
                Quickshell.execDetached(action.command);
            }

            Timer {
                id: openDelay
                interval: 140
                onTriggered: instance.panelOpen = true
            }

            Timer {
                id: closeDelay
                interval: 550
                onTriggered: {
                    if (!instance.triggerHovered && !instance.railHovered && instance.hoveredButton < 0 && !shell.openedByShortcut) {
                        instance.panelOpen = false;
                        instance.pendingIndex = -1;
                    }
                }
            }

            Timer {
                id: hideWindow
                interval: 250
                onTriggered: instance.showWindow = false
            }

            Timer {
                id: confirmTimeout
                interval: 4000
                onTriggered: instance.pendingIndex = -1
            }

            PanelWindow {
                id: triggerWindow
                screen: instance.modelData
                implicitWidth: 10
                anchors { right: true; top: true; bottom: true }
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.namespace: "quickshell:edge-session-trigger"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                HoverHandler {
                    onHoveredChanged: {
                        instance.triggerHovered = hovered;
                        if (hovered) {
                            closeDelay.stop();
                            openDelay.restart();
                        } else {
                            openDelay.stop();
                            instance.scheduleClose();
                        }
                    }
                }

            }

            PanelWindow {
                id: railWindow
                screen: instance.modelData
                visible: instance.showWindow
                implicitWidth: instance.railWidth
                anchors { right: true; top: true; bottom: true }
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.namespace: "quickshell:edge-session-rail"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                mask: Region {
                    y: Math.max(0, Math.round((railWindow.height - instance.railHeight) / 2))
                    width: railWindow.width
                    height: instance.railHeight
                }

                Rectangle {
                    id: rail
                    width: instance.railWidth
                    height: instance.railHeight
                    x: instance.expanded ? 0 : width
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 20
                    color: Qt.rgba(0, 0, 0, 0.42)
                    border.color: "#4DFFFFFF"
                    border.width: 1
                    opacity: instance.expanded ? 1 : 0

                    Behavior on x { NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    HoverHandler {
                        onHoveredChanged: {
                            instance.railHovered = hovered;
                            if (hovered)
                                closeDelay.stop();
                            else
                                instance.scheduleClose();
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        Repeater {
                            model: [
                                { label: "Bloquear", icon: "\uf023", command: ["sh", "-c", "lock_script=\"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/LockScreen.sh\"; if [ -x \"$lock_script\" ]; then exec \"$lock_script\"; elif command -v hyprlock >/dev/null 2>&1; then exec hyprlock; else exec loginctl lock-session; fi"], confirm: false },
                                { label: "Suspender", icon: "\uf186", command: ["systemctl", "suspend"], confirm: true },
                                { label: "Sair", icon: "\uf2f5", command: ["hyprctl", "dispatch", "exit"], confirm: true },
                                { label: "Reiniciar", icon: "\uf2f9", command: ["systemctl", "reboot"], confirm: true },
                                { label: "Desligar", icon: "\uf011", command: ["systemctl", "poweroff"], confirm: true }
                            ]

                            delegate: Rectangle {
                                id: actionButton
                                required property var modelData
                                required property int index
                                readonly property bool confirming: instance.pendingIndex === index

                                width: 42
                                height: 36
                                radius: 13
                                color: confirming ? "#80754943" : buttonMouse.containsMouse ? "#8039323E" : "transparent"
                                border.color: "#B3F3AEA5"
                                border.width: confirming ? 1 : 0

                                Text {
                                    anchors.centerIn: parent
                                    text: actionButton.modelData.icon
                                    color: actionButton.confirming ? "#ffdfda" : "#f0e7ef"
                                    font.family: "Font Awesome 6 Free"
                                    font.pixelSize: 16
                                    font.weight: Font.Black
                                }

                                Rectangle {
                                    visible: actionButton.confirming
                                    width: 5
                                    height: 5
                                    radius: 2.5
                                    color: "#ffd5cd"
                                    anchors { right: parent.right; top: parent.top; rightMargin: 4; topMargin: 4 }
                                }

                                MouseArea {
                                    id: buttonMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: {
                                        instance.hoveredButton = actionButton.index;
                                        closeDelay.stop();
                                    }
                                    onExited: {
                                        if (instance.hoveredButton === actionButton.index)
                                            instance.hoveredButton = -1;
                                        instance.scheduleClose();
                                    }
                                    onClicked: instance.runAction(actionButton.modelData, actionButton.index)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
