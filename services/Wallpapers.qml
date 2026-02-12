import QtQuick
import QtCore

QtObject {
    id: root

    property string current: settings.wallpaperPath

    property int reloadSerial: 0

    function setWallpaper(path) {
        if (!path || path === "")
            return

        settings.wallpaperPath = path
        reloadSerial++
    }

    property Settings settings: Settings {
        category: "MazyShell"
        property string wallpaperPath: ""
    }
}
