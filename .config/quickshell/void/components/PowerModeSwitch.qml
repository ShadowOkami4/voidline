import QtQuick
import QtQuick.Layouts
import "../core"
import "../services"

Item {
    id: root

    property bool compact: false
    readonly property int profileIndex: PowerService.profileMode === "saver"
        ? 0 : (PowerService.profileMode === "performance" ? 2 : 1)
    readonly property string profileLabel: PowerService.profileMode === "saver"
        ? I18n.tr("power.saver")
        : (PowerService.profileMode === "performance"
            ? I18n.tr("power.performance") : I18n.tr("power.balanced"))

    implicitHeight: compact ? 80 : 70

    Rectangle {
        id: selector
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: root.compact ? 58 : parent.height
        radius: Theme.radiusLarge
        color: Theme.surfaceLow

        readonly property real gap: root.compact ? 3 : 5
        readonly property real inset: root.compact ? 4 : 7
        readonly property real segmentWidth: (width - inset * 2 - gap * 2) / 3

        Rectangle {
            x: selector.inset + root.profileIndex * (selector.segmentWidth + selector.gap)
            y: selector.inset
            width: selector.segmentWidth
            height: selector.height - selector.inset * 2
            radius: Theme.radiusMedium
            color: Theme.accentContainer

            Behavior on x {
                NumberAnimation {
                    duration: Motion.selectionSlide
                    easing.type: Motion.expressiveCurve
                    easing.overshoot: 0.28
                }
            }
        }

        RowLayout {
            anchors {
                fill: parent
                margins: selector.inset
            }
            spacing: selector.gap

            Repeater {
                model: [
                    { mode: "saver", icon: "eco", label: I18n.tr("power.saver") },
                    { mode: "balanced", icon: "balance", label: I18n.tr("power.balanced") },
                    { mode: "performance", icon: "bolt", label: I18n.tr("power.performance") }
                ]

                delegate: Item {
                    id: segment
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    opacity: modelData.mode !== "performance" || PowerService.performanceAvailable ? 1 : 0.35
                    scale: segmentTap.pressed ? 0.94 : 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 5

                        MaterialIcon {
                            text: segment.modelData.icon
                            size: root.compact ? 19 : 18
                            color: PowerService.profileMode === segment.modelData.mode ? Theme.accent : Theme.textMuted
                        }

                        Text {
                            visible: !root.compact
                            text: segment.modelData.label
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: PowerService.profileMode === segment.modelData.mode ? Font.Bold : Font.Medium
                        }
                    }

                    HoverHandler { id: segmentHover }
                    TapHandler {
                        id: segmentTap
                        enabled: !PowerService.profileChanging
                            && (segment.modelData.mode !== "performance" || PowerService.performanceAvailable)
                        onTapped: PowerService.setProfile(segment.modelData.mode)
                    }

                    Behavior on scale { NumberAnimation { duration: Motion.instant; easing.type: Motion.standardCurve } }
                }
            }
        }
    }

    Text {
        visible: root.compact
        anchors {
            top: selector.bottom
            topMargin: 4
            left: parent.left
            right: parent.right
        }
        text: I18n.tr("power.profile", { mode: root.profileLabel })
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 9
        font.weight: Font.Bold
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }
}
