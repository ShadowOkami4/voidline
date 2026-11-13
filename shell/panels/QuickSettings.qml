import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.compositor
import qs.services
import qs.widgets

PanelSurface {
    id: root

    open: Shell.panel === "quick"
    anchor: Style.quickAnchor
    panelWidth: 420
    panelHeight: column.implicitHeight + 40

    readonly property var adapter: Bluetooth.defaultAdapter
    property string armed: ""

    onOpenChanged: armed = ""
    Timer { id: disarm; interval: 3000; onTriggered: root.armed = "" }

    // Power actions need a second click within three seconds.
    function power(action) {
        if (armed !== action) { armed = action; disarm.restart(); return }
        armed = ""
        Shell.close()
        if (action === "logout") Compositor.quit()
        else Quickshell.execDetached(["systemctl", action])
    }

    ColumnLayout {
        id: column
        x: 20
        y: 20
        width: parent.width - 40
        spacing: 14

        // Header: style switcher + power
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            // Connected button group (M3 Expressive): one container, the
            // selected segment becomes a pill.
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 44
                radius: height / 2
                color: Theme.surfaceContainerHighest

                Row {
                    anchors.fill: parent
                    anchors.margins: 4
                    Repeater {
                        model: [
                            { id: "voidline", label: "Voidline" },
                            { id: "windows", label: "Windows" },
                            { id: "macos", label: "macOS" }
                        ]
                        Pressable {
                            id: seg
                            required property var modelData
                            readonly property bool current: Config.style === modelData.id
                            width: parent.width / 3
                            height: parent.height
                            color: current ? Theme.primary : "transparent"
                            tint: current ? Theme.inkOnPrimary : Theme.ink
                            restRadius: current ? Theme.cornerFull : Theme.cornerS
                            Behavior on color { Tint {} }
                            onClicked: Config.style = modelData.id
                            Label {
                                anchors.centerIn: parent
                                text: seg.modelData.label
                                font.pixelSize: Theme.textLabel
                                font.weight: Font.DemiBold
                                color: seg.current ? Theme.inkOnPrimary : Theme.inkMuted
                            }
                        }
                    }
                }
            }

            Repeater {
                model: [
                    { id: "logout", icon: "logout" },
                    { id: "reboot", icon: "restart_alt" },
                    { id: "poweroff", icon: "power_settings_new" }
                ]
                IconBtn {
                    required property var modelData
                    readonly property bool hot: root.armed === modelData.id
                    icon: hot ? "check" : modelData.icon
                    size: 44
                    tonal: true
                    color: hot ? Theme.errorContainer : Theme.surfaceContainerHighest
                    restRadius: hot ? Theme.cornerM : Theme.cornerFull
                    onClicked: root.power(modelData.id)
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            Tile {
                Layout.fillWidth: true
                icon: Network.icon
                title: Network.type === "ethernet" ? "Ethernet" : "Wi-Fi"
                subtitle: Network.label
                active: Network.connected
                enabledInput: Network.available
                opacity: Network.available ? 1 : 0.5
                onClicked: Network.setWifi(!Network.wifiEnabled)
            }
            Tile {
                Layout.fillWidth: true
                icon: root.adapter && root.adapter.enabled ? "bluetooth" : "bluetooth_disabled"
                title: "Bluetooth"
                subtitle: !root.adapter ? "Unavailable" : (root.adapter.enabled ? "On" : "Off")
                active: !!root.adapter && root.adapter.enabled
                enabledInput: !!root.adapter
                opacity: root.adapter ? 1 : 0.5
                onClicked: root.adapter.enabled = !root.adapter.enabled
            }
            Tile {
                Layout.fillWidth: true
                icon: Config.doNotDisturb ? "notifications_off" : "notifications"
                title: "Do not disturb"
                subtitle: Config.doNotDisturb ? "On" : "Off"
                active: Config.doNotDisturb
                onClicked: Config.doNotDisturb = !Config.doNotDisturb
            }
            Tile {
                Layout.fillWidth: true
                icon: Config.dark ? "dark_mode" : "light_mode"
                title: "Dark theme"
                subtitle: Config.dark ? "On" : "Off"
                active: Config.dark
                onClicked: Config.dark = !Config.dark
            }
        }

        ExpSlider {
            Layout.fillWidth: true
            icon: Audio.icon
            value: Audio.volume
            onMoved: v => Audio.setVolume(v)
        }
        ExpSlider {
            Layout.fillWidth: true
            visible: Brightness.available
            icon: "brightness_medium"
            value: Brightness.value
            accent: Theme.tertiary
            onMoved: v => Brightness.set(v)
        }

        // Notifications
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Label {
                Layout.fillWidth: true
                text: "Notifications"
                font.pixelSize: Theme.textTitle
                font.weight: Font.Bold
            }
            IconBtn {
                visible: Notifs.list.length > 0
                icon: "clear_all"
                size: 32
                onClicked: Notifs.clear()
            }
        }

        Label {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.bottomMargin: 10
            visible: Notifs.list.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: "All quiet"
            color: Theme.inkMuted
        }

        ListView {
            Layout.fillWidth: true
            implicitHeight: Math.min(contentHeight, 280)
            visible: count > 0
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: Notifs.list
            delegate: NotificationCard {
                required property var modelData
                width: ListView.view.width
                notification: modelData
                onDismissed: modelData.dismiss()
            }
        }
    }
}
