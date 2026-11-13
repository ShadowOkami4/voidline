pragma Singleton

import Quickshell
import Quickshell.Services.UPower
import QtQuick

Singleton {
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
}
