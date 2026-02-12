import QtQuick
import Quickshell.Services.UPower

Item {
    id: root

    height: 30
    implicitHeight: height
    implicitWidth: row.implicitWidth
    width: implicitWidth

    property string red: "#B80000"
    property string text: "#E6E6E6"
    property string muted: "#A8A8A8"

    readonly property var batteryDev: (function() {
        const dd = UPower.displayDevice
        if (dd && dd.ready && dd.type === UPowerDeviceType.Battery)
            return dd

        const m = UPower.devices
        if (!m) return null

        for (let i = 0; i < m.count; i++) {
            const d = m.get(i)
            if (d && d.isLaptopBattery)
                return d
        }
        for (let i = 0; i < m.count; i++) {
            const d = m.get(i)
            if (d && d.type === UPowerDeviceType.Battery)
                return d
        }
        return null
    })()

    readonly property bool hasBattery: batteryDev !== null

    readonly property real pct01: (hasBattery && batteryDev.percentage !== undefined)
        ? batteryDev.percentage
        : 0.0

    readonly property int pct: Math.max(0, Math.min(100, Math.round(pct01 * 100)))

    readonly property int devState: (hasBattery && batteryDev.state !== undefined)
        ? batteryDev.state
        : UPowerDeviceState.Unknown

    readonly property bool charging:
        devState === UPowerDeviceState.Charging ||
        devState === UPowerDeviceState.PendingCharge

    function batteryIcon(p) {
        if (p >= 90) return "󰁹"
        if (p >= 80) return "󰂂"
        if (p >= 70) return "󰂁"
        if (p >= 60) return "󰂀"
        if (p >= 50) return "󰁿"
        if (p >= 40) return "󰁾"
        if (p >= 30) return "󰁽"
        if (p >= 20) return "󰁼"
        if (p >= 10) return "󰁻"
        if (p >= 5)  return "󰁺"
        return "󰁹"
    }

    Row {
        id: row
        spacing: 8
        height: root.height
        anchors.verticalCenter: parent.verticalCenter

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.hasBattery ? root.batteryIcon(root.pct) : "󰚥"
            color: root.charging ? root.red : root.text
            font.pixelSize: 18
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.hasBattery ? (String(root.pct) + "%") : "AC"
            color: root.charging ? root.red : root.text
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
        }
    }
}
