

import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root
    required property QtObject config
    required property QtObject sidebarState

    focusable: true
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "mazyshell:sidebar"

    readonly property int ew: (config && config.sidebar && config.sidebar.edgeWidth !== undefined)
        ? config.sidebar.edgeWidth
        : 8

    readonly property string edgeSide: (config && config.sidebar && config.sidebar.edgeForScreen)
        ? config.sidebar.edgeForScreen(screen ? screen.name : "")
        : "left"

    readonly property int barH: (config && config.appearance && config.appearance.barHeight !== undefined)
        ? config.appearance.barHeight
        : 40

    anchors {
        top: true
        bottom: true
        left:  edgeSide === "left"
        right: edgeSide === "right"
    }

    margins { top: barH - 1 }

    implicitWidth: ew + (sidebarState ? sidebarState.slide : 0)

    HoverHandler {
        id: rootHH
        grabPermissions: PointerHandler.TakeOverForbidden

        onHoveredChanged: root.syncOpenState()
        onPointChanged:  root.syncOpenState()
    }

    Timer {
        id: closeDebounce
        interval: 120
        repeat: false
        onTriggered: root._closeIfStillOutside()
    }

    property bool pendingLeave: false

    function inActiveRegion(): bool {
        if (!root.sidebarState) return false
        if (!rootHH.hovered) return false

        const x = rootHH.point.position.x

        const s = Math.max(0, root.sidebarState.slide || 0)
        const total = root.ew + s

        if (root.edgeSide === "left") {

            return x >= 0 && x <= total
        } else {

            return x >= (root.width - total) && x <= root.width
        }
    }

    function syncOpenState() {
        if (!root.sidebarState) return

        if (inActiveRegion()) {
            pendingLeave = false
            closeDebounce.stop()
            root.sidebarState.enterSidebar()
            return
        }

        if (!closeDebounce.running)
            closeDebounce.start()
    }

    function _closeIfStillOutside() {
        if (!root.sidebarState) return

        if (inActiveRegion()) {
            pendingLeave = false
            return
        }

        if (root.sidebarState.slideAnim?.running) {
            pendingLeave = true
            return
        }

        pendingLeave = false
        root.sidebarState.leaveSidebar()
    }

    Connections {
        target: root.sidebarState ? root.sidebarState.slideAnim : null
        function onRunningChanged() {
            if (!root.sidebarState) return
            if (!root.sidebarState.slideAnim.running && root.pendingLeave) {
                root.pendingLeave = false
                if (!root.inActiveRegion())
                    root.sidebarState.leaveSidebar()
            }
        }
    }

    Rectangle {
        id: edgeStrip
        z: 3

        x: (root.edgeSide === "left") ? 0 : (root.width - root.ew)
        width: root.ew
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        color: root.config.appearance.bg
        opacity: root.config.appearance.opacity

        HoverHandler {
            grabPermissions: PointerHandler.TakeOverForbidden
            onHoveredChanged: {
                if (hovered && root.sidebarState)
                    root.sidebarState.enterSidebar()
            }
        }
    }

    Item {
        id: body
        z: 2
        x: (root.edgeSide === "left") ? root.ew : 0
        width: Math.max(0, root.width - root.ew)
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        clip: true

        Rectangle {
            anchors.fill: parent
            color: root.config.appearance.bg
            opacity: root.config.appearance.opacity
        }

        SidebarMenu {
            anchors.fill: parent
            config: root.config
            sidebarState: root.sidebarState
            screen: root.screen
        }
    }
}
