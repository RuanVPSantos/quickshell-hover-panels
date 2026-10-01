import QtQuick
import Quickshell.Bluetooth

Rectangle {
    id: picker
    signal hoverChanged(bool hovered)
    signal settingsRequested()
    signal powerChanged()

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: {
        const all = Bluetooth.devices.values.filter(device =>
            device.adapter === adapter && (device.paired || device.connected));
        return all.sort((a, b) => Number(b.connected) - Number(a.connected) || a.name.localeCompare(b.name));
    }

    radius: 26
    color: Qt.rgba(0, 0, 0, 0.55)
    border.color: "#4DFFFFFF"
    border.width: 1

    HoverHandler { onHoveredChanged: picker.hoverChanged(hovered) }

    Text {
        x: 20; y: 18
        text: "Bluetooth devices"
        color: "#F4F4F6"
        font.family: "Noto Sans"
        font.pixelSize: 17
        font.weight: Font.DemiBold
    }

    Text {
        x: 20; y: 49
        width: parent.width - 40
        text: !picker.adapter ? "No Bluetooth adapter" :
              !picker.adapter.enabled ? "Bluetooth is off" :
              picker.devices.length + " paired device" + (picker.devices.length === 1 ? "" : "s")
        color: "#b7a8b9"
        font.family: "Noto Sans"
        font.pixelSize: 11
        elide: Text.ElideRight
    }

    Item {
        x: 14; y: 78
        width: parent.width - 28
        height: 252

        Text {
            anchors.centerIn: parent
            visible: !picker.adapter?.enabled || picker.devices.length === 0
            text: !picker.adapter?.enabled ? "Turn on Bluetooth to connect" : "No paired devices"
            color: "#c7b8c8"
            font.family: "Noto Sans"
            font.pixelSize: 12
        }

        ListView {
            anchors.fill: parent
            anchors.margins: 7
            clip: true
            spacing: 3
            visible: picker.adapter?.enabled ?? false
            model: picker.devices
            delegate: Rectangle {
                id: deviceRow
                required property var modelData
                width: ListView.view.width
                height: 46
                radius: 12
                color: rowMouse.containsMouse ? "#554859" : modelData.connected ? "#4039323E" : "transparent"

                Text {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: "#F4F4F6"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 17
                }
                Text {
                    x: 43
                    width: parent.width - 145
                    anchors.verticalCenter: parent.verticalCenter
                    text: deviceRow.modelData.name || deviceRow.modelData.deviceName || deviceRow.modelData.address
                    color: "#F4F4F6"
                    font.family: "Noto Sans"
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 11
                    anchors.verticalCenter: parent.verticalCenter
                    text: deviceRow.modelData.connected ?
                          (deviceRow.modelData.batteryAvailable ? Math.round(deviceRow.modelData.battery * 100) + "%" : "Connected") :
                          deviceRow.modelData.pairing ? "Pairing…" : "Connect"
                    color: deviceRow.modelData.connected ? "#f0e3ed" : "#b7a8b9"
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (deviceRow.modelData.connected) deviceRow.modelData.disconnect();
                        else deviceRow.modelData.connect();
                    }
                }
            }
        }
    }

    Row {
        x: 14; y: 343
        spacing: 8
        Repeater {
            model: ["Devices & settings", picker.adapter?.enabled ? "Bluetooth off" : "Bluetooth on"]
            delegate: Rectangle {
                id: footerButton
                required property int index
                required property string modelData
                width: (picker.width - 36) / 2
                height: 42
                radius: 12
                color: footerMouse.containsMouse ? "#554859" : "#423746"
                Text {
                    anchors.centerIn: parent
                    text: footerButton.modelData
                    color: "#F4F4F6"
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                }
                MouseArea {
                    id: footerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (footerButton.index === 0) picker.settingsRequested();
                        else if (picker.adapter) {
                            picker.adapter.enabled = !picker.adapter.enabled;
                            picker.powerChanged();
                        }
                    }
                }
            }
        }
    }
}
