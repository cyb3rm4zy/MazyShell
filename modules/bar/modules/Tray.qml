

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import QtQuick.Controls

Item {
    id: root

    height: 30
    implicitWidth: trayRepeater.count > 0 ? (trayRepeater.count * 22 + (trayRepeater.count - 1) * 6) : 0
    width: implicitWidth

    property string red: "#B80000"
    property string bg: "#121212"
    property string bg2: "#1A1A1A"
    property string text: "#E6E6E6"
    property string muted: "#A8A8A8"
    property string borderColor: "#2A2A2A"

    property int platformMenuEstimatedWidth: 220

    property var screenRef: null
    property var barPanel: null
    property var barPill: null

    property var contextMenuData: null
    property bool contextMenuVisible: false

    property bool isDarkMode: false

    function updateIsDarkMode() {
        const bgValue = bg || ""
        const bgLower = bgValue.toString().toLowerCase().trim()

        let isDark = false
        if (bgLower.startsWith("#") && bgLower.length >= 7) {
            const r = parseInt(bgLower.substring(1, 3), 16)
            const g = parseInt(bgLower.substring(3, 5), 16)
            const b = parseInt(bgLower.substring(5, 7), 16)
            const brightness = (r + g + b) / 3
            isDark = brightness < 128
        } else {
            isDark = bgLower === "#0b0b0b" || bgLower === "#0b0b0bff"
        }

        if (isDarkMode !== isDark) {
            isDarkMode = isDark
        }
    }

    readonly property string lightBg: "#F5F5F5"
    readonly property string lightBg2: "#E8E8E8"
    readonly property string lightText: "#1A1A1A"
    readonly property string lightMuted: "#666666"
    readonly property string lightBorderColor: "#CCCCCC"

    property string menuBg: isDarkMode ? (bg || "#121212") : lightBg
    property string menuBg2: isDarkMode ? (bg2 || "#1A1A1A") : lightBg2
    property string menuText: isDarkMode ? (text || "#E6E6E6") : lightText
    property string menuMuted: isDarkMode ? (muted || "#A8A8A8") : lightMuted
    property string menuBorderColor: isDarkMode ? (borderColor || "#2A2A2A") : lightBorderColor

    onBgChanged: updateIsDarkMode()
    Component.onCompleted: updateIsDarkMode()

    function _getDefaultScreen() {
        return root.screenRef || (Quickshell.screens && Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
    }

    function _panelOrigin(panel) {
        let px = 0
        let py = 0

        if (!panel) return { x: 0, y: 0 }

        if (panel.x !== undefined) px = panel.x
        else if (panel.margins && panel.margins.left !== undefined) px = panel.margins.left

        if (panel.y !== undefined) py = panel.y
        else if (panel.margins && panel.margins.top !== undefined) py = panel.margins.top

        return { x: px, y: py }
    }

    function _itemGlobalPoint(item, anchor) {
        const panel = root.barPanel
        const screen = (panel && panel.screen) ? panel.screen : _getDefaultScreen()

        if (panel && panel.screen) {
            const content = panel.contentItem || panel
            const p = item.mapToItem(content, 0, 0)
            const o = _panelOrigin(panel)

            if (anchor === "top-left") {
                return { x: o.x + p.x, y: o.y + p.y, screen: screen }
            }

            return {
                x: o.x + p.x + (item.width / 2),
                y: o.y + p.y + item.height,
                screen: screen
            }
        }

        const p2 = item.mapToItem(root, 0, 0)
        if (anchor === "top-left") {
            return { x: p2.x, y: p2.y, screen: screen }
        }
        return { x: p2.x + (item.width / 2), y: p2.y + item.height, screen: screen }
    }

    PanelWindow {
        id: platformMenuWindow
        visible: false
        screen: root._getDefaultScreen()

        anchors { top: true; left: true }
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        color: "transparent"
        focusable: false

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        implicitWidth: 1
        implicitHeight: 1
    }

    Row {
        id: trayRow
        spacing: 6
        height: root.height
        width: parent.width
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left

        Repeater {
            id: trayRepeater
            model: SystemTray.items

            Rectangle {
                id: trayIcon
                width: 22
                height: 22
                radius: 4
                color: hovered ? root.bg2 : Qt.rgba(0, 0, 0, 0.3)
                border.width: hovered ? 1 : 0
                border.color: root.red
                anchors.verticalCenter: parent.verticalCenter

                property bool hovered: false
                property var trayItem: modelData

                Item {
                    anchors.fill: parent
                    anchors.margins: 2

                    Image {
                        id: trayIconImage
                        anchors.fill: parent
                        source: {
                            if (!trayItem) return ""
                            try { return trayItem.icon || "" } catch (e) { return "" }
                        }
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        visible: trayItem && trayItem.icon && (status === Image.Ready || status === undefined)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (trayItem) {
                                if (trayItem.title) return trayItem.title.charAt(0).toUpperCase()
                                if (trayItem.tooltip) return trayItem.tooltip.charAt(0).toUpperCase()
                            }
                            return "?"
                        }
                        color: root.text
                        font.pixelSize: 10
                        font.bold: true
                        visible: !trayIconImage.visible
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onEntered: trayIcon.hovered = true
                    onExited: trayIcon.hovered = false

                    onClicked: function(mouse) {
                        if (!trayItem) return

                        if (mouse.button === Qt.RightButton) {

                            if (trayItem.hasMenu && trayItem.menu) {

                                const pt = root._itemGlobalPoint(trayIcon, "center-bottom")
                                const targetScreen = pt.screen

                                let screenX = pt.x - (root.platformMenuEstimatedWidth / 2)
                                let screenY = pt.y + 6

                                if (targetScreen && targetScreen.width !== undefined) {
                                    const sw = targetScreen.width
                                    const mw = root.platformMenuEstimatedWidth
                                    if (screenX + mw > sw) screenX = sw - mw
                                    if (screenX < 0) screenX = 0
                                }

                                platformMenuWindow.screen = targetScreen
                                platformMenuWindow.visible = true

                                Qt.callLater(function() {
                                    trayItem.display(platformMenuWindow, screenX, screenY)
                                })
                            } else {

                                showContextMenu(index)
                            }
                            return
                        }

                        if (mouse.button === Qt.MiddleButton) {

                            if (trayItem.activateSecondary) {
                                const pt2 = root._itemGlobalPoint(trayIcon, "top-left")
                                trayItem.activateSecondary(pt2.x, pt2.y)
                            }
                            return
                        }

                        if (!trayItem.onlyMenu && trayItem.activate) {
                            trayItem.activate()
                        }
                    }
                }
            }
        }
    }

    function showContextMenu(index) {
        if (!SystemTray.items || index < 0 || index >= SystemTray.items.count) return

        const item = SystemTray.items.get(index)
        if (!item) return

        const iconItem = trayRepeater.itemAt(index)
        if (!iconItem) return

        let screenX = 0
        let screenY = 0
        let barScreen = null

        const pt = _itemGlobalPoint(iconItem, "center-bottom")
        barScreen = pt.screen

        const menuWidth = 180
        const screenWidth = barScreen ? barScreen.width : (root.width || 0)

        let menuX = pt.x - (menuWidth / 2)

        if (screenWidth > 0) {
            if (menuX + menuWidth > screenWidth) menuX = screenWidth - menuWidth
            if (menuX < 0) menuX = 0
        }

        screenX = menuX
        screenY = pt.y + 6

        const itemTitle = item.title || item.tooltip || "Tray Item"
        const itemId = item.id || ""

        root.contextMenuData = {
            name: itemTitle,
            item: item,
            itemId: itemId,
            screenX: screenX,
            screenY: screenY,
            barScreen: barScreen,
            isStatusNotifier: true
        }
        root.contextMenuVisible = true
    }

    PanelWindow {
        id: contextMenuWindow
        visible: root.contextMenuVisible && root.contextMenuData !== null
        screen: root.contextMenuData && root.contextMenuData.barScreen
                ? root.contextMenuData.barScreen
                : (root.screenRef || Quickshell.screens[0])

        anchors { top: true; left: true }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        focusable: visible

        margins {
            left: root.contextMenuData ? root.contextMenuData.screenX : 0
            top: root.contextMenuData ? root.contextMenuData.screenY : 0
            right: 0
            bottom: 0
        }

        implicitWidth: Math.max(160, Math.max(
            nameText.implicitWidth + 24,
            Math.max(openText.implicitWidth, Math.max(killText.implicitWidth, cancelText.implicitWidth)) + 24
        ))
        implicitHeight: contextMenuColumn.implicitHeight + 12

        Shortcut {
            enabled: contextMenuWindow.visible
            sequence: "Escape"
            context: Qt.ApplicationShortcut
            onActivated: root.contextMenuVisible = false
        }

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: root.menuBg
            border.width: 1
            border.color: root.menuBorderColor
            opacity: 0.98

            Column {
                id: contextMenuColumn
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4

                Text {
                    id: nameText
                    width: parent.width
                    text: root.contextMenuData ? (root.contextMenuData.name || "Tray Item") : ""
                    color: root.menuText
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                    bottomPadding: 4
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: root.menuBorderColor
                }

                Rectangle {
                    id: openButton
                    width: parent.width
                    height: 32
                    radius: 4
                    color: openMouse.hovered ? root.menuBg2 : "transparent"

                    Text {
                        id: openText
                        anchors.centerIn: parent
                        text: "Activate"
                        color: root.menuText
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: openMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.contextMenuData && root.contextMenuData.item) {
                                const it = root.contextMenuData.item
                                if (it.activate) it.activate()
                            }
                            root.contextMenuVisible = false
                        }
                    }
                }

                Rectangle {
                    id: killButton
                    width: parent.width
                    height: 32
                    radius: 4
                    color: killMouse.hovered ? root.red : "transparent"

                    Text {
                        id: killText
                        anchors.centerIn: parent
                        text: "Remove"
                        color: root.menuText
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: killMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.contextMenuVisible = false
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: root.menuBorderColor
                }

                Rectangle {
                    id: cancelButton
                    width: parent.width
                    height: 32
                    radius: 4
                    color: cancelMouse.hovered ? root.menuBg2 : "transparent"

                    Text {
                        id: cancelText
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: root.menuText
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.contextMenuVisible = false
                    }
                }
            }
        }
    }
}
