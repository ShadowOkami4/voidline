pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.core

// Apps that start with the session. Uses the standard place,
// ~/.config/autostart/*.desktop, so entries made by apps themselves show up
// too. A window manager does not start these on its own, so the shell does,
// once per login.
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/autostart"
    // [{ file, name, icon, exec }]
    property var entries: []

    function refresh() { scan.running = true }
    function remove(file) {
        if (!/^[^\/]+\.desktop$/.test(file)) return
        Quickshell.execDetached(["rm", "-f", dir + "/" + file])
        entries = entries.filter(e => e.file !== file)
    }
    function add(entry) {
        const id = String(entry.id).replace(/[^A-Za-z0-9._-]/g, "_")
        const exec = entry.command.map(a => /[\s"'\\$`]/.test(a) ? '"' + a.replace(/(["\\$`])/g, "\\$1") + '"' : a).join(" ")
        const text = "[Desktop Entry]\nType=Application\nName=" + entry.name + "\nExec=" + exec + "\nIcon=" + (entry.icon || "") + "\n"
        writer.command = ["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$3\" > \"$1/$2.desktop\"", "sh", dir, id, text]
        writer.running = true
    }
    Process { id: writer; onExited: root.refresh() }

    readonly property string scanScript: `
for f in "$1"/*.desktop; do
    [ -f "$f" ] || continue
    grep -qi '^Hidden=true' "$f" && continue
    v() { grep -m1 "^$1=" "$f" | cut -d= -f2-; }
    printf '%s\\t%s\\t%s\\t%s\\n' "$(basename "$f")" "$(v Name)" "$(v Icon)" "$(v Exec)"
done`
    Process {
        id: scan
        running: true
        command: ["sh", "-c", root.scanScript, "sh", root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const p = l.split("\t")
                    return { file: p[0], name: p[1] || p[0], icon: p[2] || "", exec: p[3] || "" }
                })
                root.launchOnce()
            }
        }
    }

    // Once per login: a marker in the runtime directory survives shell restarts.
    property bool launched: false
    function launchOnce() {
        if (launched) return
        launched = true
        const script = `m="\${XDG_RUNTIME_DIR:-/tmp}/voidline-autostart-done"; [ -e "$m" ] && exit 0; : > "$m"
for f in "$1"/*.desktop; do
    [ -f "$f" ] || continue
    grep -qi '^Hidden=true' "$f" && continue
    cmd=$(grep -m1 '^Exec=' "$f" | cut -d= -f2- | sed 's/ *%[a-zA-Z]//g')
    [ -n "$cmd" ] && (env -u QT_SCALE_FACTOR -u VOIDLINE_UI_SCALE -u MALLOC_CONF sh -c "$cmd" >/dev/null 2>&1 &)
done`
        Quickshell.execDetached(["sh", "-c", script, "sh", dir])
    }
}
