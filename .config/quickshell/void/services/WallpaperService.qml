pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../core"

QtObject {
    id: root

    property var wallpapers: []
    property bool loading: false
    property string error: ""
    property bool sddmCacheReady: false
    property string sddmCacheError: ""
    readonly property string currentPath: Appearance.wallpaperPath

    function displayName(path) {
        const normalized = String(path || "")
        const slash = normalized.lastIndexOf("/")
        const filename = slash >= 0 ? normalized.slice(slash + 1) : normalized
        const dot = filename.lastIndexOf(".")
        return dot > 0 ? filename.slice(0, dot) : filename
    }

    function colorHex(value) {
        function channel(component) {
            return Math.round(Math.max(0, Math.min(1, component)) * 255)
                .toString(16).padStart(2, "0")
        }
        return "#" + channel(value.r) + channel(value.g) + channel(value.b)
    }

    function refresh() {
        if (listProcess.running)
            return
        loading = true
        error = ""
        listProcess.running = true
    }

    function parseList(contents) {
        const rows = contents.trim().length > 0 ? contents.trim().split("\n") : []
        const next = []
        for (let index = 0; index < rows.length; ++index) {
            const path = rows[index].trim()
            if (path.length > 0)
                next.push({ path: path, title: displayName(path) })
        }
        wallpapers = next
        loading = false

        if (Appearance.wallpaperPath.length === 0 && next.length > 0) {
            let fallback = next[0].path
            for (let index = 0; index < next.length; ++index) {
                if (next[index].path.endsWith("/background.png")) {
                    fallback = next[index].path
                    break
                }
            }
            applyWallpaper(fallback)
        }
    }

    function applyWallpaper(path) {
        const value = String(path || "").trim()
        if (value.length === 0)
            return false
        Appearance.setWallpaperPath(value)
        exportForSddm(value)
        return true
    }

    function exportForSddm(path) {
        if (cacheProcess.running || String(path || "").length === 0)
            return
        sddmCacheError = ""
        cacheProcess.wallpaperPath = String(path)
        cacheProcess.running = true
    }

    property var listProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/wallpaper-service.sh", "list"]
        stdout: StdioCollector { id: listOutput }
        stderr: StdioCollector { id: listError }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.parseList(listOutput.text)
            } else {
                root.loading = false
                root.error = listError.text.trim() || "Unable to scan wallpapers"
            }
        }
    }

    property var cacheProcess: Process {
        property string wallpaperPath: ""
        command: ["sh", Paths.shellRoot + "/scripts/sddm-wallpaper-cache.sh",
            "export", wallpaperPath,
            root.colorHex(Theme.background), root.colorHex(Theme.panel),
            root.colorHex(Theme.groupSurface), root.colorHex(Theme.groupSurfaceRaised),
            root.colorHex(Theme.text), root.colorHex(Theme.textMuted),
            root.colorHex(Theme.outlineSoft), root.colorHex(Theme.accent),
            root.colorHex(Theme.accentContainer)]
        stdout: StdioCollector { id: cacheOutput }
        stderr: StdioCollector { id: cacheError }
        onExited: (exitCode, exitStatus) => {
            root.sddmCacheReady = exitCode === 0
            root.sddmCacheError = exitCode === 0 ? "" :
                (cacheError.text.trim() || "Unable to update the SDDM wallpaper cache")
        }
    }

    property var initialCacheTimer: Timer {
        interval: 600
        running: true
        onTriggered: {
            if (Appearance.wallpaperPath.length > 0)
                root.exportForSddm(Appearance.wallpaperPath)
        }
    }

    Component.onCompleted: refresh()
}
