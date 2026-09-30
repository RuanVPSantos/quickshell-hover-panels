import QtQuick
import Quickshell.Services.Mpris

Rectangle {
    id: root
    required property var player
    required property var players
    signal selectPlayer(var selected)

    readonly property bool hasDuration: player && player.length > 0 && player.length < 2147483647
    readonly property real progress: hasDuration ? Math.max(0, Math.min(1, player.position / player.length)) : 0

    function timeLabel(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            return "--:--";
        const whole = Math.floor(seconds);
        return Math.floor(whole / 60) + ":" + ("0" + whole % 60).slice(-2);
    }

    radius: 20
    color: "#3D2D2831"
    border.color: "#80463D48"
    border.width: 1

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && root.player && root.player.isPlaying
        onTriggered: {
            if (root.player)
                root.player.positionChanged();
        }
    }

    Rectangle {
        id: coverColumn
        x: 18; y: 18
        width: 246; height: root.height - 36
        radius: 19
        color: "#4039323E"
        border.color: "#514653"
        border.width: 1

        Text {
            x: 20; y: 15
            text: "NOW PLAYING"
            color: "#c4b1c2"
            font.family: "Noto Sans"
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 1.4
        }

        Rectangle {
            x: 19; y: 54
            width: 208; height: 208
            radius: 29
            color: "#544757"
            clip: true

            Text {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: "\uf001"
                color: "#F4F4F6"
                font.family: "Font Awesome 6 Free"
                font.pixelSize: 64
                font.weight: Font.Black
            }
            Image {
                id: art
                anchors.fill: parent
                source: root.player ? root.player.trackArtUrl : ""
                visible: status === Image.Ready
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        Rectangle {
            x: 19; y: 280
            width: 208; height: 1
            color: "#625463"
        }
        Text {
            x: 20; y: 297
            width: 206
            text: root.player ? root.player.identity : "No player active"
            color: "#e4d3e1"
            font.family: "Noto Sans"
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
        Text {
            x: 20; y: 322
            text: root.player && root.player.isPlaying ? "PLAYING" : "PAUSED"
            visible: !!root.player
            color: "#ac91a8"
            font.family: "Noto Sans"
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 1.3
        }
    }

    Item {
        id: details
        x: 282; y: 18
        width: 288; height: root.height - 36

        Text {
            x: 0; y: 6
            text: "TRACK DETAILS"
            color: "#bbaebd"
            font.family: "Noto Sans"
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 1.4
        }
        Text {
            x: 0; y: 50
            width: parent.width
            text: root.player ? (root.player.trackTitle || "Untitled") : "Nothing playing"
            color: "#f3e6f0"
            font.family: "Noto Sans"
            font.pixelSize: 26
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        Text {
            x: 0; y: 119
            width: parent.width
            text: root.player ? (root.player.trackArtist || "Unknown artist") : "Open your music player"
            color: "#d1bdcf"
            font.family: "Noto Sans"
            font.pixelSize: 16
            elide: Text.ElideRight
        }
        Text {
            x: 0; y: 150
            width: parent.width
            text: root.player ? (root.player.trackAlbum || "Unknown album") : ""
            color: "#aa8fa8"
            font.family: "Noto Sans"
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        Text {
            x: 0; y: 194
            text: root.hasDuration ? root.timeLabel(root.player.position) : "--:--"
            color: "#a898aa"
            font.family: "Noto Sans"
            font.pixelSize: 11
        }
        Text {
            x: parent.width - 50; y: 194
            width: 50
            text: root.hasDuration ? root.timeLabel(root.player.length) : "--:--"
            color: "#a898aa"
            horizontalAlignment: Text.AlignRight
            font.family: "Noto Sans"
            font.pixelSize: 11
        }
        Rectangle {
            id: progressTrack
            x: 0; y: 216
            width: parent.width; height: 7
            radius: 4
            color: "#5a4e5d"
            Rectangle {
                width: parent.width * root.progress
                height: parent.height
                radius: 4
                color: "#e3cde0"
            }
            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -8
                anchors.bottomMargin: -8
                enabled: root.hasDuration && root.player.canSeek
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => root.player.position = Math.max(0, Math.min(1, mouse.x / progressTrack.width)) * root.player.length
            }
        }

        Row {
            x: 0; y: 261
            spacing: 8
            Repeater {
                model: ["\uf074", "\uf048", "\uf04b", "\uf051", "\uf01e"]
                delegate: Rectangle {
                    id: control
                    required property int index
                    required property string modelData
                    readonly property bool available: {
                        if (!root.player) return false;
                        if (index === 0) return root.player.shuffleSupported;
                        if (index === 1) return root.player.canGoPrevious;
                        if (index === 2) return root.player.canTogglePlaying;
                        if (index === 3) return root.player.canGoNext;
                        return root.player.loopSupported;
                    }
                    readonly property bool active: root.player && ((index === 0 && root.player.shuffle) || (index === 4 && root.player.loopState !== MprisLoopState.None))
                    width: index === 2 ? 56 : 46
                    height: index === 2 ? 56 : 46
                    anchors.verticalCenter: parent.verticalCenter
                    radius: height / 2
                    color: index === 2 ? "#F4F4F6" : active ? "#6a5369" : controlMouse.containsMouse && available ? "#554859" : "#423746"
                    opacity: available ? 1 : 0.38

                    Text {
                        anchors.centerIn: parent
                        text: control.index === 2 && root.player && root.player.isPlaying ? "\uf04c" : control.modelData
                        color: control.index === 2 ? "#2a222d" : "#F4F4F6"
                        font.family: "Font Awesome 6 Free"
                        font.pixelSize: control.index === 2 ? 19 : 16
                        font.weight: Font.Black
                    }
                    MouseArea {
                        id: controlMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: control.available
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (control.index === 0) root.player.shuffle = !root.player.shuffle;
                            else if (control.index === 1) root.player.previous();
                            else if (control.index === 2) root.player.togglePlaying();
                            else if (control.index === 3) root.player.next();
                            else if (root.player.loopState === MprisLoopState.None) root.player.loopState = MprisLoopState.Track;
                            else if (root.player.loopState === MprisLoopState.Track) root.player.loopState = MprisLoopState.Playlist;
                            else root.player.loopState = MprisLoopState.None;
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: lyricsPanel
        x: 588; y: 18
        width: root.width - x - 18
        height: root.height - 36
        radius: 19
        color: "#40352F39"
        border.color: "#514653"
        border.width: 1

        Text {
            x: 17; y: 18
            text: "LYRICS"
            color: "#e0cddc"
            font.family: "Noto Sans"
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.letterSpacing: 1.1
        }
        Rectangle {
            x: 17; y: 48
            width: parent.width - 34; height: 1
            color: "#594c5b"
        }
        Text {
            x: 17; y: 78
            width: parent.width - 34
            text: "No lyrics available"
            color: "#d6c4d3"
            horizontalAlignment: Text.AlignHCenter
            font.family: "Noto Sans"
            font.pixelSize: 14
            font.weight: Font.Medium
        }
        Text {
            x: 19; y: 104
            width: parent.width - 38
            text: "This player does not provide lyrics."
            color: "#a997a9"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font.family: "Noto Sans"
            font.pixelSize: 11
        }

        GardevoirAnimation {
            x: 18; y: 149
            width: parent.width - 36; height: 157
            playing: root.visible
        }

        Rectangle {
            x: 13; y: parent.height - 48
            width: parent.width - 26; height: 35
            radius: 12
            color: playerMouse.containsMouse && root.players.length > 1 ? "#59495a" : "#493d4d"
            Text {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 36
                text: root.player ? root.player.identity : "No active player"
                color: "#eadbe8"
                elide: Text.ElideRight
                font.family: "Noto Sans"
                font.pixelSize: 12
            }
            Text {
                x: parent.width - 22
                anchors.verticalCenter: parent.verticalCenter
                text: root.players.length > 1 ? "\uf0d7" : ""
                color: "#F4F4F6"
                font.family: "Font Awesome 6 Free"
                font.pixelSize: 11
                font.weight: Font.Black
            }
            MouseArea {
                id: playerMouse
                anchors.fill: parent
                enabled: root.players.length > 1
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const current = root.players.indexOf(root.player);
                    root.selectPlayer(root.players[(current + 1) % root.players.length]);
                }
            }
        }
    }
}
