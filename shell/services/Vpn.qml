pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.core

// VPN connections known to NetworkManager (OpenVPN, WireGuard and friends),
// for the tile in quick settings. Set them up once in a network tool; after
// that they are one tap away. Looked up only while `watching`.
Singleton {
    id: root

    property bool watching: false
    // [{ name, active }]
    property var list: []
    property bool busy: false
    readonly property var active: list.find(v => v.active) ?? null
    readonly property bool available: list.length > 0
    // The one the tile switches: the active one, else the one used last, else the first.
    readonly property var main: active ?? list.find(v => v.name === Config.vpnLast) ?? list[0] ?? null

    function refresh() { if (!look.running) look.running = true }
    function toggle() {
        if (!main || busy || !/^[^\n]+$/.test(main.name)) return
        busy = true
        if (!main.active) Config.vpnLast = main.name
        act.command = ["nmcli", "connection", main.active ? "down" : "up", "id", main.name]
        act.running = true
    }
    onWatchingChanged: if (watching) refresh()

    Process {
        id: look
        running: true
        command: ["nmcli", "-t", "-f", "NAME,TYPE,ACTIVE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const line of text.split("\n")) {
                    // Names may hold escaped colons; type and state never do.
                    const m = line.match(/^(.*):([^:]+):(yes|no)$/)
                    if (m && (m[2] === "vpn" || m[2] === "wireguard")) out.push({ name: m[1].replace(/\\:/g, ":"), active: m[3] === "yes" })
                }
                root.list = out
            }
        }
    }
    Process {
        id: act
        onExited: { root.busy = false; root.refresh() }
    }
    Timer { interval: 4000; running: root.watching; repeat: true; onTriggered: root.refresh() }
}
