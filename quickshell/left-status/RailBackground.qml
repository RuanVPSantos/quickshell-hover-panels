import QtQuick
import QtQuick.Shapes

Item {
    id: background
    property real cornerRadius: 10
    property real topGap: 4
    property real bottomGap: 4
    readonly property real curveTop: Math.max(0, Math.min(topGap, height / 2))
    readonly property real curveBottom: Math.max(curveTop, height - Math.max(0, bottomGap))
    readonly property real radius: Math.max(0, Math.min(cornerRadius, width - 1, (curveBottom - curveTop) / 2))
    readonly property real outerRight: width - 0.5
    readonly property real bodyRight: outerRight - radius
    readonly property real curveHandle: radius * 0.55228475

    Shape {
        anchors.fill: parent
        antialiasing: true

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: "#0C0C10"
            startX: 0
            startY: 0

            PathLine { x: background.outerRight; y: 0 }
            PathLine { x: background.outerRight; y: background.curveTop }
            PathCubic {
                x: background.bodyRight
                y: background.curveTop + background.radius
                control1X: background.outerRight - background.curveHandle
                control1Y: background.curveTop
                control2X: background.bodyRight
                control2Y: background.curveTop + background.radius - background.curveHandle
            }
            PathLine { x: background.bodyRight; y: background.curveBottom - background.radius }
            PathCubic {
                x: background.outerRight
                y: background.curveBottom
                control1X: background.bodyRight
                control1Y: background.curveBottom - background.radius + background.curveHandle
                control2X: background.outerRight - background.curveHandle
                control2Y: background.curveBottom
            }
            PathLine { x: background.outerRight; y: background.height }
            PathLine { x: 0; y: background.height }
            PathLine { x: 0; y: 0 }
        }

    }
}
