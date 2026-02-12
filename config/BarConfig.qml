import QtQuick

QtObject {
    id: root

    property var leftModules: [
        { key: "os",            enabled: true },
        { key: "resourceDials", enabled: true },
        { key: "network",       enabled: true }
    ]

    property var centerModules: [
        { key: "workspaces", enabled: true }
    ]

    property var rightModules: [
        { key: "tray",      enabled: true },
        { key: "bluetooth", enabled: true },
        { key: "volume",    enabled: true },
        { key: "clock",     enabled: true }
    ]

    function setEnabled(section, k, on) {
        const prop = section + "Modules"
        const arr = root[prop] || []
        root[prop] = arr.map(e => (e.key === k ? ({ key: e.key, enabled: !!on }) : e))
    }

    function move(section, from, to) {
        const prop = section + "Modules"
        const arr = (root[prop] || []).slice()
        if (from < 0 || from >= arr.length) return
        if (to < 0) to = 0
        if (to >= arr.length) to = arr.length - 1
        if (from === to) return
        const it = arr.splice(from, 1)[0]
        arr.splice(to, 0, it)
        root[prop] = arr
    }
}
