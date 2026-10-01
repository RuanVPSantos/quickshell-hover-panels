import QtQuick

Rectangle {
    id: panel
    signal hoverChanged(bool hovered)
    signal clearRequested()
    signal dismissRequested(string notificationKey)
    signal actionRequested(string notificationKey)
    signal dndRequested()

    property var items: []
    property bool dnd: false

    radius: 26
    color: Qt.rgba(0, 0, 0, 0.65)
    border.color: "#4DFFFFFF"
    border.width: 1

    HoverHandler { onHoveredChanged: panel.hoverChanged(hovered) }

    Text {
        x: 20; y: 18
        text: "Notifications"
        color: "#F4F4F6"
        font.family: "Noto Sans"
        font.pixelSize: 17
        font.weight: Font.DemiBold
    }

    Text {
        x: 20; y: 49
        text: panel.items.length + " recent"
        color: "#b7a8b9"
        font.family: "Noto Sans"
        font.pixelSize: 11
    }

    Rectangle {
        x: parent.width - 82; y: 16
        width: 64; height: 30
        radius: 10
        visible: panel.items.length > 0
        color: clearMouse.containsMouse ? "#A6554859" : "#80423746"
        Text {
            anchors.centerIn: parent
            text: "Clear"
            color: "#F4F4F6"
            font.family: "Noto Sans"
            font.pixelSize: 12
        }
        MouseArea {
            id: clearMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: panel.clearRequested()
        }
    }

    Item {
        x: 14; y: 78
        width: parent.width - 28
        height: 252

        Text {
            anchors.centerIn: parent
            visible: panel.items.length === 0
            text: "All caught up"
            color: "#c7b8c8"
            font.family: "Noto Sans"
            font.pixelSize: 12
        }

        ListView {
            anchors.fill: parent
            anchors.margins: 7
            clip: true
            spacing: 5
            model: panel.items
            delegate: Rectangle {
                id: notificationRow
                required property var modelData
                width: ListView.view.width
                height: 72
                radius: 12
                color: rowMouse.containsMouse ? "#A6554859" : "#8039323E"

                Text {
                    x: 12; y: 8
                    width: parent.width - 42
                    text: notificationRow.modelData.app || "Notification"
                    color: "#b7a8b9"
                    font.family: "Noto Sans"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
                Text {
                    x: 12; y: 27
                    width: parent.width - 42
                    text: notificationRow.modelData.summary
                    textFormat: Text.PlainText
                    color: "#F4F4F6"
                    font.family: "Noto Sans"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    x: 12; y: 48
                    width: parent.width - 42
                    text: notificationRow.modelData.body
                    textFormat: Text.PlainText
                    color: "#c7b8c8"
                    font.family: "Noto Sans"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.actionRequested(notificationRow.modelData.key)
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    y: 7
                    text: "×"
                    color: "#c7b8c8"
                    font.family: "Noto Sans"
                    font.pixelSize: 17
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.dismissRequested(notificationRow.modelData.key)
                    }
                }
            }
        }
    }

    Rectangle {
        x: 14; y: 343
        width: parent.width - 28
        height: 42
        radius: 12
        color: dndMouse.containsMouse ? "#A6554859" : "#80423746"
        Text {
            anchors.centerIn: parent
            text: panel.dnd ? "Do Not Disturb on" : "Do Not Disturb off"
            color: "#F4F4F6"
            font.family: "Noto Sans"
            font.pixelSize: 12
        }
        MouseArea {
            id: dndMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: panel.dndRequested()
        }
    }
}
