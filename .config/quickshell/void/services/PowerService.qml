pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import "../core"

QtObject {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property bool available: battery.ready && battery.isPresent
    readonly property int percentage: available ? Math.round(battery.percentage * 100) : 0
    readonly property bool charging: available && battery.state === UPowerDeviceState.Charging
    readonly property real watts: available ? Math.abs(battery.changeRate) : 0
    readonly property int remainingSeconds: available ? Math.round(charging ? battery.timeToFull : battery.timeToEmpty) : 0
    readonly property string remainingLabel: formatDuration(remainingSeconds)

    property bool monitoring: false
    property real cpuUsage: 0
    property real memoryUsage: 0
    property real memoryUsedGiB: 0
    property real memoryTotalGiB: 0
    property real swapUsage: 0
    property real diskUsage: 0
    property real diskUsedGiB: 0
    property real diskTotalGiB: 0
    property real loadAverage: 0
    property real cpuTemperature: 0
    property real cpuFrequencyGhz: 0
    property real gpuUsage: 0
    property real gpuTemperature: 0
    property real gpuMemoryUsedGiB: 0
    property real gpuMemoryTotalGiB: 0
    property string networkInterface: ""
    property real networkDownloadKiB: 0
    property real networkUploadKiB: 0
    property real diskReadMiB: 0
    property real diskWriteMiB: 0
    property var topCpuApplications: []
    property var topMemoryApplications: []
    property int processCount: 0
    property int uptimeSeconds: 0
    property int cycleCount: 0
    property int batteryHealth: available && battery.healthSupported ? Math.round(battery.healthPercentage) : 0
    property var cpuHistory: []
    property var memoryHistory: []

    // A real backlight device is also a reliable laptop/display capability
    // signal. It is sampled only while Home needs to present the control.
    property bool brightnessMonitoring: false
    property bool backlightAvailable: false
    property string backlightDevice: ""
    property var brightnessDevices: []
    property int brightnessPercent: 0
    property string brightnessError: ""
    property int desiredBrightness: -1
    property int writingBrightness: -1
    readonly property bool brightnessChanging: brightnessWriteDelay.running || brightnessWrite.running

    readonly property string profileMode: {
        if (PowerProfiles.profile === PowerProfile.PowerSaver)
            return "saver"
        if (PowerProfiles.profile === PowerProfile.Performance)
            return "performance"
        return "balanced"
    }
    readonly property bool performanceAvailable: PowerProfiles.hasPerformanceProfile
    property string profileError: ""
    property bool profileChanging: false
    property string requestedProfile: ""
    readonly property string uptimeLabel: formatUptime(uptimeSeconds)

    property real previousCpuIdle: -1
    property real previousCpuTotal: -1
    property double previousSnapshotMs: -1
    property double previousNetworkRx: -1
    property double previousNetworkTx: -1
    property double previousDiskReadSectors: -1
    property double previousDiskWriteSectors: -1

    readonly property string icon: {
        if (charging)
            return "battery_charging_full"
        if (percentage >= 90)
            return "battery_full"
        if (percentage >= 60)
            return "battery_5_bar"
        if (percentage >= 35)
            return "battery_3_bar"
        if (percentage >= 15)
            return "battery_2_bar"
        return "battery_alert"
    }

    function formatDuration(seconds) {
        if (!seconds || seconds <= 0)
            return charging ? "Charging" : "Estimating"

        const hours = Math.floor(seconds / 3600)
        const minutes = Math.max(1, Math.round((seconds % 3600) / 60))
        return hours > 0 ? hours + "h " + minutes + "m" : minutes + " min"
    }

    function formatUptime(seconds) {
        if (!seconds || seconds <= 0)
            return "Starting"

        const days = Math.floor(seconds / 86400)
        const hours = Math.floor((seconds % 86400) / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)
        if (days > 0)
            return days + "d " + hours + "h"
        if (hours > 0)
            return hours + "h " + minutes + "m"
        return Math.max(1, minutes) + " min"
    }

    function pushHistory(history, value) {
        const next = history.slice(Math.max(0, history.length - 39))
        next.push(value)
        return next
    }

    function parseSnapshot(contents) {
        const lines = contents.trim().split("\n")
        const timestamp = Date.now()
        const elapsed = previousSnapshotMs > 0
            ? Math.max(0.25, (timestamp - previousSnapshotMs) / 1000) : 0
        const cpuApps = []
        const memoryApps = []
        for (let index = 0; index < lines.length; ++index) {
            const line = lines[index].trim()
            if (line.startsWith("topcpu|") || line.startsWith("topmem|")) {
                const parts = line.split("|")
                const target = parts[0] === "topcpu" ? cpuApps : memoryApps
                target.push({
                    name: parts[1] || "—",
                    cpu: Number(parts[2]) || 0,
                    memory: Number(parts[3]) || 0
                })
                continue
            }
            const fields = line.split(/\s+/)
            if (fields[0] === "cpu" && fields.length >= 3) {
                const idle = Number(fields[1])
                const total = Number(fields[2])
                if (previousCpuTotal >= 0 && total > previousCpuTotal) {
                    const totalDelta = total - previousCpuTotal
                    const idleDelta = idle - previousCpuIdle
                    cpuUsage = Math.max(0, Math.min(100, (1 - idleDelta / totalDelta) * 100))
                    cpuHistory = pushHistory(cpuHistory, cpuUsage)
                }
                previousCpuIdle = idle
                previousCpuTotal = total
            } else if (fields[0] === "memory" && fields.length >= 3) {
                const totalKb = Number(fields[1])
                const availableKb = Number(fields[2])
                const usedKb = Math.max(0, totalKb - availableKb)
                memoryUsage = totalKb > 0 ? usedKb / totalKb * 100 : 0
                memoryUsedGiB = usedKb / 1048576
                memoryTotalGiB = totalKb / 1048576
                memoryHistory = pushHistory(memoryHistory, memoryUsage)
            } else if (fields[0] === "swap" && fields.length >= 3) {
                const swapTotalKb = Number(fields[1])
                const swapFreeKb = Number(fields[2])
                swapUsage = swapTotalKb > 0 ? (swapTotalKb - swapFreeKb) / swapTotalKb * 100 : 0
            } else if (fields[0] === "load" && fields.length >= 2) {
                loadAverage = Number(fields[1]) || 0
            } else if (fields[0] === "temperature" && fields.length >= 2) {
                cpuTemperature = Number(fields[1]) || 0
            } else if (fields[0] === "battery" && fields.length >= 4) {
                cycleCount = Number(fields[1]) || 0
                const full = Number(fields[2]) || 0
                const design = Number(fields[3]) || 0
                if (!(available && battery.healthSupported) && design > 0)
                    batteryHealth = Math.round(full / design * 100)
            } else if (fields[0] === "disk" && fields.length >= 3) {
                const usedKb = Number(fields[1]) || 0
                const totalKb = Number(fields[2]) || 0
                diskUsage = totalKb > 0 ? usedKb / totalKb * 100 : 0
                diskUsedGiB = usedKb / 1048576
                diskTotalGiB = totalKb / 1048576
            } else if (fields[0] === "system" && fields.length >= 4) {
                cpuFrequencyGhz = (Number(fields[1]) || 0) / 1000000
                processCount = Number(fields[2]) || 0
                uptimeSeconds = Number(fields[3]) || 0
            } else if (fields[0] === "gpu" && fields.length >= 2) {
                gpuUsage = Math.max(0, Math.min(100, Number(fields[1]) || 0))
            } else if (fields[0] === "gpu_detail" && fields.length >= 4) {
                gpuTemperature = Number(fields[1]) || 0
                gpuMemoryUsedGiB = (Number(fields[2]) || 0) / 1073741824
                gpuMemoryTotalGiB = (Number(fields[3]) || 0) / 1073741824
            } else if (fields[0] === "network" && fields.length >= 4) {
                networkInterface = fields[1]
                const received = Number(fields[2]) || 0
                const sent = Number(fields[3]) || 0
                if (elapsed > 0 && previousNetworkRx >= 0) {
                    networkDownloadKiB = Math.max(0, received - previousNetworkRx) / 1024 / elapsed
                    networkUploadKiB = Math.max(0, sent - previousNetworkTx) / 1024 / elapsed
                }
                previousNetworkRx = received
                previousNetworkTx = sent
            } else if (fields[0] === "diskio" && fields.length >= 3) {
                const readSectors = Number(fields[1]) || 0
                const writeSectors = Number(fields[2]) || 0
                if (elapsed > 0 && previousDiskReadSectors >= 0) {
                    diskReadMiB = Math.max(0, readSectors - previousDiskReadSectors) / 2048 / elapsed
                    diskWriteMiB = Math.max(0, writeSectors - previousDiskWriteSectors) / 2048 / elapsed
                }
                previousDiskReadSectors = readSectors
                previousDiskWriteSectors = writeSectors
            }
        }
        previousSnapshotMs = timestamp
        topCpuApplications = cpuApps
        topMemoryApplications = memoryApps
    }

    function refreshResources() {
        if (!snapshotProcess.running)
            snapshotProcess.running = true
    }

    function clampBrightness(value) {
        return Math.max(1, Math.min(100, Math.round(value)))
    }

    function parseBrightnessSnapshot(contents, includeExternal) {
        const rows = contents.trim().length > 0 ? contents.trim().split("\n") : []
        const parsed = includeExternal ? brightnessDevices.filter(item => item.kind === "internal") : []
        for (let index = 0; index < rows.length; ++index) {
            const fields = rows[index].split("|")
            if (fields[0] !== "device" || fields.length < 7)
                continue
            parsed.push({
                kind: fields[1],
                id: fields[2],
                percent: clampBrightness(Number(fields[3]) || 1),
                current: Number(fields[4]) || 0,
                maximum: Number(fields[5]) || 100,
                label: fields.slice(6).join("|")
            })
        }
        brightnessDevices = parsed
        const internal = parsed.find(item => item.kind === "internal")
        backlightAvailable = internal !== undefined
        backlightDevice = internal ? internal.id : ""
        if (internal && !brightnessChanging)
            brightnessPercent = internal.percent
        if (internal)
            brightnessError = ""
    }

    function refreshBrightness() {
        if (!brightnessQuery.running && !brightnessWrite.running)
            brightnessQuery.running = true
    }

    function setBrightness(value) {
        if (!backlightAvailable)
            return
        desiredBrightness = clampBrightness(value)
        brightnessPercent = desiredBrightness
        brightnessError = ""
        brightnessWriteDelay.restart()
    }

    function setDeviceBrightness(deviceId, value) {
        const target = brightnessDevices.find(item => item.id === deviceId)
        if (!target)
            return
        if (target.kind === "internal") {
            backlightDevice = target.id
            setBrightness(value)
            return
        }
        externalWrite.deviceId = target.id
        externalWrite.targetPercent = clampBrightness(value)
        brightnessDevices = brightnessDevices.map(item => item.id === target.id
            ? Object.assign({}, item, { percent: externalWrite.targetPercent })
            : item)
        brightnessError = ""
        if (!externalWrite.running)
            externalWrite.running = true
    }

    function beginBrightnessWrite() {
        if (brightnessWrite.running || desiredBrightness < 0)
            return
        writingBrightness = desiredBrightness
        brightnessWrite.running = true
    }

    function setProfile(mode) {
        if (profileChanging)
            return
        if (mode !== "saver" && mode !== "balanced" && mode !== "performance")
            return
        if (mode === "performance" && !performanceAvailable) {
            profileError = I18n.tr("power.performanceUnavailable")
            return
        }

        profileError = ""
        requestedProfile = mode
        profileChanging = true
        PowerProfiles.profile = mode === "saver" ? PowerProfile.PowerSaver
            : (mode === "performance" ? PowerProfile.Performance
                : PowerProfile.Balanced)
        profileConfirm.restart()
    }

    onMonitoringChanged: {
        if (monitoring) {
            refreshResources()
        }
    }

    onBrightnessMonitoringChanged: {
        if (brightnessMonitoring)
            refreshBrightness()
    }

    property var resourceTimer: Timer {
        interval: 2000
        repeat: true
        running: root.monitoring
        onTriggered: root.refreshResources()
    }

    property var snapshotProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/resource-snapshot.sh"]

        stdout: StdioCollector {
            onStreamFinished: root.parseSnapshot(text)
        }
    }

    property var brightnessActiveRefresh: Timer {
        interval: 1600
        repeat: true
        running: root.brightnessMonitoring
        onTriggered: root.refreshBrightness()
    }

    property var brightnessWriteDelay: Timer {
        interval: 65
        onTriggered: root.beginBrightnessWrite()
    }

    property var brightnessConfirmDelay: Timer {
        interval: 120
        onTriggered: root.refreshBrightness()
    }

    property var brightnessQuery: Process {
        command: ["sh", Paths.shellRoot + "/scripts/brightness-service.sh", "snapshot"]

        stdout: StdioCollector {
            onStreamFinished: root.parseBrightnessSnapshot(text, false)
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && !root.backlightAvailable) {
                root.backlightDevice = ""
                root.backlightAvailable = false
            }
        }
    }

    property var brightnessWrite: Process {
        command: ["sh", Paths.shellRoot + "/scripts/brightness-service.sh",
            "set-internal", root.backlightDevice, root.writingBrightness.toString()]

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.brightnessError = I18n.tr("brightness.changeFailed")

            if (root.desiredBrightness !== root.writingBrightness)
                brightnessWriteDelay.restart()
            else
                brightnessConfirmDelay.restart()
        }
    }

    property var externalRefreshTimer: Timer {
        interval: 12000
        repeat: true
        running: root.brightnessMonitoring
        triggeredOnStart: true
        onTriggered: {
            if (!externalQuery.running && !externalWrite.running)
                externalQuery.running = true
        }
    }

    property var externalQuery: Process {
        command: ["sh", Paths.shellRoot + "/scripts/brightness-service.sh", "snapshot-external"]
        stdout: StdioCollector {
            onStreamFinished: root.parseBrightnessSnapshot(text, true)
        }
    }

    property var externalWrite: Process {
        property string deviceId: ""
        property int targetPercent: 50
        command: ["sh", Paths.shellRoot + "/scripts/brightness-service.sh",
            "set-external", deviceId, targetPercent.toString()]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.brightnessError = I18n.tr("brightness.externalChangeFailed")
            externalQuery.running = true
        }
    }

    property var profileConfirm: Timer {
        interval: 900
        onTriggered: {
            root.profileChanging = false
            root.profileError = root.profileMode === root.requestedProfile
                ? "" : I18n.tr("power.profileFailed")
            root.requestedProfile = ""
        }
    }

    Component.onCompleted: refreshBrightness()
}
