pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.core

// USB sticks, SD cards and external disks: when one is plugged in it is
// made ready (mounted through udisks, as file managers do) and a
// notification offers to open it. Settings > Storage & drives lists them.
Singleton {
    id: root

    readonly property bool ready: true
    // Device paths of removable volumes seen so far; null until the first look.
    property var known: null

    Process {
        running: Config.automount
        command: ["udisksctl", "monitor"]
        stdout: SplitParser { onRead: line => { if (/Added|Removed/.test(line)) settle.restart() } }
    }
    Timer { id: settle; interval: 900; onTriggered: scan.running = true }
    Timer { interval: 3000; running: Config.automount; onTriggered: scan.running = true }

    Process {
        id: scan
        command: ["lsblk", "-J", "-b", "-o", "NAME,PATH,LABEL,SIZE,TYPE,MOUNTPOINT,RM,HOTPLUG,FSTYPE,TRAN"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = []
                const walk = (node, removable) => {
                    const rm = removable || !!(node.rm || node.hotplug || node.tran === "usb")
                    if (rm && node.fstype && node.fstype !== "swap" && node.fstype !== "crypto_LUKS" && (node.type === "part" || node.type === "disk"))
                        found.push({ dev: node.path, label: node.label || "", size: parseInt(node.size) || 0, mount: node.mountpoint || "" })
                    for (const c of node.children || []) walk(c, rm)
                }
                try { for (const d of JSON.parse(text).blockdevices) walk(d, false) } catch (e) { return }
                const first = root.known === null
                const before = root.known || []
                root.known = found.map(v => v.dev)
                // What was there when the shell started is left alone.
                if (first || !Config.automount) return
                for (const v of found) if (!before.includes(v.dev)) root.welcome(v)
            }
        }
    }

    function gb(bytes) {
        const g = bytes / 1073741824
        return g >= 100 ? Math.round(g) + " GB" : (g >= 1 ? g.toFixed(1) + " GB" : Math.round(bytes / 1048576) + " MB")
    }
    // Mounts the volume if needed, then shows a notification with "Open".
    // Device, texts and labels go in as data, never as part of the command.
    function welcome(v) {
        if (!/^\/dev\/[\w\/.-]+$/.test(v.dev)) return
        Quickshell.execDetached(["sh", "-c", `
dev="$1"; title="$2"; body="$3"; open="$4"
where=$(lsblk -no MOUNTPOINT "$dev" | head -n 1)
if [ -z "$where" ]; then
    udisksctl mount -b "$dev" --no-user-interaction >/dev/null 2>&1 || exit 0
    where=$(lsblk -no MOUNTPOINT "$dev" | head -n 1)
fi
[ -n "$where" ] || exit 0
answer=$(notify-send -a Voidline -i voidline-usb --action=open="$open" "$title" "$body")
[ "$answer" = open ] && env -u QT_SCALE_FACTOR -u VOIDLINE_UI_SCALE -u MALLOC_CONF xdg-open "$where"
true`, "sh", v.dev, v.label.length > 0 ? v.label : Lang.t("Drive plugged in"), gb(v.size) + "  ·  " + Lang.t("Ready to use"), Lang.t("Open##verb")])
    }
}
