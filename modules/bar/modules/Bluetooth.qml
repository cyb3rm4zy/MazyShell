import QtQuick
import Quickshell.Io

Item {
    id: root

    height: 30
    implicitWidth: row.implicitWidth
    width: implicitWidth

    property string red: "#B80000"
    property string bg2: "#1A1A1A"
    property string text: "#E6E6E6"
    property string muted: "#A8A8A8"
    property string borderColor: "#2A2A2A"

    property bool powered: false
    property string connectedName: ""

    readonly property string btctlPath: "$HOME/.config/quickshell/MazyShell/scripts/bluetoothctl.sh"

    function iconForState() {
        return root.powered ? "󰂯" : "󰂲"

    }

    Row {
        id: row
        spacing: 8
        height: root.height
        anchors.verticalCenter: parent.verticalCenter

        Text {
            height: parent.height
            text: root.iconForState()
            color: root.powered ? root.text : root.muted
            font.pixelSize: 16
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            height: parent.height
            text: root.powered
                  ? (root.connectedName.length ? root.connectedName : "None")
                  : "Off"
            color: root.powered
                   ? (root.connectedName.length ? root.text : root.muted)
                   : root.muted
            font.pixelSize: 12
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    Process {
        id: btProc
        command: ["sh", "-lc", root.btctlPath + " bar_status"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var raw = (this.text || "").trim()
                if (!raw) return
                var parts = raw.split("|")

                root.powered = (parts[0] === "yes")
                root.connectedName = (parts.length > 1) ? (parts[1] || "").trim() : ""
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: btProc.exec(btProc.command)
    }

    Component.onCompleted: btProc.exec(btProc.command)
}
