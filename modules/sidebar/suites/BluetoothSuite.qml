import QtQuick
import Quickshell.Io

FocusScope {
    id: root

    required property QtObject config
    property QtObject sidebarState: null

    readonly property var app: (config && config.appearance) ? config.appearance : null
    property color bg:          (app && app.bg          !== undefined && app.bg          !== null) ? app.bg          : "#121212"
    property color bg2:         (app && app.bg2         !== undefined && app.bg2         !== null) ? app.bg2         : "#1A1A1A"
    property color red:         (app && app.accent      !== undefined && app.accent      !== null) ? app.accent      : "#B80000"
    property color text:        (app && app.fg          !== undefined && app.fg          !== null) ? app.fg          : "#E6E6E6"
    property color muted:       (app && app.muted       !== undefined && app.muted       !== null) ? app.muted       : "#A8A8A8"
    property color borderColor: (app && app.borderColor !== undefined && app.borderColor !== null) ? app.borderColor : "#2A2A2A"
    property int pad: 10
    property int radius: 12

    readonly property string btctlPath: "$HOME/.config/quickshell/MazyShell/scripts/bluetoothctl.sh"

    property bool powered: false

    property bool scanning: false
    property bool discoveredExpanded: true
    property int scanTickIntervalMs: 900

    property bool actionRunning: false
    property string lastError: ""

    property string _actionKind: ""
    property string _actionMac: ""

    property var _foundMap: ({})

    ListModel { id: pairedModel }
    ListModel { id: foundModel }

    implicitWidth: 220
    implicitHeight: box.implicitHeight

    function keepPanelHovered() {
        if (sidebarState && sidebarState.enterSidebar) sidebarState.enterSidebar()
    }
    function releasePanelHover() { }

    function shQuote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    Timer {
        id: refreshTimer
        interval: 120
        repeat: false
        onTriggered: root.refresh()
    }
    function refreshSoon() { refreshTimer.restart() }

    property int scanTicksLeft: 0
    Timer {
        id: scanTick
        interval: root.scanTickIntervalMs
        repeat: true
        running: false
        onTriggered: {
            if (!root.scanning) { stop(); return }
            root.refresh()
            root.scanTicksLeft--
            if (root.scanTicksLeft <= 0) stop()
        }
    }

    function modelIndexByMac(model, mac) {
        for (var i = 0; i < model.count; i++) {
            if (model.get(i).mac === mac) return i
        }
        return -1
    }

    function upsertPaired(mac, connected, name) {
        if (!mac.length) return
        var n = (name && name.length) ? name : mac
        var idx = modelIndexByMac(pairedModel, mac)
        if (idx < 0) pairedModel.append({ mac: mac, connected: connected, name: n })
        else {
            pairedModel.setProperty(idx, "connected", connected)
            pairedModel.setProperty(idx, "name", n)
        }
    }

    function setFoundMap(mapObj) {
        root._foundMap = mapObj || ({})
        var seen = {}
        var keys = Object.keys(root._foundMap)

        keys.sort(function(a, b) {
            var na = (root._foundMap[a] || "").toLowerCase()
            var nb = (root._foundMap[b] || "").toLowerCase()
            if (na < nb) return -1
            if (na > nb) return 1
            return a < b ? -1 : (a > b ? 1 : 0)
        })

        for (var i = 0; i < keys.length; i++) {
            var mac = keys[i]
            var name = root._foundMap[mac]
            seen[mac] = true

            var idx = modelIndexByMac(foundModel, mac)
            if (idx < 0) foundModel.append({ mac: mac, name: name })
            else foundModel.setProperty(idx, "name", name)
        }

        for (var j = foundModel.count - 1; j >= 0; j--) {
            var m = foundModel.get(j).mac
            if (!seen[m]) foundModel.remove(j)
        }
    }

    function clearDiscovered() {
        root._foundMap = ({})
        foundModel.clear()
    }

    function formatBtError(outText, ec) {
        var msg = (outText || "").trim()
        msg = msg.replace(/\n?__EC:\d+\s*$/m, "").trim()
        if (!msg.length) return "Bluetooth command failed (exit " + String(ec) + ")."
        var lines = msg.split("\n").map(function(l){ return (l || "").trim() })
            .filter(function(l){ return l.length > 0 })
        return lines.length ? lines[lines.length - 1] : msg
    }

    Process { id: cleanupProc }
    function runCleanup(cmd) {
        cleanupProc.command = ["sh", "-lc", cmd + " >/dev/null 2>&1 || true" ]
        cleanupProc.exec(cleanupProc.command)
    }

    function runAction(kind, shellCmd, mac) {
        if (root.actionRunning) return
        root.lastError = ""
        root.actionRunning = true
        root._actionKind = kind
        root._actionMac = mac ? mac : ""

        actionProc.command = ["sh", "-lc",
            "out=$( { " + shellCmd + "; } 2>&1 ); ec=$?; " +
            "printf '%s\\n__EC:%s\\n' \"$out\" \"$ec\"; " +
            "exit 0"
        ]
        actionProc.exec(actionProc.command)
    }

    Process { id: scanProc }

    function refresh() {
        if (root.actionRunning) return
        statusProc.exec(statusProc.command)
    }

    function setPower(on) {
        if (root.actionRunning) return

        root.powered = on
        root.lastError = ""

        if (!on) {
            root.scanning = false
            scanTick.stop()
            runCleanup("bluetoothctl scan off")
            clearDiscovered()
        }

        runAction("power", root.btctlPath + " power " + (on ? "on" : "off"), "")
        refreshSoon()
    }

    function setScan(on) {
        if (!root.powered || root.actionRunning) return

        root.scanning = on
        root.discoveredExpanded = true
        root.lastError = ""

        if (on) {
            scanProc.command = ["sh", "-lc", root.btctlPath + " scan on >/dev/null 2>&1 || true"]
            scanProc.exec(scanProc.command)

            root.scanTicksLeft = 999999
            scanTick.start()
            refreshSoon()
        } else {
            scanTick.stop()
            clearDiscovered()
            runAction("scanOff", root.btctlPath + " scan off", "")
            refreshSoon()
        }
    }

    function toggleScan() { setScan(!root.scanning) }

    function connectOrDisconnect(mac, isConnected) {
        if (!root.powered || root.actionRunning) return

        var idx = modelIndexByMac(pairedModel, mac)
        if (idx >= 0) pairedModel.setProperty(idx, "connected", !isConnected)

        runAction(
            "connect",
            root.btctlPath + " " + (isConnected ? "disconnect " : "connect ") + shQuote(mac),
            mac
        )
        refreshSoon()
    }

    function pairAndConnect(mac) {
        if (!root.powered || root.actionRunning) return
        runAction("pairConnect", root.btctlPath + " pair-connect " + shQuote(mac), mac)
        refreshSoon()
    }

    Rectangle {
        id: box
        width: parent ? parent.width : root.implicitWidth
        implicitHeight: col.implicitHeight + (root.pad * 2)
        radius: root.radius
        antialiasing: true
        color: root.bg2
        border.width: 1
        border.color: root.borderColor
        clip: true

        Column {
            id: col
            x: root.pad
            y: root.pad
            width: box.width - (root.pad * 2)
            spacing: 10

            Text { text: "Bluetooth Suite"; color: root.text; font.pixelSize: 13 }

            Text {
                width: parent.width
                text: root.lastError
                color: root.red
                font.pixelSize: 10
                wrapMode: Text.Wrap
                visible: root.lastError.length > 0
            }

            Row {
                width: parent.width
                height: 30
                spacing: 10

                readonly property int powerW: Math.floor((width - spacing) * 0.44)
                readonly property int scanW:  (width - spacing) - powerW

                Rectangle {
                    id: powerBtn
                    height: parent.height
                    width: parent.powerW
                    radius: 10
                    color: root.bg
                    border.width: 1
                    border.color: root.borderColor
                    property bool hovered: false
                    opacity: root.actionRunning ? 0.7 : 1.0

                    Row {
                        anchors.centerIn: parent
                        height: parent.height
                        spacing: 8
                        Text { height: parent.height; text: root.powered ? "󰂯" : "󰂲"; color: powerBtn.hovered ? root.red : (root.powered ? root.text : root.muted); font.pixelSize: 16; verticalAlignment: Text.AlignVCenter }
                        Text { height: parent.height; text: root.powered ? "On" : "Off"; color: powerBtn.hovered ? root.red : (root.powered ? root.text : root.muted); font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: (!root.actionRunning) ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: !root.actionRunning
                        propagateComposedEvents: true
                        onEntered: { powerBtn.hovered = true; root.keepPanelHovered() }
                        onExited:  { powerBtn.hovered = false; root.releasePanelHover() }
                        onClicked: root.setPower(!root.powered)
                    }
                }

                Rectangle {
                    id: scanBtn
                    height: parent.height
                    width: parent.scanW
                    radius: 10
                    color: root.bg
                    border.width: 1
                    border.color: root.borderColor
                    opacity: (root.powered && !root.actionRunning) ? 1.0 : 0.6
                    property bool hovered: false

                    Row {
                        anchors.centerIn: parent
                        height: parent.height
                        spacing: 8
                        Text { height: parent.height; text: root.scanning ? "󰑐" : "󰍉"; color: scanBtn.hovered ? root.red : (root.powered ? root.text : root.muted); font.pixelSize: 16; verticalAlignment: Text.AlignVCenter }
                        Text {
                            height: parent.height
                            text: root.scanning ? "Scan On" : "Scan Off"
                            color: scanBtn.hovered ? root.red : (root.powered ? root.text : root.muted)
                            font.pixelSize: 12
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: (root.powered && !root.actionRunning) ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: root.powered && !root.actionRunning
                        propagateComposedEvents: true
                        onEntered: { scanBtn.hovered = true; root.keepPanelHovered() }
                        onExited:  { scanBtn.hovered = false; root.releasePanelHover() }
                        onClicked: root.toggleScan()
                    }
                }
            }

            Item {
                width: parent.width
                height: (pairedModel.count > 0) ? (pairedHeader.implicitHeight + pairedBox.height + 10) : 0
                visible: pairedModel.count > 0

                Column {
                    anchors.fill: parent
                    spacing: 6

                    Text { id: pairedHeader; text: "Paired"; color: root.muted; font.pixelSize: 11 }

                    Rectangle {
                        id: pairedBox
                        width: parent.width
                        height: Math.min(160, pairedCol.implicitHeight + 8)
                        radius: 10
                        color: root.bg
                        border.width: 1
                        border.color: root.borderColor
                        clip: true

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 4
                            contentWidth: width
                            contentHeight: pairedCol.implicitHeight
                            clip: true

                            Column {
                                id: pairedCol
                                width: parent.width
                                spacing: 2

                                Repeater {
                                    model: pairedModel
                                    delegate: Rectangle {
                                        width: parent.width
                                        height: 30
                                        radius: 8
                                        color: hovered ? root.bg2 : "transparent"
                                        property bool hovered: false

                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 10

                                            Text { width: 16; height: parent.height; text: model.connected ? "󰂱" : "󰂳"; color: model.connected ? root.red : root.muted; font.pixelSize: 16; verticalAlignment: Text.AlignVCenter }
                                            Text { height: parent.height; text: model.name; color: root.text; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight; width: parent.width - 90 }
                                            Text { height: parent.height; text: model.connected ? "Disconnect" : "Connect"; color: (root.powered && !root.actionRunning) ? (model.connected ? root.muted : root.text) : root.muted; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: (root.powered && !root.actionRunning) ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            enabled: root.powered && !root.actionRunning
                                            propagateComposedEvents: true
                                            onEntered: { parent.hovered = true; root.keepPanelHovered() }
                                            onExited:  { parent.hovered = false; root.releasePanelHover() }
                                            onClicked: root.connectOrDisconnect(model.mac, model.connected)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: discoveredShell
                width: parent.width
                radius: 10
                color: root.bg
                border.width: 1
                border.color: root.borderColor
                clip: true
                opacity: root.powered ? 1.0 : 0.6

                readonly property int headerH: 30
                readonly property int listH: foundCol.implicitHeight + 8

                height: root.discoveredExpanded ? (headerH + listH) : headerH
                Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                Rectangle {
                    width: parent.width
                    height: discoveredShell.headerH
                    color: "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Text { width: 16; height: parent.height; text: root.discoveredExpanded ? "󰅀" : "󰅂"; color: root.muted; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }
                        Text { height: parent.height; text: "Discovered"; color: root.muted; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter }
                        Item { width: 1; height: 1 }
                        Text { height: parent.height; text: root.scanning ? "󰑐" : ""; color: root.muted; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.powered
                        propagateComposedEvents: true
                        onEntered: root.keepPanelHovered()
                        onExited:  root.releasePanelHover()
                        onClicked: root.discoveredExpanded = !root.discoveredExpanded
                    }
                }

                Item {
                    x: 0
                    y: discoveredShell.headerH
                    width: discoveredShell.width
                    height: root.discoveredExpanded ? discoveredShell.listH : 0
                    clip: true
                    Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    Column {
                        id: foundCol
                        x: 4
                        y: 4
                        width: parent.width - 8
                        spacing: 2

                        Repeater {
                            model: foundModel
                            delegate: Rectangle {
                                width: parent.width
                                height: 30
                                radius: 8
                                color: hovered ? root.bg2 : "transparent"
                                property bool hovered: false

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Text { width: 16; height: parent.height; text: "󰂲"; color: root.muted; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }
                                    Text { height: parent.height; text: model.name; color: root.text; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight; width: parent.width - 30 }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: (root.powered && !root.actionRunning) ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    enabled: root.powered && !root.actionRunning
                                    propagateComposedEvents: true
                                    onEntered: { parent.hovered = true; root.keepPanelHovered() }
                                    onExited:  { parent.hovered = false; root.releasePanelHover() }
                                    onClicked: root.pairAndConnect(model.mac)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: actionProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var out = (this.text || "")
                var m = out.match(/__EC:(\d+)/)
                var ec = m ? parseInt(m[1], 10) : 999

                root.actionRunning = false

                if (ec === 0) {
                    root.lastError = ""
                    root.refreshSoon()
                    return
                }

                if (root._actionKind === "scanOff") {
                    root.lastError = ""
                    return
                }

                root.lastError = root.formatBtError(out, ec)

                if (root._actionKind === "connect" && root._actionMac.length) {
                    var idx = root.modelIndexByMac(pairedModel, root._actionMac)
                    if (idx >= 0) {
                        var cur = pairedModel.get(idx).connected
                        pairedModel.setProperty(idx, "connected", !cur)
                    }
                }

                root.refreshSoon()
            }
        }
    }

    Process {
        id: statusProc
        command: ["sh", "-lc", root.btctlPath + " status"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var raw = this.text
                if (!raw) return

                var newFoundLocal = []
                var seenPaired = {}

                var lines = raw.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var line = (lines[i] || "").trim()
                    if (!line.length) continue

                    var parts = line.split("|")
                    var tag = parts[0]

                    if (tag === "POWER") {
                        root.powered = (parts[1] === "yes")
                        if (!root.powered) {
                            root.scanning = false
                            scanTick.stop()
                            clearDiscovered()
                        }
                        continue
                    }

                    if (tag === "PAIRED") {
                        var macP = (parts[1] || "").trim()
                        var connP = (parts[2] === "yes")
                        var nameP = (parts.slice(3).join("|") || "").trim()
                        if (!macP.length) continue
                        seenPaired[macP] = true
                        root.upsertPaired(macP, connP, nameP)
                        continue
                    }

                    if (tag === "FOUND") {
                        var macF = (parts[1] || "").trim()
                        var nameF = (parts.slice(2).join("|") || "").trim()
                        if (!macF.length) continue
                        if (!nameF.length) nameF = macF
                        newFoundLocal.push({ mac: macF, name: nameF })
                        continue
                    }
                }

                for (var j = pairedModel.count - 1; j >= 0; j--) {
                    var mP = pairedModel.get(j).mac
                    if (!seenPaired[mP]) pairedModel.remove(j)
                }

                if (root.powered && root.scanning) {
                    var map = root._foundMap || {}
                    for (var k = 0; k < newFoundLocal.length; k++) {
                        var d = newFoundLocal[k]
                        map[d.mac] = d.name
                    }
                    root.setFoundMap(map)
                }
            }
        }
    }

    Component.onCompleted: {
        root.focus = true
        root.refresh()
    }
}
