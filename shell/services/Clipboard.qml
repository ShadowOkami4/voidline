pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.core

// Clipboard history through cliphist + wl-clipboard. The shell only starts the
// watcher and reads the list; cliphist keeps the history.
Singleton {
    id: root

    property bool available: false
    // [{ id, text, image }]
    property var entries: []

    function refresh() { if (available) list.running = true }
    function pick(id) {
        Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", String(id)])
    }
    function remove(id) {
        Quickshell.execDetached(["sh", "-c", "printf '%s\\t' \"$1\" | cliphist delete", "sh", String(id)])
        entries = entries.filter(e => e.id !== id)
    }
    function clear() { Quickshell.execDetached(["cliphist", "wipe"]); entries = [] }

    Process {
        running: true
        command: ["sh", "-c", "command -v cliphist >/dev/null && command -v wl-paste >/dev/null"]
        onExited: code => root.available = code === 0
    }
    // Records everything that is copied (text and images).
    Process { running: root.available; command: ["wl-paste", "--watch", "cliphist", "store"] }

    Process {
        id: list
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t")
                    if (tab <= 0) continue
                    const body = line.slice(tab + 1)
                    out.push({ id: line.slice(0, tab), text: body, image: /^\[\[ binary data .* (png|jpe?g|bmp|gif|webp) /i.test(body) })
                    if (out.length >= 200) break
                }
                root.entries = out
            }
        }
    }

    Connections {
        target: Shell
        function onPanelChanged() { if (Shell.panel === "clipboard") root.refresh() }
    }
}
