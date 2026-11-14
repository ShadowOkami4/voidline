pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.core

// Weather for the place named in Settings, from open-meteo.com (free, no
// account). Nothing is requested until a place is set, and then only that
// place name and its coordinates are sent. Refreshed every half hour.
Singleton {
    id: root

    readonly property string place: Config.weatherPlace.trim()
    readonly property bool wanted: Config.loaded && place.length > 0
    property bool ready: false
    property string where: ""
    property string problem: ""
    property int temperature: 0
    property int code: 0
    // [{ day, min, max, code }]
    property var days: []

    // WMO weather codes -> icon and words.
    function icon(c) {
        return c === 0 ? "clear_day" : c <= 2 ? "partly_cloudy_day" : c === 3 ? "cloud" : c <= 48 ? "foggy"
            : c <= 57 ? "rainy_light" : c <= 67 ? "rainy" : c <= 77 ? "weather_snowy" : c <= 82 ? "rainy"
            : c <= 86 ? "weather_snowy" : "thunderstorm"
    }
    function words(c) {
        return c === 0 ? "Clear" : c <= 2 ? "Partly cloudy" : c === 3 ? "Cloudy" : c <= 48 ? "Fog"
            : c <= 57 ? "Drizzle" : c <= 67 ? "Rain" : c <= 77 ? "Snow" : c <= 82 ? "Showers"
            : c <= 86 ? "Snow showers" : "Thunderstorm"
    }

    function refresh() { if (wanted) fetch.running = true }
    onWantedChanged: { ready = false; problem = ""; if (wanted) refresh() }
    onPlaceChanged: { ready = false; later.restart() }
    Timer { id: later; interval: 1500; onTriggered: root.refresh() }
    Timer { interval: 1800000; running: root.wanted; repeat: true; onTriggered: root.refresh() }

    Process {
        id: fetch
        // The place name is passed as data, never as part of the command.
        command: ["sh", "-c", `
g=$(curl -fsS --max-time 10 --get --data-urlencode "name=$1" --data "count=1&format=json" https://geocoding-api.open-meteo.com/v1/search) || { echo "error=offline"; exit 0; }
lat=$(printf '%s' "$g" | sed -n 's/.*"latitude":\\([-0-9.]*\\).*/\\1/p' | head -n 1)
lon=$(printf '%s' "$g" | sed -n 's/.*"longitude":\\([-0-9.]*\\).*/\\1/p' | head -n 1)
name=$(printf '%s' "$g" | sed -n 's/.*"results":\\[{"id":[0-9]*,"name":"\\([^"]*\\)".*/\\1/p' | head -n 1)
[ -n "$lat" ] && [ -n "$lon" ] || { echo "error=unknown"; exit 0; }
echo "name=$name"
curl -fsS --max-time 10 "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=4" || echo "error=offline"`, "sh", root.place]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.includes("error=unknown")) { root.problem = "Place not found"; root.ready = false; return }
                if (text.includes("error=offline")) { root.problem = "No connection"; return }
                try {
                    const nl = text.indexOf("\n")
                    const data = JSON.parse(text.slice(nl + 1))
                    root.where = text.slice(0, nl).replace("name=", "") || root.place
                    root.temperature = Math.round(data.current.temperature_2m)
                    root.code = data.current.weather_code
                    root.days = data.daily.time.map((t, i) => ({
                        day: Qt.formatDate(new Date(t), "ddd"),
                        min: Math.round(data.daily.temperature_2m_min[i]),
                        max: Math.round(data.daily.temperature_2m_max[i]),
                        code: data.daily.weather_code[i]
                    }))
                    root.problem = ""
                    root.ready = true
                } catch (e) { root.problem = "No weather data" }
            }
        }
    }
}
