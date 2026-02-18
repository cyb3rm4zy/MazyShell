import QtQuick

QtObject {
    required property QtObject cfg // ConfigService

    property var leftModules: cfg.leftModules
    property var centerModules: cfg.centerModules
    property var rightModules: cfg.rightModules

    function setEnabled(section, k, on) {
        cfg.setBarEnabled(section, k, on)
    }

    function move(section, from, to) {
        cfg.moveBar(section, from, to)
    }
}
