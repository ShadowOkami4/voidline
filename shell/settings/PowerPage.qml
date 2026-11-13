import Quickshell
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.compositor
import qs.services
import qs.widgets

ColumnLayout {
    id: page
    spacing: 24

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: Battery.available
    property string armed: ""

    function duration(seconds) {
        if (!seconds || seconds <= 0) return ""
        const h = Math.floor(seconds / 3600), m = Math.round((seconds % 3600) / 60)
        return h > 0 ? h + " h " + m + " min" : m + " min"
    }
    readonly property string estimate: !hasBattery ? ""
        : (Battery.charging ? (duration(battery.timeToFull) ? duration(battery.timeToFull) + " until full" : "Plugged in")
            : (duration(battery.timeToEmpty) ? duration(battery.timeToEmpty) + " left" : "On battery"))

    Timer { id: disarm; interval: 3000; onTriggered: page.armed = "" }
    function power(action) {
        if (armed !== action) { armed = action; disarm.restart(); return }
        armed = ""
        if (action === "logout") Compositor.quit()
        else Quickshell.execDetached(["systemctl", action])
    }

    // ---- battery hero ---------------------------------------------------------------
    Rectangle {
        visible: page.hasBattery
        Layout.fillWidth: true
        implicitHeight: 150
        radius: Theme.cornerXXL
        color: Theme.primaryContainer

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 28
            anchors.rightMargin: 28
            spacing: 20

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label {
                    text: Battery.percent + "%"
                    font.pixelSize: 64
                    font.weight: Font.Black
                    font.letterSpacing: -2
                    color: Theme.inkOnPrimaryContainer
                }
                Label {
                    text: page.estimate
                    font.weight: Font.DemiBold
                    color: Theme.inkOnPrimaryContainer
                    opacity: 0.85
                }
            }

            // Thick level bar
            Rectangle {
                Layout.preferredWidth: 260
                implicitHeight: 56
                radius: Theme.cornerL
                color: Theme.alpha(Theme.inkOnPrimaryContainer, 0.16)
                Rectangle {
                    width: Math.max(parent.height * 0.5, parent.width * Battery.percent / 100)
                    height: parent.height
                    radius: parent.radius
                    color: Battery.percent <= 15 && !Battery.charging ? Theme.error : Theme.primary
                    Behavior on width { Spring { duration: Motion.spatialSlow; easing.bezierCurve: Motion.spatialSlowCurve } }
                    MIcon {
                        anchors.centerIn: parent
                        visible: Battery.charging
                        icon: "bolt"
                        filled: true
                        size: 28
                        color: Theme.inkOnPrimary
                    }
                }
            }
        }
    }

    // ---- power mode --------------------------------------------------------------------
    SegGroup {
        title: "Power mode"
        SegItem {
            icon: "bolt"
            hue: 1
            lobes: 8
            title: PowerProfiles.profile === PowerProfile.PowerSaver ? "Power saver"
                : (PowerProfiles.profile === PowerProfile.Performance ? "Performance" : "Balanced")
            description: PowerProfiles.profile === PowerProfile.PowerSaver ? "Longer battery life, lower speed."
                : (PowerProfiles.profile === PowerProfile.Performance ? "Full speed, more heat and fan noise." : "A sensible mix for everyday use.")
            extra: Choice {
                Layout.fillWidth: true
                segmentWidth: (width - 8) / options.length
                value: PowerProfiles.profile
                options: PowerProfiles.hasPerformanceProfile ? [
                    { value: PowerProfile.PowerSaver, label: "Power saver" },
                    { value: PowerProfile.Balanced, label: "Balanced" },
                    { value: PowerProfile.Performance, label: "Performance" }
                ] : [
                    { value: PowerProfile.PowerSaver, label: "Power saver" },
                    { value: PowerProfile.Balanced, label: "Balanced" }
                ]
                onPicked: v => PowerProfiles.profile = v
            }
        }
    }

    SegGroup {
        visible: page.hasBattery
        title: "Battery"
        SegItem {
            icon: "battery_profile"
            hue: 2
            lobes: 4
            title: "Battery health"
            description: page.battery.healthSupported ? Math.round(page.battery.healthPercentage) + "% of original capacity" : "Not reported by this battery"
        }
        SegItem {
            icon: "electric_meter"
            hue: 3
            lobes: 0
            title: Battery.charging ? "Charging at" : "Using"
            description: Math.abs(page.battery.changeRate).toFixed(1) + " W"
        }
    }

    // ---- session -----------------------------------------------------------------------
    SegGroup {
        title: "Session"
        Repeater {
            model: [
                { id: "suspend", icon: "bedtime", label: "Sleep", text: "Suspend to memory.", hue: 4 },
                { id: "logout", icon: "logout", label: "Log out", text: "Close the session and all apps.", hue: 5 },
                { id: "reboot", icon: "restart_alt", label: "Restart", text: "", hue: 0 },
                { id: "poweroff", icon: "power_settings_new", label: "Shut down", text: "", hue: 3 }
            ]
            SegItem {
                required property var modelData
                readonly property bool hot: page.armed === modelData.id
                icon: hot ? "check" : modelData.icon
                hue: modelData.hue
                lobes: 5
                title: hot ? "Click again to " + modelData.label.toLowerCase() : modelData.label
                description: modelData.text
                clickable: true
                color: hot ? Theme.errorContainer : Theme.surfaceContainerHigh
                onClicked: page.power(modelData.id)
            }
        }
    }
}
