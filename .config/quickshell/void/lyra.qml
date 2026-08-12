//@ pragma UseQApplication
//@ pragma Env QSG_RENDER_LOOP=threaded

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "components"
import "core"
import "panels"
import "services"

Scope {
    id: app

    property bool agentDrawerOpen: false

    IpcHandler {
        target: "lyraWindow"

        function activate(): void {
            window.visible = true
            Qt.callLater(() => chatPage.focusComposer())
        }

        function newConversation(): void {
            AssistantService.clearConversation()
            activate()
        }
    }

    function internetLabel() {
        if (AssistantService.internetMode === "disabled")
            return I18n.tr("assistant.internetDisabled")
        if (AssistantService.internetMode === "always")
            return I18n.tr("assistant.internetAlways")
        if (AssistantService.internetMode === "session"
                && AssistantService.sessionInternetAllowed)
            return I18n.tr("assistant.internetSession")
        return I18n.tr("assistant.internetAsk")
    }

    function cycleInternetMode() {
        if (AssistantService.internetMode === "disabled")
            AssistantService.setInternetMode("ask")
        else if (AssistantService.internetMode === "ask")
            AssistantService.allowInternetForSession()
        else if (AssistantService.internetMode === "session")
            AssistantService.setInternetMode("always")
        else
            AssistantService.setInternetMode("disabled")
    }

    FloatingWindow {
        id: window
        visible: true
        title: I18n.tr("assistant.appTitle")
        implicitWidth: Math.round(1120 * Metrics.scale)
        implicitHeight: Math.round(760 * Metrics.scale)
        minimumSize: Qt.size(Math.round(680 * Metrics.scale),
            Math.round(520 * Metrics.scale))
        color: Theme.background

        Rectangle {
            anchors.fill: parent
            color: Theme.background

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Metrics.pagePadding
                spacing: Metrics.spaceM

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(66 * Metrics.scale)
                    radius: Metrics.cardRadius
                    color: Theme.panel
                    border.width: 1
                    border.color: Theme.outlineSoft

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Metrics.spaceM
                        anchors.rightMargin: Metrics.spaceM
                        spacing: Metrics.spaceM

                        Rectangle {
                            Layout.preferredWidth: Metrics.controlL
                            Layout.preferredHeight: Metrics.controlL
                            radius: Metrics.iconContainerRadius
                            color: Theme.accentContainer
                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "neurology"
                                size: Metrics.iconL
                                color: Theme.accent
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            RowLayout {
                                spacing: Metrics.spaceS
                                Text {
                                    text: I18n.tr("assistant.name")
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Metrics.appTextHeader
                                    font.weight: Font.Bold
                                }
                                Rectangle {
                                    Layout.preferredWidth: betaText.implicitWidth + Metrics.spaceM
                                    Layout.preferredHeight: Math.round(22 * Metrics.scale)
                                    radius: Metrics.buttonRadius
                                    color: Theme.tertiaryContainer
                                    Text {
                                        id: betaText
                                        anchors.centerIn: parent
                                        text: I18n.tr("assistant.extremeBeta")
                                        color: Theme.tertiary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Metrics.textCaption
                                        font.weight: Font.Bold
                                    }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: AssistantService.selectedModel.length > 0
                                    ? AssistantService.selectedModel
                                    : I18n.tr("assistant.modelUnloaded")
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Metrics.appTextSupporting
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: internetText.implicitWidth
                                + Metrics.spaceXL + Metrics.iconS
                            Layout.preferredHeight: Metrics.controlM
                            radius: Metrics.buttonRadius
                            color: internetHover.hovered
                                ? Theme.surfaceHigh : Theme.groupSurface
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Metrics.spaceXS
                                MaterialIcon {
                                    text: !FeatureRegistry.aiInstalled ? "download"
                                        : (AssistantService.internetAllowed
                                            ? "public" : "shield_lock")
                                    size: Metrics.iconS
                                    color: FeatureRegistry.aiInstalled
                                        ? Theme.secondary : Theme.textMuted
                                }
                                Text {
                                    id: internetText
                                    text: FeatureRegistry.aiInstalled
                                        ? app.internetLabel()
                                        : I18n.tr("assistant.notInstalled")
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Metrics.appTextSupporting
                                    font.weight: Font.DemiBold
                                }
                            }
                            HoverHandler { id: internetHover }
                            TapHandler {
                                enabled: FeatureRegistry.aiInstalled
                                onTapped: app.cycleInternetMode()
                            }
                            Behavior on color {
                                ColorAnimation { duration: Motion.fast }
                            }
                        }

                        IconButton {
                            icon: "edit_square"
                            accessibleName: I18n.tr("assistant.clearChat")
                            onClicked: {
                                AssistantService.clearConversation()
                                chatPage.focusComposer()
                            }
                        }
                        IconButton {
                            icon: app.agentDrawerOpen ? "right_panel_close"
                                : "right_panel_open"
                            accessibleName: I18n.tr("assistant.agentControls")
                            onClicked: app.agentDrawerOpen = !app.agentDrawerOpen
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Metrics.spaceM

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Metrics.panelRadius
                        color: Theme.panel
                        border.width: 1
                        border.color: Theme.outlineSoft
                        clip: true

                        LocalAiPage {
                            id: chatPage
                            anchors.fill: parent
                            anchors.margins: Metrics.panelPadding
                            active: true
                            showComposer: true
                            showHeader: false
                            showRuntimeStrip: false
                            spacious: true
                            onUseSuggestion: value => {
                                composerText = value
                                focusComposer()
                            }
                        }
                    }

                    Rectangle {
                        id: agentDrawer
                        Layout.preferredWidth: Math.round(360 * Metrics.scale)
                        Layout.fillHeight: true
                        visible: app.agentDrawerOpen
                            && window.width >= Math.round(920 * Metrics.scale)
                        radius: Metrics.panelRadius
                        color: Theme.panel
                        border.width: 1
                        border.color: Theme.outlineSoft
                        clip: true

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: Metrics.panelPadding
                            contentWidth: width
                            contentHeight: agentContent.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: agentContent
                                width: parent.width
                                spacing: Metrics.settingsSectionGap

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        Layout.fillWidth: true
                                        text: I18n.tr("assistant.agentControls")
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Metrics.appTextTitle
                                        font.weight: Font.Bold
                                    }
                                    IconButton {
                                        icon: "close"
                                        accessibleName: I18n.tr("common.close")
                                        onClicked: app.agentDrawerOpen = false
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: runtimeColumn.implicitHeight
                                        + Metrics.cardPadding * 2
                                    radius: Metrics.cardRadius
                                    color: Theme.groupSurface

                                    ColumnLayout {
                                        id: runtimeColumn
                                        anchors {
                                            left: parent.left
                                            right: parent.right
                                            top: parent.top
                                            margins: Metrics.cardPadding
                                        }
                                        spacing: Metrics.spaceS

                                        Text {
                                            Layout.fillWidth: true
                                            text: I18n.tr("assistant.runtime")
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Metrics.appTextBody
                                            font.weight: Font.Bold
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: AssistantService.statusText
                                            color: Theme.textMuted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Metrics.appTextSupporting
                                            wrapMode: Text.Wrap
                                        }
                                        SettingsAction {
                                            Layout.fillWidth: true
                                            icon: "memory"
                                            title: AssistantService.selectedModel.length > 0
                                                ? AssistantService.selectedModel
                                                : I18n.tr("assistant.noModel")
                                            subtitle: AssistantService.models.length > 1
                                                ? I18n.tr("assistant.changeModel")
                                                : I18n.tr("assistant.modelManagerHint")
                                            enabled: AssistantService.models.length > 1
                                            onClicked: AssistantService.selectNextModel()
                                        }
                                        MetricRow { Layout.fillWidth: true; label: I18n.tr("assistant.modelSize"); value: AssistantService.formatBytes(AssistantService.modelSizeBytes) }
                                        MetricRow { Layout.fillWidth: true; label: I18n.tr("assistant.providerName"); value: AssistantService.providerLabel + " · " + AssistantService.providerType }
                                        MetricRow { Layout.fillWidth: true; label: I18n.tr("assistant.modelFamily"); value: AssistantService.modelFamily + " · " + AssistantService.parameterSize }
                                        MetricRow { Layout.fillWidth: true; label: I18n.tr("assistant.quantization"); value: AssistantService.quantization }
                                        MetricRow { Layout.fillWidth: true; label: I18n.tr("assistant.contextWindow"); value: (AssistantService.loadedContextTokens || AssistantService.contextLimit) + " / " + AssistantService.nativeContextTokens }
                                        MetricRow { Layout.fillWidth: true; label: I18n.tr("assistant.inputTokens") + " / " + I18n.tr("assistant.outputTokens"); value: AssistantService.inputTokens + " / " + AssistantService.outputTokens }
                                        MetricRow { Layout.fillWidth: true; label: I18n.tr("assistant.generationSpeed"); value: AssistantService.tokensPerSecond.toFixed(1) + " tok/s" }
                                        MetricRow { Layout.fillWidth: true; label: I18n.tr("assistant.firstToken"); value: Math.round(AssistantService.timeToFirstTokenMs) + " ms" }
                                        MetricRow { Layout.fillWidth: true; label: I18n.tr("assistant.serviceMemory") + " / " + I18n.tr("assistant.cpuUsage"); value: AssistantService.formatBytes(AssistantService.serviceRamBytes) + " / " + AssistantService.serviceCpuPercent.toFixed(0) + "%" }
                                        MetricRow { Layout.fillWidth: true; label: I18n.tr("assistant.offload"); value: AssistantService.formatBytes(AssistantService.loadedVramBytes) + " · " + (AssistantService.modelLoaded ? I18n.tr("assistant.loaded") : I18n.tr("assistant.unloaded")) }
                                        MetricRow { Layout.fillWidth: true; label: I18n.tr("assistant.gpuMemory"); value: AssistantService.formatBytes(AssistantService.gpuMemoryBytes) + " / " + AssistantService.formatBytes(AssistantService.gpuMemoryTotalBytes) }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.round(164 * Metrics.scale)
                                    radius: Metrics.cardRadius
                                    color: Theme.groupSurface
                                    SettingsChoice {
                                        anchors.fill: parent
                                        anchors.margins: Metrics.spaceXS
                                        title: I18n.tr("assistant.internetPermission")
                                        subtitle: I18n.tr("assistant.internetPermissionHint")
                                        options: ["disabled", "ask", "session", "always"]
                                        optionLabels: [
                                            I18n.tr("assistant.internetOffShort"),
                                            I18n.tr("assistant.internetAskShort"),
                                            I18n.tr("assistant.internetSessionShort"),
                                            I18n.tr("assistant.internetAlwaysShort")
                                        ]
                                        maxColumns: 2
                                        value: AssistantService.internetMode
                                        onSelected: value => {
                                            if (value === "session")
                                                AssistantService.allowInternetForSession()
                                            else
                                                AssistantService.setInternetMode(value)
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: I18n.tr("assistant.actionHistory")
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Metrics.appTextBody
                                    font.weight: Font.Bold
                                }

                                Repeater {
                                    model: AssistantService.actionHistory.slice(0, 12)
                                    Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: Math.round(62 * Metrics.scale)
                                        radius: Metrics.stateRadius
                                        color: Theme.groupSurface
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: Metrics.spaceS
                                            spacing: Metrics.spaceS
                                            MaterialIcon {
                                                text: modelData.state === "failed" ? "error"
                                                    : (modelData.state === "waiting"
                                                        ? "pending" : "check_circle")
                                                size: Metrics.iconM
                                                color: modelData.state === "failed"
                                                    ? Theme.danger : Theme.secondary
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: String(modelData.action || "")
                                                    color: Theme.text
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Metrics.appTextSupporting
                                                    font.weight: Font.DemiBold
                                                    elide: Text.ElideRight
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: String(modelData.detail
                                                        || modelData.state || "")
                                                    color: Theme.textMuted
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Metrics.appTextCaption
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: AssistantService.actionHistory.length === 0
                                    text: I18n.tr("assistant.noActionsYet")
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Metrics.appTextSupporting
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }
                }
            }
        }

        Component.onCompleted: Qt.callLater(() => chatPage.focusComposer())
    }
}
