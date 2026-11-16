pragma Singleton

import Quickshell
import QtQuick
import qs.core

// A kitchen timer. Start it from the launcher ("timer 10", "25 min", "90s");
// the bar counts down and a notification rings when the time is up.
Singleton {
    id: root

    // Milliseconds since 1970 when it rings; 0 = no timer.
    property real endsAt: 0
    property int total: 0
    property int left: 0
    readonly property bool running: endsAt > 0
    readonly property string text: left >= 3600 ? Math.floor(left / 3600) + ":" + two(Math.floor(left % 3600 / 60)) + ":" + two(left % 60)
        : Math.floor(left / 60) + ":" + two(left % 60)

    function two(n) { return n < 10 ? "0" + n : "" + n }
    // "10" (minutes), "25 min", "90s", "1,5h" -> seconds; 0 when it is no time span.
    function parse(words) {
        const m = String(words).trim().toLowerCase().match(/^(\d+(?:[.,]\d+)?)\s*(s|sek|sec|sekunden|seconds|m|min|minuten|minutes|h|std|stunden|hours)?$/)
        if (!m) return 0
        const n = Number(m[1].replace(",", "."))
        const unit = (m[2] || "m")[0]
        const seconds = Math.round(n * (unit === "s" ? 1 : (unit === "h" ? 3600 : 60)))
        return seconds >= 1 && seconds <= 24 * 3600 ? seconds : 0
    }
    function words(seconds) {
        if (seconds % 3600 === 0) return Lang.t("%1 h", seconds / 3600)
        if (seconds >= 60 && seconds % 60 === 0) return Lang.t("%1 min", seconds / 60)
        if (seconds < 60) return Lang.t("%1 s", seconds)
        return Math.floor(seconds / 60) + ":" + two(seconds % 60) + " min"
    }
    function start(seconds) {
        total = seconds
        left = seconds
        endsAt = Date.now() + seconds * 1000
    }
    function stop() { endsAt = 0; left = 0 }

    Timer {
        interval: 250
        running: root.running
        repeat: true
        onTriggered: {
            const rest = Math.ceil((root.endsAt - Date.now()) / 1000)
            if (rest > 0) { root.left = rest; return }
            const was = root.total
            root.stop()
            Quickshell.execDetached(["sh", "-c", `
notify-send -a Voidline -u critical -i alarm-symbolic "$1" "$2"
for f in /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga /usr/share/sounds/freedesktop/stereo/complete.oga; do
    [ -f "$f" ] && { pw-play "$f" 2>/dev/null || paplay "$f" 2>/dev/null; break; }
done
true`, "sh", Lang.t("Time is up"), Lang.t("Your timer of %1 has run out.", root.words(was))])
        }
    }
}
