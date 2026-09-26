import QtQuick
import "../../components"
import "../../core"
import "../../services"

SettingsMasonry {
    id: root
    width: parent ? parent.width : 0
    spacing: Metrics.spaceL

    Component.onCompleted: {
        if (AssistantService.assistantEnabled) {
            AssistantService.refreshCapabilities()
            AssistantService.refreshRuntimeMetrics()
        }
    }

    SettingsSection {
        fullWidth: true
        title: I18n.tr("assistant.settingsTitle")
        subtitle: I18n.tr("assistant.settingsHint")
        icon: "neurology"

        SettingsAction {
            width: parent.width
            visible: !AssistantService.betaAcknowledged
            icon: "experiment"
            title: I18n.tr("assistant.extremeBeta")
            subtitle: I18n.tr("assistant.extremeBetaWarning")
            value: I18n.tr("assistant.acknowledgeBeta")
            active: true
            onClicked: AssistantService.acknowledgeBeta()
        }


        SettingsChoice {
            width: parent.width
            title: I18n.tr("assistant.internetPermission")
            subtitle: I18n.tr("assistant.internetPermissionHint")
            options: ["disabled", "ask", "session", "always"]
            optionLabels: [
                I18n.tr("assistant.internetOffShort"),
                I18n.tr("assistant.internetAskShort"),
                I18n.tr("assistant.internetSessionShort"),
                I18n.tr("assistant.internetAlwaysShort")
            ]
            maxColumns: 4
            value: AssistantService.internetMode
            enabled: AssistantService.assistantEnabled
            onSelected: value => {
                if (value === "session")
                    AssistantService.allowInternetForSession()
                else
                    AssistantService.setInternetMode(value)
            }
        }
    }

    SettingsSection {
        title: I18n.tr("assistant.runtime")
        subtitle: AssistantService.statusText
        icon: "memory"
        iconContainerColor: Theme.secondaryContainer
        iconColor: Theme.secondary

        SettingsAction {
            width: parent.width
            icon: "model_training"
            title: AssistantService.selectedModel.length > 0
                ? AssistantService.selectedModel : I18n.tr("assistant.noModel")
            subtitle: AssistantService.models.length > 1
                ? I18n.tr("assistant.changeModel") : I18n.tr("assistant.modelManagerHint")
            value: AssistantService.formatBytes(AssistantService.modelSizeBytes)
            enabled: AssistantService.assistantEnabled
                && AssistantService.models.length > 1
            onClicked: AssistantService.selectNextModel()
        }
        SettingsValueRow {
            width: parent.width
            icon: "speed"
            title: I18n.tr("assistant.generationSpeed")
            value: AssistantService.tokensPerSecond.toFixed(1) + " tok/s"
        }
        SettingsValueRow {
            width: parent.width
            icon: "memory_alt"
            title: I18n.tr("assistant.serviceMemory")
            value: AssistantService.formatBytes(AssistantService.serviceRamBytes)
        }
        SettingsValueRow {
            width: parent.width
            icon: "developer_board"
            title: I18n.tr("assistant.offload")
            value: AssistantService.formatBytes(AssistantService.loadedVramBytes)
        }
        SettingsAction {
            width: parent.width
            icon: AssistantService.modelLoaded ? "stop_circle" : "play_circle"
            title: AssistantService.modelLoaded
                ? I18n.tr("assistant.unloadModel") : I18n.tr("assistant.loadModel")
            subtitle: AssistantService.modelLoaded
                ? I18n.tr("assistant.unloadModelHint") : I18n.tr("assistant.loadModelHint")
            enabled: AssistantService.assistantEnabled && AssistantService.providerReady
            onClicked: {
                if (AssistantService.modelLoaded)
                    AssistantService.unloadModel()
                else
                    AssistantService.ensureWarm()
            }
        }
        SettingsAction {
            width: parent.width
            icon: "restart_alt"
            title: I18n.tr("assistant.restartService")
            subtitle: I18n.tr("assistant.restartServiceHint")
            enabled: AssistantService.assistantEnabled
                && !AssistantService.serviceChanging
            onClicked: AssistantService.restartService()
        }
        SettingsAction {
            width: parent.width
            icon: "power_settings_new"
            title: I18n.tr("assistant.stopService")
            subtitle: I18n.tr("assistant.stopServiceHint")
            enabled: AssistantService.assistantEnabled
                && !AssistantService.serviceChanging
            onClicked: AssistantService.stopService()
        }
    }

    SettingsSection {
        title: I18n.tr("assistant.performance")
        subtitle: I18n.tr("assistant.performanceHint")
        icon: "tune"
        iconContainerColor: Theme.tertiaryContainer
        iconColor: Theme.tertiary

        SettingsChoice {
            width: parent.width
            title: I18n.tr("assistant.performancePreset")
            subtitle: I18n.tr("assistant.performancePresetHint")
            options: ["automatic", "low", "balanced", "maximum"]
            optionLabels: [
                I18n.tr("assistant.presetAutomatic"),
                I18n.tr("assistant.presetLow"),
                I18n.tr("assistant.presetBalanced"),
                I18n.tr("assistant.presetMaximum")
            ]
            maxColumns: 2
            value: AssistantService.performancePreset
            enabled: AssistantService.assistantEnabled
            onSelected: value => AssistantService.setPerformancePreset(value)
        }
        SettingsChoice {
            width: parent.width
            title: I18n.tr("assistant.contextWindow")
            subtitle: I18n.tr("assistant.contextHint")
            options: ["2048", "4096", "8192", "16384"]
            optionLabels: ["2K", "4K", "8K", "16K"]
            value: String(AssistantService.contextLimit)
            enabled: AssistantService.assistantEnabled
            onSelected: value => AssistantService.setContextLimit(Number(value))
        }
        SettingsSlider {
            width: parent.width
            icon: "memory"
            title: I18n.tr("assistant.cpuThreads")
            subtitle: I18n.tr("assistant.cpuThreadsHint")
            from: 0; to: 32; step: 1
            value: AssistantService.cpuThreadLimit
            suffix: AssistantService.cpuThreadLimit === 0
                ? " · " + I18n.tr("assistant.automatic") : ""
            enabled: AssistantService.assistantEnabled
            onChanged: value => AssistantService.setCpuThreadLimit(value)
        }
        SettingsSlider {
            width: parent.width
            icon: "timer"
            title: I18n.tr("assistant.unloadTimeout")
            subtitle: I18n.tr("assistant.unloadTimeoutHint")
            from: 0; to: 60; step: 5
            value: AssistantService.unloadMinutes
            suffix: " min"
            enabled: AssistantService.assistantEnabled
            onChanged: value => AssistantService.setUnloadMinutes(value)
        }
    }
}
