import QtQuick
import Quickshell.Io

Rectangle {
    id: picker
    signal dismissed()
    signal connected()
    signal hoverChanged(bool hovered)
    signal settingsRequested()
    signal toggleWifiRequested()
    required property string helperPath
    property bool wifiEnabled: true

    property var networks: []
    property var selectedNetwork: null
    property string message: ""
    property string payload: ""
    property bool scanning: false
    property bool askingPassword: false
    property bool passwordAttempted: false

    radius: 26
    color: Qt.rgba(0, 0, 0, 0.55)
    border.color: "#4DFFFFFF"
    border.width: 1
    focus: true
    Keys.onEscapePressed: dismissed()

    HoverHandler {
        onHoveredChanged: picker.hoverChanged(hovered)
    }

    function open() {
        networks = [];
        message = "";
        askingPassword = false;
        if (!cachedList.running) cachedList.running = true;
        scanDelay.restart();
    }

    function readNetworks(output) {
        try {
            const result = JSON.parse(output);
            if (result.error) { message = result.error; return; }
            networks = result.networks || [];
            message = networks.length ? "" : "No networks found nearby";
        } catch (error) {
            message = "Could not read nearby networks";
        }
    }

    function selectNetwork(network) {
        if (network.active) { dismissed(); return; }
        if (connection.running) return;
        selectedNetwork = network;
        askingPassword = false;
        startConnection("");
    }

    function startConnection(password) {
        if (!selectedNetwork || connection.running) return;
        passwordAttempted = password.length > 0;
        message = "Connecting to " + selectedNetwork.ssid + "…";
        payload = JSON.stringify({ ssid: selectedNetwork.ssid, password: password }) + "\n";
        connection.running = true;
    }

    function submitPassword(password) {
        if (!password) { message = "Enter the Wi-Fi password"; return; }
        startConnection(password);
    }

    Timer {
        id: scanDelay
        interval: 80
        onTriggered: {
            if (!freshList.running) {
                picker.scanning = true;
                freshList.running = true;
            }
        }
    }

    Process {
        id: cachedList
        command: ["python3", picker.helperPath, "--list"]
        stdout: StdioCollector { onStreamFinished: picker.readNetworks(this.text) }
    }

    Process {
        id: freshList
        command: ["python3", picker.helperPath, "--list", "--rescan"]
        stdout: StdioCollector { onStreamFinished: picker.readNetworks(this.text) }
        onExited: picker.scanning = false
    }

    Process {
        id: connection
        command: ["python3", picker.helperPath, "--connect"]
        stdinEnabled: true
        onStarted: {
            write(picker.payload);
            picker.payload = "";
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(this.text);
                    if (result.ok) {
                        picker.connected();
                        picker.dismissed();
                    } else if (picker.selectedNetwork?.secured && !picker.passwordAttempted) {
                        picker.askingPassword = true;
                        picker.message = "Enter the password for " + picker.selectedNetwork.ssid;
                    } else {
                        picker.message = result.error || "Could not connect to this network";
                    }
                } catch (error) {
                    picker.message = "Could not connect to this network";
                }
            }
        }
    }

    Text {
        x: 20; y: 18
        text: "Wi-Fi networks"
        color: "#F4F4F6"
        font.family: "Noto Sans"
        font.pixelSize: 17
        font.weight: Font.DemiBold
    }

    Text {
        x: 20; y: 49
        width: parent.width - 40
        text: picker.message || (picker.scanning ? "Scanning nearby networks…" : picker.networks.length + " nearby network" + (picker.networks.length === 1 ? "" : "s"))
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
            visible: picker.networks.length === 0
            text: picker.scanning ? "Looking for networks…" : "No networks found"
            color: "#c7b8c8"
            font.family: "Noto Sans"
            font.pixelSize: 12
        }

        ListView {
            anchors.fill: parent
            anchors.margins: 7
            clip: true
            spacing: 3
            model: picker.networks
            delegate: Rectangle {
                id: networkRow
                required property var modelData
                width: ListView.view.width
                height: 46
                radius: 12
                color: rowMouse.containsMouse ? "#A6554859" : modelData.active ? "#8039323E" : "transparent"

                Text {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: networkRow.modelData.active ? "󰤨" : "󰤥"
                    color: "#F4F4F6"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 17
                }
                Text {
                    x: 43
                    width: parent.width - 130
                    anchors.verticalCenter: parent.verticalCenter
                    text: networkRow.modelData.ssid
                    color: "#F4F4F6"
                    font.family: "Noto Sans"
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 11
                    anchors.verticalCenter: parent.verticalCenter
                    text: networkRow.modelData.active ? "Connected" : networkRow.modelData.signal + "%"
                    color: networkRow.modelData.active ? "#f0e3ed" : "#b7a8b9"
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: picker.selectNetwork(networkRow.modelData)
                }
            }
        }
    }

    Rectangle {
        x: 14; y: 343
        width: parent.width - 28
        height: 42
        radius: 12
        visible: picker.askingPassword
        color: "#4039323E"
        border.color: "#80463D48"

        TextInput {
            id: passwordInput
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 100
            color: "#F4F4F6"
            font.family: "Noto Sans"
            font.pixelSize: 13
            echoMode: TextInput.Password
            clip: true
            onVisibleChanged: {
                if (visible) forceActiveFocus();
                else text = "";
            }
            Keys.onReturnPressed: picker.submitPassword(text)
            Keys.onEscapePressed: picker.dismissed()
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !passwordInput.text && !passwordInput.activeFocus
                text: "Password"
                color: "#b7a8b9"
                font.family: "Noto Sans"
                font.pixelSize: 13
            }
        }
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 82; height: 34
            radius: 10
            color: connectMouse.containsMouse ? "#A66A5369" : "#80514354"
            Text {
                anchors.centerIn: parent
                text: "Connect"
                color: "#F4F4F6"
                font.family: "Noto Sans"
                font.pixelSize: 12
            }
            MouseArea {
                id: connectMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: picker.submitPassword(passwordInput.text)
            }
        }
    }

    Row {
        x: 14; y: 343
        spacing: 8
        visible: !picker.askingPassword
        Repeater {
            model: ["Network settings", picker.wifiEnabled ? "Wi-Fi off" : "Wi-Fi on"]
            delegate: Rectangle {
                id: footerButton
                required property int index
                required property string modelData
                width: (picker.width - 36) / 2
                height: 42
                radius: 12
                color: footerMouse.containsMouse ? "#A6554859" : "#80423746"
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
                        else picker.toggleWifiRequested();
                    }
                }
            }
        }
    }
}
