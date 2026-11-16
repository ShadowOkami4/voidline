pragma Singleton

import Quickshell
import QtQuick
import qs.core

// Things that switch by the clock: night light in the evening, do not
// disturb at night. Each one is switched only at the start and the end of
// its time span, so what you set by hand in between stays until then.
Singleton {
    id: root

    readonly property bool ready: true

    function minutes(text) { const p = String(text).split(":"); return (Number(p[0]) || 0) * 60 + (Number(p[1]) || 0) }
    // Is `now` inside from..to? A span may cross midnight (22:00 to 07:00).
    function inside(from, to, now) {
        const a = minutes(from), b = minutes(to)
        if (a === b) return false
        return a < b ? (now >= a && now < b) : (now >= a || now < b)
    }

    // "" until the first look; then "in" or "out".
    property string night: ""
    property string quiet: ""

    function look() {
        if (!Config.loaded) return
        const d = new Date()
        const now = d.getHours() * 60 + d.getMinutes()

        if (!Config.nightLightAuto) night = ""
        else {
            const state = inside(Config.nightLightFrom, Config.nightLightTo, now) ? "in" : "out"
            // On the first look the screen follows the clock too, so a
            // computer switched on at midnight starts warm.
            if (state !== night) { night = state; Config.nightLight = state === "in" }
        }

        if (!Config.dndAuto) quiet = ""
        else {
            const state = inside(Config.dndFrom, Config.dndTo, now) ? "in" : "out"
            if (state !== quiet) {
                const first = quiet === ""
                quiet = state
                // A "quiet for 3 hours" that is still running is left alone.
                if (state === "in") { Config.dndUntil = 0; Config.doNotDisturb = true }
                else if (!first && Config.dndUntil === 0) Config.doNotDisturb = false
            }
        }
    }

    Timer { interval: 20000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.look() }
    readonly property string plan: [Config.loaded, Config.nightLightAuto, Config.nightLightFrom, Config.nightLightTo, Config.dndAuto, Config.dndFrom, Config.dndTo].join("|")
    onPlanChanged: { night = ""; quiet = ""; look() }
}
