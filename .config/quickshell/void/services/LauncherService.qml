pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import "../core"

QtObject {
    id: root

    property var applications: []
    property var recentApplicationIds: []
    property var fileResults: []
    property var clipboardEntries: []
    property var shellHistory: []
    property var calculatorHistory: []
    property string pendingShellCommand: ""
    property string shellOutput: ""
    property string shellError: ""
    property int shellExitCode: 0
    property string pendingFileQuery: ""
    property string activeFileQuery: ""
    property string pendingFileMode: "name"
    property string activeFileMode: "name"
    property string pendingFileLocation: "home"
    property string activeFileLocation: "home"
    property bool filesSearching: false
    property bool capabilitiesChecked: false
    property bool clipboardToolsAvailable: false
    property bool copyToolAvailable: false
    property bool colorPickerAvailable: false
    property bool screenshotAvailable: false
    property bool windowScreenshotAvailable: false
    property bool clipboardRefreshPending: false
    property string actionMessage: ""
    property int revision: 0
    readonly property bool shellRunning: shellProcess.running
    readonly property string shellDisplay: {
        const blocks = []
        if (shellOutput.trim().length > 0)
            blocks.push(shellOutput.trim())
        if (shellError.trim().length > 0)
            blocks.push(shellError.trim())
        if (blocks.length === 0 && !shellRunning && pendingShellCommand.length > 0)
            return I18n.tr("launcher.commandNoOutput")
        return blocks.join("\n")
    }

    // The root palette contains modules and immediate actions only. Control
    // Center detail pages deliberately stay in the Control Center.
    readonly property var rootCommands: {
        const commands = [
        { id: "apps", title: I18n.tr("launcher.modules.apps.title"), description: I18n.tr("launcher.modules.apps.description"), icon: "apps", keywords: "applications launcher programs", kind: "module" },
        { id: "calculator", title: I18n.tr("launcher.modules.calculator.title"), description: I18n.tr("launcher.modules.calculator.description"), icon: "calculate", keywords: "math equation arithmetic", kind: "module" },
        { id: "files", title: I18n.tr("launcher.modules.files.title"), description: I18n.tr("launcher.modules.files.description"), icon: "manage_search", keywords: "file search find document", kind: "module" },
        { id: "games", title: I18n.tr("launcher.modules.games.title"), description: I18n.tr("launcher.modules.games.description"), icon: "sports_esports", keywords: "steam game library play", kind: "module" },
        { id: "wallpaper", title: I18n.tr("launcher.modules.wallpaper.title"), description: I18n.tr("launcher.modules.wallpaper.description"), icon: "wallpaper", keywords: "background personalize image", kind: "module" },
        { id: "clipboard", title: I18n.tr("launcher.modules.clipboard.title"), description: I18n.tr("launcher.modules.clipboard.description"), icon: "content_paste_search", keywords: "copy paste history emoji symbol character", kind: "module" },
        { id: "overview", title: I18n.tr("launcher.modules.overview.title"), description: I18n.tr("launcher.modules.overview.description"), icon: "view_cozy", keywords: "window workspace wintab switch overview", kind: "module" },
        { id: "settings", title: I18n.tr("launcher.modules.settings.title"), description: I18n.tr("launcher.modules.settings.description"), icon: "settings", keywords: "preferences configuration system network display theme", kind: "module" },
        { id: "shell", title: I18n.tr("launcher.modules.shell.title"), description: I18n.tr("launcher.modules.shell.description"), icon: "terminal", keywords: "terminal command execute", kind: "module" }
        ]
        if (FeatureRegistry.aiInstalled && AssistantService.assistantEnabled)
            commands.splice(1, 0, {
                id: "local-ai",
                title: I18n.tr("assistant.name"),
                description: I18n.tr("assistant.description"),
                icon: "neurology",
                keywords: "lyra assistant model ask local ai llm",
                kind: "module"
            })
        return commands
    }

    readonly property var emojiCatalog: [
        { value: "😀", title: "Grinning Face", keywords: "happy smile face" },
        { value: "😂", title: "Face With Tears of Joy", keywords: "laugh crying funny" },
        { value: "🥹", title: "Holding Back Tears", keywords: "proud touched sad" },
        { value: "😍", title: "Heart Eyes", keywords: "love face crush" },
        { value: "🥰", title: "Smiling With Hearts", keywords: "love affection face" },
        { value: "😎", title: "Cool Face", keywords: "sunglasses confident" },
        { value: "🤔", title: "Thinking Face", keywords: "question consider" },
        { value: "🫡", title: "Saluting Face", keywords: "respect yes" },
        { value: "😭", title: "Loudly Crying Face", keywords: "sad tears" },
        { value: "😡", title: "Angry Face", keywords: "mad upset" },
        { value: "👍", title: "Thumbs Up", keywords: "yes approve good" },
        { value: "👎", title: "Thumbs Down", keywords: "no disapprove bad" },
        { value: "👏", title: "Clapping Hands", keywords: "applause congratulations" },
        { value: "🙏", title: "Folded Hands", keywords: "thanks please prayer" },
        { value: "🤝", title: "Handshake", keywords: "agreement deal hello" },
        { value: "👀", title: "Eyes", keywords: "look watching" },
        { value: "💪", title: "Flexed Biceps", keywords: "strong power" },
        { value: "❤️", title: "Red Heart", keywords: "love favorite" },
        { value: "💜", title: "Purple Heart", keywords: "love purple" },
        { value: "💔", title: "Broken Heart", keywords: "sad breakup" },
        { value: "🔥", title: "Fire", keywords: "hot great trending" },
        { value: "✨", title: "Sparkles", keywords: "magic shine new" },
        { value: "🎉", title: "Party Popper", keywords: "celebrate congratulations" },
        { value: "✅", title: "Check Mark", keywords: "done yes success" },
        { value: "❌", title: "Cross Mark", keywords: "no error fail" },
        { value: "⚠️", title: "Warning", keywords: "alert caution" },
        { value: "ℹ️", title: "Information", keywords: "info help" },
        { value: "🚀", title: "Rocket", keywords: "launch fast space" },
        { value: "🎮", title: "Game Controller", keywords: "games play" },
        { value: "💻", title: "Laptop", keywords: "computer code" },
        { value: "🐧", title: "Penguin", keywords: "linux tux animal" },
        { value: "🌙", title: "Crescent Moon", keywords: "night dark" },
        { value: "☀️", title: "Sun", keywords: "day light weather" },
        { value: "→", title: "Right Arrow", keywords: "arrow next right" },
        { value: "←", title: "Left Arrow", keywords: "arrow back left" },
        { value: "↑", title: "Up Arrow", keywords: "arrow up" },
        { value: "↓", title: "Down Arrow", keywords: "arrow down" },
        { value: "↔", title: "Left Right Arrow", keywords: "arrow horizontal swap" },
        { value: "✓", title: "Check", keywords: "done yes tick" },
        { value: "✕", title: "Close", keywords: "cross x close" },
        { value: "•", title: "Bullet", keywords: "dot list" },
        { value: "—", title: "Em Dash", keywords: "dash punctuation" },
        { value: "…", title: "Ellipsis", keywords: "dots punctuation" },
        { value: "©", title: "Copyright", keywords: "legal symbol" },
        { value: "®", title: "Registered", keywords: "legal trademark" },
        { value: "™", title: "Trademark", keywords: "legal mark" },
        { value: "€", title: "Euro", keywords: "currency money" },
        { value: "£", title: "Pound", keywords: "currency money" },
        { value: "¥", title: "Yen", keywords: "currency money" },
        { value: "°", title: "Degree", keywords: "temperature angle" },
        { value: "±", title: "Plus Minus", keywords: "math symbol" },
        { value: "×", title: "Multiplication", keywords: "math times" },
        { value: "÷", title: "Division", keywords: "math divide" },
        { value: "≈", title: "Approximately Equal", keywords: "math equal" },
        { value: "≠", title: "Not Equal", keywords: "math comparison" },
        { value: "≤", title: "Less Than or Equal", keywords: "math comparison" },
        { value: "≥", title: "Greater Than or Equal", keywords: "math comparison" },
        { value: "∞", title: "Infinity", keywords: "math endless" },
        { value: "π", title: "Pi", keywords: "math constant" },
        { value: "√", title: "Square Root", keywords: "math radical" }
    ]

    function refreshApplications() {
        const values = DesktopEntries.applications.values || []
        applications = values.slice().sort((left, right) => {
            return normalized(left.name).localeCompare(normalized(right.name))
        })
        revision++
    }

    function launchApplicationByName(query) {
        const needle = normalized(query)
        if (needle.length === 0)
            return false
        if (applications.length === 0)
            refreshApplications()

        let bestEntry = null
        let bestScore = -1
        for (let index = 0; index < applications.length; ++index) {
            const entry = applications[index]
            const name = normalized(entry.name)
            const genericName = normalized(entry.genericName)
            let score = fuzzyScore(entry.name || "",
                (entry.name || "") + " " + (entry.genericName || "")
                    + " " + (entry.comment || ""), needle)
            if (name === needle)
                score += 5000
            else if (name.startsWith(needle))
                score += 2500
            else if (name.indexOf(needle) >= 0 || genericName.indexOf(needle) >= 0)
                score += 1200
            if (score > bestScore) {
                bestScore = score
                bestEntry = entry
            }
        }
        if (!bestEntry || bestScore < 0)
            return false
        rememberApplication(bestEntry)
        bestEntry.execute()
        ShellState.closePanels()
        return true
    }

    function normalized(value) {
        return (value || "").toString().toLowerCase().trim()
    }

    function refreshToolCapabilities() {
        if (!capabilityProcess.running)
            capabilityProcess.running = true
    }

    function parseCapabilities(contents) {
        const rows = contents.trim().split("\n")
        for (let index = 0; index < rows.length; ++index) {
            const fields = rows[index].split("|")
            const enabled = fields[1] === "1"
            if (fields[0] === "clipboard")
                clipboardToolsAvailable = enabled
            else if (fields[0] === "copy")
                copyToolAvailable = enabled
            else if (fields[0] === "color-picker")
                colorPickerAvailable = enabled
            else if (fields[0] === "screenshot")
                screenshotAvailable = enabled
            else if (fields[0] === "window-screenshot")
                windowScreenshotAvailable = enabled
        }
        capabilitiesChecked = true
        revision++
        if (clipboardRefreshPending) {
            clipboardRefreshPending = false
            refreshClipboard()
        }
    }

    function searchFiles(query, mode, location) {
        pendingFileQuery = (query || "").trim()
        pendingFileMode = mode === "content" ? "content"
            : (mode === "recent" ? "recent" : "name")
        const safeLocations = ["home", "desktop", "documents", "downloads",
            "music", "pictures", "videos", "projects"]
        pendingFileLocation = safeLocations.indexOf(location) >= 0
            ? location : "home"
        if (pendingFileQuery.length < 2 && pendingFileMode !== "recent") {
            fileSearchDelay.stop()
            if (fileSearchProcess.running)
                fileSearchProcess.signal(15)
            filesSearching = false
            fileResults = []
            revision++
            return
        }
        filesSearching = true
        fileSearchDelay.restart()
        revision++
    }

    function startFileSearch() {
        if (pendingFileQuery.length < 2 && pendingFileMode !== "recent")
            return
        if (fileSearchProcess.running) {
            fileSearchProcess.signal(15)
            return
        }
        activeFileQuery = pendingFileQuery
        activeFileMode = pendingFileMode
        activeFileLocation = pendingFileLocation
        fileSearchProcess.running = true
    }

    function parseFileResults(contents) {
        const paths = contents.trim().length > 0 ? contents.trim().split("\n") : []
        const next = []
        for (let index = 0; index < paths.length; ++index) {
            const path = paths[index]
            if (path.length === 0)
                continue
            const slash = path.lastIndexOf("/")
            const title = slash >= 0 ? path.slice(slash + 1) : path
            const dot = title.lastIndexOf(".")
            const extension = dot >= 0 ? title.slice(dot + 1).toLowerCase() : ""
            next.push({
                kind: "file",
                key: "file:" + path,
                title: title,
                description: path.replace(/^\/home\/[^/]+/, "~"),
                icon: fileIcon(extension),
                category: fileCategory(extension),
                path: path,
                score: 1
            })
        }
        fileResults = next
        revision++
    }

    function fileIcon(extension) {
        if (["png", "jpg", "jpeg", "gif", "webp", "svg", "avif"].indexOf(extension) >= 0)
            return "image"
        if (["mp4", "mkv", "webm", "mov", "avi"].indexOf(extension) >= 0)
            return "movie"
        if (["mp3", "flac", "wav", "ogg", "m4a"].indexOf(extension) >= 0)
            return "audio_file"
        if (["pdf", "epub"].indexOf(extension) >= 0)
            return "picture_as_pdf"
        if (["zip", "tar", "gz", "xz", "7z", "rar"].indexOf(extension) >= 0)
            return "folder_zip"
        if (["qml", "js", "ts", "py", "rs", "c", "cpp", "h", "lua", "sh"].indexOf(extension) >= 0)
            return "code"
        if (["odt", "doc", "docx", "md", "txt", "rtf"].indexOf(extension) >= 0)
            return "description"
        return "draft"
    }

    function fileCategory(extension) {
        if (["png", "jpg", "jpeg", "gif", "webp", "svg", "avif"].indexOf(extension) >= 0)
            return "images"
        if (["mp4", "mkv", "webm", "mov", "avi",
                "mp3", "flac", "wav", "ogg", "m4a"].indexOf(extension) >= 0)
            return "media"
        if (["qml", "js", "ts", "py", "rs", "c", "cpp", "h", "lua",
                "sh", "json", "toml", "yaml", "yml"].indexOf(extension) >= 0)
            return "code"
        if (["pdf", "epub", "odt", "doc", "docx", "md", "txt", "rtf",
                "ods", "xls", "xlsx", "odp", "ppt", "pptx"].indexOf(extension) >= 0)
            return "documents"
        return "other"
    }

    function refreshClipboard() {
        actionMessage = ""
        if (!capabilitiesChecked) {
            clipboardRefreshPending = true
            refreshToolCapabilities()
            return
        }
        if (!clipboardToolsAvailable) {
            clipboardEntries = []
            revision++
            return
        }
        if (!clipboardListProcess.running)
            clipboardListProcess.running = true
    }

    function parseClipboard(contents) {
        const rows = contents.trim().length > 0 ? contents.trim().split("\n") : []
        const next = []
        for (let index = 0; index < rows.length; ++index) {
            const row = rows[index]
            const tab = row.indexOf("\t")
            const identifier = tab >= 0 ? row.slice(0, tab) : ""
            let preview = tab >= 0 ? row.slice(tab + 1) : row
            preview = preview.replace(/\s+/g, " ").trim()
            if (preview.length === 0)
                preview = "Clipboard item"
            next.push({
                kind: "clipboard",
                key: "clipboard:" + identifier + ":" + index,
                title: preview,
                description: identifier.length > 0 ? "Clipboard · " + identifier : "Clipboard",
                icon: "content_paste",
                encodedEntry: row,
                score: 1
            })
        }
        clipboardEntries = next
        revision++
    }

    function formatNumber(value) {
        if (!Number.isFinite(value))
            return ""
        if (Math.abs(value) < 1e-12)
            value = 0
        return Number(value.toPrecision(12)).toString()
    }

    function unitConversion(input) {
        const match = String(input || "").trim().match(
            /^(-?[0-9]+(?:\.[0-9]+)?)\s*([A-Za-z°]+)\s+(?:to|in)\s+([A-Za-z°]+)$/i)
        if (!match)
            return null
        const value = Number(match[1])
        const aliases = {
            metre: "m", metres: "m", meter: "m", meters: "m",
            kilometre: "km", kilometres: "km", kilometer: "km", kilometers: "km",
            centimetre: "cm", centimetres: "cm", centimeter: "cm", centimeters: "cm",
            millimetre: "mm", millimetres: "mm", millimeter: "mm", millimeters: "mm",
            inch: "in", inches: "in", foot: "ft", feet: "ft", yard: "yd", yards: "yd",
            mile: "mi", miles: "mi", gram: "g", grams: "g", kilogram: "kg",
            kilograms: "kg", pound: "lb", pounds: "lb", ounce: "oz", ounces: "oz",
            celsius: "c", fahrenheit: "f", kelvin: "k",
            byte: "b", bytes: "b", kilobyte: "kb", megabyte: "mb", gigabyte: "gb"
        }
        const fromText = match[2].toLowerCase().replace("°", "")
        const toText = match[3].toLowerCase().replace("°", "")
        const source = aliases[fromText] || fromText
        const target = aliases[toText] || toText
        if (["c", "f", "k"].indexOf(source) >= 0
                && ["c", "f", "k"].indexOf(target) >= 0) {
            const celsius = source === "c" ? value
                : (source === "f" ? (value - 32) * 5 / 9 : value - 273.15)
            const converted = target === "c" ? celsius
                : (target === "f" ? celsius * 9 / 5 + 32 : celsius + 273.15)
            return { ok: true, value: formatNumber(converted), unit: target.toUpperCase() }
        }
        const groups = [
            { mm: 0.001, cm: 0.01, m: 1, km: 1000,
                in: 0.0254, ft: 0.3048, yd: 0.9144, mi: 1609.344 },
            { g: 0.001, kg: 1, oz: 0.028349523125, lb: 0.45359237 },
            { b: 1, kb: 1000, mb: 1000000, gb: 1000000000 }
        ]
        for (let index = 0; index < groups.length; ++index) {
            if (groups[index][source] !== undefined && groups[index][target] !== undefined) {
                return {
                    ok: true,
                    value: formatNumber(value * groups[index][source] / groups[index][target]),
                    unit: target
                }
            }
        }
        return { ok: false, value: "", error: I18n.tr("calculator.incompatibleUnits") }
    }

    function rememberCalculation(expression, value) {
        const next = [{ expression: expression, value: value }]
        for (let index = 0; index < calculatorHistory.length && next.length < 8; ++index) {
            if (calculatorHistory[index].expression !== expression)
                next.push(calculatorHistory[index])
        }
        calculatorHistory = next
        revision++
    }

    // A deliberately small arithmetic parser keeps Calculator immediate and
    // avoids evaluating arbitrary JavaScript from the command field.
    function calculateExpression(input) {
        const converted = unitConversion(input)
        if (converted)
            return converted
        let source = String(input || "")
            .replace(/×/g, "*").replace(/÷/g, "/").replace(/−/g, "-")
            .replace(/π/g, "pi")
        let cursor = 0

        function skipSpace() {
            while (cursor < source.length && /\s/.test(source[cursor]))
                ++cursor
        }
        function consume(character) {
            skipSpace()
            if (source[cursor] !== character)
                return false
            ++cursor
            return true
        }
        function parseNumber() {
            skipSpace()
            const start = cursor
            let decimalSeen = false
            while (cursor < source.length) {
                const character = source[cursor]
                if (character >= "0" && character <= "9") {
                    ++cursor
                } else if (character === "." && !decimalSeen) {
                    decimalSeen = true
                    ++cursor
                } else {
                    break
                }
            }
            if (cursor === start)
                throw new Error("Expected a number")
            const value = Number(source.slice(start, cursor))
            if (!Number.isFinite(value))
                throw new Error("Number is too large")
            return value
        }
        function parseIdentifier() {
            skipSpace()
            const start = cursor
            while (cursor < source.length && /[A-Za-z]/.test(source[cursor]))
                ++cursor
            return source.slice(start, cursor).toLowerCase()
        }
        function parsePrimary() {
            skipSpace()
            if (consume("(")) {
                const value = parseExpressionValue()
                if (!consume(")"))
                    throw new Error("Missing closing parenthesis")
                return value
            }
            if (cursor < source.length && /[A-Za-z]/.test(source[cursor])) {
                const name = parseIdentifier()
                if (name === "pi")
                    return Math.PI
                if (name === "e")
                    return Math.E
                if (!consume("("))
                    throw new Error("Unknown value " + name)
                const argument = parseExpressionValue()
                if (!consume(")"))
                    throw new Error("Missing closing parenthesis")
                if (name === "sqrt") return Math.sqrt(argument)
                if (name === "cbrt") return Math.cbrt(argument)
                if (name === "sin") return Math.sin(argument)
                if (name === "cos") return Math.cos(argument)
                if (name === "tan") return Math.tan(argument)
                if (name === "abs") return Math.abs(argument)
                if (name === "round") return Math.round(argument)
                if (name === "floor") return Math.floor(argument)
                if (name === "ceil") return Math.ceil(argument)
                if (name === "ln") return Math.log(argument)
                if (name === "log") return Math.log(argument) / Math.LN10
                throw new Error("Unknown function " + name)
            }
            return parseNumber()
        }
        function parsePostfix() {
            let value = parsePrimary()
            while (consume("%"))
                value /= 100
            return value
        }
        function parseUnary() {
            if (consume("+")) return parseUnary()
            if (consume("-")) return -parseUnary()
            return parsePostfix()
        }
        function parsePower() {
            let value = parseUnary()
            if (consume("^"))
                value = Math.pow(value, parsePower())
            return value
        }
        function parseProduct() {
            let value = parsePower()
            while (true) {
                if (consume("*")) value *= parsePower()
                else if (consume("/")) value /= parsePower()
                else break
            }
            return value
        }
        function parseExpressionValue() {
            let value = parseProduct()
            while (true) {
                if (consume("+")) value += parseProduct()
                else if (consume("-")) value -= parseProduct()
                else break
            }
            return value
        }

        try {
            const value = parseExpressionValue()
            skipSpace()
            if (cursor !== source.length)
                throw new Error("Unexpected character " + source[cursor])
            if (!Number.isFinite(value))
                throw new Error("Result is not finite")
            return { ok: true, value: formatNumber(value), error: "" }
        } catch (error) {
            return { ok: false, value: "", error: error.message || "Incomplete expression" }
        }
    }

    function fuzzyScore(title, searchable, needle) {
        const name = normalized(title)
        const haystack = normalized(searchable)
        if (needle.length === 0)
            return 1
        if (name === needle)
            return 1200
        if (name.startsWith(needle))
            return 1000 - Math.min(160, name.length - needle.length)
        if (name.split(/\s+/).some(word => word.startsWith(needle)))
            return 820
        if (name.includes(needle))
            return 700
        if (haystack.includes(needle))
            return 520

        let cursor = 0
        for (let index = 0; index < haystack.length && cursor < needle.length; ++index) {
            if (haystack[index] === needle[cursor])
                cursor++
        }
        return cursor === needle.length ? 260 : -1
    }

    function applicationId(entry) {
        return entry.id || entry.name || entry.execString || "application"
    }

    function applicationResult(entry, score) {
        const genericName = entry.genericName || ""
        const comment = entry.comment || ""
        return {
            kind: "app",
            key: "app:" + applicationId(entry),
            title: entry.name || "Application",
            description: genericName.length > 0 ? genericName : comment,
            icon: entry.icon || "",
            entry: entry,
            score: score
        }
    }

    function commandResult(command, score) {
        return {
            kind: command.kind,
            key: "command:" + command.id,
            id: command.id,
            title: command.title,
            description: command.description,
            icon: command.icon,
            score: score
        }
    }

    function hintResult(key, title, description, icon) {
        return {
            kind: "hint",
            key: key,
            title: title,
            description: description,
            icon: icon,
            score: 1
        }
    }

    function emojiResult(entry, score, index) {
        return {
            kind: "emoji",
            key: "emoji:" + index,
            title: entry.value + "  " + entry.title,
            description: "Emoji & symbol · copy " + entry.value,
            icon: "emoji_symbols",
            value: entry.value,
            score: score
        }
    }

    function shellResult(command, score, keySuffix) {
        const interactive = shellNeedsTerminal(command)
        return {
            kind: "shell",
            key: "shell:" + (keySuffix || command),
            title: command,
            description: interactive
                ? "Open in your preferred terminal"
                : "Run in your login shell",
            icon: "terminal",
            command: command,
            terminal: interactive,
            score: score
        }
    }

    function shellCommandName(command) {
        const value = String(command || "").trim()
        if (value.length === 0)
            return ""

        // This deliberately covers the leading command only. A pipeline that
        // starts with a normal command can still be captured in the panel.
        const tokens = value.match(/(?:[^\s"']+|"[^"]*"|'[^']*')+/g) || []
        let index = 0
        while (index < tokens.length && /^[A-Za-z_][A-Za-z0-9_]*=/.test(tokens[index]))
            ++index
        if (tokens[index] === "env") {
            ++index
            while (index < tokens.length && (/^-/.test(tokens[index])
                    || /^[A-Za-z_][A-Za-z0-9_]*=/.test(tokens[index])))
                ++index
        }
        if (tokens[index] === "sudo") {
            ++index
            while (index < tokens.length && /^-/.test(tokens[index])) {
                const option = tokens[index++]
                if ((option === "-u" || option === "-g" || option === "-h"
                        || option === "-p" || option === "-C" || option === "-T")
                        && index < tokens.length)
                    ++index
            }
        }
        if (index >= tokens.length)
            return ""
        const parts = tokens[index].replace(/^["']|["']$/g, "").split("/")
        return parts[parts.length - 1].toLowerCase()
    }

    function shellNeedsTerminal(command) {
        const program = shellCommandName(command)
        return [
            "nano", "vim", "nvim", "vi", "cava", "btop", "htop", "top",
            "less", "more", "man", "ssh", "mosh", "tmux", "yazi", "ranger",
            "lazygit", "lazydocker"
        ].indexOf(program) >= 0
    }

    function rememberShellCommand(command) {
        const value = String(command || "").trim()
        if (value.length === 0)
            return
        const next = [value]
        for (let index = 0; index < shellHistory.length && next.length < 8; ++index) {
            if (shellHistory[index] !== value)
                next.push(shellHistory[index])
        }
        shellHistory = next
        revision++
    }

    function runShellCommand(command) {
        const value = String(command || "").trim()
        actionMessage = ""
        if (value.length === 0)
            return false
        if (shellNeedsTerminal(value)) {
            rememberShellCommand(value)
            Quickshell.execDetached({
                command: ["sh", Paths.shellRoot + "/scripts/terminal-command.sh", value]
            })
            ShellState.closePanels()
            return true
        }
        if (shellProcess.running) {
            actionMessage = "A shell command is already running"
            return false
        }
        rememberShellCommand(value)
        pendingShellCommand = value
        shellOutput = ""
        shellError = ""
        shellExitCode = 0
        shellProcess.running = true
        revision++
        return true
    }

    function stopShellCommand() {
        if (shellProcess.running)
            shellProcess.signal(15)
    }

    function clearShellOutput() {
        if (shellProcess.running)
            return
        pendingShellCommand = ""
        shellOutput = ""
        shellError = ""
        shellExitCode = 0
        revision++
    }

    function resultsFor(queryText, mode, clipboardSection, fileFilter, fileSearchMode) {
        const currentRevision = revision
        const currentFiles = fileResults
        const currentClipboard = clipboardEntries
        const rawQuery = (queryText || "").trim()
        const selectedMode = mode || "root"

        if (selectedMode === "shell" || rawQuery.startsWith(">")) {
            const shellText = selectedMode === "shell"
                ? rawQuery : rawQuery.slice(1).trim()
            if (shellText.length === 0) {
                if (shellHistory.length > 0) {
                    const recent = []
                    for (let index = 0; index < shellHistory.length; ++index)
                        recent.push(shellResult(shellHistory[index], 1000 - index, "recent:" + index))
                    return recent
                }
                return [{
                    kind: "hint",
                    key: "shell-hint",
                    title: I18n.tr("launcher.shellCommand"),
                    description: selectedMode === "shell"
                        ? I18n.tr("launcher.shellPrompt")
                        : I18n.tr("launcher.shellPrefixPrompt"),
                    icon: "terminal",
                    score: 1
                }]
            }
            return [shellResult(shellText, 2000, shellText)]
        }

        const needle = normalized(rawQuery)
        let results = []

        if (selectedMode === "root") {
            for (let index = 0; index < rootCommands.length; ++index) {
                const command = rootCommands[index]
                const score = fuzzyScore(command.title,
                    command.title + " " + command.description + " " + command.keywords, needle)
                if (score >= 0)
                    results.push(commandResult(command, score))
            }
        } else if (selectedMode === "apps") {
            for (let index = 0; index < applications.length; ++index) {
                const entry = applications[index]
                const name = entry.name || ""
                const searchable = name + " " + (entry.genericName || "") + " "
                    + (entry.comment || "") + " " + (entry.keywords || []).join(" ")
                let score = fuzzyScore(name, searchable, needle)
                if (needle.length === 0)
                    score = recentApplicationIds.indexOf(applicationId(entry)) >= 0 ? 120 : 1
                if (score >= 0)
                    results.push(applicationResult(entry, score))
            }
        } else if (selectedMode === "calculator") {
            if (rawQuery.length === 0) {
                if (calculatorHistory.length === 0) {
                    results.push(hintResult("calculator-hint",
                        I18n.tr("calculator.typeEquation"),
                        I18n.tr("calculator.example"), "calculate"))
                } else {
                    for (let index = 0; index < calculatorHistory.length; ++index) {
                        const item = calculatorHistory[index]
                        results.push({
                            kind: "calculator",
                            key: "calculator-history:" + index,
                            id: "calculator-history:" + index,
                            title: item.expression,
                            description: "= " + item.value,
                            icon: "history",
                            value: item.value,
                            expression: item.expression,
                            score: 100 - index
                        })
                    }
                }
            } else {
                const calculation = calculateExpression(rawQuery)
                if (calculation.ok) {
                    results.push({
                        kind: "calculator",
                        key: "calculator-result",
                        id: "calculator-result",
                        title: "= " + calculation.value
                            + (calculation.unit ? " " + calculation.unit : ""),
                        description: copyToolAvailable
                            ? I18n.tr("calculator.copyResult")
                            : I18n.tr("calculator.installClipboard"),
                        icon: "function",
                        value: calculation.value
                            + (calculation.unit ? " " + calculation.unit : ""),
                        expression: rawQuery,
                        score: 2000
                    })
                } else {
                    results.push(hintResult("calculator-incomplete", I18n.tr("calculator.keepTyping"),
                        calculation.error, "calculate"))
                }
            }
        } else if (selectedMode === "files") {
            const recentMode = fileSearchMode === "recent"
            if (!recentMode && rawQuery.length < 2) {
                results.push(hintResult("files-hint", I18n.tr("files.searchHome"),
                    I18n.tr("files.minimumCharacters"), "manage_search"))
            } else if (filesSearching && currentFiles.length === 0) {
                results.push(hintResult("files-searching", I18n.tr("files.searching"),
                    I18n.tr("files.resultsSoon"), "progress_activity"))
            } else {
                const selectedFilter = fileFilter || "all"
                results = selectedFilter === "all"
                    ? currentFiles.slice()
                    : currentFiles.filter(item => item.category === selectedFilter)
                if (results.length === 0) {
                    results.push(hintResult("files-empty", I18n.tr("files.noResults"),
                        I18n.tr("files.tryAnotherSearch"), "search_off"))
                }
            }
        } else if (selectedMode === "clipboard") {
            const section = clipboardSection || "all"
            if (section !== "symbols" && capabilitiesChecked && !clipboardToolsAvailable) {
                results.push(hintResult("clipboard-unavailable", I18n.tr("launcher.clipboardUnavailable"),
                    I18n.tr("launcher.installClipboardTools"), "content_paste_off"))
            } else if ((!capabilitiesChecked || clipboardListProcess.running)
                    && section !== "symbols") {
                results.push(hintResult("clipboard-loading", I18n.tr("launcher.clipboardLoading"),
                    I18n.tr("launcher.recentClipboardHint"), "progress_activity"))
            } else {
                const clipboardNeedle = normalized(rawQuery)
                if (section !== "symbols") {
                    const clipLimit = section === "all" && clipboardNeedle.length === 0
                        ? Math.min(12, currentClipboard.length) : currentClipboard.length
                    for (let index = 0; index < clipLimit; ++index) {
                        const item = currentClipboard[index]
                        const score = fuzzyScore(item.title, item.title + " " + item.description, clipboardNeedle)
                        if (score >= 0) {
                            const result = Object.assign({}, item)
                            result.score = score + (section === "all" ? 80 : 0)
                            results.push(result)
                        }
                    }
                }
                if (section !== "clipboard") {
                    for (let index = 0; index < emojiCatalog.length; ++index) {
                        const entry = emojiCatalog[index]
                        const score = fuzzyScore(entry.title,
                            entry.title + " " + entry.keywords + " " + entry.value, clipboardNeedle)
                        if (score >= 0)
                            results.push(emojiResult(entry, score, index))
                    }
                }
                if (results.length === 0)
                    results.push(hintResult("clipboard-empty", I18n.tr("launcher.nothingFound"),
                        section === "symbols" ? I18n.tr("launcher.tryAnotherSymbol")
                            : I18n.tr("launcher.copyOrSearchSymbols"), "content_paste"))
            }
        }

        // Preserve the intentional DragonShell-style module order until a
        // query introduces relevance ranking.
        if (needle.length > 0 || selectedMode === "apps") {
            results.sort((left, right) => {
                if (right.score !== left.score)
                    return right.score - left.score
                return normalized(left.title).localeCompare(normalized(right.title))
            })
        }
        return selectedMode === "apps" ? results.slice(0, 60) : results
    }

    function rememberApplication(entry) {
        const appId = applicationId(entry)
        const next = [appId]
        for (let index = 0; index < recentApplicationIds.length && next.length < 8; ++index) {
            if (recentApplicationIds[index] !== appId)
                next.push(recentApplicationIds[index])
        }
        recentApplicationIds = next
        revision++
    }

    function execute(result, screenName) {
        actionMessage = ""
        if (!result || result.kind === "hint" || result.kind === "module")
            return false

        if (result.kind === "app") {
            rememberApplication(result.entry)
            result.entry.execute()
            ShellState.closePanels()
            return true
        }

        if (result.kind === "shell") {
            return runShellCommand(result.command)
        }

        if (result.kind === "file") {
            Quickshell.execDetached({ command: ["xdg-open", result.path] })
            ShellState.closePanels()
            return true
        }

        if (result.kind === "clipboard") {
            if (!clipboardToolsAvailable) {
                actionMessage = I18n.tr("launcher.installClipboardTools")
                return false
            }
            Quickshell.execDetached({
                command: ["sh", Paths.shellRoot + "/scripts/launcher-tools.sh",
                    "clipboard-copy", result.encodedEntry]
            })
            ShellState.closePanels()
            return true
        }

        if (result.kind === "emoji" || result.kind === "calculator") {
            if (!copyToolAvailable) {
                actionMessage = I18n.tr("calculator.installClipboard")
                return false
            }
            Quickshell.execDetached({
                command: ["sh", Paths.shellRoot + "/scripts/launcher-tools.sh",
                    "copy-text", result.value]
            })
            if (result.kind === "calculator" && result.expression)
                rememberCalculation(result.expression, result.value)
            ShellState.closePanels()
            return true
        }

        if (result.kind !== "command")
            return false

        return false
    }

    function openContainingFolder(result) {
        if (!result || result.kind !== "file")
            return false
        Quickshell.execDetached({
            command: ["sh", Paths.shellRoot + "/scripts/launcher-tools.sh",
                "open-containing", result.path]
        })
        ShellState.closePanels()
        return true
    }

    function copyFilePath(result) {
        if (!result || result.kind !== "file" || !copyToolAvailable)
            return false
        Quickshell.execDetached({
            command: ["sh", Paths.shellRoot + "/scripts/launcher-tools.sh",
                "copy-path", result.path]
        })
        actionMessage = I18n.tr("files.pathCopied")
        return true
    }

    function takeScreenshot(mode, screenName) {
        actionMessage = ""
        const captureMode = mode || "region"
        if (!screenshotAvailable) {
            actionMessage = "Install grim and slurp to capture screenshots"
            return false
        }
        if (captureMode === "window" && !windowScreenshotAvailable) {
            actionMessage = "Install jq to capture the active window"
            return false
        }
        Quickshell.execDetached({
            command: ["sh", Paths.shellRoot + "/scripts/screenshot.sh",
                captureMode, screenName || ""]
        })
        ShellState.closePanels()
        return true
    }

    function pickColor() {
        actionMessage = ""
        if (!colorPickerAvailable) {
            actionMessage = "Install hyprpicker to pick screen colors"
            return false
        }
        Quickshell.execDetached({
            command: ["sh", Paths.shellRoot + "/scripts/launcher-tools.sh", "color-picker"]
        })
        ShellState.closePanels()
        return true
    }

    property var capabilityProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/launcher-tools.sh", "capabilities"]
        stdout: StdioCollector {
            onStreamFinished: root.parseCapabilities(text)
        }
    }

    property var fileSearchDelay: Timer {
        interval: 150
        onTriggered: root.startFileSearch()
    }

    property var fileSearchProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/launcher-tools.sh",
            "files", root.activeFileQuery, root.activeFileMode,
            root.activeFileLocation]
        stdout: StdioCollector { id: fileSearchOutput }
        onExited: (exitCode, exitStatus) => {
            if (root.activeFileQuery === root.pendingFileQuery
                    && root.activeFileMode === root.pendingFileMode
                    && root.activeFileLocation === root.pendingFileLocation
                    && exitCode === 0)
                root.parseFileResults(fileSearchOutput.text)
            if ((root.pendingFileQuery !== root.activeFileQuery
                    || root.pendingFileMode !== root.activeFileMode
                    || root.pendingFileLocation !== root.activeFileLocation)
                    && root.pendingFileQuery.length >= 2) {
                fileSearchDelay.restart()
            } else {
                root.filesSearching = false
                root.revision++
            }
        }
    }

    property var clipboardListProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/launcher-tools.sh", "clipboard-list"]
        stdout: StdioCollector { id: clipboardListOutput }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                root.parseClipboard(clipboardListOutput.text)
            else
                root.clipboardEntries = []
            root.revision++
        }
    }

    property var clipboardWatcher: Process {
        command: ["wl-paste", "--type", "text", "--watch", "cliphist", "store"]
        running: root.clipboardToolsAvailable
    }

    property var shellProcess: Process {
        command: ["sh", "-lc", root.pendingShellCommand]
        stdout: StdioCollector { id: shellStdout }
        stderr: StdioCollector { id: shellStderr }

        onExited: (exitCode, exitStatus) => {
            root.shellExitCode = exitCode
            root.shellOutput = shellStdout.text.slice(-12000)
            root.shellError = shellStderr.text.slice(-12000)
            root.revision++
        }
    }

    Component.onCompleted: {
        refreshApplications()
        refreshToolCapabilities()
    }
}
