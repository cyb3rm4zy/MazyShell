import QtQuick

QtObject {
    required property QtObject cfg  // ConfigService

    property color bg: cfg.bg
    property color bg2: cfg.bg2
    property color fg: cfg.fg
    property color accent: cfg.accent
    property color borderColor: cfg.borderColor
    property color muted: cfg.muted
    property color text: cfg.text

    // convenience alias you already use
    property color red: cfg.accent

    property real opacity: cfg.opacity

    property int barHeight: cfg.barHeight
    property int pad: cfg.pad
    property int fontSize: cfg.fontSize
    property int radius: cfg.radius

    property int animMs: cfg.animMs
}