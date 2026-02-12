import Quickshell
import QtQuick
import QtQuick.Effects

PanelWindow {
    id: win
    required property QtObject config
    required property QtObject sidebarState

    readonly property int r: config.sidebar.edgeCornerRadius
    readonly property int ew: config.sidebar.edgeWidth
    readonly property string edgeSide: config.sidebar.edgeForScreen(screen ? screen.name : "")

    surfaceFormat.opaque: false
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        left:  edgeSide === "left"
        right: edgeSide === "right"
    }

    margins { top: config.appearance.barHeight }

    

    implicitWidth: ew + config.sidebar.sidebarWidth + r
    implicitHeight: r

    Item {
        width: r
        height: r

        x: (edgeSide === "left")
            ? (ew + sidebarState.slide)
            : (win.implicitWidth - r - (ew + sidebarState.slide))

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
                x: (edgeSide === "left") ? 0 : -r
                y: 0
            }
        }
    }
}
