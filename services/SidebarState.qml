import QtQuick

QtObject {
    id: state
    required property QtObject config

    property real slide: 0.0

    property bool open: false
    property bool pinnedOpen: false

    readonly property int hoverCloseDelayMs: (config && config.sidebar && config.sidebar.hoverCloseDelayMs !== undefined)
        ? config.sidebar.hoverCloseDelayMs
        : 150

    readonly property int sidebarWidth: (config && config.sidebar && config.sidebar.sidebarWidth !== undefined)
        ? config.sidebar.sidebarWidth
        : 320

    readonly property int _durationMs: 240
    readonly property var _curveExpressiveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
    readonly property var _curveEmphasized: [0.05, 0, 2/15, 0.06, 1/6, 0.4, 5/24, 0.82, 0.25, 1, 1, 1]

    property NumberAnimation slideAnim: NumberAnimation {
        target: state
        property: "slide"
        duration: state._durationMs
        easing.type: Easing.BezierSpline
        easing.bezierCurve: state._curveExpressiveFastSpatial
    }

    property Timer closeTimer: Timer {
        interval: state.hoverCloseDelayMs
        repeat: false
        onTriggered: state._collapseNow()
    }

    function _clamp(v) {
        return Math.max(0, v)
    }

    function _almostEqual(a, b) {

        return Math.abs(a - b) < 0.5
    }

    function _stopCloseTimer() {
        if (closeTimer.running) closeTimer.stop()
    }

    function _animateTo(v) {
        const toVal = _clamp(v)

        _stopCloseTimer()

        if (_almostEqual(slide, toVal)) {

            if (slideAnim.running && slideAnim.to === toVal) return
            slideAnim.stop()
            slide = toVal
            return
        }

        if (slideAnim.running && slideAnim.to === toVal)
            return

        slideAnim.stop()
        slideAnim.to = toVal
        slideAnim.easing.bezierCurve = (toVal > slide)
            ? _curveExpressiveFastSpatial
            : _curveEmphasized
        slideAnim.start()
    }

    function _expandNow() {
        open = true
        _animateTo(sidebarWidth)
    }

    function _collapseNow() {
        open = false
        _animateTo(0)
    }

    function expand() {

        _expandNow()
    }

    function collapse() {

        _collapseNow()
    }

    function enterSidebar() {

        if (pinnedOpen) {
            _stopCloseTimer()
            _expandNow()
            return
        }

        _stopCloseTimer()
        _expandNow()
    }

    function leaveSidebar() {
        if (pinnedOpen) return

        if (!open && _almostEqual(slide, 0)) {
            _stopCloseTimer()
            return
        }

        closeTimer.restart()
    }

    function openPinned() {
        pinnedOpen = true
        _stopCloseTimer()
        _expandNow()
    }

    function closePinned() {
        pinnedOpen = false
        _stopCloseTimer()
        _collapseNow()
    }

    function togglePinned() {
        pinnedOpen = !pinnedOpen
        _stopCloseTimer()
        if (pinnedOpen) _expandNow()
        else _collapseNow()
    }
}
