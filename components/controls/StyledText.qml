import QtQuick

Text {
    required property QtObject appearance
    color: appearance.fg
    font.pixelSize: appearance.fontSize
    elide: Text.ElideRight
}