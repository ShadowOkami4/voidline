pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Deliberately small: connection state via NetworkManager's `nmcli monitor`
// (event driven, no polling). Without NetworkManager the shell still works
// and simply shows a neutral icon. Full Wi-Fi management comes with Settings.
Singleton {
    id: root

    property bool available: false
    property string type: ""        // "wifi" | "ethernet" | ""
    property string name: ""
    property bool wifiEnabled: false
    readonly property bool connected: type.length > 0
    readonly property string icon: !available ? "language"
        : (type === "ethernet" ? "lan" : (type === "wifi" ? "wifi" : (wifiEnabled ? "wifi_find" : "wifi_off")))
    readonly property string label: !available ? "Network" : (connected ? name : (wifiEnabled ? "Not connected" : "Wi-Fi off"))

    function setWifi(on) {
        if (!available) return
        wifiEnabled = on
        Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"])
    }
    function refresh() { query.running = true }

    Process {
        id: query
        running: true
        command: ["sh", "-c", "command -v nmcli >/dev/null && nmcli -t general status >/dev/null 2>&1 || exit 3; echo \"radio:$(nmcli radio wifi)\"; nmcli -t -f TYPE,NAME connection show --active"]
        stdout: StdioCollector {
            onStreamFinished: {
                let type = "", name = ""
                for (const line of text.split("\n")) {
                    if (line.startsWith("radio:")) root.wifiEnabled = line.endsWith("enabled")
                    else if (line.startsWith("802-3-ethernet:")) { type = "ethernet"; name = line.slice(15) }
                    else if (line.startsWith("802-11-wireless:") && type !== "ethernet") { type = "wifi"; name = line.slice(16) }
                }
                root.type = type
                root.name = name
            }
        }
        onExited: code => {
            root.available = code === 0
            if (code === 0) monitor.running = true
        }
    }

    Process {
        id: monitor
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: debounce.restart() }
    }

    Timer { id: debounce; interval: 400; onTriggered: root.refresh() }
}
