import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: settings

    required property QtObject config
    required property var screen

    visible: false

    implicitWidth: 820
    implicitHeight: 640

    margins {
        left: screen ? Math.round((screen.width - implicitWidth) / 2) : 0
        top:  screen ? Math.round((screen.height - implicitHeight) / 2) : 0
    }

    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"

    focusable: visible
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var app: (config && config.appearance) ? config.appearance : null
    readonly property color bg:          (app && app.bg          !== undefined && app.bg          !== null) ? app.bg          : "#121212"
    readonly property color bg2:         (app && app.bg2         !== undefined && app.bg2         !== null) ? app.bg2         : "#1A1A1A"
    readonly property color red:         (app && app.accent      !== undefined && app.accent      !== null) ? app.accent      : "#B80000"
    readonly property color text:        (app && (app.fg ?? app.text) !== undefined && (app.fg ?? app.text) !== null) ? (app.fg ?? app.text) : "#E6E6E6"
    readonly property color muted:       (app && app.muted       !== undefined && app.muted       !== null) ? app.muted       : "#A8A8A8"
    readonly property color borderColor: (app && (app.borderColor ?? app.border) !== undefined && (app.borderColor ?? app.border) !== null) ? (app.borderColor ?? app.border) : "#2A2A2A"
    readonly property int radius:        (app && app.radius !== undefined) ? app.radius : 14
    readonly property int pad:           (app && app.pad !== undefined) ? app.pad : 16

    readonly property QtObject cfg: (config && config.cfg) ? config.cfg : null

    property real contentOpacity: 0
    property real contentScale: 0.92

    Behavior on contentOpacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
    Behavior on contentScale   { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

    property int tabIndex: 0

    property int themeIndex: 0

    readonly property var darkPreset: ({
        bg: "#0B0B0B",
        bg2: "#1A1A1A",
        fg: "#E6E6E6",
        text: "#E6E6E6",
        muted: "#A8A8A8",
        accent: "#B80000",
        borderColor: "#2A2A2A",
        opacity: 1.0
    })

    readonly property var lightPreset: ({
        bg: "#F3F3F3",
        bg2: "#FFFFFF",
        fg: "#141414",
        text: "#141414",
        muted: "#5A5A5A",
        borderColor: "#D0D0D0",
        opacity: 1.0,
        accent: "#B80000"
    })

    function applyTheme(idx) {
        if (!cfg || !cfg.loaded) return
        const v = (idx === 1) ? lightPreset : darkPreset

        cfg.bg = v.bg
        cfg.bg2 = v.bg2
        cfg.fg = v.fg
        cfg.text = v.text
        cfg.muted = v.muted
        cfg.borderColor = v.borderColor
        cfg.opacity = v.opacity
        cfg.accent = v.accent
    }

    signal requestClose()

    function open()  { settings.visible = true }
    function close() { settings.visible = false }
    function toggle(){ settings.visible = !settings.visible }

    onVisibleChanged: {
        if (visible) {
            contentOpacity = 1
            contentScale = 1.0
            Qt.callLater(function() { firstFocus.forceActiveFocus() })
        } else {
            contentOpacity = 0
            contentScale = 0.92
        }
    }

    Shortcut {
        enabled: settings.visible
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: settings.close()
    }

    Item {
        anchors.fill: parent
        opacity: settings.contentOpacity
        scale: settings.contentScale
        transformOrigin: Item.Center

        MouseArea {
            anchors.fill: parent
            onClicked: settings.close()
        }

        Item {
            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                radius: settings.radius
                antialiasing: true
                color: settings.bg
                opacity: 0.96
                border.color: settings.red
                border.width: 1
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                propagateComposedEvents: false
                onClicked: (m) => m.accepted = true
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: settings.pad
                spacing: 14

                Rectangle {
                    Layout.fillWidth: true
                    height: 52
                    radius: 12
                    color: settings.bg2
                    border.width: 1
                    border.color: settings.borderColor

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        Text {
                            text: "Settings"
                            color: settings.text
                            font.pixelSize: 16
                            font.weight: 700
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Button {
                            text: "Restore Defaults"
                            enabled: !!settings.cfg
                            onClicked: if (settings.cfg) settings.cfg.restoreDefaults()
                        }

                        Button {
                            text: "Close"
                            onClicked: settings.close()
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 180
                        Layout.fillHeight: true
                        radius: 12
                        color: settings.bg2
                        border.width: 1
                        border.color: settings.borderColor

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            component TabButton: Rectangle {
                                width: parent.width
                                height: 44
                                radius: 10
                                color: active ? Qt.rgba(1,1,1,0.06) : "transparent"
                                border.width: 1
                                border.color: active ? settings.red : settings.borderColor

                                property bool active: false
                                property string label: ""
                                property string icon: ""
                                property int indexToSelect: 0

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10

                                    Text {
                                        width: 20
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: icon
                                        color: active ? settings.red : settings.muted
                                        font.pixelSize: 18
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: label
                                        color: active ? settings.text : settings.muted
                                        font.pixelSize: 13
                                        font.weight: active ? 650 : 500
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: settings.tabIndex = indexToSelect
                                }
                            }

                            TabButton { label: "Appearance"; icon: "󰏘"; active: settings.tabIndex === 0; indexToSelect: 0 }
                            TabButton { label: "Sidebar";    icon: "󰙀"; active: settings.tabIndex === 1; indexToSelect: 1 }
                            TabButton { label: "Modules";    icon: "󰜬"; active: settings.tabIndex === 2; indexToSelect: 2 }

                            Item { height: 8; width: 1 }

                            Text {
                                text: settings.cfg
                                    ? (settings.cfg.loaded ? "Saved automatically" : "Loading config…")
                                    : "ConfigService not found"
                                color: settings.muted
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 12
                        color: settings.bg2
                        border.width: 1
                        border.color: settings.borderColor
                        clip: true

                        StackLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            currentIndex: settings.tabIndex

                            Item {
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 12

                                    Text { text: "Appearance"; color: settings.text; font.pixelSize: 14; font.weight: 650 }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 2
                                        columnSpacing: 10
                                        rowSpacing: 10

                                        Text { text: "Theme"; color: settings.muted}
                                        ComboBox {
                                            Layout.fillWidth: true
                                            model: ["Dark", "Light"]
                                            currentIndex: settings.themeIndex
                                            onActivated: (i) => { 
                                                settings.themeIndex = i
                                                if (!!settings.cfg && settings.cfg.loaded === true)
                                                settings.applyTheme(i)
                                            }
                                        }

                                        Text { text: "Accent"; color: settings.muted }
                                        TextField {
                                            id: firstFocus
                                            Layout.fillWidth: true
                                            text: settings.cfg ? String(settings.cfg.accent) : ""
                                            placeholderText: "#B80000"
                                            onEditingFinished: if (settings.cfg && settings.cfg.loaded) settings.cfg.accent = text
                                        }

                                        Text { text: "BG"; color: settings.muted }
                                        TextField {
                                            Layout.fillWidth: true
                                            text: settings.cfg ? String(settings.cfg.bg) : ""
                                            placeholderText: "#0B0B0B"
                                            onEditingFinished: if (settings.cfg && settings.cfg.loaded) settings.cfg.bg = text
                                        }

                                        Text { text: "BG2"; color: settings.muted }
                                        TextField {
                                            Layout.fillWidth: true
                                            text: settings.cfg ? String(settings.cfg.bg2) : ""
                                            placeholderText: "#1A1A1A"
                                            onEditingFinished: if (settings.cfg && settings.cfg.loaded) settings.cfg.bg2 = text
                                        }

                                        Text { text: "Text"; color: settings.muted }
                                        TextField {
                                            Layout.fillWidth: true
                                            text: settings.cfg ? String(settings.cfg.text) : ""
                                            placeholderText: "#E6E6E6"
                                            onEditingFinished: if (settings.cfg && settings.cfg.loaded) settings.cfg.text = text
                                        }

                                        Text { text: "Muted"; color: settings.muted }
                                        TextField {
                                            Layout.fillWidth: true
                                            text: settings.cfg ? String(settings.cfg.muted) : ""
                                            placeholderText: "#A8A8A8"
                                            onEditingFinished: if (settings.cfg && settings.cfg.loaded) settings.cfg.muted = text
                                        }

                                        Text { text: "Border"; color: settings.muted }
                                        TextField {
                                            Layout.fillWidth: true
                                            text: settings.cfg ? String(settings.cfg.borderColor) : ""
                                            placeholderText: "#2A2A2A"
                                            onEditingFinished: if (settings.cfg && settings.cfg.loaded) settings.cfg.borderColor = text
                                        }

                                        Text { text: "Anim (ms)"; color: settings.muted }
                                        SpinBox {
                                            Layout.fillWidth: true
                                            from: 0; to: 2000
                                            value: settings.cfg ? settings.cfg.animMs : 150
                                            enabled: !!settings.cfg && settings.cfg.loaded === true
                                            onValueModified: if (settings.cfg && settings.cfg.loaded) settings.cfg.animMs = value
                                        }

                                        Text { text: "Radius"; color: settings.muted }
                                        SpinBox {
                                            Layout.fillWidth: true
                                            from: 0; to: 40
                                            value: settings.cfg ? settings.cfg.radius : settings.radius
                                            enabled: !!settings.cfg && settings.cfg.loaded === true
                                            onValueModified: if (settings.cfg && settings.cfg.loaded) settings.cfg.radius = value
                                        }

                                        Text { text: "Padding"; color: settings.muted }
                                        SpinBox {
                                            Layout.fillWidth: true
                                            from: 0; to: 64
                                            value: settings.cfg ? settings.cfg.pad : settings.pad
                                            enabled: !!settings.cfg && settings.cfg.loaded === true
                                            onValueModified: if (settings.cfg && settings.cfg.loaded) settings.cfg.pad = value
                                        }
                                    }

                                    Item { Layout.fillHeight: true }
                                }
                            }

                            Item {
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 12

                                    Text { text: "Sidebar"; color: settings.text; font.pixelSize: 14; font.weight: 650 }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 2
                                        columnSpacing: 10
                                        rowSpacing: 10

                                        Text { text: "Edge"; color: settings.muted }
                                        ComboBox {
                                            Layout.fillWidth: true
                                            model: ["left", "right"]
                                            currentIndex: (settings.cfg && settings.cfg.edge === "right") ? 1 : 0
                                            enabled: !!settings.cfg && settings.cfg.loaded === true
                                            onActivated: (i) => { if (settings.cfg && settings.cfg.loaded) settings.cfg.edge = (i === 1 ? "right" : "left") }
                                        }

                                        Text { text: "Sidebar width"; color: settings.muted }
                                        TextField {
                                            Layout.fillWidth: true
                                            text: settings.cfg ? String(settings.cfg.sidebarWidth) : ""
                                            placeholderText: "300"
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            validator: IntValidator { bottom: 200; top: 900 }
                                            enabled: !!settings.cfg && settings.cfg.loaded === true
                                            onEditingFinished: {
                                                if (!settings.cfg || !settings.cfg.loaded) return
                                                const v = parseInt(text, 10)
                                                if (!isNaN(v)) settings.cfg.sidebarWidth = v
                                                text = String(settings.cfg.sidebarWidth)
                                            }
                                        }

                                        Text { text: "Hover close (ms)"; color: settings.muted }
                                        SpinBox {
                                            Layout.fillWidth: true
                                            from: 0; to: 2000
                                            value: settings.cfg ? settings.cfg.hoverCloseDelayMs : 300
                                            enabled: !!settings.cfg && settings.cfg.loaded === true
                                            onValueModified: if (settings.cfg && settings.cfg.loaded) settings.cfg.hoverCloseDelayMs = value
                                        }

                                        Text { text: "Edge width"; color: settings.muted }
                                        SpinBox {
                                            Layout.fillWidth: true
                                            from: 1; to: 32
                                            value: settings.cfg ? settings.cfg.edgeWidth : 8
                                            enabled: !!settings.cfg && settings.cfg.loaded === true
                                            onValueModified: if (settings.cfg && settings.cfg.loaded) settings.cfg.edgeWidth = value
                                        }

                                        Text { text: "Edge corner"; color: settings.muted }
                                        SpinBox {
                                            Layout.fillWidth: true
                                            from: 0; to: 60
                                            value: settings.cfg ? settings.cfg.edgeCornerRadius : 20
                                            enabled: !!settings.cfg && settings.cfg.loaded === true
                                            onValueModified: if (settings.cfg && settings.cfg.loaded) settings.cfg.edgeCornerRadius = value
                                        }
                                    }

                                    Item { Layout.fillHeight: true }
                                }
                            }

                            Item {
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 12

                                    Text { text: "Modules"; color: settings.text; font.pixelSize: 14; font.weight: 650 }
                                    Text { text: "Bar → Right side"; color: settings.muted; font.pixelSize: 11 }

                                    Flickable {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true
                                        contentWidth: width
                                        contentHeight: modCol.implicitHeight

                                        Column {
                                            id: modCol
                                            width: parent.width
                                            spacing: 8

                                            Repeater {
                                                model: (settings.cfg && settings.cfg.rightModules) ? settings.cfg.rightModules : []
                                                delegate: Rectangle {
                                                    width: parent.width
                                                    height: 44
                                                    radius: 10
                                                    color: Qt.rgba(1,1,1,0.03)
                                                    border.width: 1
                                                    border.color: settings.borderColor

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.margins: 10
                                                        spacing: 10

                                                        Text {
                                                            text: modelData.key
                                                            color: settings.text
                                                            Layout.fillWidth: true
                                                            elide: Text.ElideRight
                                                        }

                                                        Switch {
                                                            checked: !!modelData.enabled
                                                            enabled: !!settings.cfg && settings.cfg.loaded === true
                                                            onToggled: if (settings.cfg && settings.cfg.loaded) settings.cfg.setBarEnabled("right", modelData.key, checked)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
