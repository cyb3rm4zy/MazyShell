import QtQuick

Item {
    id: s

    property string label: ""
    property real value: 0.0
    property bool muted: false
    property real maxVol: 1.5

    property string accent: "#B80000"
    property string text: "#E6E6E6"
    property string mutedText: "#A8A8A8"
    property string track: "#262626"

    readonly property int rowSpacing: 10
    readonly property int labelW: 52
    readonly property int valueW: 44

    property real displayValue: value
    property bool dragging: false
    property bool enabled: true

    signal valueCommitted(real v)

    height: 30
    width: 200
    opacity: enabled ? 1.0 : 0.6

    property real _pending: 0.0

    Timer {
        id: commitTimer
        interval: 60
        running: false
        repeat: false
        onTriggered: s.valueCommitted(s._pending)
    }

    onValueChanged: {
        if (!s.dragging) s.displayValue = s.value
    }

    Row {
        anchors.fill: parent
        spacing: s.rowSpacing

        Text {
            width: s.labelW
            height: parent.height
            text: s.label
            color: s.mutedText
            font.pixelSize: 12
            verticalAlignment: Text.AlignVCenter
        }

        Item {
            id: trackBox
            height: parent.height
            width: Math.max(60, s.width - s.labelW - s.valueW - (s.rowSpacing * 2))

            Rectangle {
                id: base
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: s.track
            }

            Rectangle {
                anchors.verticalCenter: base.verticalCenter
                width: Math.max(0, Math.min(base.width, (s.displayValue / s.maxVol) * base.width))
                height: base.height
                radius: 2
                color: s.accent
            }

            Rectangle {
                width: 12
                height: 12
                radius: 6
                color: s.text
                border.width: 1
                border.color: s.track
                y: (parent.height - height) / 2
                x: Math.max(0, Math.min(base.width - width, (s.displayValue / s.maxVol) * base.width - (width / 2)))
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                propagateComposedEvents: true
                enabled: s.enabled

                function setFromX(mx) {
                    var t = mx / base.width
                    t = Math.max(0, Math.min(1, t))
                    var v = t * s.maxVol

                    s.dragging = true
                    s.displayValue = v

                    s._pending = v
                    commitTimer.restart()
                }

                onPressed: (mouse) => setFromX(mouse.x)
                onPositionChanged: (mouse) => { if (pressed) setFromX(mouse.x) }
                onReleased: () => {
                    s.dragging = false
                    s.valueCommitted(s._pending)
                }
            }
        }

        Text {
            width: s.valueW
            height: parent.height
            text: s.muted ? "muted" : (Math.round(s.displayValue * 100) + "%")
            color: s.muted ? s.mutedText : s.text
            font.pixelSize: 12
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignRight
        }
    }
}
