//@ pragma UseQApplication
//@ pragma Env QSG_RENDER_LOOP=threaded

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import "bar"
import "components"
import "core"
import "panels"
import "services"

// Feature services are registered through their local qmldir singletons;
// display/backlight ownership lives with the power service.
Scope {
    readonly property bool transientSurfaceOpen: ShellState.controlCenterOpen
        || ShellState.launcherOpen || ShellState.powerMenuOpen
        || ShellState.musicOpen || ShellState.clockOpen || ShellState.settingsOpen

    onTransientSurfaceOpenChanged: {
        if (transientSurfaceOpen)
            deferredCollection.stop()
        else
            deferredCollection.restart()
    }

    // Loaders release heavy pages as soon as their surface closes. Delay the
    // JavaScript collection until animations and cleanup handlers have settled
    // so repeated panel use does not retain entire page object graphs.
    Timer {
        id: deferredCollection
        interval: 2500
        onTriggered: gc()
    }

    // Keep desktop applications on the same wallpaper-derived palette as the
    // shell. Referencing the singleton here also starts its debounced exporter.
    property bool applicationThemeReady: AppThemeService.ready

    LockSession {}

    // Settings is a normal desktop window, but its full navigation and content
    // tree has no reason to exist while the application is closed. Recreate it
    // on demand so the shell's idle footprint does not include a hidden app.
    Loader {
        active: ShellState.settingsOpen
        sourceComponent: Component {
            SettingsWindow {}
        }
    }

    Variants {
        model: Quickshell.screens

        Wallpaper {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        NotificationPopup {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        PolkitDialog {
            required property var modelData
            screen: modelData
        }
    }

    IpcHandler {
        target: "controlCenter"

        function open(page: string): void {
            ShellState.openControlCenter(page)
        }

        function openOn(page: string, screen: string): void {
            ShellState.openControlCenter(page, screen)
        }

        function close(): void {
            ShellState.closePanels()
        }

        function toggle(): void {
            ShellState.toggleControlCenter()
        }

    }

    IpcHandler {
        target: "launcher"

        function open(): void {
            ShellState.launcherView = ""
            ShellState.openLauncher()
        }

        function openOn(screen: string): void {
            ShellState.launcherView = ""
            ShellState.openLauncher(screen)
        }

        function openPageOn(page: string, screen: string): void {
            ShellState.launcherView = ""
            ShellState.openLauncher(screen, page)
        }

        function openViewOn(page: string, view: string, screen: string): void {
            ShellState.launcherView = view
            ShellState.openLauncher(screen, page)
        }

        function openSearch(page: string, query: string, view: string,
                mode: string, location: string, screen: string): void {
            ShellState.launcherQuery = query
            ShellState.launcherView = view
            ShellState.launcherFileMode = mode === "content" ? "content" : "name"
            ShellState.launcherFileLocation = location.length > 0 ? location : "home"
            ShellState.openLauncher(screen.length > 0 ? screen : undefined, page)
        }

        function close(): void {
            ShellState.closePanels()
        }

        function toggle(): void {
            ShellState.toggleLauncher()
        }

        function runShell(commandText: string): bool {
            return LauncherService.runShellCommand(commandText)
        }

        function clearShell(): void {
            LauncherService.clearShellOutput()
        }
    }

    IpcHandler {
        target: "lyra"

        function open(): void {
            if (FeatureRegistry.aiInstalled && AssistantService.assistantEnabled)
                ShellState.openLauncher(undefined, "local-ai")
        }

        function ask(prompt: string): bool {
            if (!FeatureRegistry.aiInstalled || !AssistantService.assistantEnabled)
                return false
            ShellState.openLauncher(undefined, "local-ai")
            return AssistantService.ask(prompt)
        }

        function confirm(): void {
            AssistantService.confirmPending()
        }

        function cancel(): void {
            AssistantService.cancelPending()
        }

        function clear(): void {
            AssistantService.clearConversation()
        }

        function status(): string {
            // A persisted disabled state remains meaningful even while the
            // optional manifest is still loading during a shell reload.
            if (!AssistantService.assistantEnabled)
                return I18n.tr("assistant.disabledState")
            return FeatureRegistry.aiInstalled
                ? AssistantService.statusText : I18n.tr("assistant.notInstalled")
        }
    }

    IpcHandler {
        target: "polkit"

        function status(): string {
            return (PolkitService.registered ? "registered" : "unregistered")
                + "|" + (PolkitService.active ? "active" : "idle")
                + "|" + PolkitService.actionId
        }

        function test(): void {
            Quickshell.execDetached({
                command: ["pkexec", "/usr/bin/true"]
            })
        }

        function cancel(): void {
            PolkitService.cancel()
        }
    }

    IpcHandler {
        target: "notifications"

        function setDnd(enabled: bool): void {
            NotificationService.setDoNotDisturb(enabled)
        }

        function toggleDnd(): void {
            NotificationService.setDoNotDisturb(!NotificationService.doNotDisturb)
        }

        function clear(): void {
            NotificationService.clearAll()
        }

        function status(): string {
            return (NotificationService.doNotDisturb ? "dnd" : "enabled")
                + "|" + NotificationService.count
        }
    }

    IpcHandler {
        target: "overview"

        function open(): void {
            ShellState.openOverview()
        }

        function openOn(screen: string): void {
            ShellState.openOverview(screen)
        }

        function close(): void {
            ShellState.closePanels()
        }

        function toggle(): void {
            ShellState.toggleOverview()
        }
    }

    IpcHandler {
        target: "media"

        function open(): void {
            ShellState.openMusic()
        }

        function openOn(screen: string): void {
            ShellState.openMusic(screen)
        }

        function close(): void {
            ShellState.closePanels()
        }

        function toggle(): void {
            ShellState.toggleMusic()
        }
    }

    IpcHandler {
        target: "clock"

        function open(): void {
            ShellState.openClock()
        }

        function openOn(screen: string): void {
            ShellState.openClock(screen)
        }

        function close(): void {
            ShellState.closePanels()
        }

        function toggle(): void {
            ShellState.toggleClock()
        }
    }

    IpcHandler {
        target: "power"

        function setProfile(mode: string): void {
            PowerService.setProfile(mode)
        }

        function status(): string {
            return PowerService.profileMode + "|"
                + PowerService.percentage + "|"
                + PowerService.brightnessPercent
        }
    }

    IpcHandler {
        target: "systemActions"

        function pickColor(): void {
            LauncherService.pickColor()
        }

        function toggleKeepAwake(): void {
            SystemActionService.toggleKeepAwake()
        }

        function status(): string {
            return (SystemActionService.keepAwakeActive ? "awake" : "normal")
        }
    }

    IpcHandler {
        target: "powerMenu"

        function open(): void {
            ShellState.openPowerMenu()
        }

        function openOn(screen: string): void {
            ShellState.openPowerMenu(screen)
        }

        function close(): void {
            ShellState.closePowerMenu()
        }
    }

    IpcHandler {
        target: "screenRecording"

        function start(screen: string): bool {
            return SystemActionService.startRecording(screen)
        }

        function stop(): bool {
            return SystemActionService.stopRecording()
        }

        function toggle(screen: string): bool {
            return SystemActionService.toggleRecording(screen)
        }

        function status(): string {
            if (SystemActionService.recordingStopping)
                return "stopping"
            return SystemActionService.recording ? "recording" : "idle"
        }

        function path(): string {
            return SystemActionService.recordingPath
        }

        function lastError(): string {
            return SystemActionService.error
        }
    }

    IpcHandler {
        target: "lockScreen"

        function lock(): void {
            LockService.lock()
        }

        function status(): string {
            return LockService.locked ? "locked" : "unlocked"
        }
    }

    IpcHandler {
        target: "appearance"

        function setColorMode(mode: string): void {
            Appearance.setColorMode(mode)
        }

        function setMagicColors(enabled: bool): void {
            Appearance.setMagicColors(enabled)
        }

        function setWallpaper(path: string, monitor: string): bool {
            // Per-monitor wallpaper assignment is not exposed until the
            // compositor adapter can persist it safely. An empty monitor
            // applies the validated image globally through the shared service.
            if (monitor.length > 0)
                return false
            return WallpaperService.applyWallpaper(path)
        }

        function setBarPosition(position: string): void {
            Appearance.setBarPosition(position)
        }

        function setBarStyle(style: string): void {
            Appearance.setBarStyle(style)
        }

        function setWorkspacePlacement(position: string): void {
            Appearance.setWorkspacePlacement(position)
        }

        function setMusicPlacement(position: string): void {
            Appearance.setMusicPlacement(position)
        }

        function status(): string {
            return Appearance.barPosition + "|"
                + Appearance.workspacePlacement + "|"
                + Appearance.musicPlacement + "|"
                + Appearance.clockStyle
        }
    }

    IpcHandler {
        target: "settings"

        function reloadShell(): void {
            Quickshell.reload(false)
        }

        function open(): void {
            ShellState.openSettings()
        }

        function openPage(page: string): void {
            ShellState.openSettings(page)
        }

        function close(): void {
            ShellState.closeSettings()
        }

        function toggle(): void {
            ShellState.toggleSettings()
        }
    }

    // UI-only network entry points for diagnostics and structured shell actions.
    // Credentials are deliberately never accepted through IPC.
    IpcHandler {
        target: "network"

        function setWifi(enabled: bool): bool {
            return ConnectivityService.setWifiEnabled(enabled)
        }

        function refresh(): void {
            ConnectivityService.refreshWifi()
            ConnectivityService.refreshWifiNetworks()
        }

        function setBluetooth(enabled: bool): void {
            if (ConnectivityService.bluetoothEnabled !== enabled)
                ConnectivityService.toggleBluetooth()
        }

        function scan(): bool {
            if (!ConnectivityService.wifiBackendAvailable
                    || !ConnectivityService.wifiEnabled
                    || ConnectivityService.wifiInterface.length === 0
                    || ConnectivityService.wifiOperationBusy
                    || ConnectivityService.wifiScanning)
                return false
            ConnectivityService.scanWifi()
            return true
        }

        function prompt(ssid: string, surface: string): bool {
            const network = ConnectivityService.networkBySsid(ssid)
            if (!network)
                return false
            const context = surface === "settings" ? "settings" : "action"
            if (context === "settings")
                ShellState.openSettings("connections")
            else
                ShellState.openControlCenter("wifi")
            if (network.connected && context === "settings")
                ConnectivityService.openNetworkDetails(network.ssid,
                    network.security, true)
            else
                ConnectivityService.requestWifiConnection(network, context)
            return true
        }

        function hidden(surface: string): void {
            const context = surface === "settings" ? "settings" : "action"
            if (context === "settings")
                ShellState.openSettings("connections")
            else
                ShellState.openControlCenter("wifi")
            ConnectivityService.requestHiddenWifi(context)
        }

        function status(): string {
            return ConnectivityService.wifiOperationState + "|"
                + ConnectivityService.wifiSsid + "|"
                + ConnectivityService.wifiBackendName
        }
    }

    GlobalShortcut {
        name: "toggleControlCenter"
        description: "Toggle the Voidline Control Center"
        onPressed: ShellState.toggleControlCenter()
    }

    GlobalShortcut {
        name: "toggleLauncher"
        description: "Toggle the Voidline App and Command Center"
        onPressed: ShellState.toggleLauncher()
    }

    GlobalShortcut {
        name: "toggleOverview"
        description: "Toggle the Voidline window and workspace overview"
        onPressed: ShellState.toggleOverview()
    }

    GlobalShortcut {
        name: "lockScreen"
        description: "Lock the Voidline session"
        onPressed: LockService.lock()
    }

    GlobalShortcut {
        name: "toggleSettings"
        description: "Toggle Voidline Settings"
        onPressed: ShellState.toggleSettings()
    }

    GlobalShortcut {
        name: "togglePowerMenu"
        description: "Toggle the Voidline power menu"
        onPressed: {
            if (ShellState.powerMenuOpen)
                ShellState.closePanels()
            else
                ShellState.openPowerMenu()
        }
    }

    GlobalShortcut {
        name: "openClipboardSymbols"
        description: "Open emoji and symbols"
        onPressed: {
            ShellState.launcherView = "symbols"
            ShellState.openLauncher(undefined, "clipboard")
        }
    }

    GlobalShortcut {
        name: "openClipboardHistory"
        description: "Open clipboard history"
        onPressed: {
            ShellState.launcherView = "clipboard"
            ShellState.openLauncher(undefined, "clipboard")
        }
    }

    GlobalShortcut {
        name: "openActionCenter"
        description: "Open the Voidline Action Center"
        onPressed: ShellState.toggleControlCenter()
    }

    GlobalShortcut {
        name: "openFileSearch"
        description: "Open file search"
        onPressed: {
            ShellState.launcherView = "all"
            ShellState.openLauncher(undefined, "files")
        }
    }

    Variants {
        model: Quickshell.screens

        ScreenFrame {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        PowerDrawer {
            required property var modelData
            screen: modelData
        }
    }
}
