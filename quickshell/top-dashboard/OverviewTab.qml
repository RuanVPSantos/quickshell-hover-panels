import QtQuick

Item {
    id: root
    required property date now
    required property var monthNames
    required property var weekNames
    required property var calendarCells
    required property int monthOffset
    required property var metrics
    required property var player
    signal focusPlayer()
    signal previousMonth()
    signal nextMonth()

    readonly property date shownMonth: new Date(now.getFullYear(), now.getMonth() + monthOffset, 1)
    readonly property var weather: metrics.weather || ({ location: "", condition: "Weather unavailable", temperature: "--°C" })

    Rectangle {
        x: 0; y: 0
        width: 245; height: 126
        radius: 20
        color: "#3D2D2831"
        border.color: "#80463D48"
        border.width: 1

        Text {
            x: 20; y: 23
            text: root.weather.condition.toLowerCase().includes("rain") ? "\uf740" : root.weather.condition.toLowerCase().includes("cloud") ? "\uf0c2" : "\uf185"
            color: "#F4F4F6"
            font.family: "Font Awesome 6 Free"
            font.pixelSize: 40
            font.weight: Font.Black
        }
        Text {
            x: 91; y: 18
            text: root.weather.temperature
            color: "#f1e5ef"
            font.family: "Noto Sans"
            font.pixelSize: 29
            font.weight: Font.DemiBold
        }
        Text {
            x: 93; y: 62
            width: 132
            text: root.weather.condition
            color: "#d2c2d1"
            font.family: "Noto Sans"
            font.pixelSize: 13
            elide: Text.ElideRight
        }
        Text {
            x: 20; y: 101
            width: 205
            text: root.weather.location || "LOCAL WEATHER"
            color: "#968899"
            font.family: "Noto Sans"
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 1
            elide: Text.ElideRight
        }
    }

    Rectangle {
        x: 257; y: 0
        width: 335; height: 126
        radius: 20
        color: "#3D2D2831"
        border.color: "#80463D48"
        border.width: 1

        Rectangle {
            x: 18; y: 25
            width: 76; height: 76
            radius: 38
            color: "#514354"
            Text {
                anchors.centerIn: parent
                text: "\uf007"
                color: "#F4F4F6"
                font.family: "Font Awesome 6 Free"
                font.pixelSize: 31
                font.weight: Font.Black
            }
        }
        Text {
            x: 110; y: 17
            width: 207
            text: (root.metrics.user || "user").toUpperCase()
            color: "#f0e3ed"
            font.family: "Noto Sans"
            font.pixelSize: 13
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
            elide: Text.ElideRight
        }
        Column {
            x: 110; y: 46
            spacing: 7
            Repeater {
                model: ["Fedora Linux", "Hyprland", "Up " + (root.metrics.uptime || "—")]
                delegate: Text {
                    required property string modelData
                    width: 207
                    text: modelData
                    color: "#c7b8c8"
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
        }
    }

    Rectangle {
        x: 0; y: 138
        width: 115; height: 256
        radius: 20
        color: "#3D2D2831"
        border.color: "#80463D48"
        border.width: 1

        Column {
            anchors.centerIn: parent
            spacing: -7
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(root.now, "HH")
                color: "#efe1ec"
                font.family: "Noto Sans"
                font.pixelSize: 40
                font.weight: Font.DemiBold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "•••"
                color: "#d8c6d6"
                font.pixelSize: 19
                font.letterSpacing: 2
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(root.now, "mm")
                color: "#efe1ec"
                font.family: "Noto Sans"
                font.pixelSize: 40
                font.weight: Font.DemiBold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.weekNames[root.now.getDay()].slice(0, 3) + ", " + root.now.getDate()
                color: "#a99bad"
                font.family: "Noto Sans"
                font.pixelSize: 12
            }
        }
    }

    Rectangle {
        x: 127; y: 138
        width: 350; height: 256
        radius: 20
        color: "#3D2D2831"
        border.color: "#80463D48"
        border.width: 1

        Text {
            x: 19; y: 12
            text: root.monthNames[root.shownMonth.getMonth()].toUpperCase() + " " + root.shownMonth.getFullYear()
            color: "#d8c9d8"
            font.family: "Noto Sans"
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 1
        }
        Text {
            x: 278; y: 6
            text: "‹"
            color: previousMouse.containsMouse ? "#ffffff" : "#F4F4F6"
            font.pixelSize: 23
            MouseArea {
                id: previousMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.previousMonth()
            }
        }
        Text {
            x: 314; y: 6
            text: "›"
            color: nextMouse.containsMouse ? "#ffffff" : "#F4F4F6"
            font.pixelSize: 23
            MouseArea {
                id: nextMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.nextMonth()
            }
        }
        Grid {
            x: 20; y: 42
            columns: 7
            columnSpacing: 4
            rowSpacing: 1
            Repeater {
                model: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
                delegate: Text {
                    required property string modelData
                    width: 41; height: 24
                    text: modelData
                    color: "#aa9aac"
                    font.family: "Noto Sans"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            Repeater {
                model: root.calendarCells
                delegate: Rectangle {
                    id: dayCell
                    required property var modelData
                    width: 41; height: 27
                    radius: 10
                    color: modelData.today ? "#e6d7e5" : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: dayCell.modelData.day
                        color: dayCell.modelData.today ? "#251f27" : dayCell.modelData.inMonth ? "#e4d8e4" : "#796d7b"
                        font.family: "Noto Sans"
                        font.pixelSize: 12
                        font.weight: dayCell.modelData.today ? Font.Bold : Font.Normal
                    }
                }
            }
        }
    }

    Rectangle {
        x: 489; y: 138
        width: 103; height: 256
        radius: 20
        color: "#3D2D2831"
        border.color: "#80463D48"
        border.width: 1

        Text {
            x: 12; y: 14
            text: "SYSTEM"
            color: "#a999aa"
            font.family: "Noto Sans"
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 1
        }
        Row {
            x: 11; y: 59
            spacing: 7
            Repeater {
                model: [
                    { label: "CPU", value: root.metrics.cpu || 0 },
                    { label: "RAM", value: root.metrics.memory || 0 },
                    { label: "DSK", value: root.metrics.disk || 0 }
                ]
                delegate: Item {
                    id: meter
                    required property var modelData
                    width: 22; height: 175
                    Rectangle {
                        x: 5; y: 0
                        width: 12; height: 126
                        radius: 6
                        color: "#514553"
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: Math.max(4, parent.height * meter.modelData.value / 100)
                            radius: 6
                            color: meter.modelData.value > 85 ? "#e59d9c" : "#ddcade"
                            Behavior on height { NumberAnimation { duration: 250 } }
                        }
                    }
                    Text {
                        x: -2; y: 135
                        width: 26
                        text: meter.modelData.label
                        color: "#c9bbcb"
                        font.family: "Noto Sans"
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        x: -2; y: 153
                        width: 26
                        text: meter.modelData.value + "%"
                        color: "#eee1ec"
                        font.family: "Noto Sans"
                        font.pixelSize: 9
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }

    Rectangle {
        x: 604; y: 0
        width: 240; height: 394
        radius: 22
        color: "#3D2D2831"
        border.color: "#80463D48"
        border.width: 1

        MouseArea {
            anchors.fill: parent
            enabled: !!root.player
            cursorShape: Qt.PointingHandCursor
            onClicked: root.focusPlayer()
        }

        Rectangle {
            x: 62; y: 18
            width: 116; height: 116
            radius: 58
            clip: true
            color: "#514354"
            Text {
                anchors.centerIn: parent
                visible: !cover.visible
                text: "\uf001"
                color: "#F4F4F6"
                font.family: "Font Awesome 6 Free"
                font.pixelSize: 28
                font.weight: Font.Black
            }
            Image {
                id: cover
                anchors.fill: parent
                visible: status === Image.Ready
                source: root.player ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
        Text {
            x: 20; y: 150
            width: 200
            text: root.player ? (root.player.trackTitle || "Untitled") : "No media"
            color: "#f1e5ef"
            font.family: "Noto Sans"
            font.pixelSize: 13
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
        Text {
            x: 20; y: 174
            width: 200
            text: root.player ? (root.player.trackArtist || root.player.identity) : "Open a player"
            color: "#c7b8c8"
            font.family: "Noto Sans"
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
        Text {
            x: 20; y: 194
            width: 200
            text: root.player ? (root.player.trackAlbum || "") : ""
            color: "#928497"
            font.family: "Noto Sans"
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
        Row {
            x: 54; y: 220
            spacing: 12
            Repeater {
                model: ["\uf048", "\uf04b", "\uf051"]
                delegate: Rectangle {
                    id: mediaButton
                    required property string modelData
                    required property int index
                    width: 36; height: 36
                    radius: 12
                    color: mediaMouse.containsMouse ? "#5b4d5d" : "#3d3540"
                    opacity: root.player ? 1 : 0.45
                    Text {
                        anchors.centerIn: parent
                        text: mediaButton.index === 1 && root.player && root.player.isPlaying ? "\uf04c" : mediaButton.modelData
                        color: "#F4F4F6"
                        font.family: "Font Awesome 6 Free"
                        font.pixelSize: 15
                        font.weight: Font.Black
                    }
                    MouseArea {
                        id: mediaMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: root.player ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (!root.player) return;
                            if (mediaButton.index === 0 && root.player.canGoPrevious) root.player.previous();
                            if (mediaButton.index === 1 && root.player.canTogglePlaying) root.player.togglePlaying();
                            if (mediaButton.index === 2 && root.player.canGoNext) root.player.next();
                        }
                    }
                }
            }
        }
        GardevoirAnimation {
            x: 26; y: 259
            width: 188; height: 125
            playing: root.visible
        }
    }
}
