pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.core

// Screenshots (grim + slurp) and screen recording (wf-recorder).
// Pictures go to ~/Pictures/Screenshots and, with wl-clipboard installed, to
// the clipboard as well. Recordings go to ~/Videos/Recordings.
Singleton {
    id: root

    property bool canShoot: false
    property bool canRecord: false
    readonly property bool recording: recorder.running

    Process {
        running: true
        command: ["sh", "-c", "command -v grim >/dev/null && echo shoot; command -v wf-recorder >/dev/null && echo record"]
        stdout: StdioCollector {
            onStreamFinished: { root.canShoot = text.includes("shoot"); root.canRecord = text.includes("record") }
        }
    }

    readonly property string shootScript: `
dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots"
mkdir -p "$dir"
file="$dir/Screenshot $(date '+%Y-%m-%d %H-%M-%S').png"
if [ "$1" = region ]; then
    area=$(slurp 2>/dev/null) || exit 0
    grim -g "$area" "$file" || exit 1
else
    grim "$file" || exit 1
fi
# Draw on it first (arrows, text, blur) when the editor is installed and wanted.
if [ "$2" = edit ] && command -v swappy >/dev/null; then
    swappy -f "$file" -o "$file"
fi
command -v wl-copy >/dev/null && wl-copy --type image/png < "$file"
notify-send -a Voidline -i "$file" "Screenshot saved" "$file"
`

    // mode: "screen" | "region"
    function shoot(mode) {
        if (!canShoot) { Quickshell.execDetached(["notify-send", "-a", "Voidline", "Screenshots need the package grim"]); return }
        Shell.close()
        later.mode = mode === "region" ? "region" : "screen"
        later.restart()
    }
    // Give an open panel time to disappear from the picture.
    Timer {
        id: later
        property string mode: "screen"
        interval: 350
        onTriggered: Quickshell.execDetached(["sh", "-c", root.shootScript, "sh", mode, Config.screenshotEdit ? "edit" : ""])
    }

    // Click any pixel: its colour is copied as #RRGGBB.
    function pickColour() {
        Shell.close()
        Quickshell.execDetached(["sh", "-c", `sleep 0.3
p=$(slurp -p 2>/dev/null) || exit 0
hex=$(grim -g "$p" -t ppm - | tail -c 3 | od -An -tx1 | tr -d ' \\n' | tr a-f A-F)
[ -n "$hex" ] || exit 1
command -v wl-copy >/dev/null && printf '#%s' "$hex" | wl-copy
notify-send -a Voidline "Colour copied" "#$hex"`])
    }

    function toggleRecording() {
        if (recorder.running) { recorder.signal(2); return }       // SIGINT lets it finish the file
        if (!canRecord) { Quickshell.execDetached(["notify-send", "-a", "Voidline", "Screen recording needs the package wf-recorder"]); return }
        Shell.close()
        recorder.running = true
    }
    Process {
        id: recorder
        command: ["sh", "-c", `dir="$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")/Recordings"; mkdir -p "$dir"; file="$dir/Recording $(date '+%Y-%m-%d %H-%M-%S').mp4"; echo "$file"; exec wf-recorder -f "$file"`]
        property string file: ""
        stdout: SplitParser { onRead: line => { if (!recorder.file) recorder.file = line } }
        onStarted: file = ""
        onExited: Quickshell.execDetached(["notify-send", "-a", "Voidline", "Recording saved", file])
    }
}
