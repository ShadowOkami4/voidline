pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../core"

// Timer state lives in a shell service, not in the clock panel. Deadlines are
// persisted so closing the panel or reloading its Loader never resets a timer.
QtObject {
    id: root

    property var timers: []
    property date selectedDate: new Date()
    property date displayMonth: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    property bool stopwatchRunning: false
    property double stopwatchStartedAt: 0
    property double stopwatchStoredMs: 0
    property double stopwatchDisplayMs: 0
    property double stopwatchFrameBaseMs: 0
    property double stopwatchFrameAnchor: 0
    property bool stopwatchFrameNeedsAnchor: true
    property var stopwatchLaps: []
    property bool uiActive: false
    property double nowMs: Date.now()
    readonly property double stopwatchElapsedMs: stopwatchRunning
        ? stopwatchDisplayMs : stopwatchStoredMs
    readonly property bool ticking: timers.some(timer => timer.running)

    function nextId() {
        return "timer-" + Date.now() + "-" + Math.floor(Math.random() * 100000)
    }

    function startTimer(totalSeconds, name) {
        const seconds = Math.max(1, Math.round(Number(totalSeconds) || 0))
        const timestamp = Date.now()
        timers = timers.concat([{
            id: nextId(),
            name: String(name || "").trim(),
            durationMs: seconds * 1000,
            remainingMs: seconds * 1000,
            deadline: timestamp + seconds * 1000,
            running: true
        }])
        nowMs = timestamp
        persist()
    }

    function pauseTimer(id) {
        const timestamp = Date.now()
        timers = timers.map(timer => timer.id === id ? Object.assign({}, timer, {
            remainingMs: Math.max(0, timer.deadline - timestamp),
            running: false
        }) : timer)
        persist()
    }

    function resumeTimer(id) {
        const timestamp = Date.now()
        timers = timers.map(timer => timer.id === id ? Object.assign({}, timer, {
            deadline: timestamp + Math.max(1000, timer.remainingMs),
            running: true
        }) : timer)
        nowMs = timestamp
        persist()
    }

    function cancelTimer(id) {
        timers = timers.filter(timer => timer.id !== id)
        persist()
    }

    function remainingMs(timer) {
        return timer.running
            ? Math.max(0, Number(timer.deadline) - nowMs)
            : Math.max(0, Number(timer.remainingMs) || 0)
    }

    function remainingLabel(timer) {
        const total = Math.max(0, Math.ceil(remainingMs(timer) / 1000))
        const hours = Math.floor(total / 3600)
        const minutes = Math.floor((total % 3600) / 60)
        const seconds = total % 60
        return (hours > 0 ? String(hours).padStart(2, "0") + ":" : "")
            + String(minutes).padStart(2, "0") + ":"
            + String(seconds).padStart(2, "0")
    }

    function notifyFinished(timer) {
        const label = timer.name.length > 0
            ? timer.name : I18n.tr("clock.timer.defaultName")
        Quickshell.execDetached({
            command: ["/usr/bin/notify-send", "-a", "Voidline", "-i", "timer",
                I18n.tr("clock.timer.finished"), label]
        })
    }

    function tick() {
        const timestamp = Date.now()
        nowMs = timestamp
        const expired = timers.filter(timer => timer.running
            && Number(timer.deadline) <= timestamp)
        if (expired.length === 0)
            return
        for (let index = 0; index < expired.length; ++index)
            notifyFinished(expired[index])
        const ids = expired.map(timer => timer.id)
        timers = timers.filter(timer => ids.indexOf(timer.id) < 0)
        persist()
    }

    function startStopwatch() {
        if (stopwatchRunning)
            return
        stopwatchStartedAt = Date.now()
        stopwatchDisplayMs = stopwatchStoredMs
        stopwatchFrameBaseMs = stopwatchDisplayMs
        stopwatchFrameNeedsAnchor = true
        stopwatchRunning = true
        persist()
    }

    function pauseStopwatch() {
        if (!stopwatchRunning)
            return
        const timestamp = Date.now()
        stopwatchStoredMs = Math.max(stopwatchDisplayMs,
            stopwatchStoredMs + Math.max(0, timestamp - stopwatchStartedAt))
        stopwatchDisplayMs = stopwatchStoredMs
        stopwatchRunning = false
        persist()
    }

    function resetStopwatch() {
        stopwatchRunning = false
        stopwatchStartedAt = 0
        stopwatchStoredMs = 0
        stopwatchDisplayMs = 0
        stopwatchFrameBaseMs = 0
        stopwatchLaps = []
        nowMs = Date.now()
        persist()
    }

    function stopwatchLabel() {
        return formatStopwatch(stopwatchElapsedMs)
    }

    function formatStopwatch(elapsedMs) {
        const totalHundredths = Math.floor(Math.max(0, elapsedMs) / 10)
        const hundredths = totalHundredths % 100
        const totalSeconds = Math.floor(totalHundredths / 100)
        const seconds = totalSeconds % 60
        const minutes = Math.floor(totalSeconds / 60) % 60
        const hours = Math.floor(totalSeconds / 3600)
        return (hours > 0 ? String(hours).padStart(2, "0") + ":" : "")
            + String(minutes).padStart(2, "0") + ":"
            + String(seconds).padStart(2, "0") + "."
            + String(hundredths).padStart(2, "0")
    }

    function addStopwatchLap() {
        if (stopwatchElapsedMs <= 0)
            return
        stopwatchLaps = [{
            id: "lap-" + Date.now(),
            elapsedMs: stopwatchElapsedMs
        }].concat(stopwatchLaps)
        persist()
    }

    function setUiActive(value) {
        uiActive = value
        if (!uiActive || !stopwatchRunning)
            return
        stopwatchDisplayMs = stopwatchStoredMs
            + Math.max(0, Date.now() - stopwatchStartedAt)
        stopwatchFrameBaseMs = stopwatchDisplayMs
        stopwatchFrameNeedsAnchor = true
    }

    function previousMonth() {
        displayMonth = new Date(displayMonth.getFullYear(), displayMonth.getMonth() - 1, 1)
    }

    function nextMonth() {
        displayMonth = new Date(displayMonth.getFullYear(), displayMonth.getMonth() + 1, 1)
    }

    function showToday() {
        selectedDate = new Date()
        displayMonth = new Date(selectedDate.getFullYear(), selectedDate.getMonth(), 1)
    }

    function persist() {
        if (!Paths.writableRootsReady)
            return
        stateFile.setText(JSON.stringify({
            timers: timers,
            stopwatchRunning: stopwatchRunning,
            stopwatchStartedAt: stopwatchStartedAt,
            stopwatchStoredMs: stopwatchStoredMs,
            stopwatchLaps: stopwatchLaps
        }, null, 2) + "\n")
    }

    function load(contents) {
        if (String(contents || "").trim().length === 0)
            return
        try {
            const data = JSON.parse(contents)
            timers = Array.isArray(data.timers) ? data.timers : []
            stopwatchRunning = data.stopwatchRunning === true
            stopwatchStartedAt = Number(data.stopwatchStartedAt) || Date.now()
            stopwatchStoredMs = Math.max(0, Number(data.stopwatchStoredMs) || 0)
            stopwatchLaps = Array.isArray(data.stopwatchLaps) ? data.stopwatchLaps : []
            stopwatchDisplayMs = stopwatchStoredMs
                + (stopwatchRunning
                    ? Math.max(0, Date.now() - stopwatchStartedAt) : 0)
            stopwatchFrameBaseMs = stopwatchDisplayMs
            stopwatchFrameNeedsAnchor = true
            tick()
        } catch (error) {
            console.warn("Voidline: unable to load clock state", error)
        }
    }

    property Timer ticker: Timer {
        interval: 250
        repeat: true
        running: root.ticking
        onTriggered: root.tick()
    }

    // FrameAnimation supplies a monotonic elapsed clock for the visible
    // stopwatch. It stops with the panel, so a closed clock does not keep a
    // high-frequency UI timer alive; persisted wall-clock timestamps bridge
    // the hidden/reload interval.
    property FrameAnimation stopwatchFrame: FrameAnimation {
        running: root.stopwatchRunning && root.uiActive
        onTriggered: {
            const frameMs = elapsedTime * 1000
            if (root.stopwatchFrameNeedsAnchor) {
                root.stopwatchFrameAnchor = frameMs
                root.stopwatchFrameBaseMs = root.stopwatchDisplayMs
                root.stopwatchFrameNeedsAnchor = false
            }
            root.stopwatchDisplayMs = root.stopwatchFrameBaseMs
                + Math.max(0, frameMs - root.stopwatchFrameAnchor)
        }
    }

    property FileView stateFile: FileView {
        path: Paths.writableRootsReady ? Paths.stateRoot + "/clock-state.json" : ""
        watchChanges: false
        printErrors: false
        onLoaded: root.load(text())
    }
}
