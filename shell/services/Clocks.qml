pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.core

// Alarms and clocks for other places.
//
// An alarm is "HH:MM|repeat|on" with repeat "" (once), "daily" or
// "weekdays". It rings with a notification and a sound, and can be
// snoozed for nine minutes. Alarms ring only while the computer is awake;
// one that is asleep at the time does not wake up for it.
//
// A world clock is a time zone name ("Asia/Tokyo"). Its offset from world
// time is asked from the system now and then, so summer time is right.
Singleton {
    id: root

    readonly property bool ready: true

    // ---- alarms -----------------------------------------------------------------------
    readonly property var alarms: Config.alarms.map((e, i) => {
        const p = String(e).split("|")
        return { index: i, time: p[0] || "07:00", repeat: p[1] || "", on: p[2] !== "off" }
    })
    function write(list) { Config.alarms = list.map(a => a.time + "|" + a.repeat + "|" + (a.on ? "on" : "off")) }
    function addAlarm(time, repeat) {
        if (!/^\d\d:\d\d$/.test(time)) return
        write(alarms.concat([{ time: time, repeat: repeat || "", on: true }]))
    }
    function setAlarm(index, change) { write(alarms.map(a => a.index === index ? Object.assign({}, a, change) : a)) }
    function removeAlarm(index) { write(alarms.filter(a => a.index !== index)) }
    // The next alarm that will ring, as a Date, or null.
    readonly property var next: {
        void tick.beat
        let best = null
        const now = new Date()
        for (const a of alarms) {
            if (!a.on) continue
            const p = a.time.split(":").map(Number)
            for (let d = 0; d < 8; ++d) {
                const t = new Date(now.getFullYear(), now.getMonth(), now.getDate() + d, p[0], p[1], 0)
                if (t <= now) continue
                if (a.repeat === "weekdays" && (t.getDay() === 0 || t.getDay() === 6)) continue
                if (!best || t < best) best = t
                break
            }
        }
        return best
    }

    // Rang already this minute (so it rings once), and snoozed ones.
    property string rangAt: ""
    property var snoozed: []        // [ms since 1970]
    function ring(label) {
        Quickshell.execDetached(["sh", "-c", `
( for i in 1 2 3 4 5 6; do
    for f in /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga /usr/share/sounds/freedesktop/stereo/complete.oga; do
        [ -f "$f" ] && { pw-play "$f" 2>/dev/null || paplay "$f" 2>/dev/null; break; }
    done
    sleep 1
done ) &
sound=$!
answer=$(timeout 10m notify-send -a Voidline -u critical -i voidline-alarm --action=snooze="$3" --action=stop="$4" "$1" "$2")
kill $sound 2>/dev/null
[ "$answer" = snooze ] && qs -c voidline ipc call shell snooze
true`, "sh", Lang.t("Alarm"), label, Lang.t("Snooze 9 minutes"), Lang.t("Stop")])
    }
    function snooze() { snoozed = snoozed.concat([Date.now() + 9 * 60000]) }

    QtObject { id: tick; property int beat: 0 }
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            tick.beat++
            const now = new Date()
            const hm = (now.getHours() < 10 ? "0" : "") + now.getHours() + ":" + (now.getMinutes() < 10 ? "0" : "") + now.getMinutes()
            const stamp = now.toDateString() + " " + hm
            if (root.rangAt !== stamp) {
                const weekend = now.getDay() === 0 || now.getDay() === 6
                for (const a of root.alarms) {
                    if (!a.on || a.time !== hm || (a.repeat === "weekdays" && weekend)) continue
                    root.rangAt = stamp
                    root.ring(a.time)
                    // A one-time alarm switches itself off after ringing.
                    if (a.repeat === "") root.setAlarm(a.index, { on: false })
                }
            }
            const due = root.snoozed.filter(t => t <= Date.now())
            if (due.length > 0) {
                root.snoozed = root.snoozed.filter(t => t > Date.now())
                root.ring(Lang.t("Snoozed"))
            }
        }
    }

    // ---- world clocks -------------------------------------------------------------------
    // zone -> minutes ahead of world time
    property var offsets: ({})
    function refreshZones() {
        const zones = Config.worldClocks.filter(z => /^[A-Za-z0-9_+\-\/]+$/.test(z))
        if (zones.length === 0 || look.running) return
        // Zone names go in as data, never as part of the command.
        look.command = ["sh", "-c", 'for z in "$@"; do printf "%s %s\\n" "$z" "$(TZ="$z" date +%z)"; done', "sh"].concat(zones)
        look.running = true
    }
    Process {
        id: look
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {}
                for (const line of text.split("\n")) {
                    const m = line.match(/^(\S+) ([+-])(\d\d)(\d\d)$/)
                    if (m) out[m[1]] = (m[2] === "-" ? -1 : 1) * (Number(m[3]) * 60 + Number(m[4]))
                }
                root.offsets = out
            }
        }
    }
    readonly property string zonesWanted: Config.worldClocks.join(",")
    onZonesWantedChanged: refreshZones()
    Timer { interval: 10 * 60 * 1000; running: Config.worldClocks.length > 0; repeat: true; triggeredOnStart: true; onTriggered: root.refreshZones() }

    // The time in `zone` at `now`, as a Date whose fields read like a local one.
    function timeIn(zone, now) {
        const off = offsets[zone]
        if (off === undefined) return null
        return new Date(now.getTime() + (off + now.getTimezoneOffset()) * 60000)
    }
    // "+8 h", "−1:30 h", "same time"
    function difference(zone, now) {
        const off = offsets[zone]
        if (off === undefined) return ""
        const diff = off + now.getTimezoneOffset()
        if (diff === 0) return Lang.t("same time")
        const h = Math.floor(Math.abs(diff) / 60), m = Math.abs(diff) % 60
        return (diff > 0 ? "+" : "−") + h + (m > 0 ? ":" + (m < 10 ? "0" : "") + m : "") + " h"
    }
    function cityOf(zone) { return zone.split("/").pop().replace(/_/g, " ") }
}
