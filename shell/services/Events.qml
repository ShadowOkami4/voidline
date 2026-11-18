pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.core

// Calendar events. Your own ones live in a small file on this computer;
// calendars from elsewhere (Google, Nextcloud, a school timetable) are read
// through their iCal address and shown next to them. Nothing is sent
// anywhere: subscribed calendars are only ever downloaded.
//
// An event: { id, date: "2026-11-16", time: "14:30" | "", title,
//             repeat: "" | "daily" | "weekly" | "monthly" | "yearly",
//             every, days (weekdays, weekly only), until, end, own }
Singleton {
    id: root

    readonly property bool ready: true
    readonly property string statePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/voidline/events.json"

    readonly property var own: {
        const out = []
        for (const e of store.entries) {
            try { const o = JSON.parse(e); o.own = true; out.push(o) } catch (err) {}
        }
        return out
    }
    // From subscribed calendars.
    property var fetched: []
    readonly property var all: own.concat(fetched)
    // Why a subscribed calendar could not be read, or "".
    property string problem: ""
    property bool loading: false

    // ---- dates -------------------------------------------------------------------------
    function two(n) { return n < 10 ? "0" + n : "" + n }
    function key(d) { return d.getFullYear() + "-" + two(d.getMonth() + 1) + "-" + two(d.getDate()) }
    function fromKey(k) { const p = k.split("-").map(Number); return new Date(p[0], p[1] - 1, p[2]) }
    function dayNumber(d) { return Math.round(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()) / 86400000) }

    function happens(e, d) {
        const k = key(d)
        if (k < e.date) return false
        if (!e.repeat) return e.end ? k < e.end : k === e.date
        if (e.until && k > e.until) return false
        const start = fromKey(e.date)
        const every = Math.max(1, e.every || 1)
        const days = dayNumber(d) - dayNumber(start)
        if (e.repeat === "daily") return days % every === 0
        if (e.repeat === "weekly") {
            const weeks = Math.floor((days + start.getDay()) / 7)
            if (weeks % every !== 0) return false
            return e.days && e.days.length > 0 ? e.days.includes(d.getDay()) : d.getDay() === start.getDay()
        }
        const months = (d.getFullYear() - start.getFullYear()) * 12 + d.getMonth() - start.getMonth()
        if (e.repeat === "monthly") return d.getDate() === start.getDate() && months % every === 0
        if (e.repeat === "yearly") return d.getDate() === start.getDate() && d.getMonth() === start.getMonth() && (months / 12) % every === 0
        return false
    }
    // Events of one day: all-day ones first, then by time.
    function on(d) {
        return all.filter(e => happens(e, d)).sort((a, b) => (a.time || "").localeCompare(b.time || "") || a.title.localeCompare(b.title))
    }
    function busy(d) { return all.some(e => happens(e, d)) }

    // ---- your own events ---------------------------------------------------------------
    // "9", "930", "9:30", "9.30", "14 30" -> "09:30"; "" when it is no time.
    function tidyTime(text) {
        const m = String(text).trim().match(/^(\d{1,2})(?:[:. ]?(\d{2}))?$/)
        if (!m || Number(m[1]) > 23 || Number(m[2] || 0) > 59) return ""
        return two(Number(m[1])) + ":" + (m[2] || "00")
    }
    function add(dateKey, time, title, repeat) {
        const clean = String(title).trim().slice(0, 80)
        if (clean.length === 0) return
        const e = { id: Date.now().toString(36) + Math.floor(Math.random() * 1296).toString(36), date: dateKey, time: tidyTime(time), title: clean, repeat: repeat || "" }
        store.entries = store.entries.concat([JSON.stringify(e)])
    }
    // Changes an own event; its first day stays.
    function update(id, time, title, repeat) {
        const clean = String(title).trim().slice(0, 80)
        if (clean.length === 0) return
        store.entries = store.entries.map(e => {
            let o = null
            try { o = JSON.parse(e) } catch (x) { return e }
            if (o.id !== id) return e
            o.time = tidyTime(time)
            o.title = clean
            o.repeat = repeat || ""
            return JSON.stringify(o)
        })
    }
    function remove(id) { store.entries = store.entries.filter(e => !e.includes('"id":"' + id + '"')) }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", statePath.replace(/\/[^\/]*$/, "")])
    FileView {
        path: root.statePath
        watchChanges: false
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter() }
        JsonAdapter {
            id: store
            property list<string> entries: []
        }
    }

    // ---- subscribed calendars ----------------------------------------------------------
    function stamp(value) {
        const m = value.match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?/)
        if (!m) return null
        if (!m[4]) return { date: m[1] + "-" + m[2] + "-" + m[3], time: "" }
        // "Z" is world time; everything else is taken as the time on the wall.
        const d = m[7] ? new Date(Date.UTC(m[1], m[2] - 1, m[3], m[4], m[5])) : new Date(m[1], m[2] - 1, m[3], m[4], m[5])
        return { date: key(d), time: two(d.getHours()) + ":" + two(d.getMinutes()) }
    }
    function readIcs(text) {
        const lines = text.replace(/\r?\n[ \t]/g, "").split(/\r?\n/)
        const weekdays = { SU: 0, MO: 1, TU: 2, WE: 3, TH: 4, FR: 5, SA: 6 }
        const repeats = { DAILY: "daily", WEEKLY: "weekly", MONTHLY: "monthly", YEARLY: "yearly" }
        const out = []
        let failed = 0
        let cur = null
        for (const line of lines) {
            if (line.startsWith("X-VOIDLINE-FAILED")) { failed++; continue }
            if (line === "BEGIN:VEVENT") { cur = { title: "", repeat: "" }; continue }
            if (!cur) continue
            if (line === "END:VEVENT") {
                if (cur.date && !cur.cancelled) {
                    if (cur.title.length === 0) cur.title = Lang.t("Event")
                    cur.id = "s" + out.length
                    out.push(cur)
                }
                cur = null
                continue
            }
            const at = line.indexOf(":")
            if (at < 0) continue
            const name = line.slice(0, at).split(";")[0].toUpperCase()
            const value = line.slice(at + 1)
            if (name === "SUMMARY") cur.title = value.replace(/\\n/gi, " ").replace(/\\([,;\\])/g, "$1").trim().slice(0, 120)
            else if (name === "STATUS") cur.cancelled = value.trim().toUpperCase() === "CANCELLED"
            else if (name === "DTSTART") { const s = stamp(value); if (s) { cur.date = s.date; cur.time = s.time } }
            else if (name === "DTEND") { const s = stamp(value); if (s && s.time === "") cur.end = s.date }
            else if (name === "RRULE") {
                const rule = {}
                for (const part of value.split(";")) { const p = part.split("="); rule[p[0].toUpperCase()] = p[1] || "" }
                // Rules like "second Tuesday of the month" are beyond this
                // calendar; such an event shows on its first day only.
                if (!repeats[rule.FREQ] || rule.BYSETPOS || rule.BYMONTHDAY || (rule.BYDAY && /\d/.test(rule.BYDAY)) || (rule.BYDAY && rule.FREQ !== "WEEKLY")) continue
                cur.repeat = repeats[rule.FREQ]
                cur.every = Math.max(1, Number(rule.INTERVAL) || 1)
                if (rule.BYDAY) cur.days = rule.BYDAY.split(",").map(x => weekdays[x]).filter(x => x !== undefined)
                if (rule.UNTIL) { const s = stamp(rule.UNTIL); if (s) cur.until = s.date }
                if (rule.COUNT) cur.count = Number(rule.COUNT)
            }
        }
        for (const e of out) {
            // A one-day event ends on the next day in iCal; that is no span.
            if (e.end && (e.repeat || dayNumber(fromKey(e.end)) - dayNumber(fromKey(e.date)) <= 1)) delete e.end
            // "Ten times" becomes a last day.
            if (e.count > 0 && !e.until) {
                const start = fromKey(e.date)
                const steps = Math.ceil(e.count / (e.days && e.days.length > 0 ? e.days.length : 1)) * e.every - 1
                const last = e.repeat === "daily" ? new Date(start.getFullYear(), start.getMonth(), start.getDate() + e.count * e.every - e.every)
                    : e.repeat === "weekly" ? new Date(start.getFullYear(), start.getMonth(), start.getDate() + steps * 7 + 6 - start.getDay())
                    : e.repeat === "monthly" ? new Date(start.getFullYear(), start.getMonth() + (e.count - 1) * e.every, start.getDate())
                    : new Date(start.getFullYear() + (e.count - 1) * e.every, start.getMonth(), start.getDate())
                e.until = key(last)
            }
            delete e.count
        }
        fetched = out
        problem = failed === 0 ? "" : (failed === Config.calendars.length ? Lang.t("The calendars could not be read.") : Lang.t("One calendar could not be read."))
    }

    function refresh() {
        if (Config.calendars.length === 0) { fetched = []; problem = ""; return }
        if (fetch.running) { again.restart(); return }
        loading = true
        fetch.command = ["sh", "-c", `
c="\${XDG_CACHE_HOME:-$HOME/.cache}/voidline"; mkdir -p "$c"; n=0
for u in "$@"; do
    n=$((n+1)); f="$c/calendar-$n.ics"
    case "$u" in webcal://*) u="https://\${u#webcal://}";; esac
    case "$u" in
        /*) cp -- "$u" "$f.new" 2>/dev/null;;
        http://*|https://*) curl -fsSL --max-time 20 -o "$f.new" -- "$u" 2>/dev/null;;
    esac
    if [ -s "$f.new" ]; then mv "$f.new" "$f"; else rm -f "$f.new"; echo "X-VOIDLINE-FAILED:$n"; fi
    [ -f "$f" ] && cat "$f"
    echo
done`, "sh"].concat(Config.calendars)
        fetch.running = true
    }
    Process {
        id: fetch
        stdout: StdioCollector { onStreamFinished: { root.loading = false; root.readIcs(text) } }
    }
    Timer { id: again; interval: 1500; onTriggered: root.refresh() }
    Timer { interval: 30 * 60 * 1000; running: Config.calendars.length > 0; repeat: true; onTriggered: root.refresh() }
    readonly property string wanted: Config.loaded ? Config.calendars.join("\n") : "?"
    onWantedChanged: if (Config.loaded) again.restart()

    // ---- reminders ---------------------------------------------------------------------
    // Ten minutes before an event with a time, once.
    property var reminded: ({})
    Timer {
        interval: 30000
        running: Config.eventReminders
        repeat: true
        onTriggered: {
            const now = new Date()
            const today = root.key(now)
            const minutes = now.getHours() * 60 + now.getMinutes()
            for (const e of root.all) {
                if (!e.time || !root.happens(e, now)) continue
                const p = e.time.split(":").map(Number)
                const left = p[0] * 60 + p[1] - minutes
                const mark = today + e.id + e.title
                if (left < 0 || left > 10 || root.reminded[mark]) continue
                root.reminded[mark] = true
                Quickshell.execDetached(["notify-send", "-a", "Voidline", "-i", "voidline-event", e.title,
                    left === 0 ? Lang.t("Now") : Lang.t("At %1, in %2 minutes", e.time, left)])
            }
        }
    }
}
