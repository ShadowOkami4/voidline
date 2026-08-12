import QtQuick
import QtQuick.Layouts
import "../components"
import "../core"
import "../services"

Item {
    id: root

    property bool active: false
    signal back

    function transferLabel(value, suffix) {
        const amount = Number(value) || 0
        if (amount >= 1024)
            return (amount / 1024).toFixed(1) + " MiB/s " + suffix
        return Math.round(amount) + " KiB/s " + suffix
    }

    onActiveChanged: PowerService.monitoring = active
    Component.onDestruction: PowerService.monitoring = false

    component ProcessList: ColumnLayout {
        id: processList
        property string title: ""
        property string valueKey: "cpu"
        property var processes: []

        spacing: Metrics.spaceXS
        Text {
            Layout.fillWidth: true
            text: processList.title
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Metrics.textTitle
            font.weight: Font.DemiBold
        }
        Repeater {
            model: processList.processes
            Rectangle {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(34 * Metrics.scale)
                radius: Metrics.radiusS
                color: Theme.surfaceLow
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Metrics.spaceS
                    anchors.rightMargin: Metrics.spaceS
                    spacing: Metrics.spaceS
                    Text {
                        Layout.fillWidth: true
                        text: modelData.name
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Metrics.textSupporting
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                    Text {
                        text: Number(modelData[processList.valueKey]).toFixed(1) + "%"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Metrics.textSupporting
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.spaceS

        PanelHeader {
            Layout.fillWidth: true
            title: I18n.tr("resources.title")
            subtitle: I18n.tr("resources.live", { uptime: PowerService.uptimeLabel })
            onBack: root.back()
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: resourceContent.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: resourceContent
                width: parent.width
                spacing: Metrics.spaceM

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(116 * Metrics.scale)
                    radius: Metrics.cardRadius
                    color: Theme.accentContainer

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Metrics.cardPaddingWide
                        spacing: Metrics.spaceL

                        Item {
                            Layout.preferredWidth: Math.round(84 * Metrics.scale)
                            Layout.preferredHeight: Math.round(84 * Metrics.scale)
                            Canvas {
                                id: batteryRing
                                anchors.fill: parent
                                antialiasing: true
                                onPaint: {
                                    const context = getContext("2d")
                                    const center = width / 2
                                    const radius = width / 2 - 7
                                    context.reset()
                                    context.lineWidth = 9
                                    context.lineCap = "round"
                                    context.strokeStyle = Theme.surfaceHover
                                    context.beginPath()
                                    context.arc(center, center, radius, 0, Math.PI * 2)
                                    context.stroke()
                                    context.strokeStyle = PowerService.percentage <= 15
                                        ? Theme.danger : Theme.accent
                                    context.beginPath()
                                    context.arc(center, center, radius, -Math.PI / 2,
                                        -Math.PI / 2 + Math.PI * 2
                                            * (PowerService.available ? PowerService.percentage : 100) / 100)
                                    context.stroke()
                                }
                                Connections {
                                    target: PowerService
                                    function onPercentageChanged() { batteryRing.requestPaint() }
                                }
                                Component.onCompleted: requestPaint()
                            }
                            Text {
                                anchors.centerIn: parent
                                text: PowerService.available ? PowerService.percentage + "%" : "AC"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Metrics.textTitle
                                font.weight: Font.Bold
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Metrics.spaceXS
                            Text {
                                Layout.fillWidth: true
                                text: PowerService.charging
                                    ? I18n.tr("resources.charging") : PowerService.remainingLabel
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Metrics.textHeader
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: PowerService.watts.toFixed(1) + " W · "
                                    + (PowerService.batteryHealth > 0
                                        ? PowerService.batteryHealth + "% " + I18n.tr("resources.health")
                                        : I18n.tr("resources.healthUnknown"))
                                    + " · " + PowerService.cycleCount + " " + I18n.tr("resources.cycles")
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Metrics.textSupporting
                                elide: Text.ElideRight
                            }
                            Text {
                                text: PowerService.profileMode
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Metrics.textSupporting
                                font.weight: Font.DemiBold
                                font.capitalization: Font.Capitalize
                            }
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: Metrics.spaceS
                    rowSpacing: Metrics.spaceS

                    MetricCard {
                        Layout.fillWidth: true
                        icon: "memory"
                        label: I18n.tr("resources.cpu")
                        value: Math.round(PowerService.cpuUsage) + "%"
                        detail: PowerService.cpuFrequencyGhz.toFixed(2) + " GHz · "
                            + (PowerService.cpuTemperature > 0
                                ? Math.round(PowerService.cpuTemperature) + "°C" : "—")
                        progress: PowerService.cpuUsage / 100
                    }
                    MetricCard {
                        Layout.fillWidth: true
                        icon: "memory_alt"
                        label: I18n.tr("resources.memory")
                        value: PowerService.memoryUsedGiB.toFixed(1) + " GiB"
                        detail: (PowerService.memoryTotalGiB - PowerService.memoryUsedGiB).toFixed(1)
                            + " GiB " + I18n.tr("resources.available")
                        progress: PowerService.memoryUsage / 100
                        containerColor: Theme.secondaryContainer
                        accentColor: Theme.secondary
                    }
                    MetricCard {
                        Layout.fillWidth: true
                        icon: "developer_board"
                        label: I18n.tr("resources.gpu")
                        value: Math.round(PowerService.gpuUsage) + "%"
                        detail: PowerService.gpuMemoryTotalGiB > 0
                            ? PowerService.gpuMemoryUsedGiB.toFixed(1) + " / "
                                + PowerService.gpuMemoryTotalGiB.toFixed(1) + " GiB"
                            : (PowerService.gpuTemperature > 0
                                ? Math.round(PowerService.gpuTemperature) + "°C" : "—")
                        progress: PowerService.gpuUsage / 100
                        containerColor: Theme.tertiaryContainer
                        accentColor: Theme.tertiary
                    }
                    MetricCard {
                        Layout.fillWidth: true
                        icon: "hard_drive"
                        label: I18n.tr("resources.storage")
                        value: Math.round(PowerService.diskUsage) + "%"
                        detail: "↓ " + PowerService.diskReadMiB.toFixed(1)
                            + " · ↑ " + PowerService.diskWriteMiB.toFixed(1) + " MiB/s"
                        progress: PowerService.diskUsage / 100
                    }
                    MetricCard {
                        Layout.fillWidth: true
                        icon: "swap_vert"
                        label: I18n.tr("resources.swap")
                        value: Math.round(PowerService.swapUsage) + "%"
                        detail: I18n.tr("resources.load", { value: PowerService.loadAverage.toFixed(2) })
                        progress: PowerService.swapUsage / 100
                        containerColor: Theme.secondaryContainer
                        accentColor: Theme.secondary
                    }
                    MetricCard {
                        Layout.fillWidth: true
                        icon: "network_check"
                        label: PowerService.networkInterface.length > 0
                            ? PowerService.networkInterface : I18n.tr("resources.network")
                        value: "↓ " + root.transferLabel(PowerService.networkDownloadKiB, "")
                        detail: "↑ " + root.transferLabel(PowerService.networkUploadKiB, "")
                        containerColor: Theme.tertiaryContainer
                        accentColor: Theme.tertiary
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(96 * Metrics.scale)
                    radius: Metrics.cardRadius
                    color: Theme.surfaceLow
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Metrics.cardPadding
                        spacing: Metrics.spaceXS
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: I18n.tr("resources.activity")
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Metrics.textTitle
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: PowerService.processCount + " " + I18n.tr("resources.processes")
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Metrics.textCaption
                            }
                        }
                        HistoryGraph {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            primaryValues: PowerService.cpuHistory
                            secondaryValues: PowerService.memoryHistory
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(230 * Metrics.scale)
                    radius: Metrics.cardRadius
                    color: Theme.groupSurface
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Metrics.cardPaddingWide
                        spacing: Metrics.spaceL
                        ProcessList {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            title: I18n.tr("resources.topCpu")
                            valueKey: "cpu"
                            processes: PowerService.topCpuApplications
                        }
                        Rectangle {
                            Layout.preferredWidth: Metrics.border
                            Layout.fillHeight: true
                            color: Theme.divider
                        }
                        ProcessList {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            title: I18n.tr("resources.topMemory")
                            valueKey: "memory"
                            processes: PowerService.topMemoryApplications
                        }
                    }
                }

                PowerModeSwitch {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(70 * Metrics.scale)
                }
            }
        }
    }
}
