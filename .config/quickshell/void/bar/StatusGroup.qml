import Quickshell
import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../services"

Item {
    id: root

    property bool panelActive: false
    signal clicked

    implicitWidth: content.implicitWidth + 16
    implicitHeight: 36
    scale: tap.pressed ? 0.98 : 1

    function networkIcon() {
        if (SystemActionService.hotspotActive)
            return "wifi_tethering"
        if (ConnectivityService.ethernetConnected)
            return "lan"
        if (ConnectivityService.wifiConnected)
            return "wifi"
        if (ConnectivityService.wifiEnabled)
            return "wifi_find"
        return "signal_wifi_off"
    }

    // Pill-shaped status chip; tonal accent container while its panel is open.
    Rectangle {
        anchors.fill: parent
        radius: tap.pressed ? Metrics.radiusS : height / 2
        color: root.panelActive ? Theme.accentContainer
            : (hover.hovered ? Theme.surfaceHover : "transparent")

        Behavior on color { ColorAnimation { duration: Motion.effectsFastDuration } }
        Behavior on radius {
            NumberAnimation {
                duration: Motion.springFast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spatialFast
            }
        }
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 9

        MaterialIcon {
            text: root.networkIcon()
            size: 17
            color: SystemActionService.hotspotActive
                || ConnectivityService.ethernetConnected
                || ConnectivityService.wifiConnected
                ? Theme.accent : Theme.textMuted
        }

        MaterialIcon {
            text: AudioService.outputMuted ? "volume_off" : "volume_up"
            size: 17
            color: AudioService.outputMuted ? Theme.textMuted : Theme.accent
        }

        MaterialIcon {
            visible: ConnectivityService.bluetoothAvailable
            text: ConnectivityService.bluetoothEnabled ? "bluetooth" : "bluetooth_disabled"
            size: 17
            color: ConnectivityService.bluetoothEnabled ? Theme.accent : Theme.textMuted
        }

        RowLayout {
            visible: PowerService.available
            spacing: 3

            MaterialIcon {
                text: PowerService.icon
                size: 17
                color: PowerService.percentage <= 15 ? Theme.danger : Theme.accent
            }

            Text {
                text: PowerService.percentage + "%"
                color: root.panelActive ? Theme.accentContainerInk : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }
    }

    HoverHandler { id: hover }
    TapHandler {
        id: tap
        onTapped: root.clicked()
    }

    Behavior on scale { NumberAnimation { duration: Motion.instant } }
}
