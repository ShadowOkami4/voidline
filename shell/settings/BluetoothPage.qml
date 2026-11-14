import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.services
import qs.widgets

ColumnLayout {
    id: page
    spacing: 24

    readonly property var adapter: Bt.adapter
    readonly property bool btOn: Bt.on
    readonly property var mine: Bt.mine
    readonly property var nearby: Bt.nearby

    // Search for new devices only while this page is open.
    Component.onCompleted: if (btOn) adapter.discovering = true
    Component.onDestruction: if (adapter && adapter.discovering) adapter.discovering = false
    onBtOnChanged: if (btOn) adapter.discovering = true

    function glyph(d) { return Bt.glyph(d) }

    Label {
        visible: !page.adapter
        text: "No Bluetooth adapter found."
        color: Theme.inkMuted
    }

    SegGroup {
        visible: !!page.adapter
        SegItem {
            icon: page.btOn ? "bluetooth" : "bluetooth_disabled"
            hue: 0
            lobes: 8
            title: "Bluetooth"
            description: Bt.switching ? "Switching on…" : (!page.btOn ? "Off" : (page.adapter.discovering ? "On  ·  searching for devices" : "On"))
            Toggle { checked: page.btOn; onToggled: v => Bt.setOn(v) }
        }
        SegItem {
            visible: page.btOn
            icon: "visibility"
            hue: 1
            lobes: 4
            title: "Visible to other devices"
            description: "As \"" + (page.adapter ? page.adapter.name : "") + "\""
            Toggle {
                checked: !!page.adapter && page.adapter.discoverable
                onToggled: v => page.adapter.discoverable = v
            }
        }
    }

    SegGroup {
        visible: page.btOn && page.mine.length > 0
        title: "Your devices"
        Repeater {
            model: page.mine
            SegItem {
                id: dev
                required property var modelData
                icon: page.glyph(modelData)
                hue: modelData.connected ? 0 : 2
                lobes: modelData.connected ? 8 : 0
                title: modelData.name
                description: (modelData.connected ? "Connected" : "Not connected")
                    + (modelData.batteryAvailable ? "  ·  " + Math.round(modelData.battery * 100) + "% battery" : "")

                Row {
                    spacing: 6
                    IconBtn {
                        icon: "delete"
                        size: 38
                        onClicked: dev.modelData.forget()
                    }
                    Pressable {
                        width: 116
                        height: 40
                        color: dev.modelData.connected ? Theme.surfaceContainerHighest : Theme.primary
                        tint: dev.modelData.connected ? Theme.ink : Theme.inkOnPrimary
                        onClicked: dev.modelData.connected ? dev.modelData.disconnect() : dev.modelData.connect()
                        Label {
                            anchors.centerIn: parent
                            text: dev.modelData.connected ? "Disconnect" : "Connect"
                            font.pixelSize: Theme.textLabel + 1
                            font.weight: Font.DemiBold
                            color: dev.modelData.connected ? Theme.ink : Theme.inkOnPrimary
                        }
                    }
                }
            }
        }
    }

    SegGroup {
        visible: page.btOn
        title: "Nearby"

        Label {
            Layout.margins: 18
            visible: page.nearby.length === 0
            text: "Searching... Put the device you want to add into pairing mode."
            color: Theme.inkMuted
        }

        Repeater {
            model: page.nearby
            SegItem {
                id: near
                required property var modelData
                icon: page.glyph(modelData)
                hue: 3
                lobes: 4
                title: modelData.name
                description: modelData.pairing ? "Pairing..." : ""
                Pressable {
                    width: 92
                    height: 40
                    color: Theme.surfaceContainerHighest
                    enabledInput: !near.modelData.pairing
                    onClicked: near.modelData.pair()
                    Label { anchors.centerIn: parent; text: "Pair"; font.pixelSize: Theme.textLabel + 1; font.weight: Font.DemiBold }
                }
            }
        }
    }
}
