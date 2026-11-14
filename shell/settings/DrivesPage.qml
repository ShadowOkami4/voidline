import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.services
import qs.widgets

// Disk space, and USB sticks, SD cards and external disks: open, mount, eject.
// Mounting goes through udisks, the same service file managers use, so no
// password is needed for removable drives.
ColumnLayout {
    id: page
    spacing: 24

    // [{ dev, label, size, fs, mount, used, total, percent, removable, drive }]
    property var volumes: []
    readonly property var fixed: volumes.filter(v => !v.removable && v.mount.length > 0)
    readonly property var removable: volumes.filter(v => v.removable)
    property string problem: ""

    function refresh() { scan.running = true }
    function run(args) {
        problem = ""
        action.command = ["udisksctl"].concat(args)
        action.running = true
    }
    function gb(bytes) {
        const g = bytes / 1073741824
        return g >= 100 ? Math.round(g) + " GB" : (g >= 1 ? g.toFixed(1) + " GB" : Math.round(bytes / 1048576) + " MB")
    }

    Process {
        id: scan
        running: true
        command: ["lsblk", "-J", "-b", "-o", "NAME,PATH,LABEL,SIZE,TYPE,MOUNTPOINT,RM,HOTPLUG,FSTYPE,TRAN,FSUSED,FSSIZE,PKNAME"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                const walk = (node, parent) => {
                    const removable = !!(node.rm || node.hotplug || node.tran === "usb" || (parent && parent.removable))
                    const here = { removable: removable }
                    const mount = node.mountpoint || ""
                    const real = node.fstype && node.fstype !== "swap" && !mount.startsWith("[") && mount !== "/boot" && mount !== "/efi"
                    if (real && (node.type === "part" || node.type === "disk" || node.type === "crypt" || node.type === "lvm")) {
                        const total = parseInt(node.fssize) || 0, used = parseInt(node.fsused) || 0
                        out.push({
                            dev: node.path, label: node.label || "", size: parseInt(node.size) || 0, fs: node.fstype, mount: mount,
                            used: used, total: total, percent: total > 0 ? used / total : 0, removable: removable,
                            drive: parent && parent.path ? parent.path : node.path
                        })
                    }
                    for (const c of node.children || []) walk(c, { removable: removable, path: node.type === "disk" ? node.path : (parent ? parent.path : node.path) })
                }
                try { for (const d of JSON.parse(text).blockdevices) walk(d, null) } catch (e) { console.warn("lsblk:", e) }
                page.volumes = out
            }
        }
    }
    Process {
        id: action
        stderr: StdioCollector { id: errors }
        onExited: code => {
            if (code !== 0) page.problem = errors.text.trim().split("\n").pop().replace(/^Error [^:]*: /, "") || "That did not work."
            page.refresh()
        }
    }
    // Plugging something in or out updates the list.
    Process {
        running: true
        command: ["udisksctl", "monitor"]
        stdout: SplitParser { onRead: line => { if (/Added|Removed|Properties Changed/.test(line)) settle.restart() } }
    }
    Timer { id: settle; interval: 700; onTriggered: page.refresh() }

    Rectangle {
        visible: page.problem.length > 0
        Layout.fillWidth: true
        implicitHeight: issue.implicitHeight + 32
        radius: Theme.cornerL
        color: Theme.errorContainer
        Label { id: issue; x: 20; y: 16; width: parent.width - 40; wrapMode: Text.Wrap; text: page.problem; font.weight: Font.DemiBold; color: Theme.inkOnErrorContainer }
    }

    SegGroup {
        title: "This computer"
        Repeater {
            model: page.fixed
            SegItem {
                id: disk
                required property var modelData
                required property int index
                icon: modelData.mount === "/" ? "hard_drive" : "folder_open"
                hue: index
                lobes: [8, 4, 0, 5][index % 4]
                title: modelData.mount === "/" ? "System" : (modelData.label || modelData.mount)
                description: page.gb(modelData.total - modelData.used) + " free of " + page.gb(modelData.total)
                clickable: true
                onClicked: Apps.openUrl("file://" + modelData.mount)
                extra: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 12
                    radius: 6
                    color: Theme.surfaceContainerHighest
                    Rectangle {
                        width: Math.max(height, parent.width * disk.modelData.percent)
                        height: parent.height
                        radius: parent.radius
                        color: disk.modelData.percent > 0.9 ? Theme.error : Theme.primary
                    }
                }
            }
        }
    }

    SegGroup {
        title: "Removable drives"
        Repeater {
            model: page.removable
            SegItem {
                id: stick
                required property var modelData
                required property int index
                readonly property bool mounted: modelData.mount.length > 0
                icon: "usb"
                hue: index + 2
                lobes: [0, 5, 8, 4][index % 4]
                title: modelData.label || (page.gb(modelData.size) + " drive")
                description: mounted ? page.gb(modelData.total - modelData.used) + " free of " + page.gb(modelData.total)
                    : page.gb(modelData.size) + "  ·  not opened yet"
                clickable: mounted
                onClicked: Apps.openUrl("file://" + modelData.mount)
                Row {
                    spacing: 6
                    IconBtn {
                        visible: !stick.mounted
                        icon: "folder_open"
                        size: 42
                        tonal: true
                        onClicked: page.run(["mount", "-b", stick.modelData.dev])
                    }
                    IconBtn {
                        icon: "eject"
                        size: 42
                        tonal: true
                        // Unmount, then switch the drive off so it is safe to pull out.
                        onClicked: {
                            page.problem = ""
                            action.command = ["sh", "-c", "udisksctl unmount -b \"$1\" 2>/dev/null; udisksctl power-off -b \"$2\"", "sh", stick.modelData.dev, stick.modelData.drive]
                            action.running = true
                        }
                    }
                }
            }
        }
        SegItem {
            visible: page.removable.length === 0
            icon: "usb_off"
            hue: 2
            lobes: 0
            title: "Nothing plugged in"
            description: "USB sticks, SD cards and external disks show up here."
        }
    }
}
