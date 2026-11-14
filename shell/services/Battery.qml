pragma Singleton

import Quickshell
import Quickshell.Services.UPower
import Quickshell.Io
import QtQuick
import qs.core

Singleton {
    id: root
    readonly property var device: UPower.displayDevice
    readonly property bool available: !!device && device.isLaptopBattery
    readonly property int percent: available ? Math.round(device.percentage * 100) : 0
    readonly property bool charging: available && !UPower.onBattery
    readonly property bool onBattery: UPower.onBattery
    readonly property string icon: {
        if (charging) return "battery_charging_full"
        const steps = ["battery_0_bar", "battery_1_bar", "battery_2_bar", "battery_3_bar",
            "battery_4_bar", "battery_5_bar", "battery_6_bar", "battery_full"]
        return steps[Math.min(7, Math.floor(percent / 100 * 8))]
    }

    // ---- low battery warnings: once at 20 %, once at 10 %, per discharge ------------------
    property int warned: 100
    onChargingChanged: if (charging) warned = 100
    onPercentChanged: {
        if (!available || charging || !Config.loaded || !Config.batteryWarnings) return
        for (const level of [10, 20]) {
            if (percent <= level && warned > level) {
                warned = level
                Quickshell.execDetached(["notify-send", "-a", "Voidline", "-u", level === 10 ? "critical" : "normal",
                    "-i", "battery-caution", level === 10 ? "Battery very low" : "Battery low",
                    percent + "% left. Plug in the charger."])
                break
            }
        }
    }

    // ---- charge limit (battery health) ------------------------------------------------------
    // Lenovo laptops call it "conservation mode": the battery stops at about
    // 60 % (some models 80 %), which makes it last more years when the laptop
    // is mostly plugged in. Changing it needs the administrator password.
    property string limitPath: ""
    property bool limitOn: false
    readonly property bool limitAvailable: limitPath.length > 0
    function readLimit() { limitRead.running = true }
    function setLimit(v) {
        if (!limitAvailable) return
        limitWrite.command = ["pkexec", "sh", "-c", "echo \"$1\" > \"$2\"", "sh", v ? "1" : "0", limitPath]
        limitWrite.running = true
    }
    Process {
        id: limitRead
        running: true
        command: ["sh", "-c", "f=$(find /sys/bus/platform/drivers/ideapad_acpi/ /sys/devices -maxdepth 6 -name conservation_mode 2>/dev/null | head -n 1); [ -n \"$f\" ] && echo \"$f $(cat \"$f\")\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(" ")
                if (p.length === 2) { root.limitPath = p[0]; root.limitOn = p[1] === "1" }
            }
        }
    }
    Process { id: limitWrite; onExited: root.readLimit() }
}
