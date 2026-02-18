import QtQuick

QtObject {
    required property QtObject cfg  // ConfigService

    property string edge: cfg.edge
    property int edgeWidth: cfg.edgeWidth
    property int edgeCornerRadius: cfg.edgeCornerRadius
    property int sidebarWidth: cfg.sidebarWidth
    property int hoverCloseDelayMs: cfg.hoverCloseDelayMs

    property var edgeByScreen: cfg.edgeByScreen

    function edgeForScreen(screenName) {
        return cfg.edgeForScreen(screenName)
    }
}
