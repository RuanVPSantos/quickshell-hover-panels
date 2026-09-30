import QtQuick

Rectangle {
    id: root
    required property var metrics

    radius: 20
    color: "#3D2D2831"
    border.color: "#80463D48"
    border.width: 1

    Row {
        x: 17; y: 17
        spacing: 14

        Repeater {
            model: [
                {
                    label: "CPU",
                    detail: "Processor",
                    usage: root.metrics.cpu ?? 0,
                    temperature: root.metrics.cpuTemp,
                    accent: "#ddc4dc"
                },
                {
                    label: "GPU",
                    detail: "Graphics",
                    usage: root.metrics.gpu,
                    temperature: root.metrics.gpuTemp,
                    accent: "#d5a6bb"
                }
            ]

            delegate: Rectangle {
                id: hero
                required property var modelData
                width: (root.width - 48) / 2
                height: 214
                radius: 17
                color: "#4039323E"

                Text {
                    x: 22; y: 18
                    text: hero.modelData.label
                    color: "#f0e2ee"
                    font.family: "Noto Sans"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
                Text {
                    x: 22; y: 44
                    text: hero.modelData.detail
                    color: "#b6a5b7"
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                }

                Text {
                    x: parent.width - 134; y: 20
                    width: 112
                    text: hero.modelData.temperature == null ? "—" : hero.modelData.temperature + "°C"
                    color: "#e9d7e6"
                    horizontalAlignment: Text.AlignRight
                    font.family: "Noto Sans"
                    font.pixelSize: 24
                    font.weight: Font.Medium
                }
                Text {
                    x: parent.width - 134; y: 53
                    width: 112
                    text: "TEMPERATURE"
                    color: "#9f8da1"
                    horizontalAlignment: Text.AlignRight
                    font.family: "Noto Sans"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                }

                Text {
                    x: 22; y: 88
                    text: hero.modelData.usage == null ? "—" : hero.modelData.usage + "%"
                    color: "#f4e8f1"
                    font.family: "Noto Sans"
                    font.pixelSize: 52
                    font.weight: Font.Medium
                }
                Text {
                    x: 24; y: 156
                    text: "Usage"
                    color: "#bdacbe"
                    font.family: "Noto Sans"
                    font.pixelSize: 12
                }

                Rectangle {
                    x: 22; y: 185
                    width: parent.width - 44
                    height: 7
                    radius: 4
                    color: "#5b4f5d"
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(100, Number(hero.modelData.usage) || 0)) / 100
                        height: parent.height
                        radius: 4
                        color: hero.modelData.usage > 85 ? "#e59d9c" : hero.modelData.accent
                        Behavior on width { NumberAnimation { duration: 180 } }
                    }
                }
            }
        }
    }

    Row {
        x: 17; y: 245
        spacing: 14

        Repeater {
            model: [
                {
                    label: "Memory",
                    value: root.metrics.memoryUsedGiB == null ? "—" : root.metrics.memoryUsedGiB + " GiB",
                    detail: root.metrics.memoryTotalGiB == null ? "Loading" : "of " + root.metrics.memoryTotalGiB + " GiB",
                    percent: root.metrics.memory ?? 0,
                    accent: "#c5a5c6"
                },
                {
                    label: "Storage",
                    value: root.metrics.diskUsedGiB == null ? "—" : Math.round(root.metrics.diskUsedGiB) + " GiB",
                    detail: root.metrics.diskTotalGiB == null ? "Loading" : "of " + Math.round(root.metrics.diskTotalGiB) + " GiB",
                    percent: root.metrics.disk ?? 0,
                    accent: "#bfa6c8"
                },
                {
                    label: root.metrics.battery ? "Battery" : "Uptime",
                    value: root.metrics.battery ? root.metrics.battery.percent + "%" : (root.metrics.uptime || "—"),
                    detail: root.metrics.battery ? root.metrics.battery.status : "System running",
                    percent: root.metrics.battery ? root.metrics.battery.percent : 100,
                    accent: "#d7b3c0"
                }
            ]

            delegate: Rectangle {
                id: resource
                required property var modelData
                width: (root.width - 62) / 3
                height: 132
                radius: 17
                color: "#40352F39"

                Text {
                    x: 17; y: 15
                    text: resource.modelData.label
                    color: "#d8c6d5"
                    font.family: "Noto Sans"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                Text {
                    x: 17; y: 40
                    width: parent.width - 34
                    text: resource.modelData.value
                    color: "#f0e3ed"
                    font.family: "Noto Sans"
                    font.pixelSize: 24
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    x: 17; y: 74
                    width: parent.width - 34
                    text: resource.modelData.detail
                    color: "#aa98ab"
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
                Rectangle {
                    x: 17; y: 106
                    width: parent.width - 34
                    height: 6
                    radius: 3
                    color: "#574b59"
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(100, Number(resource.modelData.percent) || 0)) / 100
                        height: parent.height
                        radius: 3
                        color: resource.modelData.accent
                        Behavior on width { NumberAnimation { duration: 180 } }
                    }
                }
            }
        }
    }
}
