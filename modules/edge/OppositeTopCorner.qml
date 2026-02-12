import Quickshell
import QtQuick
import QtQuick.Effects

PanelWindow {
    required property QtObject config

    readonly property int r: config.sidebar.edgeCornerRadius
    readonly property string edgeSide: config.sidebar.edgeForScreen(screen ? screen.name : "")

    surfaceFormat.opaque: false
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        left:  edgeSide === "right"
        right: edgeSide === "left"
    }

    margins { top: config.appearance.barHeight - 1 }

    implicitWidth: r
    implicitHeight: r

    Rectangle {
        anchors.fill: parent
        color: config.appearance.bg
        opacity: config.appearance.opacity

        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskInverted: true
            maskSource: quarterMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }

    Item {
        id: quarterMask
        width: r
        height: r
        clip: true
        visible: false
        layer.enabled: true

        Rectangle {
            width: 2 * r
            height: 2 * r
            radius: r
            color: "white"
            x: (edgeSide === "left") ? -r : 0
            y: 0
        }
    }
}
