import QtQuick

QtObject {
    id: state
    required property QtObject config

    property real slide: 0.0

    property bool open: false
    property bool pinnedOpen: false

    readonly property int animMs: (config && config.appearance && config.appearance.animMs !== undefined)
        ? config.appearance.animMs
        : 220

    readonly property int hoverCloseDelayMs: (config && config.sidebar && config.sidebar.hoverCloseDelayMs !== undefined)
        ? config.sidebar.hoverCloseDelayMs
        : 150

    readonly property int sidebarWidth: (config && config.sidebar && config.sidebar.sidebarWidth !== undefined)
        ? config.sidebar.sidebarWidth
        : 320

    property NumberAnimation slideAnim: NumberAnimation {
        target: state
        property: "slide"
        duration: state.animMs
        easing.type: Easing.InOutCubic
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
