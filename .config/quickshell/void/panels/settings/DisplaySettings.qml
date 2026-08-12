import QtQuick
import "../../components"
import "../../core"
import "../../services"

SettingsMasonry {
    id: root
    width: parent ? parent.width : 0
    spacing: 18

    property string selectedName: SystemSettingsService.primaryMonitor
    property bool advancedWarningVisible: false
    property string manualWidth: selectedMonitor ? String(selectedMonitor.width) : "1920"
    property string manualHeight: selectedMonitor ? String(selectedMonitor.height) : "1080"
    property string manualRefresh: selectedMonitor
        ? Number(selectedMonitor.refreshRate).toFixed(3) : "60.000"
    property string manualScale: selectedMonitor ? String(selectedMonitor.scale) : "1"
    property string manualX: selectedMonitor ? String(selectedMonitor.x) : "0"
    property string manualY: selectedMonitor ? String(selectedMonitor.y) : "0"
    readonly property var selectedMonitor: {
        for (let index = 0; index < SystemSettingsService.monitors.length; ++index) {
            if (SystemSettingsService.monitors[index].name === selectedName)
                return SystemSettingsService.monitors[index]
        }
        return SystemSettingsService.monitors.length > 0
            ? SystemSettingsService.monitors[0] : null
    }
    readonly property int enabledMonitorCount: {
        let count = 0
        for (let index = 0; index < SystemSettingsService.monitors.length; ++index) {
            if (!SystemSettingsService.monitors[index].disabled)
                count++
        }
        return count
    }

    function currentMode(monitor) {
        if (!monitor)
            return "preferred"
        return monitor.width + "x" + monitor.height + "@"
            + Number(monitor.refreshRate).toFixed(2) + "Hz"
    }

    function offeredModes(monitor) {
        if (!monitor)
            return ["preferred"]
        const modes = monitor.modes.slice()
        const current = currentMode(monitor)
        if (modes.indexOf(current) < 0)
            modes.unshift(current)
        return modes
    }

    function applySelected(overrides) {
        const monitor = selectedMonitor
        if (!monitor)
            return
        const options = overrides || ({})
        SystemSettingsService.setMonitor(
            monitor.name,
            options.mode !== undefined ? options.mode : currentMode(monitor),
            options.x !== undefined ? options.x : monitor.x,
            options.y !== undefined ? options.y : monitor.y,
            options.scale !== undefined ? options.scale : monitor.scale,
            options.transform !== undefined ? options.transform : monitor.transform,
            options.vrr !== undefined ? options.vrr : monitor.vrr,
            options.mirror !== undefined ? options.mirror : monitor.mirror,
            options.colorProfile !== undefined
                ? options.colorProfile : monitor.colorProfile)
    }

    SettingsSection {
        fullWidth: true
        title: I18n.tr("display.arrangement")
        subtitle: I18n.plural("display.detected",
            SystemSettingsService.monitors.length)
        icon: "desktop_windows"

        Rectangle {
            width: parent.width
            height: SystemSettingsService.monitorApplyState === "idle" ? 0 : 44
            visible: height > 0
            radius: Theme.radiusMedium
            color: SystemSettingsService.monitorApplyState === "failure"
                ? Theme.dangerContainer
                : (SystemSettingsService.monitorApplyState === "success"
                    ? Theme.secondaryContainer : Theme.surfaceHigh)
            clip: true

            Row {
                anchors { fill: parent; leftMargin: 13; rightMargin: 13 }
                spacing: 10

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: SystemSettingsService.monitorApplyState === "failure"
                        ? "error" : (SystemSettingsService.monitorApplyState === "success"
                            ? "check_circle" : "progress_activity")
                    size: 19
                    color: SystemSettingsService.monitorApplyState === "failure"
                        ? Theme.danger : Theme.secondary
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 42
                    text: SystemSettingsService.monitorApplyMessage
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: Appearance.reduceMotion ? 0 : Motion.fast
                    easing.type: Motion.standardCurve
                }
            }
        }

        MonitorArrangement {
            width: parent.width
            monitors: SystemSettingsService.monitors
            selectedName: root.selectedName
            onSelected: name => root.selectedName = name
            onMonitorMoved: (name, x, y) => {
                root.selectedName = name
                root.applySelected({ x: x, y: y })
            }
        }
        SettingsAction {
            width: parent.width
            icon: "monitor"
            title: root.selectedMonitor ? root.selectedMonitor.name
                : I18n.tr("display.noDisplay")
            subtitle: root.selectedMonitor ? root.selectedMonitor.description
                : I18n.tr("display.noMonitorInfo")
            value: root.selectedMonitor
                ? root.selectedMonitor.width + " × " + root.selectedMonitor.height : ""
            active: root.selectedMonitor && root.selectedMonitor.name
                === SystemSettingsService.primaryMonitor
            interactive: false
        }
    }

    SettingsSection {
        title: I18n.tr("display.selected")
        subtitle: root.selectedMonitor ? root.selectedMonitor.name
            : I18n.tr("display.selectAbove")
        icon: "display_settings"

        SettingsToggle {
            width: parent.width
            icon: "power_settings_new"
            title: I18n.tr("display.enable")
            subtitle: root.enabledMonitorCount <= 1
                ? I18n.tr("display.onlyActive")
                : I18n.tr("display.disableHint")
            checked: root.selectedMonitor && !root.selectedMonitor.disabled
            enabled: root.selectedMonitor && (root.enabledMonitorCount > 1
                || root.selectedMonitor.disabled) && !SystemSettingsService.monitorApplying
            onToggled: value => {
                if (value)
                    root.applySelected({ mode: "preferred" })
                else
                    SystemSettingsService.disableMonitor(root.selectedMonitor.name)
            }
        }
        SettingsChoice {
            width: parent.width
            title: I18n.tr("display.resolutionRefresh")
            subtitle: I18n.tr("display.modeHint")
            options: root.offeredModes(root.selectedMonitor)
            optionLabels: options
            value: root.selectedMonitor ? root.currentMode(root.selectedMonitor) : "preferred"
            enabled: root.selectedMonitor !== null && !SystemSettingsService.monitorApplying
            onSelected: value => root.applySelected({ mode: value })
        }
        SettingsChoice {
            width: parent.width
            maxColumns: 5
            title: I18n.tr("display.scale")
            subtitle: I18n.tr("display.scaleHint")
            options: ["1", "1.25", "1.5", "1.75", "2"]
            optionLabels: ["100%", "125%", "150%", "175%", "200%"]
            value: root.selectedMonitor ? String(root.selectedMonitor.scale) : "1"
            enabled: root.selectedMonitor !== null && !SystemSettingsService.monitorApplying
            onSelected: value => root.applySelected({ scale: Number(value) })
        }
        SettingsChoice {
            width: parent.width
            title: I18n.tr("display.orientation")
            subtitle: I18n.tr("display.orientationHint")
            options: ["0", "1", "2", "3", "4", "5", "6", "7"]
            optionLabels: [
                I18n.tr("display.landscape"), "90°", "180°", "270°",
                I18n.tr("display.flipped"), I18n.tr("display.flip90"),
                I18n.tr("display.flip180"), I18n.tr("display.flip270")
            ]
            value: root.selectedMonitor ? String(root.selectedMonitor.transform) : "0"
            enabled: root.selectedMonitor !== null && !SystemSettingsService.monitorApplying
            onSelected: value => root.applySelected({ transform: Number(value) })
        }
        SettingsAction {
            width: parent.width
            icon: "open_with"
            title: I18n.tr("display.position")
            subtitle: I18n.tr("display.positionHint")
            value: root.selectedMonitor
                ? root.selectedMonitor.x + ", " + root.selectedMonitor.y : ""
            interactive: false
        }
        SettingsToggle {
            width: parent.width
            icon: "home"
            title: I18n.tr("display.primary")
            subtitle: I18n.tr("display.primaryHint")
            checked: root.selectedMonitor && root.selectedMonitor.name
                === SystemSettingsService.primaryMonitor
            enabled: root.selectedMonitor !== null
            onToggled: value => {
                if (value)
                    SystemSettingsService.setPrimaryMonitor(root.selectedMonitor.name)
            }
        }
        SettingsToggle {
            width: parent.width
            icon: "sync"
            title: I18n.tr("display.vrr")
            subtitle: I18n.tr("display.vrrHint")
            checked: root.selectedMonitor && root.selectedMonitor.vrr
            enabled: root.selectedMonitor !== null
            onToggled: value => root.applySelected({ vrr: value })
        }
        SettingsChoice {
            width: parent.width
            title: I18n.tr("display.mirror")
            subtitle: SystemSettingsService.monitors.length > 1
                ? I18n.tr("display.mirrorHint")
                : I18n.tr("display.mirrorUnavailable")
            options: {
                const choices = ["none"]
                for (let index = 0; index < SystemSettingsService.monitors.length; ++index) {
                    const name = SystemSettingsService.monitors[index].name
                    if (name !== root.selectedName)
                        choices.push(name)
                }
                return choices
            }
            optionLabels: options
            value: root.selectedMonitor && root.selectedMonitor.mirror.length > 0
                ? root.selectedMonitor.mirror : "none"
            enabled: root.selectedMonitor !== null && !SystemSettingsService.monitorApplying
            onSelected: value => root.applySelected({ mirror: value })
        }
        SettingsChoice {
            width: parent.width
            title: I18n.tr("display.colorProfile")
            subtitle: SystemSettingsService.available("color")
                ? I18n.tr("display.colorAvailable")
                : I18n.tr("display.colorNeedsColord")
            options: ["srgb", "dcip3", "dp3", "adobe", "wide"]
            optionLabels: ["sRGB", "DCI-P3", "Display P3", "Adobe RGB", "Wide"]
            value: root.selectedMonitor ? root.selectedMonitor.colorProfile : "srgb"
            enabled: root.selectedMonitor !== null && !SystemSettingsService.monitorApplying
            onSelected: value => root.applySelected({ colorProfile: value })
        }
    }

    SettingsSection {
        fullWidth: true
        title: I18n.tr("display.advancedMode")
        subtitle: I18n.tr("display.advancedModeHint")
        icon: "warning"
        iconContainerColor: Theme.dangerContainer
        iconColor: Theme.danger

        SettingsAction {
            width: parent.width
            icon: SystemSettingsService.advancedDisplayMode
                ? "verified_user" : "manufacturing"
            title: SystemSettingsService.advancedDisplayMode
                ? I18n.tr("display.advancedEnabled")
                : I18n.tr("display.enableAdvanced")
            subtitle: SystemSettingsService.advancedDisplayMode
                ? I18n.tr("display.advancedEnabledHint")
                : I18n.tr("display.enableAdvancedHint")
            value: SystemSettingsService.advancedDisplayMode
                ? I18n.tr("common.on") : I18n.tr("common.off")
            active: SystemSettingsService.advancedDisplayMode
            onClicked: {
                if (SystemSettingsService.advancedDisplayMode)
                    SystemSettingsService.setAdvancedDisplayMode(false)
                else
                    root.advancedWarningVisible = true
            }
        }
        SettingsAction {
            visible: root.advancedWarningVisible
            width: parent.width
            icon: "dangerous"
            title: I18n.tr("display.advancedWarning")
            subtitle: I18n.tr("display.advancedWarningBody")
            value: I18n.tr("display.acceptRisk")
            onClicked: {
                root.advancedWarningVisible = false
                SystemSettingsService.setAdvancedDisplayMode(true)
            }
        }
        SettingsAction {
            visible: root.advancedWarningVisible
            width: parent.width
            icon: "close"
            title: I18n.tr("common.cancel")
            subtitle: I18n.tr("display.keepDetected")
            onClicked: root.advancedWarningVisible = false
        }
    }

    SettingsSection {
        visible: SystemSettingsService.advancedDisplayMode
        fullWidth: true
        title: I18n.tr("display.manualTiming")
        subtitle: root.selectedMonitor ? root.selectedMonitor.name
            : I18n.tr("display.selectAbove")
        icon: "tune"

        SettingsField {
            width: parent.width
            icon: "width"
            title: I18n.tr("display.manualWidth")
            subtitle: I18n.tr("display.pixels")
            value: root.manualWidth
            onAccepted: value => root.manualWidth = value
        }
        SettingsField {
            width: parent.width
            icon: "height"
            title: I18n.tr("display.manualHeight")
            subtitle: I18n.tr("display.pixels")
            value: root.manualHeight
            onAccepted: value => root.manualHeight = value
        }
        SettingsField {
            width: parent.width
            icon: "speed"
            title: I18n.tr("display.manualRefresh")
            subtitle: I18n.tr("display.hertz")
            value: root.manualRefresh
            onAccepted: value => root.manualRefresh = value
        }
        SettingsField {
            width: parent.width
            icon: "zoom_out_map"
            title: I18n.tr("display.scale")
            subtitle: "0.5–4.0"
            value: root.manualScale
            onAccepted: value => root.manualScale = value
        }
        SettingsField {
            width: parent.width
            icon: "open_with"
            title: I18n.tr("display.manualPosition")
            subtitle: I18n.tr("display.manualPositionHint")
            value: root.manualX + ", " + root.manualY
            onAccepted: value => {
                const parts = String(value).split(",")
                if (parts.length === 2) {
                    root.manualX = parts[0].trim()
                    root.manualY = parts[1].trim()
                }
            }
        }
        SettingsAction {
            width: parent.width
            icon: "display_settings"
            title: I18n.tr("display.applyManual")
            subtitle: I18n.tr("display.rollbackHint")
            value: I18n.tr("common.apply")
            enabled: root.selectedMonitor !== null
                && !SystemSettingsService.monitorApplying
                && !SystemSettingsService.pendingAdvancedConfirmation
            onClicked: SystemSettingsService.applyAdvancedMonitor(
                root.selectedMonitor.name, root.manualWidth, root.manualHeight,
                root.manualRefresh, root.manualScale, root.manualX, root.manualY,
                root.selectedMonitor.transform, root.selectedMonitor.vrr)
        }
        SettingsAction {
            width: parent.width
            icon: "restart_alt"
            title: I18n.tr("display.resetDetected")
            subtitle: I18n.tr("display.resetDetectedHint")
            enabled: !SystemSettingsService.monitorApplying
                && !SystemSettingsService.pendingAdvancedConfirmation
            onClicked: SystemSettingsService.resetDetectedMonitors()
        }
        SettingsAction {
            visible: SystemSettingsService.pendingAdvancedConfirmation
            width: parent.width
            icon: "check_circle"
            title: I18n.tr("display.keepChanges")
            subtitle: I18n.tr("display.confirmAdvanced", {
                seconds: SystemSettingsService.advancedConfirmSeconds
            })
            value: I18n.tr("common.confirm")
            active: true
            onClicked: SystemSettingsService.confirmAdvancedMonitor()
        }
        SettingsAction {
            visible: SystemSettingsService.pendingAdvancedConfirmation
            width: parent.width
            icon: "undo"
            title: I18n.tr("display.revertNow")
            subtitle: I18n.tr("display.safeFallback")
            onClicked: SystemSettingsService.rollbackAdvancedMonitor()
        }
    }

    SettingsSection {
        title: I18n.tr("display.lightImage")
        subtitle: I18n.tr("display.lightImageHint")
        icon: "brightness_6"
        iconContainerColor: Theme.tertiaryContainer
        iconColor: Theme.tertiary

        SettingsSlider {
            width: parent.width
            title: I18n.tr("display.brightness")
            subtitle: PowerService.backlightAvailable
                ? I18n.tr("display.builtinBacklight")
                : I18n.tr("display.noBacklight")
            icon: "brightness_6"
            from: 1; to: 100; value: PowerService.brightnessPercent; suffix: "%"
            enabled: PowerService.backlightAvailable
            onChanged: value => PowerService.setBrightness(value)
        }
        Repeater {
            model: PowerService.brightnessDevices.filter(item => item.kind === "external")
            delegate: SettingsSlider {
                required property var modelData
                width: parent.width
                title: modelData.label
                subtitle: I18n.tr("display.ddc")
                icon: "monitor"
                from: 1
                to: 100
                value: modelData.percent
                suffix: "%"
                onChanged: value => PowerService.setDeviceBrightness(modelData.id, value)
            }
        }
        SettingsToggle {
            width: parent.width
            icon: "nightlight"
            title: I18n.tr("display.nightLight")
            subtitle: SystemSettingsService.available("nightlight")
                ? I18n.tr("display.nightLightHint")
                : I18n.tr("display.nightLightNeedsBackend")
            checked: SystemSettingsService.nightLightEnabled
            enabled: SystemSettingsService.available("nightlight")
            onToggled: value => SystemSettingsService.setNightLight(value)
        }
        SettingsToggle {
            width: parent.width
            icon: "hdr_on"
            title: I18n.tr("display.hdr")
            subtitle: root.selectedMonitor && (root.selectedMonitor.format.indexOf("10") >= 0
                    || root.selectedMonitor.colorProfile === "hdr")
                ? I18n.tr("display.hdrExperimental")
                : I18n.tr("display.hdrUnavailable")
            checked: root.selectedMonitor && (root.selectedMonitor.colorProfile === "hdr"
                || root.selectedMonitor.colorProfile === "hdredid")
            enabled: root.selectedMonitor && (root.selectedMonitor.format.indexOf("10") >= 0
                || root.selectedMonitor.colorProfile === "hdr"
                || root.selectedMonitor.colorProfile === "hdredid")
            onToggled: value => root.applySelected({
                colorProfile: value ? "hdr" : "srgb"
            })
        }
    }
}
