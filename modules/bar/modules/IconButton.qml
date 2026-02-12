import QtQuick
import Quickshell.Io

Item {
    id: root

    property string icon: ""
    property string baseColor: "#E6E6E6"
    property string hoverColor: "#B80000"
    property int iconSize: 24
    property int hitSize: 26

    signal clicked()

    property bool hovered: false
    property string distroId: "linux"

    readonly property string resolvedIcon: (root.icon && root.icon.length)
        ? root.icon
        : root.distroIcon(root.distroId)

    width: root.hitSize
    height: root.hitSize

    Process {
        id: osReleaseProc
        command: ["sh", "-lc",
            "if [ -r /etc/os-release ]; then . /etc/os-release; " +
            "elif [ -r /usr/lib/os-release ]; then . /usr/lib/os-release; " +
            "fi; echo \"${ID:-linux}\""
        ]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const v = (this.text || "").trim()
                root.distroId = v.length ? v : "linux"
            }
        }
    }

    Component.onCompleted: osReleaseProc.exec(osReleaseProc.command)

    function distroIcon(id) {
        switch ((id || "").toLowerCase()) {
        case "arch": return "󰣇"
        case "endeavouros": return "󰣇"
        case "manjaro": return "󱘊"
        case "fedora": return "󰣛"
        case "ubuntu": return "󰕈"
        case "debian": return "󰣚"
        case "gentoo": return "󰣨"
        case "nixos": return "󱄅"
        case "opensuse":
        case "opensuse-tumbleweed":
        case "opensuse-leap":
            return ""
        default: return "󰌽"
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.resolvedIcon
        color: root.hovered ? root.hoverColor : root.baseColor
        font.pixelSize: root.iconSize
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered = true
        onExited:  root.hovered = false
        onClicked: root.clicked()
    }
}
