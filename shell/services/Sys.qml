pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.core

// Processor, memory and temperature at a glance. Reads /proc only while
// something is showing the numbers (set `watching`), every two seconds.
Singleton {
    id: root

    property bool watching: false
    property real cpu: 0            // 0..1
    property real memory: 0         // 0..1
    property real memoryGb: 0
    property int temperature: 0     // degrees C, 0 when unknown

    property var last: null

    Process {
        id: read
        command: ["sh", "-c", "head -n 1 /proc/stat; awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {print \"mem\", t, a}' /proc/meminfo; t=0; for z in /sys/class/thermal/thermal_zone*/temp; do v=$(cat \"$z\" 2>/dev/null) && [ \"$v\" -gt \"$t\" ] && t=$v; done; echo \"temp $t\""]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const p = line.trim().split(/\s+/)
                    if (p[0] === "cpu") {
                        const n = p.slice(1).map(Number)
                        const idle = n[3] + (n[4] || 0), total = n.reduce((a, b) => a + b, 0)
                        if (root.last && total > root.last.total)
                            root.cpu = 1 - (idle - root.last.idle) / (total - root.last.total)
                        root.last = { idle: idle, total: total }
                    } else if (p[0] === "mem") {
                        const total = Number(p[1]), free = Number(p[2])
                        if (total > 0) { root.memory = 1 - free / total; root.memoryGb = (total - free) / 1048576 }
                    } else if (p[0] === "temp") root.temperature = Math.round(Number(p[1]) / 1000)
                }
            }
        }
    }
    Timer {
        interval: 2000
        running: root.watching
        repeat: true
        triggeredOnStart: true
        onTriggered: read.running = true
    }
}
