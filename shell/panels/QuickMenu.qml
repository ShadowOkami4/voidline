import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.services
import qs.widgets

// The mini menus of quick settings: Wi-Fi networks and Bluetooth devices,
// opened with the arrow on their tiles. Enough for the everyday cases (join a
// known network, connect your headphones); everything else is one tap away in
// Settings.
ColumnLayout {
    id: root

    // "wifi" | "bluetooth"
    property string kind: "wifi"
    signal back()

    readonly property bool wifiKind: kind === "wifi"
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var networks: wifi ? wifi.networks.values.slice().sort((a, b) =>
        (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength)).filter(n => n.name.length > 0) : []
    readonly property bool switchedOn: wifiKind ? Networking.wifiEnabled : Bt.on

    // Scan only while the menu is open.
    onVisibleChanged: {
        if (wifi) wifi.scannerEnabled = visible && wifiKind
        if (Bt.adapter && Bt.on && !wifiKind) Bt.adapter.discovering = visible
    }

    function bars(strength) {
        return strength > 0.75 ? "signal_wifi_4_bar" : (strength > 0.5 ? "network_wifi_3_bar"
            : (strength > 0.25 ? "network_wifi_2_bar" : "network_wifi_1_bar"))
    }

    spacing: 12

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        IconBtn { icon: "arrow_back"; size: 44; tonal: true; onClicked: root.back() }
        Label {
            Layout.fillWidth: true
            leftPadding: 6
            text: root.wifiKind ? "Wi-Fi" : "Bluetooth"
            font.pixelSize: Theme.textHeadline
            font.weight: Font.Black
        }
        Toggle {
            checked: root.switchedOn
            onToggled: v => root.wifiKind ? (Networking.wifiEnabled = v) : Bt.setOn(v)
        }
    }

    Label {
        Layout.fillWidth: true
        Layout.topMargin: 10
        Layout.bottomMargin: 10
        visible: !root.switchedOn || list.count === 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        color: Theme.inkMuted
        text: !root.switchedOn ? (root.wifiKind ? "Wi-Fi is off" : (Bt.switching ? "Switching on…" : "Bluetooth is off"))
            : (root.wifiKind ? "Looking for networks…" : "No devices yet. Add one in Bluetooth settings.")
    }

    ListView {
        id: list
        Layout.fillWidth: true
        implicitHeight: Math.min(contentHeight, 330)
        visible: root.switchedOn && count > 0
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        model: !root.switchedOn ? [] : (root.wifiKind ? root.networks : Bt.mine.concat(Bt.nearby))

        delegate: Pressable {
            id: row
            required property var modelData
            readonly property bool wifiRow: root.wifiKind
            readonly property bool live: !!modelData.connected
            readonly property bool secured: wifiRow && modelData.security !== WifiSecurityType.Open
            readonly property bool mine: wifiRow ? !!modelData.known : !!(modelData.paired || modelData.bonded || modelData.connected)
            readonly property bool busy: wifiRow ? !!modelData.stateChanging : !!modelData.pairing

            width: list.width
            height: 56
            color: live ? Theme.secondaryContainer : Theme.surfaceContainerHighest
            restRadius: live ? Theme.cornerFull : Theme.cornerL
            pressedRadius: Theme.cornerM
            Behavior on color { Tint {} }
            onClicked: {
                if (live) { modelData.disconnect(); return }
                if (wifiRow) {
                    if (mine || !secured) modelData.connect()
                    else { Shell.openSettings("network") }        // needs a password
                } else {
                    if (mine) modelData.connect()
                    else modelData.pair()
                }
            }

            MIcon {
                id: glyph
                x: 18
                anchors.verticalCenter: parent.verticalCenter
                icon: row.wifiRow ? root.bars(row.modelData.signalStrength) : Bt.glyph(row.modelData)
                filled: row.live
                size: 22
                color: row.live ? Theme.inkOnSecondaryContainer : Theme.ink
            }
            Column {
                anchors.left: glyph.right
                anchors.leftMargin: 14
                anchors.right: tail.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                Label {
                    width: parent.width
                    elide: Text.ElideRight
                    text: row.modelData.name
                    font.weight: row.live ? Font.Bold : Font.DemiBold
                    color: row.live ? Theme.inkOnSecondaryContainer : Theme.ink
                }
                Label {
                    width: parent.width
                    elide: Text.ElideRight
                    font.pixelSize: Theme.textLabelS
                    color: row.live ? Theme.inkOnSecondaryContainer : Theme.inkMuted
                    text: row.busy ? (row.wifiRow ? "Connecting…" : "Pairing…")
                        : (row.live ? "Connected  ·  tap to disconnect"
                            : (row.wifiRow ? (row.mine ? "Saved" : (row.secured ? "Needs a password" : "Open"))
                                : (row.mine ? "Tap to connect" : "New  ·  tap to pair")))
                }
            }
            MIcon {
                id: tail
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                visible: row.live || (row.secured && !row.mine)
                icon: row.live ? "check" : "lock"
                size: 18
                color: row.live ? Theme.inkOnSecondaryContainer : Theme.inkMuted
            }
        }
    }

    Pressable {
        Layout.fillWidth: true
        implicitHeight: 48
        color: Theme.surfaceContainerHigh
        onClicked: Shell.openSettings(root.wifiKind ? "network" : "bluetooth")
        Label {
            anchors.centerIn: parent
            text: root.wifiKind ? "Network settings" : "Bluetooth settings"
            font.weight: Font.DemiBold
        }
    }
}
