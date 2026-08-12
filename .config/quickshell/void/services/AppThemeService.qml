pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../core"

QtObject {
    id: root

    property bool ready: false
    property bool dirty: true
    property string error: ""

    function componentHex(component) {
        const number = Math.max(0, Math.min(255,
            Math.round(Number(component) * 255)))
        const value = number.toString(16)
        return value.length < 2 ? "0" + value : value
    }

    function colorString(value) {
        return "#" + componentHex(value.r)
            + componentHex(value.g) + componentHex(value.b)
    }

    function scheduleApply() {
        dirty = true
        applyTimer.restart()
    }

    function applyNow() {
        if (applyProcess.running) {
            dirty = true
            return
        }
        dirty = false
        error = ""
        applyProcess.running = true
    }

    property Timer applyTimer: Timer {
        interval: 360
        repeat: false
        onTriggered: root.applyNow()
    }

    property Process applyProcess: Process {
        command: [
            "sh", Paths.shellRoot + "/scripts/app-theme.sh", "apply",
            Appearance.darkMode ? "dark" : "light",
            root.colorString(Theme.background),
            root.colorString(Theme.panelRaised),
            root.colorString(Theme.surfaceLow),
            root.colorString(Theme.groupSurface),
            root.colorString(Theme.groupSurfaceRaised),
            root.colorString(Theme.text),
            root.colorString(Theme.textMuted),
            root.colorString(Theme.outlineSoft),
            root.colorString(Theme.accent),
            root.colorString(Theme.secondary),
            root.colorString(Theme.tertiary),
            root.colorString(Theme.accentContainer),
            root.colorString(Theme.accentInk),
            Appearance.interfaceFont,
            Appearance.iconTheme,
            Appearance.cursorTheme
        ]
        stderr: StdioCollector { id: applyError }
        onExited: (exitCode, exitStatus) => {
            root.ready = exitCode === 0
            root.error = exitCode === 0 ? ""
                : (applyError.text.trim() || "Unable to apply application theme")
            if (root.dirty)
                root.applyTimer.restart()
        }
    }

    property Connections appearanceConnections: Connections {
        target: Appearance
        function onColorModeChanged() { root.scheduleApply() }
        function onMagicColorsChanged() { root.scheduleApply() }
        function onWallpaperPathChanged() { root.scheduleApply() }
        function onAccentColorChanged() { root.scheduleApply() }
        function onInterfaceFontChanged() { root.scheduleApply() }
        function onIconThemeChanged() { root.scheduleApply() }
        function onCursorThemeChanged() { root.scheduleApply() }
        function onHighContrastChanged() { root.scheduleApply() }
    }

    property Connections themeConnections: Connections {
        target: Theme
        function onBackgroundChanged() { root.scheduleApply() }
        function onPanelRaisedChanged() { root.scheduleApply() }
        function onSurfaceLowChanged() { root.scheduleApply() }
        function onGroupSurfaceChanged() { root.scheduleApply() }
        function onGroupSurfaceRaisedChanged() { root.scheduleApply() }
        function onTextChanged() { root.scheduleApply() }
        function onTextMutedChanged() { root.scheduleApply() }
        function onOutlineSoftChanged() { root.scheduleApply() }
        function onAccentChanged() { root.scheduleApply() }
        function onSecondaryChanged() { root.scheduleApply() }
        function onTertiaryChanged() { root.scheduleApply() }
        function onAccentContainerChanged() { root.scheduleApply() }
        function onAccentInkChanged() { root.scheduleApply() }
    }

    Component.onCompleted: scheduleApply()
}
