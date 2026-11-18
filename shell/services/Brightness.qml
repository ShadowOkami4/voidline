pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs.compositor

// Reads the backlight from sysfs (no polling: the file is watched) and writes
// through brightnessctl, which handles permissions via logind.
//
// Monitors on a cable have no backlight file; they are asked over the
// monitor cable itself (DDC/CI) with ddcutil, when that is installed.
Singleton {
    id: root

    property string device: ""
    property int max: 0
    property int current: 0
    readonly property bool available: device.length > 0 && max > 0
    readonly property real value: available ? current / max : 0

    // While a slider is dragged the newest value wins: one brightnessctl
    // runs at a time, and what the file reports meanwhile is ignored, or the
    // slider would jump back to values that are already old.
    property real lastSet: 0
    property int wanted: -1
    function set(v) {
        if (!available) return
        const clamped = Math.max(0.02, Math.min(1, v))
        current = Math.round(clamped * max)
        lastSet = Date.now()
        wanted = Math.round(clamped * 100)
        if (!write.running) send()
        calm.restart()
    }
    function send() {
        if (wanted < 0) return
        write.command = ["brightnessctl", "-q", "-d", device, "set", wanted + "%"]
        wanted = -1
        write.running = true
    }
    Process { id: write; onExited: root.send() }
    Timer { id: calm; interval: 700; onTriggered: level.reload() }

    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/backlight/*; do [ -e \"$d/brightness\" ] && echo \"$(basename \"$d\") $(cat \"$d/max_brightness\")\" && break; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(" ")
                if (parts.length === 2) { root.max = parseInt(parts[1]); root.device = parts[0] }
            }
        }
    }

    FileView {
        id: level
        path: root.device ? "/sys/class/backlight/" + root.device + "/actual_brightness" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: if (Date.now() - root.lastSet > 600) root.current = parseInt(text()) || 0
    }

    // ---- monitors on a cable -----------------------------------------------------------
    property bool hasDdc: false
    // "" | "missing" (ddcutil not installed) | "blocked" (no access to the monitors)
    property string ddcProblem: ""
    // [{ bus, name, connector, max }]. Replaced only when monitors come or
    // go, so sliders built from it are not rebuilt while they are dragged.
    property var externals: []
    // bus -> 0..1
    property var levels: ({})
    function levelOf(bus) { const v = levels[bus]; return v === undefined ? 0 : v }
    property bool looking: false

    function rescan() { if (!detect.running) { looking = true; detect.running = true } }
    // Screens come and go: look again a moment after the set changed.
    readonly property int screens: Compositor.outputs.length
    onScreensChanged: settle.restart()
    Timer { id: settle; interval: 3500; onTriggered: root.rescan() }
    Timer { interval: 6000; running: true; onTriggered: root.rescan() }

    Process {
        id: detect
        // One block per monitor: bus, connector and name from "detect", then
        // "VCP 10 C <now> <max>" from asking for the brightness.
        command: ["sh", "-c", `
command -v ddcutil >/dev/null || { echo "@@missing"; exit 0; }
ls /dev/i2c-* >/dev/null 2>&1 || { echo "@@blocked"; exit 0; }
LC_ALL=C ddcutil detect --brief 2>/dev/null | awk '
    /^Display/ { ok = 1; next }
    /^Invalid/ { ok = 0; next }
    ok && /I2C bus:/ { n = $NF; sub(/.*i2c-/, "", n); bus = n }
    ok && /DRM.connector:/ { con = $NF; sub(/^card[0-9]+-/, "", con) }
    ok && /Monitor:/ { sub(/^[ \t]*Monitor:[ \t]*/, ""); print "@@display|" bus "|" con "|" $0; con = "" }
' | while IFS='|' read -r tag bus con name; do
    v=$(LC_ALL=C ddcutil --bus "$bus" getvcp 10 --brief 2>/dev/null | awk '$1 == "VCP" && $2 == "10" { print $4 "|" $5 }')
    [ -n "$v" ] && echo "$tag|$bus|$con|$name|$v"
done
true`]
        stdout: StdioCollector {
            onStreamFinished: {
                root.looking = false
                root.hasDdc = !text.includes("@@missing")
                root.ddcProblem = text.includes("@@missing") ? "missing" : (text.includes("@@blocked") ? "blocked" : "")
                const out = []
                const read = {}
                for (const line of text.split("\n")) {
                    const p = line.split("|")
                    if (p[0] !== "@@display" || p.length < 6 || !/^\d+$/.test(p[1])) continue
                    const max = Number(p[5]) || 100
                    // "DEL:DELL U2415:serial" -> "DELL U2415"
                    const model = p[3].split(":")[1] || p[3]
                    out.push({ bus: Number(p[1]), connector: p[2], name: model.trim() || p[2], max: max })
                    read[Number(p[1])] = Math.max(0, Math.min(1, Number(p[4]) / max))
                }
                // Same monitors as before: keep the list, so nothing is rebuilt.
                if (JSON.stringify(out) !== JSON.stringify(root.externals)) root.externals = out
                if (Date.now() - root.lastExternal > 2000) root.levels = read
            }
        }
    }

    // Monitors answer slowly, so while a slider moves only the newest value
    // is sent, one command at a time.
    property var waiting: ({})
    property real lastExternal: 0
    function setExternal(bus, v) {
        const clamped = Math.max(0, Math.min(1, v))
        const next = Object.assign({}, levels)
        next[bus] = clamped
        levels = next
        lastExternal = Date.now()
        waiting[bus] = clamped
        if (!push.running) pump.restart()
    }
    function setAllExternal(v) { for (const e of externals) setExternal(e.bus, v) }
    Timer {
        id: pump
        interval: 120
        onTriggered: {
            const buses = Object.keys(root.waiting)
            if (buses.length === 0 || push.running) return
            const bus = buses[0]
            const e = root.externals.find(x => String(x.bus) === bus)
            const v = root.waiting[bus]
            delete root.waiting[bus]
            if (!e) { restart(); return }
            push.command = ["ddcutil", "--bus", bus, "setvcp", "10", String(Math.round(v * e.max)), "--noverify"]
            push.running = true
        }
    }
    Process { id: push; onExited: if (Object.keys(root.waiting).length > 0) pump.restart() }

    // ---- brightness keys ---------------------------------------------------------------
    // The keys change the screen you are working on: a monitor on a cable
    // when the focus is there, otherwise the built-in screen. `builtIn` is
    // false when your own config already moves the built-in screen.
    // The monitor last changed with the keys, for the on-screen level.
    property int stepped: -1
    signal externalStepped()
    function step(up, builtIn) {
        const by = up ? 0.05 : -0.05
        const name = Compositor.name === "hyprland" && Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        let ext = externals.find(e => e.connector === name)
        // No built-in screen (a desktop computer): the first monitor will do.
        if (!ext && !available && externals.length > 0) ext = externals[0]
        if (ext) {
            setExternal(ext.bus, Math.round((levelOf(ext.bus) + by) * 20) / 20)
            stepped = ext.bus
            externalStepped()
        } else if (builtIn && available) {
            set(Math.round((value + by) * 20) / 20)
        }
    }
}
