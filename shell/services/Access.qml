pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.core

// Accessibility helpers: the on-screen keyboard's typing and the screen reader.
//  - Typing goes through "wtype", which hands key presses to the compositor.
//    It types characters as such, so the keyboard does not depend on the
//    layout set for the real keyboard.
//  - The screen reader is Orca. The shell only starts and stops it and tells
//    apps to describe themselves; Voidline's own bar and panels are not read.
Singleton {
    id: root

    property bool canType: false
    property bool hasReader: false
    // Asked for by the page and the shell so the checks run once.
    readonly property bool ready: canType || hasReader

    Process {
        running: true
        command: ["sh", "-c", "command -v wtype >/dev/null && echo type; command -v orca >/dev/null && echo reader"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.canType = text.includes("type")
                root.hasReader = text.includes("reader")
            }
        }
    }

    // ---- on-screen keyboard ---------------------------------------------------------
    function toggleKeyboard() { Config.onScreenKeyboard = !Config.onScreenKeyboard }

    // text: characters to type. mods: held while typing, e.g. ["ctrl"].
    function type(text, mods) {
        if (!canType) return
        const args = ["wtype"]
        for (const m of mods || []) args.push("-M", m)
        args.push("--", text)
        Quickshell.execDetached(args)
    }
    // A named key: BackSpace, Return, Tab, Escape, Left, Right, Up, Down.
    function key(name, mods) {
        if (!canType) return
        const args = ["wtype"]
        for (const m of mods || []) args.push("-M", m)
        args.push("-k", name)
        Quickshell.execDetached(args)
    }

    // ---- screen reader --------------------------------------------------------------
    readonly property bool reading: Config.screenReader && hasReader
    onReadingChanged: {
        const v = reading ? "true" : "false"
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "toolkit-accessibility", v])
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.a11y.applications", "screen-reader-enabled", v])
    }
    Process {
        running: root.reading
        command: ["env", "-u", "QT_SCALE_FACTOR", "-u", "VOIDLINE_UI_SCALE", "-u", "MALLOC_CONF", "orca"]
    }
}
