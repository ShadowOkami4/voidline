pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../core"

QtObject {
    id: root

    property bool persistPending: false

    property bool active: false
    property bool loading: false
    property bool devicesActive: false
    property bool devicesLoading: false
    property var monitors: []
    property var devices: ({
        bluetooth: [], printer: [], scanner: [], camera: [], usb: [],
        storage: [], controller: [], tablet: [], touchscreen: [],
        audio: [], mouse: [], touchpad: [], keyboard: []
    })
    property var capabilities: ({})
    property string dnsServers: "Automatic"
    property bool nightLightEnabled: false
    property bool monitorApplying: false
    property string monitorApplyState: "idle"
    property string monitorApplyMessage: ""
    property var monitorRollback: []
    property var pendingMonitorCommand: []
    property var pendingHyprWrite: null
    property var activeHyprWrite: null
    property string hyprApplyState: "idle"
    property string hyprApplyMessage: ""
    property bool advancedDisplayMode: false
    property bool advancedDisplayApplying: false
    property bool pendingAdvancedConfirmation: false
    property int advancedConfirmSeconds: 0

    property int borderSize: 10
    property string activeBorderColor: "rgba(8fb8acff)"
    property string activeBorderColor2: "rgba(9caedbff)"
    property int activeBorderAngle: 45
    property bool activeBorderGradient: true
    property string inactiveBorderColor: "rgba(59605fff)"
    property real activeOpacity: 1
    property real inactiveOpacity: 0.9
    property int windowRounding: 15
    property int innerGaps: 8
    property int outerGaps: 20
    property bool shadowsEnabled: true
    property int shadowSize: 32
    property int shadowStrength: 2
    property real shadowRange: 1
    property string shadowColor: "rgba(00000050)"
    property bool blurEnabled: true
    property int blurStrength: 16
    property int blurPasses: 2
    property bool blurPopups: true
    property string animationPreset: "balanced"
    property string primaryMonitor: ""

    property real pointerSpeed: 0
    property bool naturalScroll: false
    property bool tapToClick: true
    property string scrollMethod: "2fg"
    property bool workspaceGestures: true
    property string keyboardLayout: "de"
    property int repeatRate: 25
    property int repeatDelay: 600

    function setActive(value) {
        active = value
        if (value) {
            refresh()
            refreshTimer.restart()
        } else {
            refreshTimer.stop()
        }
    }

    function setDevicesActive(value) {
        devicesActive = Boolean(value)
    }

    function refresh() {
        if (!coreSnapshot.running) {
            loading = true
            coreSnapshot.running = true
        }
        if (devicesActive)
            refreshDevices()
    }

    function refreshDevices() {
        if (!deviceSnapshot.running) {
            devicesLoading = true
            deviceSnapshot.running = true
        }
    }

    function available(name) {
        return capabilities[name] === true
    }

    function list(kind) {
        if (kind === "printscan")
            return (devices.printer || []).concat(devices.scanner || [])
        return devices[kind] || []
    }

    function parseSnapshot(contents, includeDevices) {
        const nextMonitors = []
        const nextDevices = {
            bluetooth: [], printer: [], scanner: [], camera: [], usb: [],
            storage: [], controller: [], tablet: [], touchscreen: [],
            audio: [], mouse: [], touchpad: [], keyboard: []
        }
        const nextCaps = {}
        const configProperties = {
            BorderSize: ["borderSize", "number"],
            Activecolor: ["activeBorderColor", "string"],
            Inactivecolor: ["inactiveBorderColor", "string"],
            Active_opacity: ["activeOpacity", "number"],
            Inactive_opacity: ["inactiveOpacity", "number"],
            Rounding: ["windowRounding", "number"],
            WindowGaps: ["innerGaps", "number"],
            ScreenGaps: ["outerGaps", "number"],
            Shadow_enabled: ["shadowsEnabled", "boolean"],
            Shadow_range: ["shadowSize", "number"],
            Shadow_render_power: ["shadowStrength", "number"],
            Shadow_scale: ["shadowRange", "number"],
            Shadow_color: ["shadowColor", "string"],
            Blur_enabled: ["blurEnabled", "boolean"],
            Blur_size: ["blurStrength", "number"],
            Blur_passes: ["blurPasses", "number"],
            Blur_popups: ["blurPopups", "boolean"],
            PointerSensitivity: ["pointerSpeed", "number"],
            NaturalScroll: ["naturalScroll", "boolean"],
            TapToClick: ["tapToClick", "boolean"],
            ScrollMethod: ["scrollMethod", "string"],
            KeyboardLayout: ["keyboardLayout", "string"],
            RepeatRate: ["repeatRate", "number"],
            RepeatDelay: ["repeatDelay", "number"],
            WorkspaceSwipe: ["workspaceGestures", "boolean"]
        }
        const rows = contents.trim().length > 0 ? contents.trim().split("\n") : []

        for (let index = 0; index < rows.length; ++index) {
            const fields = rows[index].split("|")
            if (fields[0] === "cap") {
                nextCaps[fields[1]] = fields[2] === "1"
            } else if (fields[0] === "setting") {
                if (fields[1] === "Animation") {
                    const animationMap = {
                        disabled: "off", smooth: "calm",
                        fast: "balanced", dynamic: "expressive"
                    }
                    animationPreset = animationMap[fields[2]] || animationPreset
                } else if (fields[1] === "Activecolor") {
                    const raw = fields.slice(2).join("|")
                    const colors = raw.match(/rgba?\([^)]*\)/g) || []
                    if (colors.length > 0)
                        activeBorderColor = colors[0]
                    activeBorderColor2 = colors.length > 1
                        ? colors[1] : activeBorderColor
                    activeBorderGradient = colors.length > 1
                    const angle = raw.match(/angle\s*=\s*([0-9.]+)/)
                    activeBorderAngle = angle ? Math.max(0,
                        Math.min(360, Math.round(Number(angle[1])))) : 45
                } else if (configProperties[fields[1]]) {
                    const target = configProperties[fields[1]]
                    const raw = fields.slice(2).join("|")
                    if (target[1] === "number")
                        root[target[0]] = Number(raw)
                    else if (target[1] === "boolean")
                        root[target[0]] = raw === "true" || raw === "1"
                    else {
                        const colorMatch = raw.match(/rgba?\([^)]*\)/)
                        root[target[0]] = colorMatch ? colorMatch[0] : raw
                    }
                }
            } else if (fields[0] === "monitor") {
                const modes = (fields[16] || "").split(",").filter(mode => mode.length > 0)
                nextMonitors.push({
                    name: fields[1], description: fields[2],
                    width: Number(fields[3]) || 0, height: Number(fields[4]) || 0,
                    refreshRate: Number(fields[5]) || 0,
                    x: Number(fields[6]) || 0, y: Number(fields[7]) || 0,
                    scale: Number(fields[8]) || 1, transform: Number(fields[9]) || 0,
                    focused: fields[10] === "true", disabled: fields[11] === "true",
                    vrr: fields[12] === "true" || Number(fields[12]) > 0,
                    mirror: fields[13] || "", format: fields[14] || "",
                    colorProfile: fields[15] || "srgb", modes: modes
                })
            } else if (fields[0] === "input") {
                const kind = fields[1]
                if (nextDevices[kind])
                    nextDevices[kind].push({
                        kind: kind,
                        id: fields[2], name: fields[2],
                        detail: fields[3] || "Connected",
                        status: "Connected", connection: "Hyprland input",
                        manufacturer: "", model: fields[2],
                        driver: "libinput", battery: ""
                    })
            } else if (fields[0] === "device") {
                const kind = fields[1]
                if (nextDevices[kind]) {
                    const nextDevice = {
                        kind: kind,
                        id: fields[2] || fields[3] || "device",
                        name: fields[3] || fields[2] || "Device",
                        status: fields[4] || "Detected",
                        detail: fields[4] || "Detected",
                        connection: fields[5] || "",
                        manufacturer: fields[6] || "",
                        model: fields[7] || "",
                        driver: fields[8] || "",
                        battery: fields[9] || ""
                    }
                    let duplicateIndex = -1
                    for (let deviceIndex = 0;
                            deviceIndex < nextDevices[kind].length;
                            ++deviceIndex) {
                        const candidate = nextDevices[kind][deviceIndex]
                        if (candidate.id === nextDevice.id) {
                            duplicateIndex = deviceIndex
                            break
                        }
                        if ((kind === "printer" || kind === "scanner")
                                && candidate.connection.length > 0
                                && candidate.connection === nextDevice.connection) {
                            duplicateIndex = deviceIndex
                            break
                        }
                    }
                    if (duplicateIndex < 0) {
                        nextDevices[kind].push(nextDevice)
                    } else if (nextDevice.status === "Saved"
                            && nextDevices[kind][duplicateIndex].status !== "Saved") {
                        nextDevices[kind][duplicateIndex] = nextDevice
                    }
                }
            } else if (fields[0] === "network" && fields[1] === "dns") {
                dnsServers = fields.slice(2).join("|") || "Automatic"
            }
        }

        if (!monitorApplying)
            monitors = nextMonitors
        if (includeDevices)
            devices = nextDevices
        capabilities = nextCaps
        if (primaryMonitor.length === 0 && monitors.length > 0)
            primaryMonitor = monitors.find(item => item.focused)?.name || monitors[0].name
        if (includeDevices)
            devicesLoading = false
        else
            loading = false
    }

    function queueHypr(propertyName, key, value, previous, previousValues) {
        const queued = pendingHyprWrite
        pendingHyprWrite = {
            propertyName: propertyName,
            key: key,
            value: value,
            previous: queued && queued.propertyName === propertyName
                ? queued.previous : previous,
            previousValues: queued && queued.propertyName === propertyName
                ? queued.previousValues : (previousValues || null)
        }
        hyprApplyState = "applying"
        hyprApplyMessage = I18n.tr("display.applying")
        hyprWriteDelay.restart()
    }

    function discover(kind) {
        devicesLoading = true
        Quickshell.execDetached({
            command: ["sh", Paths.shellRoot + "/scripts/system-settings.sh",
                "discover", String(kind)]
        })
        discoveryRefresh.restart()
    }

    function deviceAction(kind, action, identifier) {
        devicesLoading = true
        Quickshell.execDetached({
            command: ["sh", Paths.shellRoot + "/scripts/system-settings.sh",
                "device-action", String(kind), String(action), String(identifier)]
        })
        discoveryRefresh.restart()
    }

    function updateValue(propertyName, value, hyprKey) {
        const previous = root[propertyName]
        root[propertyName] = value
        persist()
        queueHypr(propertyName, hyprKey, value, previous)
    }

    function validHyprColor(value) {
        return /^rgba?\([0-9a-fA-F]{6}([0-9a-fA-F]{2})?\)$/.test(
            String(value || ""))
    }

    function setActiveBorder(first, second, angle, gradient) {
        const primary = String(first || "")
        const secondary = String(second || primary)
        const safeAngle = Math.max(0, Math.min(360,
            Math.round(Number(angle) || 0)))
        const useGradient = Boolean(gradient)
        if (!validHyprColor(primary)
                || (useGradient && !validHyprColor(secondary)))
            return false
        const previousValues = {
            activeBorderColor: activeBorderColor,
            activeBorderColor2: activeBorderColor2,
            activeBorderAngle: activeBorderAngle,
            activeBorderGradient: activeBorderGradient
        }
        activeBorderColor = primary
        activeBorderColor2 = useGradient ? secondary : primary
        activeBorderAngle = safeAngle
        activeBorderGradient = useGradient
        persist()
        const encoded = useGradient
            ? primary + "|" + secondary + "|" + safeAngle : primary
        queueHypr("activeBorderColor", "general:col.active_border",
            encoded, previousValues.activeBorderColor, previousValues)
        return true
    }

    function setMonitor(name, mode, x, y, scale, transform, vrr, mirror,
            colorProfile) {
        if (monitorApplying || pendingAdvancedConfirmation)
            return
        const position = Math.round(x) + "x" + Math.round(y)
        const next = monitors.map(item => {
            if (item.name !== name)
                return item
            const updated = Object.assign({}, item, {
                x: Math.round(x), y: Math.round(y), scale: Number(scale),
                transform: Number(transform), vrr: Boolean(vrr),
                mirror: mirror === "none" ? "" : (mirror || ""),
                colorProfile: colorProfile || "srgb",
                disabled: mode === "disabled"
            })
            const parsedMode = String(mode).match(/^([0-9]+)x([0-9]+)@([0-9.]+)/)
            if (parsedMode) {
                updated.width = Number(parsedMode[1])
                updated.height = Number(parsedMode[2])
                updated.refreshRate = Number(parsedMode[3])
            }
            return updated
        })
        monitorRollback = monitors
        monitors = next
        monitorApplyState = "applying"
        monitorApplyMessage = I18n.tr("display.applying")
        monitorApplying = true
        pendingMonitorCommand = ["sh",
            Paths.shellRoot + "/scripts/system-settings.sh",
            "monitor", name, mode, position, String(scale), String(transform),
            vrr ? "1" : "0", mirror || "none", colorProfile || "srgb"]
        monitorApplyProcess.errorText = ""
        monitorApplyProcess.running = true
    }

    function setAdvancedDisplayMode(value) {
        advancedDisplayMode = Boolean(value)
        if (!advancedDisplayMode && pendingAdvancedConfirmation)
            rollbackAdvancedMonitor()
    }

    function applyAdvancedMonitor(name, width, height, refresh, scale, x, y,
            transform, vrr) {
        if (!advancedDisplayMode || monitorApplying
                || pendingAdvancedConfirmation)
            return false
        const safeWidth = Math.round(Number(width))
        const safeHeight = Math.round(Number(height))
        const safeRefresh = Number(refresh)
        const safeScale = Number(scale)
        if (safeWidth < 320 || safeWidth > 16384
                || safeHeight < 200 || safeHeight > 8640
                || safeRefresh < 20 || safeRefresh > 500
                || safeScale < 0.5 || safeScale > 4)
            return false
        advancedDisplayApplying = true
        setMonitor(name, safeWidth + "x" + safeHeight + "@"
            + safeRefresh.toFixed(3) + "Hz", x, y, safeScale,
            transform, vrr, "none", "srgb")
        return true
    }

    function resetDetectedMonitors() {
        if (monitorApplying || safeMonitorProcess.running)
            return
        monitorApplying = true
        monitorApplyState = "applying"
        monitorApplyMessage = I18n.tr("display.applying")
        safeMonitorProcess.running = true
    }

    function confirmAdvancedMonitor() {
        if (!pendingAdvancedConfirmation)
            return
        advancedConfirmTimer.stop()
        pendingAdvancedConfirmation = false
        advancedDisplayApplying = false
        advancedConfirmSeconds = 0
        monitorRollback = []
        monitorApplyState = "success"
        monitorApplyMessage = I18n.tr("display.applied")
        monitorStatusClear.restart()
    }

    function rollbackAdvancedMonitor() {
        if (!pendingAdvancedConfirmation || monitorRollback.length === 0)
            return
        const currentName = pendingMonitorCommand.length > 3
            ? pendingMonitorCommand[3] : ""
        let previous = null
        for (let index = 0; index < monitorRollback.length; ++index) {
            if (monitorRollback[index].name === currentName) {
                previous = monitorRollback[index]
                break
            }
        }
        advancedConfirmTimer.stop()
        pendingAdvancedConfirmation = false
        advancedDisplayApplying = false
        advancedConfirmSeconds = 0
        if (!previous) {
            refresh()
            return
        }
        const previousMode = previous.disabled ? "disabled"
            : previous.width + "x" + previous.height + "@"
                + Number(previous.refreshRate).toFixed(3) + "Hz"
        monitorRollback = []
        setMonitor(previous.name, previousMode, previous.x, previous.y,
            previous.scale, previous.transform, previous.vrr,
            previous.mirror || "none", previous.colorProfile || "srgb")
        monitorApplyMessage = I18n.tr("display.rolledBack")
    }

    function disableMonitor(name) {
        setMonitor(name, "disabled", 0, 0, 1, 0, false, "none", "srgb")
    }

    function setPrimaryMonitor(name) {
        if (!/^[A-Za-z0-9_.:-]+$/.test(String(name || "")))
            return
        primaryMonitor = name
        persist()
        Quickshell.execDetached({
            command: ["hyprctl", "eval",
                'hl.dispatch(hl.dsp.focus({ monitor = "' + name + '" }))']
        })
    }

    function setAnimationPreset(value) {
        animationPreset = value
        persist()
        Quickshell.execDetached({
            command: ["sh", Paths.shellRoot + "/scripts/system-settings.sh",
                "animation", value]
        })
    }

    function testSound() {
        Quickshell.execDetached({
            command: ["sh", Paths.shellRoot + "/scripts/system-settings.sh", "test-sound"]
        })
    }

    function setNightLight(value) {
        if (!available("nightlight"))
            return
        nightLightEnabled = value
        nightLightProcess.running = value
    }

    function setCursorTheme(name) {
        Quickshell.execDetached({
            command: ["sh", Paths.shellRoot + "/scripts/system-settings.sh",
                "appearance", "cursor", String(name)]
        })
    }

    function setIconTheme(name) {
        Quickshell.execDetached({
            command: ["sh", Paths.shellRoot + "/scripts/system-settings.sh",
                "appearance", "icons", String(name)]
        })
    }

    function persist() {
        if (!Paths.writableRootsReady) {
            persistPending = true
            return
        }
        stateFile.setText(JSON.stringify({
            borderSize, activeBorderColor, activeBorderColor2,
            activeBorderAngle, activeBorderGradient, inactiveBorderColor,
            activeOpacity, inactiveOpacity, windowRounding, innerGaps, outerGaps,
            shadowsEnabled, shadowSize, shadowStrength, shadowRange, shadowColor,
            blurEnabled, blurStrength, blurPasses, blurPopups, animationPreset,
            primaryMonitor, pointerSpeed, naturalScroll, tapToClick,
            keyboardLayout, repeatRate, repeatDelay, scrollMethod, workspaceGestures
        }, null, 2) + "\n")
        persistPending = false
    }

    property Connections pathReadiness: Connections {
        target: Paths
        function onWritableRootsReadyChanged() {
            if (Paths.writableRootsReady && root.persistPending)
                root.persist()
        }
    }

    function loadState(contents) {
        if (String(contents || "").trim().length === 0)
            return
        try {
            const data = JSON.parse(contents)
            const keys = [
                "borderSize", "activeBorderColor", "activeBorderColor2",
                "activeBorderAngle", "activeBorderGradient", "inactiveBorderColor",
                "activeOpacity", "inactiveOpacity", "windowRounding",
                "innerGaps", "outerGaps", "shadowsEnabled", "shadowSize",
                "shadowStrength", "shadowRange", "shadowColor", "blurEnabled",
                "blurStrength", "blurPasses", "blurPopups", "animationPreset",
                "primaryMonitor", "pointerSpeed", "naturalScroll", "tapToClick",
                "keyboardLayout", "repeatRate", "repeatDelay", "scrollMethod",
                "workspaceGestures"
            ]
            for (let index = 0; index < keys.length; ++index) {
                const key = keys[index]
                if (data[key] !== undefined)
                    root[key] = data[key]
            }
        } catch (error) {
            console.warn("Voidline: unable to parse system settings", error)
        }
    }

    property var stateFile: FileView {
        path: Paths.writableRootsReady
            ? Paths.configRoot + "/system-settings.json" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: stateReload.restart()
        onLoaded: root.loadState(text())
    }

    property var stateReload: Timer {
        interval: 70
        onTriggered: stateFile.reload()
    }

    property var coreSnapshot: Process {
        command: ["sh", Paths.shellRoot + "/scripts/system-settings.sh", "snapshot-core"]
        stdout: StdioCollector { onStreamFinished: root.parseSnapshot(text, false) }
        onExited: (code, status) => {
            if (code !== 0)
                root.loading = false
        }
    }

    property var deviceSnapshot: Process {
        command: ["sh", Paths.shellRoot + "/scripts/system-settings.sh", "snapshot-devices"]
        stdout: StdioCollector { onStreamFinished: root.parseSnapshot(text, true) }
        onExited: (code, status) => {
            if (code !== 0)
                root.devicesLoading = false
        }
    }

    property var nightLightProcess: Process {
        command: ["hyprsunset", "-t", "4500"]
        onExited: (code, status) => root.nightLightEnabled = false
    }

    property var refreshTimer: Timer {
        interval: 15000
        repeat: true
        onTriggered: root.refresh()
    }

    property var monitorRefresh: Timer {
        interval: 100
        onTriggered: root.refresh()
    }

    property var monitorStatusClear: Timer {
        interval: 2600
        onTriggered: {
            if (!root.monitorApplying) {
                root.monitorApplyState = "idle"
                root.monitorApplyMessage = ""
            }
        }
    }

    property var monitorApplyProcess: Process {
        property string errorText: ""
        command: root.pendingMonitorCommand
        stderr: StdioCollector {
            onStreamFinished: monitorApplyProcess.errorText = text.trim()
        }
        onExited: (exitCode, exitStatus) => {
            root.monitorApplying = false
            if (exitCode === 0) {
                if (root.advancedDisplayApplying) {
                    root.pendingAdvancedConfirmation = true
                    root.advancedConfirmSeconds = 15
                    root.monitorApplyState = "confirm"
                    root.monitorApplyMessage = I18n.tr("display.confirmAdvanced", {
                        seconds: root.advancedConfirmSeconds
                    })
                    advancedConfirmTimer.restart()
                } else {
                    root.monitorApplyState = "success"
                    root.monitorApplyMessage = I18n.tr("display.applied")
                    root.monitorRollback = []
                }
                root.monitorRefresh.restart()
            } else {
                root.monitors = root.monitorRollback
                root.monitorRollback = []
                root.monitorApplyState = "failure"
                root.monitorApplyMessage = monitorApplyProcess.errorText.length > 0
                    ? monitorApplyProcess.errorText : I18n.tr("display.applyFailed")
                root.advancedDisplayApplying = false
            }
            if (!root.pendingAdvancedConfirmation)
                root.monitorStatusClear.restart()
        }
    }

    property var safeMonitorProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/system-settings.sh",
            "safe-monitors"]
        property string errorText: ""
        stderr: StdioCollector {
            onStreamFinished: safeMonitorProcess.errorText = text.trim()
        }
        onExited: (exitCode, exitStatus) => {
            root.monitorApplying = false
            root.advancedDisplayApplying = false
            root.pendingAdvancedConfirmation = false
            root.monitorRollback = []
            root.monitorApplyState = exitCode === 0 ? "success" : "failure"
            root.monitorApplyMessage = exitCode === 0
                ? I18n.tr("display.resetDetectedDone")
                : (safeMonitorProcess.errorText.length > 0
                    ? safeMonitorProcess.errorText : I18n.tr("display.applyFailed"))
            root.monitorRefresh.restart()
            root.monitorStatusClear.restart()
        }
    }

    property var advancedConfirmTimer: Timer {
        interval: 1000
        repeat: true
        onTriggered: {
            root.advancedConfirmSeconds--
            if (root.advancedConfirmSeconds <= 0) {
                stop()
                root.rollbackAdvancedMonitor()
            } else {
                root.monitorApplyMessage = I18n.tr("display.confirmAdvanced", {
                    seconds: root.advancedConfirmSeconds
                })
            }
        }
    }

    property var applyRefresh: Timer {
        interval: 850
        onTriggered: root.refresh()
    }

    property var hyprWriteDelay: Timer {
        interval: 90
        onTriggered: {
            if (hyprApplyProcess.running || !root.pendingHyprWrite)
                return
            root.activeHyprWrite = root.pendingHyprWrite
            root.pendingHyprWrite = null
            hyprApplyProcess.errorText = ""
            hyprApplyProcess.running = true
        }
    }

    property var hyprApplyProcess: Process {
        property string errorText: ""
        command: root.activeHyprWrite ? [
            "sh", Paths.shellRoot + "/scripts/system-settings.sh", "hypr",
            root.activeHyprWrite.key, String(root.activeHyprWrite.value)
        ] : ["/usr/bin/true"]
        stderr: StdioCollector {
            onStreamFinished: hyprApplyProcess.errorText = text.trim()
        }
        onExited: (exitCode, exitStatus) => {
            const applied = root.activeHyprWrite
            if (exitCode === 0) {
                root.hyprApplyState = "success"
                root.hyprApplyMessage = I18n.tr("display.applied")
            } else if (applied) {
                if (applied.previousValues) {
                    const keys = Object.keys(applied.previousValues)
                    for (let index = 0; index < keys.length; ++index)
                        root[keys[index]] = applied.previousValues[keys[index]]
                } else {
                    root[applied.propertyName] = applied.previous
                }
                root.persist()
                root.hyprApplyState = "failure"
                root.hyprApplyMessage = hyprApplyProcess.errorText.length > 0
                    ? hyprApplyProcess.errorText : I18n.tr("display.applyFailed")
            }
            root.activeHyprWrite = null
            hyprStatusClear.restart()
            if (root.pendingHyprWrite)
                hyprWriteDelay.restart()
            else if (exitCode === 0)
                applyRefresh.restart()
        }
    }

    property var hyprStatusClear: Timer {
        interval: 2200
        onTriggered: {
            if (!hyprApplyProcess.running && !root.pendingHyprWrite) {
                root.hyprApplyState = "idle"
                root.hyprApplyMessage = ""
            }
        }
    }

    property var discoveryRefresh: Timer {
        interval: 7200
        onTriggered: root.refreshDevices()
    }
}
