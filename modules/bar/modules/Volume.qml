import QtQuick
import Quickshell.Io

Item {
    id: root

    height: 30
    implicitWidth: content.implicitWidth
    width: implicitWidth

    property string red: "#B80000"
    property string bg2: "#1A1A1A"
    property string text: "#E6E6E6"
    property string muted: "#A8A8A8"
    property string borderColor: "#2A2A2A"

    property real volume01: 0.0
    property bool isMuted: false
    readonly property int volumePct: Math.max(0, Math.min(150, Math.round(root.volume01 * 100)))

    property real pendingVolume: -1
    property bool hasPendingChange: false

    function _icon() {
        if (root.isMuted || root.volume01 <= 0.001) return "󰖁"
        if (root.volume01 < 0.33) return "󰕿"
        if (root.volume01 < 0.66) return "󰖀"
        return "󰕾"
    }

    function refreshSoon() { refreshTimer.restart(); }

    function toggleMute() {
        runner.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        runner.exec(runner.command)
        refreshSoon()
    }

    Row {
        id: content
        spacing: 8
        height: root.height
        anchors.verticalCenter: parent.verticalCenter

        Text {
            height: parent.height
            text: root._icon()
            color: root.text
            font.pixelSize: 18
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            height: parent.height
            text: root.isMuted ? "muted" : (String(root.volumePct) + "%")
            color: root.isMuted ? root.muted : root.text
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
        }
    }

    Process { id: runner }

    Process {
        id: getProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var raw = this.text.trim()
                if (!raw) return

                var m = raw.match(/Volume:\s*([0-9]*\.?[0-9]+)/)
                if (m && m[1] !== undefined) {
                    var v = Number(m[1])
                    if (isFinite(v)) {

                        if (!root.hasPendingChange || Math.abs(v - root.pendingVolume) < 0.01) {
                            root.volume01 = v
                            root.hasPendingChange = false
                            root.pendingVolume = -1
                        }

                    }
                }
                root.isMuted = /\[MUTED\]/i.test(raw)
            }
        }
    }

    Timer {
        id: pollTimer
        interval: 1500

        running: true
        repeat: true
        onTriggered: getProc.exec(getProc.command)
    }

    Timer {
        id: refreshTimer
        interval: 100

        running: false
        repeat: false
        onTriggered: getProc.exec(getProc.command)
    }

    Component.onCompleted: getProc.exec(getProc.command)

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: root.toggleMute()
        
        function changeVolume(delta) {

            const newVol = Math.max(0, Math.min(1.5, root.volume01 + delta))

            root.pendingVolume = newVol
            root.hasPendingChange = true

            root.volume01 = newVol

            if (delta > 0 && root.isMuted) {
                root.isMuted = false
            }

            runner.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", String(newVol.toFixed(3))]
            runner.exec(runner.command)

            Qt.callLater(function() {
                getProc.exec(getProc.command)
            })
        }
        
        onWheel: function(wheel) {

            const baseIncrement = 0.02
            const scrollFactor = Math.abs(wheel.angleDelta.y) / 120.0
            const increment = baseIncrement * Math.max(1.0, Math.min(scrollFactor, 3.0))

            
            if (wheel.angleDelta.y > 0) {

                changeVolume(increment)
            } else if (wheel.angleDelta.y < 0) {

                changeVolume(-increment)
            }

            wheel.accepted = true
        }
    }
}
