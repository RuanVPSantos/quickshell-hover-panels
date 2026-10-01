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
    readonly property real outerStrokeRadius: radius + 0.5
    readonly property real innerStrokeRadius: Math.max(0, radius - 0.5)

    Shape {
        anchors.fill: parent
        antialiasing: true

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: Qt.rgba(0, 0, 0, 0.55)
            fillGradient: LinearGradient {
                x1: background.bodyRight
                y1: 0
                x2: Math.max(background.bodyRight + 0.001, background.outerRight)
                y2: 0
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.55) }
                GradientStop { position: 1; color: "transparent" }
            }
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

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: background.bodyRight
                y1: 0
                x2: Math.max(background.bodyRight + 0.001, background.outerRight)
                y2: 0
                GradientStop { position: 0; color: "#4DFFFFFF" }
                GradientStop { position: 1; color: "transparent" }
            }
            startX: background.outerRight
            startY: background.curveTop + background.radius - background.outerStrokeRadius

            PathCubic {
                x: background.outerRight - background.outerStrokeRadius
                y: background.curveTop + background.radius
                control1X: background.outerRight - background.outerStrokeRadius * 0.55228475
                control1Y: background.curveTop + background.radius - background.outerStrokeRadius
                control2X: background.outerRight - background.outerStrokeRadius
                control2Y: background.curveTop + background.radius - background.outerStrokeRadius * 0.55228475
            }
            PathLine { x: background.outerRight - background.outerStrokeRadius; y: background.curveBottom - background.radius }
            PathCubic {
                x: background.outerRight
                y: background.curveBottom - background.radius + background.outerStrokeRadius
                control1X: background.outerRight - background.outerStrokeRadius
                control1Y: background.curveBottom - background.radius + background.outerStrokeRadius * 0.55228475
                control2X: background.outerRight - background.outerStrokeRadius * 0.55228475
                control2Y: background.curveBottom - background.radius + background.outerStrokeRadius
            }
            PathLine { x: background.outerRight; y: background.curveBottom - background.radius + background.innerStrokeRadius }
            PathCubic {
                x: background.outerRight - background.innerStrokeRadius
                y: background.curveBottom - background.radius
                control1X: background.outerRight - background.innerStrokeRadius * 0.55228475
                control1Y: background.curveBottom - background.radius + background.innerStrokeRadius
                control2X: background.outerRight - background.innerStrokeRadius
                control2Y: background.curveBottom - background.radius + background.innerStrokeRadius * 0.55228475
            }
            PathLine { x: background.outerRight - background.innerStrokeRadius; y: background.curveTop + background.radius }
            PathCubic {
                x: background.outerRight
                y: background.curveTop + background.radius - background.innerStrokeRadius
                control1X: background.outerRight - background.innerStrokeRadius
                control1Y: background.curveTop + background.radius - background.innerStrokeRadius * 0.55228475
                control2X: background.outerRight - background.innerStrokeRadius * 0.55228475
                control2Y: background.curveTop + background.radius - background.innerStrokeRadius
            }
            PathLine { x: background.outerRight; y: background.curveTop + background.radius - background.outerStrokeRadius }
        }
    }
}
