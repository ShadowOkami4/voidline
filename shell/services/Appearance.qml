pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.core

// How other apps look: dark or light, icon theme, mouse pointer. These are the
// desktop-wide settings GTK, libadwaita, Qt and Electron apps read (gsettings),
// plus night light.
Singleton {
    id: root

    property bool available: false          // gsettings present
    property string iconTheme: ""
    property string cursorTheme: ""
    property int cursorSize: 24
    property var iconThemes: []
    property var cursorThemes: []
    property string nightTool: ""           // "hyprsunset" | "gammastep" | ""

    function gset(key, value) {
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", key, String(value)])
    }
    function setIconTheme(name) { iconTheme = name; gset("icon-theme", name) }
    function setCursor(name, size) {
        cursorTheme = name
        cursorSize = size
        gset("cursor-theme", name)
        gset("cursor-size", size)
        // Hyprland applies a new pointer at once; others pick it up for new windows.
        if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"))
            Quickshell.execDetached(["hyprctl", "setcursor", name, String(size)])
    }

    // Dark / light follows the shell.
    readonly property bool wantDark: Config.dark
    function applyScheme() {
        if (available && Config.loaded && Config.syncAppTheme) gset("color-scheme", Config.dark ? "prefer-dark" : "prefer-light")
    }
    onWantDarkChanged: applyScheme()
    onAvailableChanged: applyScheme()
    Connections {
        target: Config
        function onLoadedChanged() { root.applyScheme() }
        function onSyncAppThemeChanged() { root.applyScheme() }
    }

    Process {
        running: true
        command: ["sh", "-c", `
command -v gsettings >/dev/null || exit 0
echo "ok=1"
g() { gsettings get org.gnome.desktop.interface "$1" 2>/dev/null | tr -d "'"; }
echo "icon=$(g icon-theme)"; echo "cursor=$(g cursor-theme)"; echo "size=$(g cursor-size)"
for d in /usr/share/icons "$HOME/.local/share/icons" "$HOME/.icons"; do
    for t in "$d"/*/; do
        [ -d "$t" ] || continue
        n=$(basename "$t")
        [ -d "$t/cursors" ] && echo "c=$n"
        [ -f "$t/index.theme" ] && grep -q '^Directories=' "$t/index.theme" && [ "$n" != hicolor ] && [ "$n" != default ] && [ "$n" != locolor ] && echo "i=$n"
    done
done
command -v hyprsunset >/dev/null && echo "night=hyprsunset"
command -v gammastep >/dev/null && echo "night=gammastep"
exit 0`]
        stdout: StdioCollector {
            onStreamFinished: {
                const icons = [], cursors = []
                let night = ""
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=")
                    if (i < 0) continue
                    const k = line.slice(0, i), v = line.slice(i + 1).trim()
                    if (k === "ok") root.available = true
                    else if (k === "icon") root.iconTheme = v
                    else if (k === "cursor") root.cursorTheme = v
                    else if (k === "size") root.cursorSize = parseInt(v) || 24
                    else if (k === "i" && !icons.includes(v)) icons.push(v)
                    else if (k === "c" && !cursors.includes(v)) cursors.push(v)
                    else if (k === "night" && (night === "" || (v === "hyprsunset" && Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")))) night = v
                }
                // Hyprland forgets the pointer between sessions; set it again.
                if (root.cursorTheme.length > 0 && root.cursorTheme !== "default" && Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"))
                    Quickshell.execDetached(["hyprctl", "setcursor", root.cursorTheme, String(root.cursorSize)])
                root.iconThemes = icons.sort()
                root.cursorThemes = cursors.sort()
                root.nightTool = night
            }
        }
    }

    // Light by day, dark at night.
    function followClock() {
        if (!Config.loaded || !Config.autoTheme) return
        const h = new Date().getHours()
        const dark = !(h >= 7 && h < 19)
        if (Config.dark !== dark) Config.dark = dark
    }
    Timer { interval: 60000; running: Config.autoTheme; repeat: true; triggeredOnStart: true; onTriggered: root.followClock() }

    // Night light: a warmer screen. The tool runs only while it is on.
    readonly property bool nightAvailable: nightTool.length > 0
    readonly property int nightTemp: Math.max(2500, Math.min(6000, Config.nightLightTemp))
    Process {
        id: night
        command: root.nightTool === "hyprsunset" ? ["hyprsunset", "-t", String(root.nightTemp)]
            : ["gammastep", "-O", String(root.nightTemp)]
        running: root.nightAvailable && Config.loaded && Config.nightLight
        onCommandChanged: if (running) { running = false; again.restart() }
    }
    Timer { id: again; interval: 300; onTriggered: night.running = Qt.binding(() => root.nightAvailable && Config.loaded && Config.nightLight) }
}
