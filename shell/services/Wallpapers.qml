pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.core

// Finds still wallpapers (images) and live wallpapers (QML packages).
// Scanned on demand, never in the background.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string dataDir: Config.wallpaperDir
    // Bundled wallpapers for this screen shape first, then the user's own.
    readonly property var dirs: [dataDir + "/" + Config.aspectDir(Quickshell.screens[0] ?? null), dataDir,
        home + "/Pictures/Wallpapers", home + "/Bilder/Wallpapers"]
    property var files: []

    // [{ id, dir, name, description, author, options: [...], preview }]
    property var live: []
    property bool liveScanned: false

    function refresh() { scan.running = true; liveScan.running = true }

    function liveInfo(id) { return live.find(w => w.id === id) ?? null }

    // Option values handed to a live wallpaper: manifest defaults overridden by
    // what the user saved, converted to the type of the default.
    function liveValues(id) {
        const info = liveInfo(id), saved = Config.liveSaved(id), out = {}
        if (!info) return out
        for (const o of info.options) {
            let v = o.default
            if (saved[o.key] !== undefined) {
                const raw = saved[o.key]
                v = typeof o.default === "boolean" ? raw === "true"
                    : (typeof o.default === "number" ? (isNaN(Number(raw)) ? o.default : Number(raw)) : raw)
            }
            out[o.key] = v
        }
        return out
    }

    // A live wallpaper is in use: its manifest is needed right at start.
    readonly property bool wanted: Config.loaded && Config.liveId.length > 0
    onWantedChanged: if (wanted && !liveScanned) liveScan.running = true

    Process {
        id: scan
        command: ["find"].concat(root.dirs).concat(["-maxdepth", "1", "-type", "f",
            "(", "-iname", "*.png", "-o", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp", ")"])
        stdout: StdioCollector {
            onStreamFinished: root.files = text.split("\n").filter(l => l.length > 0).sort()
        }
    }

    // One line per package: "<dir>\t<manifest json on one line>"
    Process {
        id: liveScan
        command: ["sh", "-c", "for d in \"$1\"/*/; do [ -f \"$d/wallpaper.qml\" ] || continue; printf '%s\\t' \"${d%/}\"; [ -f \"$d/wallpaper.json\" ] && tr -d '\\n' < \"$d/wallpaper.json\"; echo; done", "sh", Config.liveDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = []
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t")
                    if (tab < 0) continue
                    const dir = line.slice(0, tab), id = dir.slice(dir.lastIndexOf("/") + 1)
                    let meta = {}
                    try { meta = JSON.parse(line.slice(tab + 1) || "{}") } catch (e) { console.warn("live wallpaper", id, "has a broken wallpaper.json:", e) }
                    found.push({
                        id: id,
                        dir: dir,
                        name: meta.name || id,
                        description: meta.description || "",
                        author: meta.author || "",
                        options: Array.isArray(meta.options) ? meta.options.filter(o => o && o.key && o.default !== undefined) : [],
                        preview: dir + "/preview.png"
                    })
                }
                root.live = found.sort((a, b) => a.name.localeCompare(b.name))
                root.liveScanned = true
            }
        }
    }
}
