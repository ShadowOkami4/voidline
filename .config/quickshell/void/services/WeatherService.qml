pragma Singleton

import Quickshell.Io
import QtQuick
import "../core"

QtObject {
    id: root

    property bool panelActive: false
    property bool lockActive: false
    property bool loading: false
    property string error: ""
    property var weather: ({})
    property var sources: []
    property double lastUpdated: 0
    readonly property string location: Appearance.weatherLocation
    readonly property bool configured: location.length > 0
    readonly property bool available: Object.keys(weather).length > 0
    readonly property bool monitoring: configured && (panelActive || lockActive)
    readonly property bool stale: Date.now() - lastUpdated > 30 * 60 * 1000

    function iconForCode(value) {
        const code = Number(value)
        if (code === 0)
            return "clear_day"
        if (code <= 3)
            return "partly_cloudy_day"
        if (code === 45 || code === 48)
            return "foggy"
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82))
            return "rainy"
        if ((code >= 71 && code <= 77) || code >= 85 && code <= 86)
            return "weather_snowy"
        if (code >= 95)
            return "thunderstorm"
        return "cloud"
    }

    function setPanelActive(value) {
        panelActive = Boolean(value)
        if (panelActive)
            refresh(false)
    }

    function setLockActive(value) {
        lockActive = Boolean(value)
        if (lockActive)
            refresh(false)
    }

    function setLocation(value) {
        Appearance.setWeatherLocation(value)
        weather = ({})
        lastUpdated = 0
        if (Appearance.weatherLocation.length > 0)
            refresh(true)
    }

    function refresh(force) {
        if (!configured || loading || (!force && available && !stale))
            return
        error = ""
        query.command = ["/usr/bin/sh", Paths.scripts + "/weather-query.sh", location]
        query.running = true
        loading = true
    }

    function loadCache(contents) {
        if (String(contents || "").trim().length === 0)
            return
        try {
            const data = JSON.parse(contents)
            if (String(data.location || "") !== location)
                return
            weather = data.weather || ({})
            sources = Array.isArray(data.sources) ? data.sources : []
            lastUpdated = Number(data.lastUpdated) || 0
        } catch (cacheError) {
            console.warn("Voidline: unable to read weather cache", cacheError)
        }
    }

    function parseResponse(contents) {
        const envelope = JSON.parse(String(contents || "{}"))
        if (String(envelope.status || "") !== "ok" || !envelope.payload)
            throw new Error(envelope.error && envelope.error.message
                ? envelope.error.message : "Weather backend failed")
        const payload = envelope.payload
        if (!payload.weather)
            throw new Error("Weather response did not contain conditions")
        weather = payload.weather
        sources = Array.isArray(payload.sources) ? payload.sources : []
        lastUpdated = Date.now()
        if (Paths.writableRootsReady) {
            cacheFile.setText(JSON.stringify({
                location: location,
                weather: weather,
                sources: sources,
                lastUpdated: lastUpdated
            }, null, 2) + "\n")
        }
    }

    property Process query: Process {
        stdout: StdioCollector { id: weatherOutput }
        stderr: StdioCollector { id: weatherError }
        onExited: (exitCode, exitStatus) => {
            root.loading = false
            if (exitCode !== 0) {
                root.error = weatherError.text.trim().length > 0
                    ? weatherError.text.trim() : I18n.tr("clock.weather.error")
                return
            }
            try {
                root.parseResponse(weatherOutput.text)
            } catch (parseError) {
                root.error = String(parseError)
            }
        }
    }

    property Timer refreshTimer: Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: root.monitoring
        onTriggered: root.refresh(true)
    }

    property FileView cacheFile: FileView {
        path: Paths.writableRootsReady ? Paths.stateRoot + "/weather-cache.json" : ""
        watchChanges: false
        printErrors: false
        onLoaded: root.loadCache(text())
    }
}
