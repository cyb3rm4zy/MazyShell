import QtQuick

QtObject {

    property string edge: "left"

    property int edgeWidth: 8

    property int edgeCornerRadius: 20

    property int sidebarWidth: 300

    property int hoverCloseDelayMs: 300

    property var edgeByScreen: ({ "DP-2": "right", "DP-3": "left"})
    function edgeForScreen(screenName) {
        const v = edgeByScreen[screenName]
        return (v === "left" || v === "right") ? v : edge
    }
}