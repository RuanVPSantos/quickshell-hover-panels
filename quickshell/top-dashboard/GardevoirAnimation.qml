import QtQuick

Item {
    id: root
    property bool playing: true
    property int frameIndex: 0

    Image {
        id: frame
        anchors.fill: parent
        source: "assets/gardevoir-frames/" + (root.frameIndex < 10 ? "0" : "") + root.frameIndex + ".png"
        fillMode: Image.PreserveAspectFit
        asynchronous: false
        cache: true
        visible: status === Image.Ready
    }

    Text {
        anchors.centerIn: parent
        visible: frame.status !== Image.Ready
        text: "\uf001"
        color: "#F4F4F6"
        font.family: "Font Awesome 6 Free"
        font.pixelSize: 32
        font.weight: Font.Black
    }

    Timer {
        interval: 100
        repeat: true
        running: root.playing && root.visible && frame.status === Image.Ready
        onTriggered: root.frameIndex = (root.frameIndex + 1) % 32
    }

    onVisibleChanged: {
        if (!visible)
            frameIndex = 0;
    }
}
