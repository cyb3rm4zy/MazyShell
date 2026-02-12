import QtQuick
import Quickshell.Io

Item {
    id: root
    required property QtObject config

    signal requestWallpaper()
    signal requestAppLauncher()

    implicitHeight: grid.implicitHeight
    height: implicitHeight

    readonly property var app: (config && config.appearance) ? config.appearance : null
    readonly property color bg2: (app && app.bg2 !== undefined) ? app.bg2 : "#1A1A1A"
    readonly property color red: (app && app.accent !== undefined) ? app.accent : "#B80000"
    readonly property color border: (app && (app.borderColor ?? app.border) !== undefined) ? (app.borderColor ?? app.border) : "#2A2A2A"
    readonly property color text: (app && (app.fg ?? app.text) !== undefined) ? (app.fg ?? app.text) : "#E6E6E6"
    readonly property int radius: (app && app.radius !== undefined) ? app.radius : 12

    Process { id: runner }
    function sh(cmd) {
        runner.command = ["sh", "-lc", cmd]
        runner.running = true
    }

    function runShutdown()    { sh("systemctl poweroff") }
    function runReboot()      { sh("systemctl reboot") }
    function runLogout()      { sh("loginctl terminate-user $USER") }
    function runLock()        { sh("loginctl lock-session") }
    function runWifiUi()      { sh("kitty nmtui >/dev/null 2>&1 &") }
    function runProcessesUi() { sh("kitty -e btop >/dev/null 2>&1 &") }

    component IconAction: Rectangle {
        width: 100
        height: 46
        radius: root.radius
        color: root.bg2
        border.color: root.border
        border.width: 1

        property string icon: "?"
        property var action: function() {}
        property bool hovered: false

        Text {
            anchors.centerIn: parent
            text: parent.icon
            color: parent.hovered ? root.red : root.text
            font.pixelSize: 20
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: parent.hovered = true
            onExited:  parent.hovered = false
            onClicked: parent.action()
        }
    }

    Column {
        id: grid
        width: parent.width
        spacing: 10

        Row {
            spacing: 10
            IconAction {
                width: grid.width
                icon: "󰀻"

                action: function(){ root.requestAppLauncher() }
            }
        }

        Row {
            spacing: 10
            IconAction { width: (grid.width - 10)/2; icon: "󰐥"; action: runShutdown }
            IconAction { width: (grid.width - 10)/2; icon: "󰌾"; action: runLock }
        }
        Row {
            spacing: 10
            IconAction { width: (grid.width - 10)/2; icon: "󰜉"; action: runReboot }
            IconAction { width: (grid.width - 10)/2; icon: "󰍃"; action: runLogout }
        }
        Row {
            spacing: 10
            IconAction { width: (grid.width - 10)/2; icon: "󰤨"; action: runWifiUi }
            IconAction { width: (grid.width - 10)/2; icon: "󰄪"; action: runProcessesUi }
        }
        Row {
            spacing: 10
            IconAction { width: (grid.width - 10)/2; icon: "󰉏"; action: function(){ root.requestWallpaper() } }
            IconAction { width: (grid.width - 10)/2; icon: "󰒓"; action: function() {} }
        }

    }
}
