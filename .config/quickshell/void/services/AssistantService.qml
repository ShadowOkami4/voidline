pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../core"

QtObject {
    id: root

    property bool agentStatePersistPending: false
    property bool providerPersistPending: false

    property string provider: "none"
    property bool providerReady: false
    property bool capabilitiesChecked: false
    property bool onlineProvider: false
    property string accelerator: "unknown"
    property string providerType: "local"
    property string modelFamily: "unknown"
    property string parameterSize: "unknown"
    property string quantization: "unknown"
    property string modelCapabilities: ""
    property int nativeContextTokens: 0
    property var models: []
    property string configuredModel: ""
    property string selectedModel: ""
    property string systemContext: ""
    property var messages: []
    property string streamingText: ""
    property string activePrompt: ""
    property string activeSystemPrompt: ""
    property string lastError: ""
    property bool cancellationRequested: false
    property var pendingConfirmation: null
    property string pendingFileQuery: ""
    property int historyLimit: 4
    property int revision: 0
    property string internetMode: "ask"
    property bool sessionInternetAllowed: false
    property var actionHistory: []
    property var pendingPlan: []
    property var backendActionQueue: []
    property var activeBackendAction: null
    property bool backendCancellationRequested: false
    property string plannerPrompt: ""
    property bool assistantEnabled: true
    property bool betaAcknowledged: false
    property bool agentStateLoaded: false
    property string performancePreset: "automatic"
    property int contextLimit: 4096
    property int cpuThreadLimit: 0
    property int unloadMinutes: 15
    property var providerConfiguration: ({})
    property double modelSizeBytes: 0
    property double loadedSizeBytes: 0
    property double loadedVramBytes: 0
    property int loadedContextTokens: 0
    property bool modelLoaded: false
    property double systemRamBytes: 0
    property double availableRamBytes: 0
    property double serviceRamBytes: 0
    property real serviceCpuPercent: 0
    property real gpuUsagePercent: 0
    property double gpuMemoryBytes: 0
    property double gpuMemoryTotalBytes: 0
    property bool gpuMemoryShared: false
    property int inputTokens: 0
    property int outputTokens: 0
    property int conversationTokens: 0
    property real tokensPerSecond: 0
    property real timeToFirstTokenMs: 0
    property real generationDurationMs: 0
    property string pendingCopyText: ""
    property var pendingInlineFileSearch: null
    property double inlineFileSearchDeadline: 0

    readonly property bool internetAllowed: internetMode === "always"
        || (internetMode === "session" && sessionInternetAllowed)

    readonly property bool busy: answerProcess.running || plannerProcess.running
    readonly property bool serviceChanging: stopServiceProcess.running
        || restartServiceProcess.running
    readonly property bool warming: warmProcess.running
    readonly property bool providerInstalled: provider !== "none"
    readonly property bool canAsk: assistantEnabled && providerReady
        && selectedModel.length > 0 && !busy
    readonly property string providerLabel: provider === "ollama"
        ? "Ollama" : I18n.tr("assistant.localProvider")
    readonly property string statusText: {
        if (!capabilitiesChecked)
            return I18n.tr("assistant.checkingRuntime")
        if (!providerInstalled)
            return I18n.tr("assistant.noProvider")
        if (!providerReady)
            return I18n.tr("assistant.providerUnavailable", {
                provider: providerLabel
            })
        if (models.length === 0)
            return I18n.tr("assistant.installModel")
        const compute = accelerator === "cpu" ? "CPU"
            : accelerator.charAt(0).toUpperCase() + accelerator.slice(1)
        return I18n.tr("assistant.modelStatus", {
            model: selectedModel,
            compute: compute
        })
    }

    function refreshCapabilities() {
        if (!FeatureRegistry.aiInstalled || !assistantEnabled)
            return
        if (!capabilityProcess.running)
            capabilityProcess.running = true
        if (!systemContextProcess.running && systemContext.length === 0)
            systemContextProcess.running = true
    }

    function parseCapabilities(contents) {
        const nextModels = []
        let nextProvider = "none"
        let nextReady = false
        let nextConfiguredModel = ""
        let nextAccelerator = "unknown"
        let nextOnline = false
        let nextHistoryLimit = 4
        const lines = String(contents || "").trim().split("\n")
        for (let index = 0; index < lines.length; ++index) {
            const separator = lines[index].indexOf("|")
            if (separator < 0)
                continue
            const key = lines[index].slice(0, separator)
            const value = lines[index].slice(separator + 1).trim()
            if (key === "provider")
                nextProvider = value || "none"
            else if (key === "provider-type")
                providerType = value || "local"
            else if (key === "ready")
                nextReady = value === "1"
            else if (key === "configured-model")
                nextConfiguredModel = value
            else if (key === "model" && value.length > 0)
                nextModels.push(value)
            else if (key === "accelerator")
                nextAccelerator = value || "unknown"
            else if (key === "online")
                nextOnline = value === "true" || value === "1"
            else if (key === "history-messages")
                nextHistoryLimit = Math.max(0, Math.min(12,
                    Number(value) || 4))
            else if (key === "model-size")
                modelSizeBytes = Math.max(0, Number(value) || 0)
            else if (key === "loaded")
                modelLoaded = value === "true" || value === "1"
            else if (key === "loaded-size")
                loadedSizeBytes = Math.max(0, Number(value) || 0)
            else if (key === "loaded-vram")
                loadedVramBytes = Math.max(0, Number(value) || 0)
            else if (key === "loaded-context")
                loadedContextTokens = Math.max(0, Number(value) || 0)
            else if (key === "model-family")
                modelFamily = value || "unknown"
            else if (key === "parameter-size")
                parameterSize = value || "unknown"
            else if (key === "quantization")
                quantization = value || "unknown"
            else if (key === "native-context")
                nativeContextTokens = Math.max(0, Number(value) || 0)
            else if (key === "model-capabilities")
                modelCapabilities = value
        }
        provider = nextProvider
        providerReady = nextReady
        configuredModel = nextConfiguredModel
        models = nextModels
        accelerator = nextAccelerator
        onlineProvider = nextOnline
        historyLimit = nextHistoryLimit
        if (models.indexOf(selectedModel) < 0) {
            selectedModel = models.indexOf(configuredModel) >= 0
                ? configuredModel : (models.length > 0 ? models[0] : "")
        }
        capabilitiesChecked = true
        revision++
    }

    function parseRuntimeMetrics(contents) {
        const lines = String(contents || "").trim().split("\n")
        for (let index = 0; index < lines.length; ++index) {
            const separator = lines[index].indexOf("|")
            if (separator < 0)
                continue
            const key = lines[index].slice(0, separator)
            const value = lines[index].slice(separator + 1).trim()
            if (key === "ram-total")
                systemRamBytes = Math.max(0, Number(value) || 0)
            else if (key === "ram-available")
                availableRamBytes = Math.max(0, Number(value) || 0)
            else if (key === "service-rss")
                serviceRamBytes = Math.max(0, Number(value) || 0)
            else if (key === "service-cpu")
                serviceCpuPercent = Math.max(0, Number(value) || 0)
            else if (key === "gpu-usage")
                gpuUsagePercent = Math.max(0, Number(value) || 0)
            else if (key === "gpu-memory-used")
                gpuMemoryBytes = Math.max(0, Number(value) || 0)
            else if (key === "gpu-memory-total")
                gpuMemoryTotalBytes = Math.max(0, Number(value) || 0)
            else if (key === "gpu-memory-shared")
                gpuMemoryShared = value === "true" || value === "1"
            else if (key === "model-size")
                modelSizeBytes = Math.max(0, Number(value) || 0)
            else if (key === "loaded")
                modelLoaded = value === "true" || value === "1"
            else if (key === "loaded-size")
                loadedSizeBytes = Math.max(0, Number(value) || 0)
            else if (key === "loaded-vram")
                loadedVramBytes = Math.max(0, Number(value) || 0)
            else if (key === "loaded-context")
                loadedContextTokens = Math.max(0, Number(value) || 0)
        }
        revision++
    }

    function refreshRuntimeMetrics() {
        if (FeatureRegistry.aiInstalled && providerReady && !metricsProcess.running)
            metricsProcess.running = true
    }

    function parseGenerationMetadata(contents) {
        const match = String(contents || "").match(/^VOIDLINE_METRICS\|(.+)$/m)
        if (!match)
            return
        try {
            const data = JSON.parse(match[1])
            inputTokens = Math.max(0, Number(data.input_tokens) || 0)
            outputTokens = Math.max(0, Number(data.output_tokens) || 0)
            conversationTokens += Math.max(0, Number(data.total_tokens) || 0)
            tokensPerSecond = Math.max(0, Number(data.tokens_per_second) || 0)
            timeToFirstTokenMs = Math.max(0, Number(data.time_to_first_token_ms) || 0)
            generationDurationMs = Math.max(0, Number(data.total_duration_ms) || 0)
            modelLoaded = true
        } catch (error) {
            // Metrics are supplementary; a malformed provider trailer must
            // never discard an otherwise valid answer.
        }
    }

    function cleanProviderError(contents) {
        return String(contents || "")
            .split("\n")
            .filter(line => !line.startsWith("VOIDLINE_METRICS|"))
            .join("\n").trim()
    }

    function formatBytes(value) {
        const bytes = Math.max(0, Number(value) || 0)
        if (bytes >= 1073741824)
            return (bytes / 1073741824).toFixed(bytes >= 10737418240 ? 0 : 1) + " GiB"
        if (bytes >= 1048576)
            return (bytes / 1048576).toFixed(0) + " MiB"
        return (bytes / 1024).toFixed(0) + " KiB"
    }

    function selectNextModel() {
        if (models.length < 2)
            return
        const index = models.indexOf(selectedModel)
        selectedModel = models[(index + 1) % models.length]
        revision++
    }

    function selectModel(model) {
        const candidate = String(model || "")
        if (models.indexOf(candidate) < 0 || candidate === selectedModel)
            return
        selectedModel = candidate
        revision++
        ensureWarm()
    }

    function ensureWarm() {
        if (FeatureRegistry.aiInstalled && assistantEnabled
                && providerReady && selectedModel.length > 0
                && !warmProcess.running && !answerProcess.running
                && !plannerProcess.running)
            warmProcess.running = true
    }

    function unloadModel() {
        cancel()
        if (selectedModel.length > 0 && !unloadProcess.running)
            unloadProcess.running = true
    }

    function stopService() {
        cancel()
        if (!stopServiceProcess.running && !restartServiceProcess.running)
            stopServiceProcess.running = true
    }

    function restartService() {
        cancel()
        if (!stopServiceProcess.running && !restartServiceProcess.running)
            restartServiceProcess.running = true
    }

    function cleanTarget(value) {
        return String(value || "")
            .replace(/[?.!,]+$/g, "")
            .replace(/^(the|my)\s+/i, "")
            .replace(/^for\s+/i, "")
            .replace(/\s+(please|for me)$/i, "")
            .trim()
    }

    function requestedPercent(text) {
        const match = String(text || "").match(/(\d{1,3})\s*%?/)
        if (!match)
            return -1
        return Math.max(0, Math.min(100, Number(match[1])))
    }

    function actionLevel(action) {
        if (!action)
            return "invalid"
        if (action.name === "session")
            return "dangerous"
        if (["online_search", "online_weather"].indexOf(action.name) >= 0)
            return internetAllowed ? "safe" : "confirmation"
        if (["screenshot", "screen_record", "set_wifi", "set_bluetooth"]
                .indexOf(action.name) >= 0)
            return "confirmation"
        return "safe"
    }

    function validateAction(action) {
        if (!action || typeof action.name !== "string")
            return false
        const allowed = [
            "confirm_pending", "cancel_pending", "open_item", "open_game",
            "search_apps", "search_games", "search_files", "current_wallpaper",
            "online_search", "online_weather",
            "show_system_info", "diagnostic", "open_panel", "open_settings",
            "set_volume", "set_brightness", "set_dnd", "set_wifi",
            "set_bluetooth", "power_profile", "screenshot", "color_picker",
            "keep_awake", "screen_record", "lock", "session"
        ]
        if (allowed.indexOf(action.name) < 0)
            return false
        const args = action.args || ({})
        const boundedText = value => typeof value === "string"
            && value.length > 0 && value.length <= 240
            && !/[\u0000-\u001f\u007f]/.test(value)
        if (["open_item", "open_game", "search_apps", "search_games"]
                .indexOf(action.name) >= 0 && !boundedText(args.query))
            return false
        if (["online_search", "online_weather"].indexOf(action.name) >= 0
                && !boundedText(args.query))
            return false
        if (action.name === "search_files") {
            if (!boundedText(args.query)
                    || ["all", "documents", "images", "media", "code"]
                        .indexOf(String(args.filter || "all")) < 0
                    || ["name", "content"]
                        .indexOf(String(args.mode || "name")) < 0
                    || ["home", "desktop", "documents", "downloads",
                        "music", "pictures", "videos", "projects"]
                        .indexOf(String(args.location || "home")) < 0)
                return false
        }
        if ((action.name === "set_volume" || action.name === "set_brightness")
                && (!Number.isFinite(Number(args.value))
                    || Number(args.value) < 0 || Number(args.value) > 100))
            return false
        if (action.name === "session"
                && ["poweroff", "reboot", "logout", "suspend"]
                    .indexOf(String(args.action || "")) < 0)
            return false
        if (action.name === "power_profile"
                && ["saver", "balanced", "performance"]
                    .indexOf(String(args.mode || "")) < 0)
            return false
        if (action.name === "open_panel"
                && ["control-center", "power", "music", "launcher"]
                    .indexOf(String(args.panel || "")) < 0)
            return false
        if (action.name === "open_settings"
                && ["home", "connections", "audio", "devices",
                    "notifications", "display", "appearance", "lock",
                    "security", "accessibility", "assistant", "updates", "system",
                    "developer"].indexOf(String(args.section || "home")) < 0)
            return false
        if (action.name === "diagnostic"
                && ["system", "network", "audio", "bluetooth", "display"]
                    .indexOf(String(args.area || "system")) < 0)
            return false
        if (["set_dnd", "set_wifi", "set_bluetooth"]
                .indexOf(action.name) >= 0 && typeof args.enabled !== "boolean")
            return false
        return true
    }

    function recordAction(action, state, detail) {
        const entry = {
            time: new Date().toISOString(),
            action: action ? action.name : "unknown",
            level: actionLevel(action),
            state: state,
            detail: String(detail || "")
        }
        actionHistory = [entry].concat(actionHistory).slice(0, 40)
        revision++
    }

    function setInternetMode(mode) {
        if (["disabled", "ask", "session", "always"].indexOf(mode) < 0)
            return
        internetMode = mode
        if (mode !== "session")
            sessionInternetAllowed = false
        persistAgentState()
    }

    function setAssistantEnabled(value) {
        const next = Boolean(value)
        if (next && !betaAcknowledged) {
            assistantEnabled = false
            revision++
            return
        }
        if (assistantEnabled === next)
            return
        assistantEnabled = next
        if (!next) {
            cancel()
            persistAgentState()
            stopService()
        } else {
            // Persist before the provider is requested: the user service has
            // an ExecCondition that refuses starts while this flag is false.
            persistAgentState()
            refreshCapabilities()
        }
        revision++
    }

    function acknowledgeBeta() {
        betaAcknowledged = true
        persistAgentState()
        setAssistantEnabled(true)
    }

    function allowInternetForSession() {
        internetMode = "session"
        sessionInternetAllowed = true
        persistAgentState()
    }

    function loadAgentState(contents) {
        try {
            const data = JSON.parse(String(contents || "{}"))
            internetMode = ["disabled", "ask", "session", "always"]
                .indexOf(data.internetMode) >= 0 ? data.internetMode : "ask"
            // Existing installations already opted into Lyra before the beta
            // acknowledgement flag existed. Preserve that choice; a fresh
            // empty state still requires explicit acknowledgement.
            const legacyEnabled = Object.prototype.hasOwnProperty.call(data, "enabled")
                && data.enabled !== false
            betaAcknowledged = data.betaAcknowledged === true || legacyEnabled
            assistantEnabled = data.enabled !== false && betaAcknowledged
        } catch (error) {
            internetMode = "ask"
            betaAcknowledged = false
            assistantEnabled = false
        }
        // A previous session permission never survives shell startup.
        sessionInternetAllowed = false
        agentStateLoaded = true
        if (!assistantEnabled)
            stopService()
    }

    function persistAgentState() {
        if (!Paths.writableRootsReady) {
            agentStatePersistPending = true
            return
        }
        agentStateFile.setText(JSON.stringify({
            enabled: assistantEnabled,
            betaAcknowledged: betaAcknowledged,
            internetMode: internetMode === "session" ? "ask" : internetMode
        }, null, 2) + "\n")
        agentStatePersistPending = false
    }

    function loadProviderConfiguration(contents) {
        try {
            const data = JSON.parse(String(contents || "{}"))
            providerConfiguration = data
            performancePreset = ["automatic", "low", "balanced", "maximum"]
                .indexOf(data.performancePreset) >= 0
                ? data.performancePreset : "automatic"
            contextLimit = Math.max(1024, Math.min(32768,
                Number(data.contextTokens) || 4096))
            cpuThreadLimit = Math.max(0, Math.min(64,
                Number(data.cpuThreads) || 0))
            const keepAlive = String(data.keepAlive || "15m")
            const minutes = keepAlive.match(/^(\d+)m$/)
            unloadMinutes = minutes ? Math.max(0,
                Math.min(120, Number(minutes[1]))) : 15
        } catch (error) {
            providerConfiguration = ({})
        }
        revision++
    }

    function writeProviderConfiguration(changes) {
        providerConfiguration = Object.assign({}, providerConfiguration, changes)
        if (!Paths.writableRootsReady) {
            providerPersistPending = true
            return
        }
        providerConfigFile.setText(JSON.stringify(providerConfiguration,
            null, 2) + "\n")
        providerPersistPending = false
        revision++
    }

    property Connections pathReadiness: Connections {
        target: Paths
        function onWritableRootsReadyChanged() {
            if (!Paths.writableRootsReady)
                return
            if (root.agentStatePersistPending)
                root.persistAgentState()
            if (root.providerPersistPending)
                root.writeProviderConfiguration({})
        }
    }

    function setPerformancePreset(value) {
        if (["automatic", "low", "balanced", "maximum"].indexOf(value) < 0)
            return
        performancePreset = value
        const contexts = { low: 2048, balanced: 4096, maximum: 8192 }
        if (contexts[value])
            contextLimit = contexts[value]
        writeProviderConfiguration({
            performancePreset: value,
            contextTokens: contextLimit
        })
    }

    function setContextLimit(value) {
        contextLimit = Math.max(1024, Math.min(32768, Math.round(Number(value))))
        performancePreset = "automatic"
        writeProviderConfiguration({
            performancePreset: performancePreset,
            contextTokens: contextLimit
        })
    }

    function setCpuThreadLimit(value) {
        cpuThreadLimit = Math.max(0, Math.min(64, Math.round(Number(value))))
        writeProviderConfiguration({ cpuThreads: cpuThreadLimit })
    }

    function setUnloadMinutes(value) {
        unloadMinutes = Math.max(0, Math.min(120, Math.round(Number(value))))
        writeProviderConfiguration({ keepAlive: unloadMinutes + "m" })
    }

    function settingsSection(text) {
        const value = String(text || "").toLowerCase()
        const sections = [
            ["connection", "connections"], ["network", "connections"],
            ["wifi", "connections"], ["wi-fi", "connections"],
            ["bluetooth", "devices"],
            ["audio", "audio"], ["sound", "audio"],
            ["device", "devices"], ["printer", "devices"],
            ["notification", "notifications"], ["display", "display"],
            ["monitor", "display"], ["appearance", "appearance"],
            ["theme", "appearance"], ["wallpaper", "appearance"],
            ["lock", "lock"], ["security", "security"],
            ["accessibility", "accessibility"], ["update", "updates"],
            ["system", "system"], ["about", "system"],
            ["lyra", "assistant"], ["assistant", "assistant"],
            ["developer", "developer"]
        ]
        for (let index = 0; index < sections.length; ++index) {
            if (value.indexOf(sections[index][0]) >= 0)
                return sections[index][1]
        }
        return "home"
    }

    function fastAction(prompt) {
        const raw = String(prompt || "").trim()
        const text = raw.toLowerCase()
        if (pendingConfirmation) {
            if (/^(yes|confirm|do it|proceed)$/i.test(raw))
                return { name: "confirm_pending", args: {} }
            if (/^(no|cancel|never mind|nevermind)$/i.test(raw))
                return { name: "cancel_pending", args: {} }
        }

        // Resolve shell-owned state before generic search parsing. A sentence
        // such as "find the file used as my current wallpaper" is an intent,
        // not a literal filename query.
        const mentionsWallpaperFile = /\bwallpaper\b/.test(text)
            && ((/\b(current|active|selected)\b/.test(text)
                    && /\b(file|path|folder|find|show|open|where)\b/.test(text))
                || (/\b(file|path|folder)\b/.test(text)
                    && /\b(find|show|open|where)\b/.test(text)))
        if (mentionsWallpaperFile || /\bwhere is\b.*\bwallpaper\b/.test(text))
            return { name: "current_wallpaper", args: {} }
        if (/\b(system information|system info|about (this )?(computer|system)|computer details)\b/.test(text))
            return { name: "show_system_info", args: {} }
        const explicitWeather = raw.match(/\bweather\s+(?:in|for)\s+(.+)/i)
        if (explicitWeather)
            return { name: "online_weather", args: { query: cleanTarget(explicitWeather[1]) } }
        if (/\b(weather|forecast|temperature outside)\b/i.test(raw)
                && Appearance.weatherLocation.length > 0)
            return { name: "online_weather", args: { query: Appearance.weatherLocation } }

        // Online and local searches are distinct intents. Words such as
        // "google", "browse", "news", and "information about" select the
        // web tool; a local search requires an explicit file/folder/content
        // cue or a known home-folder location below.
        const onlineIntent = /\b(google|browse|web|internet|online|news|latest|documentation|docs)\b/i.test(raw)
            || /\b(search|look up|find)\b.*\b(info|information|details|facts)\b/i.test(raw)
        if (onlineIntent) {
            const query = cleanTarget(raw
                .replace(/^(please\s+)?(google|browse|search|look up|find)(\s+the)?(\s+web|\s+internet|\s+online)?(\s+for)?(\s+me)?/i, "")
                .replace(/^(info|information|details|facts)\s+(for\s+me\s+)?(about|on)?\s*/i, ""))
            if (query.length > 0)
                return { name: "online_search", args: { query: query } }
        }
        if (/\b(diagnose|diagnostic|check status|troubleshoot)\b/.test(text)) {
            const area = /\b(network|internet|wi-?fi|ethernet)\b/.test(text) ? "network"
                : (/\b(audio|sound|pipewire|microphone)\b/.test(text) ? "audio"
                    : (/\bbluetooth\b/.test(text) ? "bluetooth"
                        : (/\bdisplay|monitor\b/.test(text) ? "display" : "system")))
            return { name: "diagnostic", args: { area: area } }
        }

        let percent = -1
        if (/\b(volume|sound)\b/.test(text)
                && (percent = requestedPercent(text)) >= 0)
            return { name: "set_volume", args: { value: percent } }
        if (/\b(brightness|backlight)\b/.test(text)
                && (percent = requestedPercent(text)) >= 0)
            return { name: "set_brightness", args: { value: percent } }

        if (/\b(do not disturb|dnd)\b/.test(text)
                && /\b(turn|switch|enable|disable|start|stop)\b/.test(text)) {
            const enabled = !/\b(off|disable|stop)\b/.test(text)
            return { name: "set_dnd", args: { enabled: enabled } }
        }
        if (/\bwi-?fi\b/.test(text)
                && /\b(turn|switch|enable|disable)\b/.test(text)) {
            const enabled = !/\b(off|disable)\b/.test(text)
            return { name: "set_wifi", args: { enabled: enabled } }
        }
        if (/\bbluetooth\b/.test(text)
                && /\b(turn|switch|enable|disable)\b/.test(text)) {
            const enabled = !/\b(off|disable)\b/.test(text)
            return { name: "set_bluetooth", args: { enabled: enabled } }
        }
        if (/\b(power saver|battery saver|balanced|performance)\b/.test(text)
                && /\b(set|switch|use|enable|turn)\b/.test(text)) {
            const mode = /\bperformance\b/.test(text) ? "performance"
                : (/\b(power saver|battery saver)\b/.test(text) ? "saver" : "balanced")
            return { name: "power_profile", args: { mode: mode } }
        }

        if (/^(please\s+)?(power off|shut down|shutdown)\b/.test(text))
            return { name: "session", args: { action: "poweroff" }, confirm: true }
        if (/^(please\s+)?(reboot|restart)\b/.test(text))
            return { name: "session", args: { action: "reboot" }, confirm: true }
        if (/^(please\s+)?(log out|logout|sign out)\b/.test(text))
            return { name: "session", args: { action: "logout" }, confirm: true }
        if (/^(please\s+)?(suspend|sleep)\b/.test(text))
            return { name: "session", args: { action: "suspend" }, confirm: true }
        if (/^(please\s+)?lock (the )?(screen|computer|session)\b/.test(text))
            return { name: "lock", args: {}, confirm: true }
        if (/\b(start|stop|toggle)\b.*\b(screen record|screen recording)\b/.test(text)
                || /^(please\s+)?record (the )?screen\b/.test(text))
            return { name: "screen_record", args: {}, confirm: true }

        if (/\b(take|capture|start|open)\b.*\b(screenshot|screen shot)\b/.test(text))
            return { name: "screenshot", args: {} }
        if (/\b(open|start|use)\b.*\bcolor picker\b/.test(text)
                || /\bpick (a )?colou?r\b/.test(text))
            return { name: "color_picker", args: {} }
        if (/\b(turn|toggle|enable|disable)\b.*\bkeep awake\b/.test(text))
            return { name: "keep_awake", args: {} }

        if (/\b(action center|control center|quick settings)\b/.test(text))
            return { name: "open_panel", args: { panel: "control-center" } }
        if (/\b(power menu|shutdown menu)\b/.test(text))
            return { name: "open_panel", args: { panel: "power" } }
        if (/\b(music panel|media panel|now playing)\b/.test(text))
            return { name: "open_panel", args: { panel: "music" } }
        if (/\b(app center|app launcher|launcher)\b/.test(text)
                && !/\b(search|find|look for)\b/.test(text))
            return { name: "open_panel", args: { panel: "launcher" } }
        if (/\bsettings\b/.test(text))
            return { name: "open_settings", args: { section: settingsSection(text) } }

        const locationMatch = raw.match(/\bin (?:my )?(home|desktop|documents|downloads|music|pictures|videos|projects)(?:\s+folder)?\b/i)
        const location = locationMatch ? locationMatch[1].toLowerCase() : "home"
        let contentMatch = raw.match(/(?:search|find|look for).*\b(?:containing|with (?:the )?(?:text|content))\s+[\"']?(.+)/i)
        if (contentMatch) {
            let contentQuery = cleanTarget(contentMatch[1])
                .replace(/\bin (?:my )?(home|desktop|documents|downloads|music|pictures|videos|projects)(?:\s+folder)?\b.*$/i, "")
                .replace(/[\"']+$/g, "").trim()
            return { name: "search_files", args: {
                query: contentQuery,
                filter: "all",
                mode: "content",
                location: location
            } }
        }

        const localSearchIntent = /\b(file|files|folder|folders|path|document|documents|config|configuration|containing|content)\b/i.test(raw)
            || locationMatch !== null
        let match = localSearchIntent
            ? raw.match(/(?:search|find|look for)\s+(?:my\s+)?(?:files?\s+)?(?:for\s+)?(.+)/i)
            : null
        if (match) {
            let query = cleanTarget(match[1])
            if (/\b(app|application|program)s?\b/i.test(raw))
                return { name: "search_apps", args: { query: query.replace(/\b(app|application|program)s?\b/ig, "").trim() } }
            if (/\bgames?\b/i.test(raw))
                return { name: "search_games", args: { query: query.replace(/\bgames?\b/ig, "").trim() } }
            let filter = "all"
            if (/\b(image|photo|picture|png|jpe?g|webp)s?\b/i.test(raw))
                filter = "images"
            else if (/\b(audio|music|song|video|movie|media)s?\b/i.test(raw))
                filter = "media"
            else if (/\b(code|source|script|qml|javascript|python|config(uration)?)s?\b/i.test(raw))
                filter = "code"
            else if (/\b(document|pdf|text|spreadsheet|presentation)s?\b/i.test(raw))
                filter = "documents"
            query = query
                .replace(/\b(file|files|document|documents|image|images|photo|photos|picture|pictures|audio|music|song|songs|video|videos|movie|movies|media|code|source|script|scripts)s?\b/ig, " ")
                .replace(/\s+/g, " ").trim()
                .replace(/\bin (?:my )?(home|desktop|documents|downloads|music|pictures|videos|projects)(?:\s+folder)?\b.*$/i, "")
                .trim()
            return { name: "search_files", args: {
                query: query.length >= 2 ? query : cleanTarget(match[1]),
                filter: filter,
                mode: "name",
                location: location
            } }
        }

        // A generic information search is online. Keeping this fallback after
        // the explicit local-file parser prevents "search info about Discord"
        // from ever becoming a literal filename query again.
        match = raw.match(/(?:search|look up|find|google)\s+(?:for\s+)?(.+)/i)
        if (match) {
            const query = cleanTarget(match[1])
            if (query.length > 0)
                return { name: "online_search", args: { query: query } }
        }

        match = raw.match(/(?:play|launch)\s+(?:the\s+game\s+)?(.+)/i)
        if (match && /^play\b/i.test(raw))
            return { name: "open_game", args: { query: cleanTarget(match[1]) } }

        match = raw.match(/(?:open|launch|start|run|bring up)\s+(.+)/i)
        if (match)
            return { name: "open_item", args: { query: cleanTarget(match[1]) } }

        return null
    }

    function fastPlan(prompt) {
        const parts = String(prompt || "").split(/\s+(?:and then|then)\s+|;/i)
            .map(part => part.trim()).filter(part => part.length > 0)
        if (parts.length < 2 || parts.length > 5)
            return []
        const actions = []
        for (let index = 0; index < parts.length; ++index) {
            const action = fastAction(parts[index])
            if (!action || !validateAction(action))
                return []
            actions.push(action)
        }
        return actions
    }

    function confirmationLabel(action) {
        if (action.name === "session") {
            const labels = {
                poweroff: I18n.tr("assistant.confirmPowerOff"),
                reboot: I18n.tr("assistant.confirmRestart"),
                logout: I18n.tr("assistant.confirmLogout"),
                suspend: I18n.tr("assistant.confirmSuspend")
            }
            return labels[action.args.action] || I18n.tr("assistant.confirmSession")
        }
        if (action.name === "lock")
            return I18n.tr("assistant.confirmLock")
        if (action.name === "screen_record")
            return I18n.tr("assistant.confirmRecording")
        if (action.name === "online_search" || action.name === "online_weather")
            return I18n.tr("assistant.confirmInternet")
        return I18n.tr("power.confirmation")
    }

    function appendAssistant(text, kind, payload) {
        const value = String(text || "").trim()
        if (value.length === 0)
            return
        messages = messages.concat([{
            role: "assistant",
            text: value,
            kind: String(kind || "text"),
            payload: payload || ({})
        }])
        revision++
    }

    function appendToolPayload(action, payload) {
        const result = payload || ({})
        const text = String(result.output || "").trim()
        if (action.name === "online_weather") {
            appendAssistant(text.length > 0 ? text : I18n.tr("assistant.onlineNoResult"),
                "weather", result)
            return
        }
        if (action.name === "online_search") {
            appendAssistant(text.length > 0 ? text : I18n.tr("assistant.onlineNoResult"),
                "web", result)
            return
        }
        appendAssistant(text.length > 0 ? text : I18n.tr("assistant.actionSucceeded", {
            action: actionName(action.name)
        }), "tool", result)
    }

    function parseBackendPayload(contents) {
        try {
            const envelope = JSON.parse(String(contents || "{}"))
            if (String(envelope.status || "") !== "ok" || !envelope.payload)
                return null
            return envelope.payload
        } catch (error) {
            return null
        }
    }

    function appSearchResults(query) {
        LauncherService.refreshApplications()
        return LauncherService.resultsFor(query, "apps", "all", "all").slice(0, 8)
    }

    function gameSearchResults(query) {
        const needle = String(query || "").toLowerCase()
        return (SteamGameService.games || []).filter(game =>
            String(game.name || "").toLowerCase().indexOf(needle) >= 0).slice(0, 8)
    }

    function appendSearchResults(kind, query, results) {
        const count = results.length
        const text = count > 0
            ? I18n.plural("assistant.inlineResults", count, { query: query })
            : I18n.tr("assistant.inlineNoResults", { query: query })
        appendAssistant(text, kind, { query: query, results: results })
    }

    function beginInlineFileSearch(action) {
        pendingInlineFileSearch = action
        inlineFileSearchDeadline = Date.now() + 15000
        LauncherService.searchFiles(action.args.query,
            action.args.mode || "name", action.args.location || "home")
        inlineFileSearchPoll.restart()
    }

    function finishInlineFileSearch(timedOut) {
        const action = pendingInlineFileSearch
        if (!action)
            return
        pendingInlineFileSearch = null
        let results = timedOut ? [] : LauncherService.fileResults.slice()
        const filter = String(action.args.filter || "all")
        if (filter !== "all")
            results = results.filter(item => item.category === filter)
        appendSearchResults("files", action.args.query, results.slice(0, 12))
        recordAction(action, timedOut ? "failed" : "succeeded",
            timedOut ? I18n.tr("assistant.actionFailed", { action: actionName(action.name) })
                : I18n.tr("assistant.actionSucceeded", { action: actionName(action.name) }))
    }

    function activateResult(result) {
        if (!result)
            return false
        if (result.kind === "app" && result.entry) {
            result.entry.execute()
            return true
        }
        if (result.kind === "file" && result.path) {
            Quickshell.execDetached({ command: ["/usr/bin/xdg-open", result.path] })
            return true
        }
        if (result.appid !== undefined) {
            Quickshell.execDetached({ command: ["/usr/bin/steam", "-applaunch", String(result.appid)] })
            return true
        }
        if (result.url) {
            Qt.openUrlExternally(result.url)
            return true
        }
        return false
    }

    function requestConfirmation(action) {
        pendingConfirmation = {
            name: action.name,
            args: action.args || {},
            label: confirmationLabel(action),
            level: actionLevel(action)
        }
        recordAction(action, "waiting", pendingConfirmation.label)
        appendAssistant(I18n.tr("assistant.confirmation"))
    }

    function requestPlanConfirmation(actions) {
        pendingConfirmation = {
            name: "plan",
            actions: actions,
            args: {},
            level: "dangerous",
            label: I18n.plural("assistant.confirmPlan", actions.length)
        }
        pendingPlan = actions
        actionHistory = [{
            time: new Date().toISOString(), action: "plan",
            level: "confirmation", state: "waiting",
            detail: pendingConfirmation.label
        }].concat(actionHistory).slice(0, 40)
        let summary = I18n.tr("assistant.planReady", { count: actions.length })
        for (let index = 0; index < actions.length; ++index)
            summary += "\n" + (index + 1) + ". " + actionSummary(actions[index])
        appendAssistant(summary)
        revision++
    }

    function actionSummary(action) {
        const args = action.args || ({})
        let detail = ""
        if (args.query !== undefined)
            detail = String(args.query)
        else if (args.value !== undefined)
            detail = Math.round(Number(args.value)) + "%"
        else if (args.enabled !== undefined)
            detail = args.enabled ? I18n.tr("common.on") : I18n.tr("common.off")
        else if (args.mode !== undefined)
            detail = actionValueName(String(args.mode))
        else if (args.action !== undefined)
            detail = actionValueName(String(args.action))
        else if (args.panel !== undefined)
            detail = actionValueName(String(args.panel))
        else if (args.section !== undefined)
            detail = actionValueName(String(args.section))
        return detail.length > 0
            ? I18n.tr("assistant.actionWithDetail", {
                action: actionName(action.name), detail: detail
            }) : actionName(action.name)
    }

    function actionName(name) {
        const names = {
            open_item: I18n.tr("assistant.actionNames.open_item"),
            open_game: I18n.tr("assistant.actionNames.open_game"),
            search_apps: I18n.tr("assistant.actionNames.search_apps"),
            search_games: I18n.tr("assistant.actionNames.search_games"),
            search_files: I18n.tr("assistant.actionNames.search_files"),
            online_search: I18n.tr("assistant.actionNames.online_search"),
            online_weather: I18n.tr("assistant.actionNames.online_weather"),
            current_wallpaper: I18n.tr("assistant.actionNames.current_wallpaper"),
            show_system_info: I18n.tr("assistant.actionNames.show_system_info"),
            diagnostic: I18n.tr("assistant.actionNames.diagnostic"),
            open_panel: I18n.tr("assistant.actionNames.open_panel"),
            open_settings: I18n.tr("assistant.actionNames.open_settings"),
            set_volume: I18n.tr("assistant.actionNames.set_volume"),
            set_brightness: I18n.tr("assistant.actionNames.set_brightness"),
            set_dnd: I18n.tr("assistant.actionNames.set_dnd"),
            set_wifi: I18n.tr("assistant.actionNames.set_wifi"),
            set_bluetooth: I18n.tr("assistant.actionNames.set_bluetooth"),
            power_profile: I18n.tr("assistant.actionNames.power_profile"),
            screenshot: I18n.tr("assistant.actionNames.screenshot"),
            color_picker: I18n.tr("assistant.actionNames.color_picker"),
            keep_awake: I18n.tr("assistant.actionNames.keep_awake"),
            screen_record: I18n.tr("assistant.actionNames.screen_record"),
            lock: I18n.tr("assistant.actionNames.lock"),
            session: I18n.tr("assistant.actionNames.session")
        }
        return names[name] || I18n.tr("assistant.unavailableAction")
    }

    function actionValueName(value) {
        const values = {
            saver: I18n.tr("assistant.valueNames.saver"),
            balanced: I18n.tr("assistant.valueNames.balanced"),
            performance: I18n.tr("assistant.valueNames.performance"),
            poweroff: I18n.tr("assistant.valueNames.poweroff"),
            reboot: I18n.tr("assistant.valueNames.reboot"),
            logout: I18n.tr("assistant.valueNames.logout"),
            suspend: I18n.tr("assistant.valueNames.suspend"),
            "control-center": I18n.tr("assistant.valueNames.control-center"),
            power: I18n.tr("assistant.valueNames.power"),
            music: I18n.tr("assistant.valueNames.music"),
            launcher: I18n.tr("assistant.valueNames.launcher"),
            home: I18n.tr("assistant.valueNames.home"),
            connections: I18n.tr("assistant.valueNames.connections"),
            audio: I18n.tr("assistant.valueNames.audio"),
            devices: I18n.tr("assistant.valueNames.devices"),
            notifications: I18n.tr("assistant.valueNames.notifications"),
            display: I18n.tr("assistant.valueNames.display"),
            appearance: I18n.tr("assistant.valueNames.appearance"),
            lock: I18n.tr("assistant.valueNames.lock"),
            security: I18n.tr("assistant.valueNames.security"),
            accessibility: I18n.tr("assistant.valueNames.accessibility"),
            updates: I18n.tr("assistant.valueNames.updates"),
            system: I18n.tr("assistant.valueNames.system"),
            developer: I18n.tr("assistant.valueNames.developer")
        }
        return values[value] || value
    }

    function backendActionSupported(name) {
        return ["online_search", "online_weather", "open_panel",
            "open_settings", "set_volume", "set_brightness", "set_dnd",
            "set_wifi", "set_bluetooth", "power_profile", "screenshot",
            "color_picker", "keep_awake", "screen_record", "lock", "session"]
            .indexOf(String(name || "")) >= 0
    }

    function backendActionCommand(action) {
        const args = action && action.args ? action.args : ({})
        let first = ""
        let second = ""
        let third = ""
        if (["search_apps", "search_games"].indexOf(action.name) >= 0)
            first = String(args.query || "")
        else if (["online_search", "online_weather"].indexOf(action.name) >= 0)
            first = String(args.query || "")
        else if (action.name === "search_files") {
            first = String(args.query || "")
            second = String(args.mode || "name")
            third = String(args.location || "home")
        } else if (action.name === "open_panel")
            first = String(args.panel || "launcher")
        else if (action.name === "open_settings")
            first = String(args.section || "home")
        else if (action.name === "set_volume" || action.name === "set_brightness")
            first = Math.round(Number(args.value)).toString()
        else if (["set_dnd", "set_wifi", "set_bluetooth"].indexOf(action.name) >= 0)
            first = args.enabled ? "true" : "false"
        else if (action.name === "power_profile")
            first = String(args.mode || "balanced")
        else if (action.name === "session")
            first = String(args.action || "")
        return ["sh", Paths.shellRoot + "/scripts/lyra-action.sh",
            action.name, action._approved === true ? "1" : "0",
            first, second, third]
    }

    function dispatchBackendAction(action) {
        backendActionQueue = backendActionQueue.concat([action])
        recordAction(action, "queued", I18n.tr("assistant.actionDispatched"))
        if (!backendActionProcess.running && activeBackendAction === null)
            backendActionKick.restart()
    }

    function startNextBackendAction() {
        if (backendActionProcess.running || activeBackendAction !== null
                || backendActionQueue.length === 0)
            return
        const queue = backendActionQueue.slice()
        activeBackendAction = queue.shift()
        backendActionQueue = queue
        backendActionProcess.running = true
    }

    function shouldUsePlanner(prompt) {
        return /\b(open|launch|start|run|find|search|weather|latest|current|online|web|show|change|set|turn|switch|enable|disable|take|capture|record|lock|restart|reboot|shutdown|shut down|power off|log out|logout|suspend|diagnose|check|connect|disconnect)\b/i
            .test(String(prompt || ""))
    }

    function startAnswer() {
        activePrompt = conversationPrompt() + "Lyra:"
        activeSystemPrompt = systemPrompt()
        streamingText = ""
        cancellationRequested = false
        answerProcess.running = true
        revision++
    }

    function handlePlannerResult(contents) {
        let actions = []
        try {
            const result = JSON.parse(String(contents || "{}"))
            const proposed = Array.isArray(result.actions) ? result.actions : []
            for (let index = 0; index < proposed.length && index < 5; ++index) {
                const action = {
                    name: String(proposed[index].name || ""),
                    args: proposed[index].args || ({})
                }
                if (action.name === "confirm_pending"
                        || action.name === "cancel_pending") {
                    recordAction(action, "rejected", I18n.tr("assistant.invalidAction"))
                    appendAssistant(I18n.tr("assistant.invalidPlan"))
                    return
                }
                if (!validateAction(action)) {
                    recordAction(action, "rejected", I18n.tr("assistant.invalidAction"))
                    appendAssistant(I18n.tr("assistant.invalidPlan"))
                    return
                }
                actions.push(action)
            }
        } catch (error) {
            actions = []
        }
        if (actions.length > 1)
            requestPlanConfirmation(actions)
        else if (actions.length === 1)
            authorizeAction(actions[0])
        else
            startAnswer()
    }

    function authorizeAction(action) {
        if (!validateAction(action)) {
            recordAction(action, "rejected", I18n.tr("assistant.invalidAction"))
            appendAssistant(I18n.tr("assistant.invalidAction"))
            return false
        }
        const onlineAction = ["online_search", "online_weather"]
            .indexOf(action.name) >= 0
        if (onlineAction && internetMode === "disabled") {
            recordAction(action, "rejected", I18n.tr("assistant.internetDisabled"))
            appendAssistant(I18n.tr("assistant.internetDisabledAction"))
            return false
        }
        if (onlineAction && internetAllowed)
            action._approved = true
        const level = actionLevel(action)
        if (onlineAction && internetAllowed) {
            executeAction(action)
            return true
        }
        if (level === "confirmation" || level === "privileged"
                || level === "dangerous") {
            requestConfirmation(action)
            return true
        }
        executeAction(action)
        return true
    }

    function launchGame(query) {
        const needle = String(query || "").toLowerCase()
        const games = SteamGameService.games || []
        let best = null
        for (let index = 0; index < games.length; ++index) {
            const name = String(games[index].name || "").toLowerCase()
            if (name === needle) {
                best = games[index]
                break
            }
            if (!best && name.indexOf(needle) >= 0)
                best = games[index]
        }
        if (!best)
            return false
        SteamGameService.launch(best)
        ShellState.closePanels()
        return true
    }

    function openSearch(page, query, view, mode, location) {
        ShellState.launcherQuery = String(query || "")
        ShellState.launcherView = String(view || "")
        ShellState.launcherFileMode = mode === "content" ? "content" : "name"
        ShellState.launcherFileLocation = String(location || "home")
        ShellState.openLauncher(undefined, page)
    }

    function resolveHomeItem(query) {
        if (fileResolver.running)
            return false
        pendingFileQuery = String(query || "").trim()
        if (pendingFileQuery.length === 0)
            return false
        fileResolver.running = true
        return true
    }

    function executeAction(action) {
        if (!validateAction(action)) {
            recordAction(action, "rejected", I18n.tr("assistant.invalidAction"))
            appendAssistant(I18n.tr("assistant.invalidAction"))
            return
        }
        const args = action.args || {}
        if (action.name === "confirm_pending") {
            confirmPending()
            return
        }
        if (action.name === "cancel_pending") {
            cancelPending()
            return
        }
        if (backendActionSupported(action.name)) {
            dispatchBackendAction(action)
            return
        }
        recordAction(action, "dispatched", I18n.tr("assistant.actionDispatched"))
        if (action.name === "open_item") {
            if (LauncherService.launchApplicationByName(args.query))
                return
            if (launchGame(args.query))
                return
            if (resolveHomeItem(args.query))
                appendAssistant(I18n.tr("assistant.openingClosest"))
            else
                appendAssistant(I18n.tr("assistant.couldNotResolve"))
            return
        }
        if (action.name === "open_game") {
            if (!launchGame(args.query)) {
                openSearch("games", args.query)
                appendAssistant(I18n.tr("assistant.openedGamesSearch"))
            }
            return
        }
        if (action.name === "search_apps") {
            const results = appSearchResults(args.query)
            appendSearchResults("apps", args.query, results)
            recordAction(action, "succeeded", I18n.tr("assistant.actionSucceeded", {
                action: actionName(action.name)
            }))
            return
        }
        if (action.name === "search_games") {
            const results = gameSearchResults(args.query)
            appendSearchResults("games", args.query, results)
            recordAction(action, "succeeded", I18n.tr("assistant.actionSucceeded", {
                action: actionName(action.name)
            }))
            return
        }
        if (action.name === "search_files") {
            beginInlineFileSearch(action)
            return
        }
        if (action.name === "current_wallpaper") {
            const path = String(Appearance.wallpaperPath || "")
            if (path.length === 0) {
                appendAssistant(I18n.tr("assistant.noWallpaper"))
                return
            }
            Quickshell.execDetached({
                command: ["sh", Paths.shellRoot + "/scripts/assistant-actions.sh",
                    "reveal-path", path]
            })
            appendAssistant(I18n.tr("assistant.wallpaperPath", { path: path }))
            ShellState.closePanels()
            return
        }
        if (action.name === "show_system_info") {
            appendAssistant(liveSystemContext())
            ShellState.openSettings("system")
            return
        }
        if (action.name === "diagnostic") {
            const area = args.area || "system"
            let report = ""
            if (area === "network")
                report = I18n.tr("assistant.diagNetwork", {
                    network: ConnectivityService.activeNetworkLabel,
                    state: ConnectivityService.wifiEnabled
                        ? I18n.tr("common.enabled") : I18n.tr("common.disabled")
                })
                    + (ConnectivityService.wifiError.length > 0
                        ? " " + I18n.tr("assistant.lastError", {
                            error: ConnectivityService.wifiError
                        }) : "")
            else if (area === "audio")
                report = I18n.tr("assistant.diagAudio", {
                    output: AudioService.outputName,
                    value: Math.round(AudioService.outputVolume * 100)
                })
            else if (area === "bluetooth")
                report = I18n.plural("assistant.diagBluetooth",
                    ConnectivityService.connectedBluetoothDevices, {
                        state: ConnectivityService.bluetoothEnabled
                            ? I18n.tr("common.enabled")
                            : I18n.tr("common.disabled")
                    })
                    + (ConnectivityService.bluetoothError.length > 0
                        ? " " + I18n.tr("assistant.lastError", {
                            error: ConnectivityService.bluetoothError
                        }) : "")
            else if (area === "display")
                report = I18n.plural("display.detected",
                    SystemSettingsService.monitors.length) + ". "
                    + (PowerService.backlightAvailable
                        ? I18n.tr("assistant.brightnessAvailable")
                        : I18n.tr("assistant.noInternalBacklight"))
            else
                report = liveSystemContext()
            appendAssistant(report)
            return
        }
        if (action.name === "open_panel") {
            if (args.panel === "control-center")
                ShellState.openControlCenter("")
            else if (args.panel === "power")
                ShellState.openPowerMenu()
            else if (args.panel === "music")
                ShellState.openMusic()
            else
                ShellState.openLauncher()
            return
        }
        if (action.name === "open_settings") {
            ShellState.openSettings(args.section || "home")
            return
        }
        if (action.name === "set_volume") {
            AudioService.setOutputVolume(Number(args.value) / 100)
            appendAssistant(I18n.tr("assistant.volumeSet", {
                value: Math.round(Number(args.value))
            }))
            return
        }
        if (action.name === "set_brightness") {
            if (!PowerService.backlightAvailable) {
                appendAssistant(I18n.tr("assistant.brightnessUnavailable"))
            } else {
                PowerService.setBrightness(Number(args.value))
                appendAssistant(I18n.tr("assistant.brightnessSet", {
                    value: Math.round(Number(args.value))
                }))
            }
            return
        }
        if (action.name === "set_wifi") {
            if (ConnectivityService.setWifiEnabled(Boolean(args.enabled))) {
                appendAssistant(I18n.tr("assistant.wifiSet", {
                    state: args.enabled ? I18n.tr("common.on") : I18n.tr("common.off")
                }))
            } else {
                appendAssistant(I18n.tr("network.noAdapter"))
            }
            return
        }
        if (action.name === "set_bluetooth") {
            if (ConnectivityService.bluetoothEnabled !== Boolean(args.enabled))
                ConnectivityService.toggleBluetooth()
            appendAssistant(I18n.tr("assistant.bluetoothSet", {
                state: args.enabled ? I18n.tr("common.on") : I18n.tr("common.off")
            }))
            return
        }
        if (action.name === "power_profile") {
            PowerService.setProfile(args.mode)
            appendAssistant(I18n.tr("assistant.powerModeSet", { mode: args.mode }))
            return
        }
        if (action.name === "screenshot") {
            LauncherService.takeScreenshot("region", ShellState.requestedScreenName())
            return
        }
        if (action.name === "color_picker") {
            LauncherService.pickColor()
            return
        }
        if (action.name === "keep_awake") {
            SystemActionService.toggleKeepAwake()
            appendAssistant(I18n.tr("assistant.keepAwakeToggled"))
            return
        }
        if (action.name === "screen_record") {
            SystemActionService.toggleRecording(ShellState.requestedScreenName())
            appendAssistant(I18n.tr("assistant.recordingToggled"))
            return
        }
        if (action.name === "lock") {
            LockService.lock()
            return
        }
        if (action.name === "session") {
            SystemActionService.performSessionAction(args.action)
            return
        }
        appendAssistant(I18n.tr("assistant.unavailableAction"))
    }

    function confirmPending() {
        if (!pendingConfirmation)
            return
        const action = pendingConfirmation
        pendingConfirmation = null
        if (action.actions && action.actions.length > 0) {
            const actions = action.actions.slice()
            pendingPlan = []
            for (let index = 0; index < actions.length; ++index) {
                const onlineAction = actions[index].name === "online_search"
                    || actions[index].name === "online_weather"
                if (onlineAction && internetMode === "disabled") {
                    recordAction(actions[index], "rejected",
                        I18n.tr("assistant.internetDisabled"))
                    appendAssistant(I18n.tr("assistant.internetDisabledAction"))
                    continue
                }
                if (onlineAction && internetMode === "session")
                    sessionInternetAllowed = true
                actions[index]._approved = true
                executeAction(actions[index])
            }
            appendAssistant(I18n.plural("assistant.planDispatched", actions.length))
            revision++
            return
        }
        recordAction(action, "approved", action.label || "")
        if ((action.name === "online_search" || action.name === "online_weather")
                && internetMode === "session")
            sessionInternetAllowed = true
        action._approved = true
        executeAction(action)
        revision++
    }

    function cancelPending() {
        if (!pendingConfirmation)
            return
        pendingConfirmation = null
        pendingPlan = []
        recordAction({ name: "cancel_pending", args: {} }, "cancelled", "")
        appendAssistant(I18n.tr("assistant.cancelled"))
    }

    function liveSystemContext() {
        const lines = [systemContext.trim()]
        lines.push("Current shell state:")
        lines.push("- Bar position: " + Appearance.barPosition)
        lines.push("- Network: " + (ConnectivityService.ethernetConnected
            ? "Ethernet connected" : (ConnectivityService.wifiConnected
                ? "Wi-Fi connected" : "Disconnected")))
        lines.push("- Bluetooth: " + (ConnectivityService.bluetoothEnabled ? "on" : "off"))
        lines.push("- Output volume: " + Math.round(AudioService.outputVolume * 100)
            + "%" + (AudioService.outputMuted ? " (muted)" : ""))
        if (PowerService.available)
            lines.push("- Battery: " + PowerService.percentage + "%"
                + (PowerService.charging ? " charging" : ""))
        if (PowerService.backlightAvailable)
            lines.push("- Brightness: " + PowerService.brightnessPercent + "%")
        lines.push("- Power profile: " + PowerService.profileMode)
        return lines.filter(line => line.length > 0).join("\n")
    }

    function conversationPrompt() {
        const history = messages.slice(Math.max(0,
            messages.length - historyLimit))
        let context = ""
        for (let index = 0; index < history.length; ++index) {
            const role = history[index].role === "user" ? "User" : "Lyra"
            context += role + ": " + String(history[index].text || "").slice(0, 900) + "\n"
        }
        return context
    }

    function systemPrompt() {
        return [
            "You are Lyra, Voidline's local assistant.",
            "Answer concisely in one to four short paragraphs.",
            "Use the supplied system state when the user asks about this computer.",
            "Never invent having run a command or changed a setting.",
            "Never output shell commands as actions. Voidline handles actions through a separate allow-listed bridge.",
            "Internet permission is " + internetMode + ". Online requests are handled by a separate validated tool; never claim to browse directly.",
            "If information is missing, say so clearly.",
            "",
            liveSystemContext()
        ].join("\n")
    }

    function ask(prompt) {
        const value = String(prompt || "").trim()
        lastError = ""
        if (value.length === 0)
            return false

        const plan = fastPlan(value)
        // A conjunction with multiple action verbs must not be collapsed into
        // the last deterministic match (for example "open music and show
        // display settings"). Let the structured planner preserve every step.
        const complexIntent = /\b(and|also|plus)\b/i.test(value)
            && shouldUsePlanner(value)
        const action = plan.length === 0 && !complexIntent
            ? fastAction(value) : null
        if (plan.length === 0 && !action && !canAsk) {
            lastError = statusText
            revision++
            return false
        }

        messages = messages.concat([{ role: "user", text: value }])
        if (plan.length > 0) {
            requestPlanConfirmation(plan)
            revision++
            return true
        }
        if (action) {
            authorizeAction(action)
            revision++
            return true
        }

        if (shouldUsePlanner(value)) {
            plannerPrompt = value
            plannerProcess.running = true
            revision++
        } else {
            startAnswer()
        }
        return true
    }

    function cancel() {
        backendActionQueue = []
        pendingInlineFileSearch = null
        inlineFileSearchPoll.stop()
        if (backendActionProcess.running) {
            backendCancellationRequested = true
            backendActionProcess.signal(15)
        }
        if (plannerProcess.running) {
            cancellationRequested = true
            plannerProcess.signal(15)
        }
        if (answerProcess.running) {
            cancellationRequested = true
            answerProcess.signal(15)
        }
    }

    function clearConversation() {
        cancel()
        messages = []
        streamingText = ""
        activePrompt = ""
        activeSystemPrompt = ""
        lastError = ""
        pendingConfirmation = null
        pendingPlan = []
        plannerPrompt = ""
        inputTokens = 0
        outputTokens = 0
        conversationTokens = 0
        tokensPerSecond = 0
        timeToFirstTokenMs = 0
        generationDurationMs = 0
        revision++
    }

    function copyText(value) {
        const text = String(value || "")
        if (text.length === 0 || copyProcess.running)
            return false
        pendingCopyText = text
        copyProcess.running = true
        return true
    }

    property Timer backendActionKick: Timer {
        interval: 0
        onTriggered: root.startNextBackendAction()
    }

    property Timer inlineFileSearchPoll: Timer {
        interval: 120
        repeat: false
        onTriggered: {
            if (root.pendingInlineFileSearch === null)
                return
            if (!LauncherService.filesSearching) {
                root.finishInlineFileSearch(false)
                return
            }
            if (Date.now() >= root.inlineFileSearchDeadline) {
                root.finishInlineFileSearch(true)
                return
            }
            restart()
        }
    }

    property Process backendActionProcess: Process {
        command: root.activeBackendAction !== null
            ? root.backendActionCommand(root.activeBackendAction) : ["/usr/bin/true"]
        stdout: StdioCollector { id: backendActionOutput }
        stderr: StdioCollector { id: backendActionError }
        onExited: (exitCode, exitStatus) => {
            const action = root.activeBackendAction
            if (action !== null) {
                if (root.backendCancellationRequested) {
                    root.recordAction(action, "cancelled", I18n.tr("assistant.cancelled"))
                } else if (exitCode === 0) {
                    root.recordAction(action, "succeeded",
                        I18n.tr("assistant.actionSucceeded", {
                            action: root.actionName(action.name)
                        }))
                    if (action.name === "online_search"
                            || action.name === "online_weather") {
                        const payload = root.parseBackendPayload(backendActionOutput.text)
                        if (payload)
                            root.appendToolPayload(action, payload)
                        else
                            root.appendAssistant(I18n.tr("assistant.onlineNoResult"))
                    } else {
                        root.appendAssistant(I18n.tr("assistant.actionSucceeded", {
                            action: root.actionName(action.name)
                        }))
                    }
                } else {
                    root.recordAction(action, "failed",
                        I18n.tr("assistant.actionFailed", {
                            action: root.actionName(action.name)
                        }))
                    root.appendAssistant(I18n.tr("assistant.actionFailed", {
                        action: root.actionName(action.name)
                    }))
                }
            }
            root.backendCancellationRequested = false
            root.activeBackendAction = null
            root.backendActionKick.restart()
        }
    }

    property Process capabilityProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/ai-provider.sh", "capabilities"]
        stdout: StdioCollector {
            onStreamFinished: root.parseCapabilities(text)
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.provider = "none"
                root.providerReady = false
                root.models = []
                root.capabilitiesChecked = true
                root.revision++
            }
        }
    }

    property Process systemContextProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/ai-provider.sh", "system-context"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.systemContext = text.trim()
                root.revision++
            }
        }
    }

    property Process warmProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/ai-provider.sh",
            "warm", root.selectedModel]
    }

    property Process metricsProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/ai-provider.sh",
            "metrics", root.selectedModel]
        stdout: StdioCollector {
            onStreamFinished: root.parseRuntimeMetrics(text)
        }
    }

    property Process unloadProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/ai-provider.sh",
            "unload", root.selectedModel]
        onExited: {
            root.modelLoaded = false
            root.loadedSizeBytes = 0
            root.loadedVramBytes = 0
            root.revision++
        }
    }

    property Process stopServiceProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/ai-provider.sh", "stop"]
        onExited: {
            root.providerReady = false
            root.modelLoaded = false
            root.loadedSizeBytes = 0
            root.loadedVramBytes = 0
            root.serviceRamBytes = 0
            root.revision++
        }
    }

    property Process restartServiceProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/ai-provider.sh", "restart"]
        onExited: (exitCode, exitStatus) => {
            root.providerReady = false
            root.modelLoaded = false
            root.loadedSizeBytes = 0
            root.loadedVramBytes = 0
            root.serviceRamBytes = 0
            if (exitCode === 0)
                root.refreshCapabilities()
            else
                root.lastError = I18n.tr("assistant.serviceRestartFailed")
            root.revision++
        }
    }

    property Process plannerProcess: Process {
        command: [
            "sh", Paths.shellRoot + "/scripts/ai-provider.sh", "plan",
            root.selectedModel, root.liveSystemContext(), root.plannerPrompt
        ]
        stdout: StdioCollector { id: plannerOutput }
        stderr: StdioCollector { id: plannerError }
        onExited: (exitCode, exitStatus) => {
            const cancelled = root.cancellationRequested
            root.plannerPrompt = ""
            if (exitCode === 0 && !cancelled)
                root.handlePlannerResult(plannerOutput.text)
            else if (!cancelled)
                root.startAnswer()
            root.cancellationRequested = false
            root.revision++
        }
    }

    property Process answerProcess: Process {
        command: [
            "sh", Paths.shellRoot + "/scripts/ai-provider.sh", "stream",
            root.selectedModel, root.activeSystemPrompt, root.activePrompt
        ]
        stdout: StdioCollector {
            id: answerOutput
            onTextChanged: root.streamingText = text
        }
        stderr: StdioCollector { id: answerError }

        onExited: (exitCode, exitStatus) => {
            const response = answerOutput.text.trim()
            root.parseGenerationMetadata(answerError.text)
            const errorText = root.cleanProviderError(answerError.text)
            if (exitCode === 0 && response.length > 0) {
                root.messages = root.messages.concat([
                    { role: "assistant", text: response }
                ])
                root.lastError = ""
            } else if (!root.cancellationRequested) {
                root.lastError = errorText.length > 0
                    ? errorText : I18n.tr("assistant.noAnswer")
            }
            root.cancellationRequested = false
            root.streamingText = ""
            root.activePrompt = ""
            root.activeSystemPrompt = ""
            root.revision++
        }
    }

    property Process fileResolver: Process {
        command: ["sh", Paths.shellRoot + "/scripts/assistant-actions.sh",
            "resolve-home-item", root.pendingFileQuery]
        stdout: StdioCollector { id: resolvedPathOutput }
        onExited: (exitCode, exitStatus) => {
            const path = resolvedPathOutput.text.trim()
            const homePrefix = Quickshell.env("HOME") + "/"
            if (exitCode === 0 && path.startsWith(homePrefix)) {
                Quickshell.execDetached({ command: ["xdg-open", path] })
                ShellState.closePanels()
            } else {
                root.appendAssistant(I18n.tr("assistant.noLocalItem"))
            }
            root.pendingFileQuery = ""
        }
    }

    property Process copyProcess: Process {
        command: ["/usr/bin/wl-copy", "--type", "text/plain;charset=utf-8"]
        stdinEnabled: true
        onStarted: {
            write(root.pendingCopyText)
            closeWriteChannel()
        }
        onExited: root.pendingCopyText = ""
    }

    property var agentStateFile: FileView {
        path: Paths.writableRootsReady
            ? Paths.configRoot + "/assistant-state.json" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.loadAgentState(text())
    }

    property Timer agentStateFallback: Timer {
        interval: 250
        running: !root.agentStateLoaded
        onTriggered: {
            root.agentStateLoaded = true
            root.persistAgentState()
        }
    }

    property var providerConfigFile: FileView {
        path: Paths.writableRootsReady ? Paths.providerConfig : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.loadProviderConfiguration(text())
    }

    property var featureWatcher: Connections {
        target: FeatureRegistry
        function onAiInstalledChanged() {
            if (!FeatureRegistry.aiInstalled)
                root.stopService()
            root.capabilitiesChecked = false
            root.providerReady = false
            root.models = []
            root.revision++
        }
    }

    Component.onCompleted: {
        // The persisted enabled state is loaded before starting any provider.
    }
}
