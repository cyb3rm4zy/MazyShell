import QtQuick
import "../services" as S

QtObject {
    id: root

    // Persistent config service
    property S.ConfigService cfg: S.ConfigService {}

    // Back-compat: your code reads config.appearance.X etc
    property QtObject appearance: QtObject {
        property color bg: cfg.bg
        property color bg2: cfg.bg2
        property color fg: cfg.fg
        property color text: cfg.text
        property color muted: cfg.muted
        property color accent: cfg.accent
        property color borderColor: cfg.borderColor
        property real opacity: cfg.opacity

        property int barHeight: cfg.barHeight
        property int pad: cfg.pad
        property int fontSize: cfg.fontSize
        property int radius: cfg.radius
        property int animMs: cfg.animMs
    }

    property QtObject sidebar: QtObject {
        property string edge: cfg.edge
        property int edgeWidth: cfg.edgeWidth
        property int edgeCornerRadius: cfg.edgeCornerRadius
        property int sidebarWidth: cfg.sidebarWidth
        property int hoverCloseDelayMs: cfg.hoverCloseDelayMs
        property var edgeByScreen: cfg.edgeByScreen

        function edgeForScreen(screenName) {
            const v = edgeByScreen ? edgeByScreen[screenName] : undefined
            return (v === "left" || v === "right") ? v : edge
        }
    }

    property QtObject bar: QtObject {
        property var leftModules: cfg.leftModules
        property var centerModules: cfg.centerModules
        property var rightModules: cfg.rightModules

        function setEnabled(section, k, on) { cfg.setBarEnabled(section, k, on) }
        function setBarEnabled(section, k, on) { cfg.setBarEnabled(section, k, on) } // (if you call this name elsewhere)
    }

    // ✅ RESTORE wallpapers service so config.wallpapers.* exists again
    property S.Wallpapers wallpapers: S.Wallpapers {}
}
