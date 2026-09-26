pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property bool persistPending: false

    property string colorMode: "dark"
    property bool magicColors: true
    property string wallpaperPath: ""
    property string barPosition: "top"
    property string pendingBarPosition: "top"
    // Bar presentation. "frame" keeps the connected bar, screen frame, and
    // attached panels; every other style floats and detaches its panels.
    readonly property var barStyles: ["frame", "islands", "floating", "minimal", "taskbar"]
    property string barStyle: "frame"
    property string pendingBarStyle: "frame"
    // The taskbar always lives on the bottom edge; the previous edge is
    // restored when another style is chosen.
    property string positionBeforeTaskbar: "top"
    // The taskbar hides below the screen edge and slides in when the pointer
    // reaches the bottom edge, so windows keep the full height.
    property bool taskbarAutoHide: true
    readonly property bool panelsAttached: barStyle === "frame"
    // Desktop entry ids pinned to the taskbar dock, in display order.
    property var pinnedApps: ["org.gnome.Nautilus", "firefox", "voidline-terminal", "voidline-settings"]
    property bool barVisible: true
    property bool barTransitioning: false
    readonly property string requestedBarPosition: barTransitioning ? pendingBarPosition : barPosition
    property string workspacePlacement: "center"
    property string musicPlacement: "bar"
    property string clockStyle: "split"
    property string clockFont: "Roboto Flex"
    property string interfaceFont: "Roboto Flex"
    property string accentColor: "#8FB8AC"
    property real uiScale: 1.0
    property string uiDensity: "comfortable"
    property string iconTheme: "Papirus-Dark"
    property string cursorTheme: "Bibata-Modern-Classic"
    property string language: "auto"
    // Retained only as read-only compatibility properties for older callers.
    readonly property real panelOpacity: 1.0
    readonly property bool panelBlur: false
    property bool developerMode: false
    property bool doNotDisturb: false
    property bool notificationPopups: true
    property bool reduceMotion: false
    property bool highContrast: false
    property real textScale: 1.0
    property real animationDurationScale: 1.0
    property bool disableTransparency: false
    property bool largePointer: false
    property bool focusIndicators: false
    property bool visualAlerts: false
    property string lockClockStyle: "pixel"
    property string lockClockFont: "Roboto Flex"
    property int lockClockWeight: 780
    property real lockClockSize: 1.0
    property real lockClockSpacing: -2
    property string lockDatePlacement: "below"
    property bool lockShowDate: true
    property bool lockShowWeather: false
    property bool lockShowWeatherTemperature: true
    property bool lockShowWeatherCondition: true
    property bool lockShowWeatherIcon: true
    property bool lockShowWeatherForecast: false
    property string weatherLocation: ""
    property string lockClockColorMode: "wallpaper"
    property string lockClockColor1: "#FFFFFF"
    property string lockClockColor2: "#B8D8D0"
    property real lockClockX: 0.04
    property real lockClockY: 0.14
    property var automaticClock: SystemClock {
        precision: SystemClock.Minutes
    }
    readonly property bool automaticDark: automaticClock.date.getHours() < 7
        || automaticClock.date.getHours() >= 19
    readonly property bool darkMode: colorMode === "auto"
        ? automaticDark : colorMode !== "light"

    function loadSettings(contents) {
        if (String(contents || "").trim().length === 0)
            return
        try {
            const data = JSON.parse(contents)
            root.colorMode = ["light", "dark", "auto"].indexOf(data.colorMode) >= 0
                ? data.colorMode : "dark"
            root.magicColors = data.magicColors !== false
            root.wallpaperPath = data.wallpaperPath || ""
            root.barPosition = ["top", "bottom", "left", "right"].indexOf(data.barPosition) >= 0
                ? data.barPosition : "top"
            root.pendingBarPosition = root.barPosition
            root.barStyle = root.barStyles.indexOf(data.barStyle) >= 0
                ? data.barStyle : "frame"
            root.pendingBarStyle = root.barStyle
            root.positionBeforeTaskbar = ["top", "bottom", "left", "right"]
                .indexOf(data.positionBeforeTaskbar) >= 0
                ? data.positionBeforeTaskbar : "top"
            root.taskbarAutoHide = data.taskbarAutoHide !== false
            if (Array.isArray(data.pinnedApps))
                root.pinnedApps = data.pinnedApps
                    .filter(value => typeof value === "string" && /^[A-Za-z0-9._-]{1,128}$/.test(value))
                    .slice(0, 24)
            if (root.barStyle === "taskbar") {
                root.barPosition = "bottom"
                root.pendingBarPosition = "bottom"
            }
            root.workspacePlacement = ["clock", "center", "action"].indexOf(data.workspacePlacement) >= 0
                ? data.workspacePlacement : "center"
            root.musicPlacement = ["bar", "clock", "action", "hidden"].indexOf(data.musicPlacement) >= 0
                ? data.musicPlacement : "bar"
            root.clockStyle = ["split", "compact", "stacked", "minimal"].indexOf(data.clockStyle) >= 0
                ? data.clockStyle : "split"
            root.clockFont = data.clockFont || "Roboto Flex"
            root.interfaceFont = data.interfaceFont || "Roboto Flex"
            root.accentColor = data.accentColor || "#8FB8AC"
            root.uiScale = Math.max(0.8, Math.min(1.4, Number(data.uiScale) || 1))
            root.uiDensity = ["compact", "comfortable", "spacious"].indexOf(data.uiDensity) >= 0
                ? data.uiDensity : "comfortable"
            root.iconTheme = data.iconTheme || "Papirus-Dark"
            root.cursorTheme = data.cursorTheme || "Bibata-Modern-Classic"
            root.language = ["auto", "en-US", "de-DE", "pl-PL"].indexOf(data.language) >= 0
                ? data.language : "auto"
            root.developerMode = data.developerMode === true
            root.doNotDisturb = data.doNotDisturb === true
            root.notificationPopups = data.notificationPopups !== false
            root.reduceMotion = data.reduceMotion === true
            root.highContrast = data.highContrast === true
            root.textScale = Math.max(0.85, Math.min(1.6,
                Number(data.textScale) || 1))
            root.animationDurationScale = Math.max(0.5, Math.min(2.5,
                Number(data.animationDurationScale) || 1))
            root.disableTransparency = data.disableTransparency === true
            root.largePointer = data.largePointer === true
            root.focusIndicators = data.focusIndicators === true
            root.visualAlerts = data.visualAlerts === true
            const legacyClock = data.lockClockStyle === "large" ? "digital-large"
                : (data.lockClockStyle === "compact" ? "digital-compact"
                    : data.lockClockStyle)
            root.lockClockStyle = [
                "pixel", "digital-large", "digital-compact", "stacked", "horizontal",
                "minimal", "analog", "playful"
            ].indexOf(legacyClock) >= 0 ? legacyClock : "pixel"
            root.lockClockFont = data.lockClockFont || "Roboto Flex"
            root.lockClockWeight = Math.max(100, Math.min(900,
                Number(data.lockClockWeight) || 780))
            root.lockClockSize = Math.max(0.65, Math.min(1.6,
                Number(data.lockClockSize) || 1))
            root.lockClockSpacing = Math.max(-6, Math.min(12,
                Number(data.lockClockSpacing) || -2))
            root.lockDatePlacement = ["above", "below", "side", "hidden"]
                .indexOf(data.lockDatePlacement) >= 0
                ? data.lockDatePlacement : "below"
            root.lockShowDate = data.lockShowDate !== false
            root.lockShowWeather = data.lockShowWeather === true
            root.lockShowWeatherTemperature = data.lockShowWeatherTemperature !== false
            root.lockShowWeatherCondition = data.lockShowWeatherCondition !== false
            root.lockShowWeatherIcon = data.lockShowWeatherIcon !== false
            root.lockShowWeatherForecast = data.lockShowWeatherForecast === true
            root.weatherLocation = String(data.weatherLocation || "")
            root.lockClockColorMode = ["wallpaper", "custom", "gradient"]
                .indexOf(data.lockClockColorMode) >= 0
                ? data.lockClockColorMode : "wallpaper"
            root.lockClockColor1 = data.lockClockColor1 || "#FFFFFF"
            root.lockClockColor2 = data.lockClockColor2 || "#B8D8D0"
            root.lockClockX = Math.max(0, Math.min(1, data.lockClockX === undefined ? 0.04 : Number(data.lockClockX)))
            root.lockClockY = Math.max(0, Math.min(1,
                data.lockClockY === undefined ? 0.14 : Number(data.lockClockY)))
        } catch (error) {
            console.warn("Voidline: unable to parse appearance settings", error)
        }
    }

    function persist() {
        if (!Paths.writableRootsReady) {
            persistPending = true
            return
        }
        settingsFile.setText(JSON.stringify({
            colorMode: colorMode,
            magicColors: magicColors,
            wallpaperPath: wallpaperPath,
            barPosition: barPosition,
            barStyle: barStyle,
            positionBeforeTaskbar: positionBeforeTaskbar,
            taskbarAutoHide: taskbarAutoHide,
            pinnedApps: pinnedApps,
            workspacePlacement: workspacePlacement,
            musicPlacement: musicPlacement,
            clockStyle: clockStyle,
            clockFont: clockFont,
            interfaceFont: interfaceFont,
            accentColor: accentColor,
            uiScale: uiScale,
            uiDensity: uiDensity,
            iconTheme: iconTheme,
            cursorTheme: cursorTheme,
            language: language,
            developerMode: developerMode,
            doNotDisturb: doNotDisturb,
            notificationPopups: notificationPopups,
            reduceMotion: reduceMotion,
            highContrast: highContrast,
            textScale: textScale,
            animationDurationScale: animationDurationScale,
            disableTransparency: disableTransparency,
            largePointer: largePointer,
            focusIndicators: focusIndicators,
            visualAlerts: visualAlerts,
            lockClockStyle: lockClockStyle,
            lockClockFont: lockClockFont,
            lockClockWeight: lockClockWeight,
            lockClockSize: lockClockSize,
            lockClockSpacing: lockClockSpacing,
            lockDatePlacement: lockDatePlacement,
            lockShowDate: lockShowDate,
            lockShowWeather: lockShowWeather,
            lockShowWeatherTemperature: lockShowWeatherTemperature,
            lockShowWeatherCondition: lockShowWeatherCondition,
            lockShowWeatherIcon: lockShowWeatherIcon,
            lockShowWeatherForecast: lockShowWeatherForecast,
            weatherLocation: weatherLocation,
            lockClockColorMode: lockClockColorMode,
            lockClockColor1: lockClockColor1,
            lockClockColor2: lockClockColor2,
            lockClockX: lockClockX,
            lockClockY: lockClockY
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

    function setColorMode(value) {
        if (["light", "dark", "auto"].indexOf(value) < 0)
            return
        colorMode = value
        persist()
    }

    function setMagicColors(value) {
        magicColors = value
        persist()
    }

    function setWallpaperPath(value) {
        wallpaperPath = String(value || "")
        persist()
    }

    function setBarPosition(value) {
        if (["top", "bottom", "left", "right"].indexOf(value) < 0)
            return
        // The taskbar is bottom-only; remember the request for later.
        if (barStyle === "taskbar") {
            positionBeforeTaskbar = value
            persist()
            return
        }
        if (!barTransitioning && value === barPosition)
            return

        pendingBarPosition = value
        beginBarRelocation()
    }

    function setBarStyle(value) {
        if (barStyles.indexOf(value) < 0)
            return
        if (!barTransitioning && value === barStyle)
            return
        pendingBarStyle = value
        if (value === "taskbar" && barStyle !== "taskbar") {
            positionBeforeTaskbar = barPosition
            pendingBarPosition = "bottom"
        } else if (value !== "taskbar" && barStyle === "taskbar") {
            pendingBarPosition = positionBeforeTaskbar
        } else {
            pendingBarPosition = barPosition
        }
        beginBarRelocation()
    }

    function setTaskbarAutoHide(value) {
        if (taskbarAutoHide === !!value)
            return
        taskbarAutoHide = !!value
        persist()
    }

    function togglePinnedApp(appId) {
        const id = String(appId || "").replace(/\.desktop$/, "")
        if (!/^[A-Za-z0-9._-]{1,128}$/.test(id))
            return
        const next = pinnedApps.slice()
        const index = next.indexOf(id)
        if (index >= 0)
            next.splice(index, 1)
        else if (next.length < 24)
            next.push(id)
        pinnedApps = next
        persist()
    }

    function beginBarRelocation() {
        barTransitioning = true
        barVisible = false
        ShellState.closePanels()
        barRelocationReveal.stop()
        barRelocationFinish.stop()
        barRelocationSwap.restart()
    }

    function setWorkspacePlacement(value) {
        if (["clock", "center", "action"].indexOf(value) < 0)
            return
        workspacePlacement = value
        persist()
    }

    function setMusicPlacement(value) {
        if (["bar", "clock", "action", "hidden"].indexOf(value) < 0)
            return
        musicPlacement = value
        persist()
    }

    function setClockStyle(value) {
        if (["split", "compact", "stacked", "minimal"].indexOf(value) < 0)
            return
        clockStyle = value
        persist()
    }

    function setClockFont(value) {
        clockFont = value || "Roboto Flex"
        persist()
    }

    function setInterfaceFont(value) {
        interfaceFont = value || "Roboto Flex"
        persist()
    }

    function setAccentColor(value) {
        accentColor = String(value || "#8FB8AC")
        persist()
    }

    function setUiScale(value) {
        uiScale = Math.max(0.8, Math.min(1.4, Number(value) || 1))
        persist()
    }

    function setUiDensity(value) {
        if (["compact", "comfortable", "spacious"].indexOf(value) < 0)
            return
        uiDensity = value
        persist()
    }

    function setIconTheme(value) {
        iconTheme = String(value || "Papirus-Dark")
        persist()
    }

    function setCursorTheme(value) {
        cursorTheme = String(value || "Bibata-Modern-Classic")
        persist()
    }

    function setLanguage(value) {
        if (["auto", "en-US", "de-DE", "pl-PL"].indexOf(value) < 0)
            return
        language = value
        persist()
    }

    function setPanelBlur(value) {
        // Connected panels intentionally do not expose transparency or blur.
    }

    function setDeveloperMode(value) {
        developerMode = value
        persist()
    }

    function setDoNotDisturb(value) {
        doNotDisturb = value
        persist()
    }

    function setNotificationPopups(value) {
        notificationPopups = value
        persist()
    }

    function setReduceMotion(value) {
        reduceMotion = value
        persist()
    }

    function setHighContrast(value) {
        highContrast = value
        persist()
    }

    function setTextScale(value) {
        textScale = Math.max(0.85, Math.min(1.6, Number(value) || 1))
        persist()
    }

    function setAnimationDurationScale(value) {
        animationDurationScale = Math.max(0.5, Math.min(2.5, Number(value) || 1))
        persist()
    }

    function setDisableTransparency(value) {
        disableTransparency = Boolean(value)
        persist()
    }

    function setLargePointer(value) {
        largePointer = Boolean(value)
        persist()
        Quickshell.execDetached({
            command: ["hyprctl", "setcursor", cursorTheme,
                largePointer ? "40" : "24"]
        })
    }

    function setFocusIndicators(value) {
        focusIndicators = Boolean(value)
        persist()
    }

    function setVisualAlerts(value) {
        visualAlerts = Boolean(value)
        persist()
    }

    function setLockClockStyle(value) {
        if (["pixel", "digital-large", "digital-compact", "stacked", "horizontal",
                "minimal", "analog", "playful"].indexOf(value) < 0)
            return
        lockClockStyle = value
        persist()
    }

    function setLockShowDate(value) {
        lockShowDate = value
        persist()
    }

    function setLockClockFont(value) {
        lockClockFont = String(value || "Roboto Flex")
        persist()
    }

    function setLockClockWeight(value) {
        lockClockWeight = Math.max(100, Math.min(900, Math.round(value)))
        persist()
    }

    function setLockClockSize(value) {
        lockClockSize = Math.max(0.65, Math.min(1.6, Number(value) || 1))
        persist()
    }

    function setLockClockSpacing(value) {
        lockClockSpacing = Math.max(-6, Math.min(12, Number(value) || 0))
        persist()
    }

    function setLockDatePlacement(value) {
        if (["above", "below", "side", "hidden"].indexOf(value) < 0)
            return
        lockDatePlacement = value
        lockShowDate = value !== "hidden"
        persist()
    }

    function setLockShowWeather(value) {
        lockShowWeather = Boolean(value)
        persist()
    }

    function setLockWeatherPart(part, value) {
        if (part === "temperature")
            lockShowWeatherTemperature = Boolean(value)
        else if (part === "condition")
            lockShowWeatherCondition = Boolean(value)
        else if (part === "icon")
            lockShowWeatherIcon = Boolean(value)
        else if (part === "forecast")
            lockShowWeatherForecast = Boolean(value)
        else
            return
        persist()
    }

    function setLockClockColorMode(value) {
        if (["wallpaper", "custom", "gradient"].indexOf(value) < 0)
            return
        lockClockColorMode = value
        persist()
    }

    function setLockClockColors(first, second) {
        lockClockColor1 = String(first || "#FFFFFF")
        lockClockColor2 = String(second || lockClockColor1)
        persist()
    }

    function setLockClockPosition(x, y) {
        lockClockX = Math.max(0, Math.min(1, Number(x) || 0))
        lockClockY = Math.max(0, Math.min(1, Number(y) || 0))
        persist()
    }

    function setWeatherLocation(value) {
        weatherLocation = String(value || "").trim()
        persist()
    }

    function resetLockClock() {
        lockClockStyle = "digital-large"
        lockClockFont = "Roboto Flex"
        lockClockWeight = 760
        lockClockSize = 1
        lockClockSpacing = -2
        lockDatePlacement = "below"
        lockShowDate = true
        lockShowWeather = false
        lockShowWeatherTemperature = true
        lockShowWeatherCondition = true
        lockShowWeatherIcon = true
        lockShowWeatherForecast = false
        lockClockColorMode = "wallpaper"
        lockClockColor1 = "#FFFFFF"
        lockClockColor2 = "#B8D8D0"
        lockClockX = 0.5
        lockClockY = 0.12
        persist()
    }

    property var settingsFile: FileView {
        path: Paths.writableRootsReady ? Paths.configRoot + "/settings.json" : ""
        watchChanges: true
        printErrors: false

        onFileChanged: settingsReload.restart()
        onLoaded: root.loadSettings(text())
    }

    property Timer settingsReload: Timer {
        interval: 70
        repeat: false
        onTriggered: settingsFile.reload()
    }

    // Moving a layer-shell surface directly makes it visibly travel between
    // opposite screen edges. Instead, hide its chrome, relocate the surface
    // while transparent, let the compositor settle, then reveal it again.
    property Timer barRelocationSwap: Timer {
        interval: root.reduceMotion ? 1 : 135
        repeat: false
        onTriggered: {
            root.barPosition = root.pendingBarPosition
            root.barStyle = root.pendingBarStyle
            root.persist()
            barRelocationReveal.restart()
        }
    }

    property Timer barRelocationReveal: Timer {
        interval: root.reduceMotion ? 1 : 45
        repeat: false
        onTriggered: {
            root.barVisible = true
            barRelocationFinish.restart()
        }
    }

    property Timer barRelocationFinish: Timer {
        interval: root.reduceMotion ? 1 : 190
        repeat: false
        onTriggered: root.barTransitioning = false
    }
}
