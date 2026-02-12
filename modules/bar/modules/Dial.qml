import QtQuick

Item {
    id: root

    property real value: 0

    property string icon: "󰘚"

    property string ringColor: "#B80000"
    property string trackColor: "#262626"
    property string iconColor: "#E6E6E6"

    property int size: 24
    property int thickness: 2
    property int iconPixelSize: 14

    property string iconFontFamily: "Symbols Nerd Font Mono"

    property int iconXBias: 0
    property int iconYBias: 0

    width: size
    height: size

    function clamp01(x) { return Math.max(0, Math.min(1, x)); }

    Canvas {
        id: c
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            const w = width;
            const h = height;

            ctx.clearRect(0, 0, w, h);

            const cx = w / 2;
            const cy = h / 2;

            const r = (Math.min(w, h) - root.thickness) / 2;

            const start = -Math.PI / 2;
            const frac = root.clamp01(root.value / 100.0);
            const end = start + (Math.PI * 2 * frac);

            ctx.beginPath();
            ctx.lineWidth = root.thickness;
            ctx.strokeStyle = root.trackColor;
            ctx.lineCap = "round";
            ctx.arc(cx, cy, r, 0, Math.PI * 2, false);
            ctx.stroke();

            ctx.beginPath();
            ctx.lineWidth = root.thickness;
            ctx.strokeStyle = root.ringColor;
            ctx.lineCap = "round";
            ctx.arc(cx, cy, r, start, end, false);
            ctx.stroke();
        }
    }

    Text {
        id: iconText
        text: root.icon
        color: root.iconColor

        font.pixelSize: root.iconPixelSize
        font.family: root.iconFontFamily
        font.hintingPreference: Font.PreferNoHinting
        renderType: Text.NativeRendering
    }

    TextMetrics {
        id: tm
        text: iconText.text
        font: iconText.font
    }

    Binding {
        target: iconText
        property: "x"
        value: Math.round((root.width - tm.tightBoundingRect.width) / 2 - tm.tightBoundingRect.x) + root.iconXBias
    }

    Binding {
        target: iconText
        property: "y"
        value: Math.round((root.height - tm.tightBoundingRect.height) / 2 - iconText.baselineOffset - tm.tightBoundingRect.y) + root.iconYBias
    }

    onValueChanged: c.requestPaint()
    onRingColorChanged: c.requestPaint()
    onTrackColorChanged: c.requestPaint()
    onThicknessChanged: c.requestPaint()
    onSizeChanged: c.requestPaint()
}
