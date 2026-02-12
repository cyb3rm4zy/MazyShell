import QtQuick

QtObject {
    id: root

    property string now: ""

    function update() {

        now = Qt.formatDateTime(new Date(), "MM/dd hh:mm")
    }

    property Timer ticker: Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.update()
    }

    Component.onCompleted: update()
}
