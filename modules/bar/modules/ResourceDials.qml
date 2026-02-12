import QtQuick
import Quickshell.Io

Row {
    id: root
    spacing: 8

    property string red: "#B80000"
    property string bg2: "#1A1A1A"
    property string text: "#E6E6E6"
    property string muted: "#A8A8A8"
    property string borderColor: "#2A2A2A"

    property real cpuPct: 0
    property real gpuPct: 0
    property real ramPct: 0
    property real swapPct: 0

    property real _prevTotal: 0
    property real _prevIdle: 0
    property bool _cpuPrimed: false

    readonly property int dialSize: 24
    readonly property int dialThickness: 2
    readonly property int dialIconSize: 14

    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    Dial {
        value: root.cpuPct
        icon: ""

        ringColor: root.red
        trackColor: root.borderColor
        iconColor: root.text
        size: root.dialSize
        thickness: root.dialThickness
        iconPixelSize: root.dialIconSize
        iconXBias: 0
        iconYBias: 0
    }

    Dial {
        value: root.gpuPct
        icon: ""

        ringColor: root.red
        trackColor: root.borderColor
        iconColor: root.text
        size: root.dialSize
        thickness: root.dialThickness
        iconPixelSize: root.dialIconSize
        iconXBias: 0
        iconYBias: 0
    }

    Dial {
        value: root.ramPct
        icon: ""

        ringColor: root.red
        trackColor: root.borderColor
        iconColor: root.text
        size: root.dialSize
        thickness: root.dialThickness
        iconPixelSize: root.dialIconSize
        iconXBias: 0
        iconYBias: 0
    }

    Dial {
        value: root.swapPct
        icon: "󰯍"

        ringColor: root.red
        trackColor: root.borderColor
        iconColor: root.text
        size: root.dialSize
        thickness: root.dialThickness
        iconPixelSize: root.dialIconSize
        iconXBias: 0
        iconYBias: 0
    }

    Process {
        id: cpuProc
        command: ["sh", "-lc", "awk '/^cpu /{print $2,$3,$4,$5,$6,$7,$8,$9}' /proc/stat"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const raw = this.text.trim()
                if (!raw) return

                const parts = raw.split(/\s+/).map(Number)
                if (parts.length < 8) return
                if (parts.some(v => Number.isNaN(v))) return

                const user = parts[0]
                const nice = parts[1]
                const system = parts[2]
                const idle = parts[3]
                const iowait = parts[4]
                const irq = parts[5]
                const softirq = parts[6]
                const steal = parts[7]

                const idleAll = idle + iowait
                const nonIdle = user + nice + system + irq + softirq + steal
                const total = idleAll + nonIdle

                if (!root._cpuPrimed) {
                    root._prevTotal = total
                    root._prevIdle = idleAll
                    root._cpuPrimed = true
                    return
                }

                const totald = total - root._prevTotal
                const idled = idleAll - root._prevIdle

                root._prevTotal = total
                root._prevIdle = idleAll

                if (totald <= 0) return

                const usage = (totald - idled) / totald * 100.0
                root.cpuPct = Math.max(0, Math.min(100, usage))
            }
        }
    }

    Process {
        id: otherProc
        command: ["sh", "-c",
            "GPU=0; " +
            "for f in /sys/class/drm/card*/device/gpu_busy_percent; do " +
            "  [ -r \"$f\" ] 2>/dev/null && GPU=$(cat \"$f\" 2>/dev/null | tr -dc '0-9') && break; " +
            "done 2>/dev/null; " +
            "RAM=$(awk \"BEGIN{t=0;a=0} /^MemTotal:/{t=\\$2} /^MemAvailable:/{a=\\$2} END{if(t>0){printf(\\\"%d\\\", ((t-a)*100)/t)} else {print 0}}\" /proc/meminfo); " +
            "SWP=$(awk \"BEGIN{t=0;f=0} /^SwapTotal:/{t=\\$2} /^SwapFree:/{f=\\$2} END{if(t>0){printf(\\\"%d\\\", ((t-f)*100)/t)} else {print 0}}\" /proc/meminfo); " +
            "printf \"%s %s %s\\n\" \"${GPU:-0}\" \"${RAM:-0}\" \"${SWP:-0}\""
        ]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const raw = this.text.trim()
                if (!raw) return

                const parts = raw.split(/\s+/).map(Number)
                if (parts.length < 3) return
                if (parts.some(v => Number.isNaN(v))) return

                root.gpuPct = Math.max(0, Math.min(100, parts[0]))
                root.ramPct = Math.max(0, Math.min(100, parts[1]))
                root.swapPct = Math.max(0, Math.min(100, parts[2]))
            }
        }
    }

    Timer {
        interval: 1000

        running: true
        repeat: true
        onTriggered: {
            cpuProc.exec(cpuProc.command)
            otherProc.exec(otherProc.command)
        }
    }

    Component.onCompleted: {
        cpuProc.exec(cpuProc.command)
        otherProc.exec(otherProc.command)
    }
}

