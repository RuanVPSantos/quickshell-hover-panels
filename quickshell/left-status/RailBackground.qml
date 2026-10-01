import QtQuick
import QtQuick.Shapes

Item {
    id: background
    property real cornerRadius: 10
    readonly property real radius: Math.max(0, Math.min(cornerRadius, width - 1, (height - 1) / 2))
    readonly property real bodyRight: width - 0.5 - radius
    readonly property real curveHandle: radius * 0.55228475

    Shape {
        anchors.fill: parent
        antialiasing: true

        ShapePath {
            strokeWidth: 1
            strokeColor: "#4DFFFFFF"
            fillColor: Qt.rgba(0, 0, 0, 0.55)
            startX: 0.5
            startY: 0.5

            PathLine { x: background.width - 0.5; y: 0.5 }
            PathCubic {
                x: background.bodyRight
                y: 0.5 + background.radius
                control1X: background.width - 0.5 - background.curveHandle
                control1Y: 0.5
                control2X: background.bodyRight
                control2Y: 0.5 + background.radius - background.curveHandle
            }
            PathLine { x: background.bodyRight; y: background.height - 0.5 - background.radius }
            PathCubic {
                x: background.width - 0.5
                y: background.height - 0.5
                control1X: background.bodyRight
                control1Y: background.height - 0.5 - background.radius + background.curveHandle
                control2X: background.width - 0.5 - background.curveHandle
                control2Y: background.height - 0.5
            }
            PathLine { x: 0.5; y: background.height - 0.5 }
            PathLine { x: 0.5; y: 0.5 }
        }
    }
}
