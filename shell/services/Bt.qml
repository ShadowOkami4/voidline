pragma Singleton

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
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

    // ---- pairing questions ------------------------------------------------------------
    // Some devices want a number compared or a code typed before they pair.
    // BlueZ puts such questions to an "agent"; without one, pairing those
    // devices just fails. The agent here is bluetoothctl, kept running while
    // Bluetooth is on: its questions are read from its output and shown by
    // PairDialog, the answer is written back to it.
    //
    // ask: null, or { kind, code }
    //   confirm  both sides show `code`; yes or no
    //   show     type `code` on the device
    //   pin      the user types the device's PIN
    //   passkey  the user types a number of up to six digits
    //   accept   yes or no, nothing to compare
    //   service  a known device wants to connect; yes or no
    property var ask: null
    // The device the question is about, as far as it can be told.
    readonly property var asking: all.find(d => d.pairing) ?? null
    property real answered: 0
    property string heard: ""

    function answer(text) {
        if (!ask) return
        agent.write(text + "\n")
        answered = Date.now()
        ask = null
    }
    function refuse() {
        if (!ask) return
        const kind = ask.kind
        answered = Date.now()
        ask = null
        if (kind === "confirm" || kind === "accept" || kind === "service") agent.write("no\n")
        // A question that waits for a code is ended by stopping the pairing.
        else for (const d of all) if (d.pairing) d.cancelPair()
    }
    // A shown code has done its job once nothing is pairing any more.
    onAskingChanged: if (!asking && ask && ask.kind === "show") ask = null

    function hear(data) {
        // Drop colours and cursor movement; keep the tail, questions are short.
        heard = (heard + data).replace(/\x1b\[[0-9;?]*[A-Za-z]/g, "").replace(/\r/g, "\n").slice(-600)
        if (/Request canceled|Agent unregistered/.test(heard)) { ask = null; heard = ""; return }
        // bluetoothctl repeats the question when it echoes the answer.
        if (Date.now() - answered < 1500) { heard = ""; return }
        let m
        if ((m = heard.match(/Confirm passkey (\d+) \(yes\/no\):/))) ask = { kind: "confirm", code: m[1] }
        else if (/Enter PIN code:/.test(heard)) ask = { kind: "pin", code: "" }
        else if (/Enter passkey \(number/.test(heard)) ask = { kind: "passkey", code: "" }
        else if (/Accept pairing \(yes\/no\):/.test(heard)) ask = { kind: "accept", code: "" }
        else if (/Authorize service \S+ \(yes\/no\):/.test(heard)) ask = { kind: "service", code: "" }
        else if ((m = heard.match(/\] Passkey: (\d+)/)) || (m = heard.match(/\] PIN code: (\S+)/))) ask = { kind: "show", code: m[1] }
        else return
        heard = ""
    }

    Process {
        id: agent
        command: ["bluetoothctl", "--agent", "KeyboardDisplay"]
        running: root.on
        stdinEnabled: true
        onStarted: write("default-agent\n")
        stdout: SplitParser { splitMarker: ""; onRead: data => root.hear(data) }
        onExited: { root.ask = null; if (root.on) again.restart() }
    }
    // bluetoothctl ends when the Bluetooth service restarts; start it again.
    Timer { id: again; interval: 5000; onTriggered: if (root.on) agent.running = true }

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
