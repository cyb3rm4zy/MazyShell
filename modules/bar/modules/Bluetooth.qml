import QtQuick
import Quickshell.Bluetooth

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

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter ? adapter.enabled : false

    readonly property string connectedName: {
        const vals = Bluetooth.devices?.values ?? [];
        for (let i = 0; i < vals.length; i++) {
            if (vals[i].connected) {
                const n = vals[i].name || vals[i].deviceName || "";
                return n.length ? n : vals[i].address;
            }
        }
        return "";
    }

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
}