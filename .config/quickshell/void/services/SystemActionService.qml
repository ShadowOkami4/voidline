pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../core"

QtObject {
    id: root

    property bool homeActive: false
    property bool hotspotPageActive: false
    property bool projectPageActive: false
    property bool recorderAvailable: false
    property string hotspotCommand: ""
    property bool hotspotActive: false
    property bool hotspotStarting: false
    property bool hotspotStopping: false
    property bool hotspotStopRequested: false
    property string hotspotWifiInterface: ""
    property string hotspotInternetInterface: ""
    property string hotspotSsid: "Voidline"
    property string hotspotPassword: ""
    property string hotspotBand: "2.4"
    property string hotspotMessage: ""
    property string hotspotError: ""
    property var hotspotClients: []
    property bool hotspotQrAvailable: false
    property bool hotspotProfileLoaded: false
    property bool hotspotProfileSaved: false
    property bool hotspotQrGenerating: false
    property string hotspotQrPath: ""
    property int hotspotQrRevision: 0
    property string pendingProfileSsid: ""
    property string pendingProfilePassword: ""
    property string pendingProfileBand: "2.4"
    property string pendingQrSsid: ""
    property string pendingQrPassword: ""
    property string recordingPath: ""
    property string recordingOutputName: ""
    property string recordingDiagnostic: ""
    property bool recordingStopping: false
    property string message: ""
    property string error: ""
    property var monitors: []
    property string projectionMode: "internal"
    property string pendingProjectionMode: ""
    property int capabilityProbeAttempts: 0
    property bool keepAwakeStopping: false
    property string sessionActionError: ""
    property string pendingSessionAction: ""

    readonly property bool recording: recorderProcess.running
    readonly property bool hotspotAvailable: hotspotCommand.length > 0
    readonly property bool hotspotChanging: hotspotStarting || hotspotStopping
    readonly property bool hotspotProfileReady: hotspotProfileLoaded
        && hotspotSsid.length > 0 && hotspotPassword.length >= 8
    readonly property int hotspotClientCount: hotspotClients.length
    readonly property bool projectionChanging: projectionProcess.running
    readonly property int monitorCount: monitors.length
    readonly property bool keepAwakeActive: keepAwakeProcess.running && !keepAwakeStopping
    readonly property bool sessionActionRunning: sessionActionProcess.running

    function refreshCapabilities() {
        if (!capabilityProbe.running)
            capabilityProbe.running = true
    }

    function parseCapabilities(contents) {
        const rows = contents.trim().split("\n")
        for (let index = 0; index < rows.length; ++index) {
            const fields = rows[index].split("|")
            if (fields[0] === "recorder")
                recorderAvailable = fields[1] === "1"
            else if (fields[0] === "hotspot")
                hotspotCommand = fields[1] || ""
            else if (fields[0] === "hotspot-qr")
                hotspotQrAvailable = fields[1] === "1"
        }
    }

    function loadHotspotProfile() {
        if (!hotspotProfileQuery.running)
            hotspotProfileQuery.running = true
    }

    function parseHotspotProfile(contents) {
        const rows = contents.trim().split("\n")
        for (let index = 0; index < rows.length; ++index) {
            const fields = rows[index].split("|")
            const value = fields.slice(1).join("|")
            if (fields[0] === "ssid")
                hotspotSsid = value
            else if (fields[0] === "password")
                hotspotPassword = value
            else if (fields[0] === "band")
                hotspotBand = value === "5" ? "5" : "2.4"
        }
        hotspotProfileLoaded = true
        hotspotProfileSaved = hotspotSsid.length > 0 && hotspotPassword.length >= 8
    }

    function saveHotspotProfile(ssid, password, band) {
        if (hotspotProfileSave.running)
            return
        pendingProfileSsid = ssid.trim()
        pendingProfilePassword = password
        pendingProfileBand = band === "5" ? "5" : "2.4"
        hotspotSsid = pendingProfileSsid
        hotspotPassword = pendingProfilePassword
        hotspotBand = pendingProfileBand
        hotspotProfileSaved = false
        hotspotProfileSave.running = true
    }

    function generateHotspotQr(ssid, password) {
        hotspotError = ""
        if (!hotspotQrAvailable) {
            hotspotError = "Install qrencode to share this network"
            return
        }
        if (ssid.trim().length === 0 || password.length < 8) {
            hotspotError = "Enter a valid network name and password first"
            return
        }
        if (hotspotQrProcess.running)
            return
        pendingQrSsid = ssid.trim()
        pendingQrPassword = password
        hotspotQrPath = ""
        hotspotQrGenerating = true
        hotspotQrProcess.running = true
    }

    function refreshDisplays() {
        if (!monitorQuery.running)
            monitorQuery.running = true
    }

    function refreshHotspotState() {
        if (hotspotAvailable && !hotspotStateQuery.running)
            hotspotStateQuery.running = true
        else if (!hotspotAvailable)
            hotspotActive = false
    }

    function refreshHotspotInterfaces() {
        if (!hotspotInterfaceQuery.running)
            hotspotInterfaceQuery.running = true
    }

    function parseHotspotInterfaces(contents) {
        const rows = contents.trim().split("\n")
        for (let index = 0; index < rows.length; ++index) {
            const fields = rows[index].split("|")
            if (fields[0] === "wifi")
                hotspotWifiInterface = fields[1] || ""
            else if (fields[0] === "internet")
                hotspotInternetInterface = fields[1] || ""
        }
    }

    function refreshHotspotClients() {
        if (hotspotActive && !hotspotClientQuery.running)
            hotspotClientQuery.running = true
        else if (!hotspotActive)
            hotspotClients = []
    }

    function startHotspot(ssid, password, band) {
        const cleanSsid = ssid.trim()
        hotspotError = ""
        hotspotMessage = ""

        if (!hotspotAvailable) {
            hotspotError = "Install linux-wifi-hotspot, hostapd and dnsmasq"
            return
        }
        if (hotspotWifiInterface.length === 0 || hotspotInternetInterface.length === 0) {
            hotspotError = "Wi-Fi or internet uplink could not be detected"
            refreshHotspotInterfaces()
            return
        }
        if (cleanSsid.length === 0 || cleanSsid.length > 32) {
            hotspotError = "Network name must contain 1 to 32 characters"
            return
        }
        if (password.length < 8 || password.length > 63) {
            hotspotError = "Password must contain 8 to 63 characters"
            return
        }
        if (hotspotActive || hotspotChanging || hotspotStartProcess.running)
            return

        hotspotSsid = cleanSsid
        hotspotPassword = password
        hotspotBand = band === "5" ? "5" : "2.4"
        saveHotspotProfile(hotspotSsid, hotspotPassword, hotspotBand)
        hotspotStopRequested = false
        hotspotStarting = true
        hotspotMessage = "Starting hotspot…"
        hotspotStartProcess.running = true
        hotspotStartTimeout.restart()
    }

    function stopHotspot() {
        hotspotError = ""
        if (!hotspotActive || hotspotStopping)
            return
        hotspotStopRequested = true
        hotspotStopping = true
        hotspotMessage = "Stopping hotspot…"
        hotspotStopProcess.running = true
    }

    function parseMonitors(contents) {
        try {
            const payload = JSON.parse(contents)
            monitors = payload
            const enabled = []
            for (let index = 0; index < payload.length; ++index) {
                if (!payload[index].disabled && payload[index].width > 0)
                    enabled.push(payload[index])
            }

            if (enabled.length <= 1) {
                const name = enabled.length === 1 ? enabled[0].name || "" : ""
                projectionMode = name.indexOf("eDP-") === 0 ? "internal" : "external"
                return
            }

            let mirrored = false
            for (let index = 0; index < enabled.length; ++index) {
                if (enabled[index].mirrorOf && enabled[index].mirrorOf !== "none") {
                    mirrored = true
                    break
                }
            }
            projectionMode = mirrored ? "duplicate" : "extend"
        } catch (parseError) {
            root.error = "Display state could not be read"
        }
    }

    function notifyRecording(title, body, icon) {
        Quickshell.execDetached({
            command: ["notify-send", "-a", "Voidline", "-i", icon, title, body]
        })
    }

    function startRecording(outputName) {
        error = ""
        message = ""
        if (!recorderAvailable) {
            error = "Install wf-recorder to enable screen recording"
            return false
        }
        if (recorderProcess.running)
            return false

        recordingPath = ""
        recordingDiagnostic = ""
        recordingOutputName = outputName || ""
        recordingStopping = false
        recorderProcess.running = true
        recorderStartFeedback.restart()
        return true
    }

    function stopRecording() {
        error = ""
        if (!recorderProcess.running || recordingStopping)
            return false
        recordingStopping = true
        message = "Finishing screen recording…"
        recorderProcess.signal(2)
        recorderStopTimeout.restart()
        return true
    }

    function toggleRecording(outputName) {
        return recorderProcess.running ? stopRecording() : startRecording(outputName)
    }

    function setProjectionMode(mode) {
        if (projectionProcess.running || (monitorCount < 2 && mode !== "internal"))
            return
        pendingProjectionMode = mode
        error = ""
        projectionProcess.running = true
    }

    function toggleKeepAwake() {
        sessionActionError = ""
        if (keepAwakeProcess.running) {
            keepAwakeStopping = true
            keepAwakeProcess.signal(15)
        } else {
            keepAwakeStopping = false
            keepAwakeProcess.running = true
        }
    }

    function performSessionAction(action) {
        const allowed = ["suspend", "logout", "reboot", "poweroff"]
        if (allowed.indexOf(action) < 0 || sessionActionProcess.running)
            return
        sessionActionError = ""
        pendingSessionAction = action
        sessionActionProcess.running = true
    }

    onHomeActiveChanged: {
        if (homeActive) {
            capabilityProbeAttempts = 0
            refreshCapabilities()
            refreshDisplays()
            refreshHotspotState()
        }
    }

    onHotspotPageActiveChanged: {
        if (hotspotPageActive) {
            capabilityProbeAttempts = 0
            refreshCapabilities()
            refreshHotspotInterfaces()
            refreshHotspotState()
            refreshHotspotClients()
            if (!hotspotProfileLoaded)
                loadHotspotProfile()
        }
    }

    onProjectPageActiveChanged: {
        if (projectPageActive)
            refreshDisplays()
    }

    property var projectRefresh: Timer {
        interval: 1800
        repeat: true
        running: root.projectPageActive
        onTriggered: root.refreshDisplays()
    }

    property var capabilityProbe: Process {
        command: ["sh", Paths.shellRoot + "/scripts/action-capabilities.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.parseCapabilities(text)
                root.refreshHotspotState()
            }
        }
    }

    // Briefly discover packages that finish installing while Home is open,
    // without leaving a permanent idle process behind.
    property var capabilityRefresh: Timer {
        interval: 2500
        repeat: true
        running: (root.homeActive || root.hotspotPageActive) && root.capabilityProbeAttempts < 12
            && (!root.recorderAvailable || !root.hotspotAvailable || !root.hotspotQrAvailable)
        onTriggered: {
            ++root.capabilityProbeAttempts
            root.refreshCapabilities()
        }
    }

    property var monitorQuery: Process {
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector { onStreamFinished: root.parseMonitors(text) }
    }

    property var hotspotRefresh: Timer {
        interval: 1500
        repeat: true
        running: (root.homeActive || root.hotspotPageActive || root.hotspotStarting || root.hotspotStopping)
            && root.hotspotAvailable
        onTriggered: root.refreshHotspotState()
    }

    property var hotspotStateQuery: Process {
        command: ["sh", Paths.shellRoot + "/scripts/hotspot-state.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const wasActive = root.hotspotActive
                root.hotspotActive = text.trim() === "1"
                if (root.hotspotActive) {
                    root.hotspotStarting = false
                    hotspotStartTimeout.stop()
                    if (!wasActive)
                        root.hotspotMessage = "Hotspot is active"
                    root.refreshHotspotClients()
                } else {
                    root.hotspotClients = []
                    if (wasActive && !root.hotspotStopping)
                        root.hotspotMessage = "Hotspot stopped"
                }
            }
        }
    }

    property var hotspotInterfaceQuery: Process {
        command: ["sh", Paths.shellRoot + "/scripts/hotspot-interfaces.sh"]
        stdout: StdioCollector { onStreamFinished: root.parseHotspotInterfaces(text) }
    }

    property var hotspotClientQuery: Process {
        command: ["sh", Paths.shellRoot + "/scripts/hotspot-clients.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const clients = []
                const rows = text.trim().split("\n")
                for (let index = 0; index < rows.length; ++index) {
                    const fields = rows[index].split("|")
                    if (fields[0] === "client" && fields[1])
                        clients.push(fields[1])
                }
                root.hotspotClients = clients
            }
        }
    }

    property var hotspotClientRefresh: Timer {
        interval: 2500
        repeat: true
        running: root.hotspotPageActive && root.hotspotActive
        onTriggered: root.refreshHotspotClients()
    }

    property var hotspotProfileQuery: Process {
        command: ["sh", Paths.shellRoot + "/scripts/hotspot-profile.sh", "read"]
        stdout: StdioCollector { onStreamFinished: root.parseHotspotProfile(text) }
    }

    property var hotspotProfileSave: Process {
        command: ["sh", Paths.shellRoot + "/scripts/hotspot-profile.sh", "write"]
        stdinEnabled: true

        onStarted: write(root.pendingProfileSsid + "\n" + root.pendingProfilePassword
            + "\n" + root.pendingProfileBand + "\n")

        onExited: (exitCode, exitStatus) => {
            root.hotspotProfileSaved = exitCode === 0
            if (exitCode !== 0)
                root.hotspotError = "The hotspot password could not be saved"
            root.pendingProfileSsid = ""
            root.pendingProfilePassword = ""
        }
    }

    property var hotspotQrProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/hotspot-qr.sh"]
        stdinEnabled: true

        onStarted: write(root.pendingQrSsid + "\n" + root.pendingQrPassword + "\n")

        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.trim().split("\n")
                for (let index = 0; index < rows.length; ++index) {
                    const fields = rows[index].split("|")
                    if (fields[0] === "path" && fields[1]) {
                        root.hotspotQrPath = fields.slice(1).join("|")
                        ++root.hotspotQrRevision
                    } else if (fields[0] === "error") {
                        root.hotspotError = fields.slice(1).join("|")
                    }
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            root.hotspotQrGenerating = false
            if (exitCode !== 0 && root.hotspotError.length === 0)
                root.hotspotError = "The hotspot QR code could not be generated"
            root.pendingQrSsid = ""
            root.pendingQrPassword = ""
        }
    }

    property var recorderProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/screen-record.sh",
            root.recordingOutputName]

        stdout: SplitParser {
            onRead: data => {
                const match = data.match(/^path\|(.+)$/)
                if (match)
                    root.recordingPath = match[1].trim()
            }
        }

        stderr: SplitParser {
            onRead: data => {
                const line = data.trim()
                if (line.length > 0)
                    root.recordingDiagnostic = line
            }
        }

        onExited: (exitCode, exitStatus) => {
            const wasStopping = root.recordingStopping
            recorderStartFeedback.stop()
            recorderStopTimeout.stop()
            root.recordingStopping = false
            root.recordingOutputName = ""

            if (root.recordingPath.length > 0 && (exitCode === 0 || wasStopping)) {
                root.message = "Recording saved to " + root.recordingPath
                root.notifyRecording("Screen recording saved", root.recordingPath,
                    "video-x-generic")
            } else if (exitCode !== 0) {
                root.error = root.recordingDiagnostic.length > 0
                    ? root.recordingDiagnostic : "Screen recording could not start"
                root.notifyRecording("Screen recording failed", root.error, "dialog-error")
            }
        }
    }

    property var recorderStartFeedback: Timer {
        interval: 750
        onTriggered: {
            if (!root.recorderProcess.running || root.recordingPath.length === 0)
                return
            root.message = root.recordingOutputName.length > 0
                ? "Recording " + root.recordingOutputName
                : "Screen recording started"
            root.notifyRecording("Screen recording started", "Select Record again to stop and save",
                "media-record")
        }
    }

    property var recorderStopTimeout: Timer {
        interval: 2500
        onTriggered: {
            if (root.recorderProcess.running)
                root.recorderProcess.signal(15)
        }
    }

    property var hotspotStartProcess: Process {
        command: root.hotspotCommand.length > 0
            ? ["pkexec", root.hotspotCommand, "--freq-band", root.hotspotBand,
                root.hotspotWifiInterface, root.hotspotInternetInterface]
            : ["true"]
        stdinEnabled: true

        onStarted: {
            write(root.hotspotSsid + "\n" + root.hotspotPassword + "\n")
        }

        stdout: StdioCollector {
            id: hotspotStartOutput
            waitForEnd: false
        }

        stderr: StdioCollector {
            id: hotspotStartErrorOutput
            waitForEnd: false
        }

        onExited: (exitCode, exitStatus) => {
            hotspotStartTimeout.stop()
            root.hotspotStarting = false
            if (exitCode !== 0 && !root.hotspotStopRequested) {
                const details = hotspotStartErrorOutput.text.trim()
                root.hotspotError = details.length > 0
                    ? details.split("\n").slice(-1)[0]
                    : "The hotspot could not be started"
            }
            root.hotspotStopRequested = false
            root.refreshHotspotState()
        }
    }

    property var hotspotStartTimeout: Timer {
        interval: 15000
        onTriggered: {
            if (root.hotspotStarting && !root.hotspotActive) {
                root.hotspotStarting = false
                root.hotspotError = "The hotspot took too long to start"
                if (hotspotStartProcess.running)
                    hotspotStartProcess.signal(15)
            }
        }
    }

    property var hotspotStopProcess: Process {
        command: root.hotspotCommand.length > 0
            ? ["pkexec", root.hotspotCommand, "--stop", root.hotspotWifiInterface]
            : ["true"]

        onExited: (exitCode, exitStatus) => {
            root.hotspotStopping = false
            if (exitCode !== 0) {
                root.hotspotStopRequested = false
                root.hotspotError = "The hotspot could not be stopped"
            } else {
                root.hotspotMessage = "Hotspot stopped"
            }
            hotspotStopRefresh.restart()
        }
    }

    property var hotspotStopRefresh: Timer {
        interval: 450
        onTriggered: root.refreshHotspotState()
    }

    property var projectionProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/project-display.sh", root.pendingProjectionMode]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.error = "The display mode could not be applied"
            root.pendingProjectionMode = ""
            projectionRefreshDelay.restart()
        }
    }

    property var projectionRefreshDelay: Timer {
        interval: 500
        onTriggered: root.refreshDisplays()
    }

    property var keepAwakeProcess: Process {
        command: ["systemd-inhibit", "--what=idle:sleep", "--who=Voidline",
            "--why=Keep Awake is enabled", "--mode=block", "sleep", "infinity"]

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && !root.keepAwakeStopping)
                root.sessionActionError = "Keep Awake could not be enabled"
            root.keepAwakeStopping = false
        }
    }

    property var sessionActionProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/session-action.sh",
            root.pendingSessionAction]
        stderr: StdioCollector { id: sessionActionStderr }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                const details = sessionActionStderr.text.trim()
                root.sessionActionError = details.length > 0
                    ? details.split("\n").slice(-1)[0]
                    : "The requested session action failed"
            }
            root.pendingSessionAction = ""
        }
    }

    Component.onCompleted: {
        capabilityProbeAttempts = 0
        refreshCapabilities()
        refreshDisplays()
        refreshHotspotInterfaces()
        loadHotspotProfile()
    }
}
