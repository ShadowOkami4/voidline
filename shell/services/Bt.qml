pragma Singleton

import Quickshell
import Quickshell.Bluetooth
import QtQuick

// Bluetooth in one place for Settings, the quick tile and its mini menu.
// Switching on first lifts the radio block (rfkill): on many laptops the
// adapter is "soft blocked" after boot or airplane mode, and asking BlueZ to
// power it on then silently does nothing.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: !!adapter
    readonly property bool on: !!adapter && adapter.enabled
    // True from the click until the adapter reports back.
    property bool switching: false

    readonly property var all: adapter ? adapter.devices.values : []
    readonly property var mine: all.filter(d => d.paired || d.bonded || d.connected)
        .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    readonly property var nearby: all.filter(d => !(d.paired || d.bonded || d.connected) && d.name.length > 0)
        .sort((a, b) => a.name.localeCompare(b.name))
    readonly property var connected: mine.filter(d => d.connected)

    function setOn(v) {
        if (!adapter) return
        if (!v) { adapter.enabled = false; return }
        switching = true
        Quickshell.execDetached(["rfkill", "unblock", "bluetooth"])
        powerOn.tries = 0
        powerOn.restart()
    }
    // The unblock takes a moment to reach BlueZ; try a few times.
    Timer {
        id: powerOn
        property int tries: 0
        interval: 500
        onTriggered: {
            if (!root.adapter) { root.switching = false; return }
            if (root.adapter.enabled) { root.switching = false; return }
            root.adapter.enabled = true
            if (++tries < 6) restart()
            else root.switching = false
        }
    }
    onOnChanged: if (on) switching = false

    function glyph(d) {
        const i = d.icon || ""
        if (i.includes("headset") || i.includes("headphone")) return "headphones"
        if (i.includes("audio")) return "speaker"
        if (i.includes("mouse")) return "mouse"
        if (i.includes("keyboard")) return "keyboard"
        if (i.includes("phone")) return "smartphone"
        if (i.includes("gaming")) return "sports_esports"
        if (i.includes("computer")) return "computer"
        return "bluetooth"
    }
}
