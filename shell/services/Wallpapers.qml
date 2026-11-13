pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Lists images in the wallpaper folders. Scanned on demand (when Settings
// opens), never in the background.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string dataDir: (Quickshell.env("XDG_DATA_HOME") || home + "/.local/share") + "/voidline/wallpapers"
    readonly property var dirs: [dataDir, home + "/Pictures/Wallpapers", home + "/Bilder/Wallpapers", home + "/.config/voidline/wallpapers"]
    property var files: []

    function refresh() { scan.running = true }

    Process {
        id: scan
        command: ["find"].concat(root.dirs).concat(["-maxdepth", "1", "-type", "f",
            "(", "-iname", "*.png", "-o", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp", ")"])
        stdout: StdioCollector {
            onStreamFinished: root.files = text.split("\n").filter(l => l.length > 0).sort()
        }
    }
}
