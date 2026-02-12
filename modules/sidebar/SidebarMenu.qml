import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs

import "suites"
import qs.modules.launcher

Item {
    id: root
    required property QtObject config
    required property QtObject sidebarState

    required property var screen

    readonly property int pad: (config && config.appearance && config.appearance.pad !== undefined)
        ? config.appearance.pad
        : 12

    

    readonly property int outsidePadLeft:  5
    readonly property int insidePadLeft:   14

    readonly property int outsidePadRight: 5
    readonly property int insidePadRight:  14

    readonly property string screenName: (root.screen && root.screen.name) ? root.screen.name : ""

    readonly property string edgeRaw: (root.config && root.config.sidebar)
        ? (root.config.sidebar.edgeForScreen
            ? root.config.sidebar.edgeForScreen(root.screenName)
            : (root.config.sidebar.edge ?? "right"))
        : "right"

    readonly property string edge: String(edgeRaw).trim().toLowerCase()

    readonly property bool isRightEdge: (root.edge === "right")
    readonly property bool isLeftEdge:  (root.edge === "left")

    readonly property int outsidePad: root.isRightEdge ? root.outsidePadRight : root.outsidePadLeft
    readonly property int insidePad:  root.isRightEdge ? root.insidePadRight  : root.insidePadLeft

    readonly property int leftPad:  root.isRightEdge ? root.insidePad  : root.outsidePad
    readonly property int rightPad: root.isRightEdge ? root.outsidePad : root.insidePad

    FileDialog {
        id: wallpaperDialog
        title: "Select a wallpaper"
        nameFilters: [
            "Images (*.png *.jpg *.jpeg *.webp *.bmp *.gif)",
            "All files (*)"
        ]

        onAccepted: {
            const u = selectedFile.toString()
            const path = u.startsWith("file://") ? decodeURIComponent(u.slice(7)) : u
            if (root.config && root.config.wallpapers && root.config.wallpapers.setWallpaper)
                root.config.wallpapers.setWallpaper(path)
        }
    }

    AppLauncher {
        id: launcher
        visible: false

        screen: root.screen

        bg: (root.config && root.config.appearance && root.config.appearance.bg)
            ? root.config.appearance.bg : "#121212"
        bg2: (root.config && root.config.appearance && root.config.appearance.bg2)
            ? root.config.appearance.bg2 : "#1A1A1A"
        red: (root.config && root.config.appearance && root.config.appearance.accent)
            ? root.config.appearance.accent : "#B80000"
        text: (root.config && root.config.appearance && (root.config.appearance.fg ?? root.config.appearance.text))
            ? (root.config.appearance.fg ?? root.config.appearance.text) : "#E6E6E6"
        borderColor: (root.config && root.config.appearance && (root.config.appearance.borderColor ?? root.config.appearance.border))
            ? (root.config.appearance.borderColor ?? root.config.appearance.border) : "#2A2A2A"
    }

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true

        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: true

        contentX: 0

        contentWidth: width
        contentHeight: col.implicitHeight + (root.pad * 2)

        Column {
            id: col

            y: root.pad

            x: root.leftPad
            width: Math.max(0, flick.width - (root.leftPad + root.rightPad))

            spacing: 10

            Buttons {
                width: col.width
                config: root.config
                onRequestWallpaper: wallpaperDialog.open()
                onRequestAppLauncher: launcher.visible = !launcher.visible
            }

            VisualSuite    { width: col.width; config: root.config; sidebarState: root.sidebarState }
            VolumeSuite    { width: col.width; config: root.config; sidebarState: root.sidebarState }
            BluetoothSuite { width: col.width; config: root.config; sidebarState: root.sidebarState }
            NetworkSuite   { width: col.width; config: root.config; sidebarState: root.sidebarState }
            VPNSuite       { width: col.width; config: root.config; sidebarState: root.sidebarState }
            DGPUSuite      { width: col.width; config: root.config; sidebarState: root.sidebarState }
            PowerSuite     { width: col.width; config: root.config; sidebarState: root.sidebarState }
        }
    }
}
