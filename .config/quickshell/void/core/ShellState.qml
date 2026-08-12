pragma Singleton

import Quickshell
import Quickshell.Hyprland
import QtQuick

QtObject {
    property bool controlCenterOpen: false
    property string controlCenterScreenName: ""
    property string detailScreenName: ""
    property string detailPage: ""
    property bool launcherOpen: false
    property string launcherScreenName: ""
    property string launcherPage: "root"
    property string launcherView: ""
    property string launcherQuery: ""
    property string launcherFileMode: "name"
    property string launcherFileLocation: "home"
    property bool powerMenuOpen: false
    property string powerMenuScreenName: ""
    property bool musicOpen: false
    property string musicScreenName: ""
    property bool clockOpen: false
    property string clockScreenName: ""
    property bool settingsOpen: false
    property string settingsSection: "connections"
    property string settingsDeviceCategory: ""

    function requestedScreenName(screen) {
        if (typeof screen === "string" && screen.length > 0)
            return screen
        if (screen && screen.name)
            return screen.name
        if (Hyprland.focusedMonitor)
            return Hyprland.focusedMonitor.name
        return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
    }

    function isControlCenterScreen(screen) {
        return controlCenterOpen && requestedScreenName(screen) === controlCenterScreenName
    }

    function isLauncherScreen(screen) {
        return launcherOpen && requestedScreenName(screen) === launcherScreenName
    }

    function isPowerMenuScreen(screen) {
        return powerMenuOpen && requestedScreenName(screen) === powerMenuScreenName
    }

    function isMusicScreen(screen) {
        return musicOpen && requestedScreenName(screen) === musicScreenName
    }

    function isClockScreen(screen) {
        return clockOpen && requestedScreenName(screen) === clockScreenName
    }

    function normalizedLauncherPage(page) {
        const pages = ["apps", "overview", "calculator", "files", "games",
            "clipboard", "shell", "wallpaper", "local-ai"]
        return pages.indexOf(page) >= 0 ? page : "root"
    }

    function toggleControlCenter(screen) {
        const requested = requestedScreenName(screen)
        if (controlCenterOpen && controlCenterScreenName === requested) {
            closePanels()
        } else {
            launcherOpen = false
            powerMenuOpen = false
            musicOpen = false
            clockOpen = false
            detailScreenName = requested
            detailPage = ""
            controlCenterScreenName = requested
            controlCenterOpen = true
        }
    }

    function openControlCenter(page, screen) {
        const requested = requestedScreenName(screen)
        launcherOpen = false
        powerMenuOpen = false
        musicOpen = false
        clockOpen = false
        detailScreenName = requested
        detailPage = page || ""
        controlCenterScreenName = requested
        controlCenterOpen = true
    }

    function toggleLauncher(screen, page) {
        const requested = requestedScreenName(screen)
        const requestedPage = normalizedLauncherPage(page)
        if (launcherOpen && launcherScreenName === requested && launcherPage === requestedPage) {
            closePanels()
        } else {
            controlCenterOpen = false
            powerMenuOpen = false
            musicOpen = false
            clockOpen = false
            launcherScreenName = requested
            launcherPage = requestedPage
            launcherOpen = true
        }
    }

    function openLauncher(screen, page) {
        const requested = requestedScreenName(screen)
        controlCenterOpen = false
        powerMenuOpen = false
        musicOpen = false
        clockOpen = false
        launcherScreenName = requested
        launcherPage = normalizedLauncherPage(page)
        launcherOpen = true
    }

    function toggleOverview(screen) {
        toggleLauncher(screen, "overview")
    }

    function openOverview(screen) {
        openLauncher(screen, "overview")
    }

    function openPowerMenu(screen) {
        const requested = requestedScreenName(screen)
        controlCenterOpen = false
        launcherOpen = false
        musicOpen = false
        clockOpen = false
        powerMenuScreenName = requested
        powerMenuOpen = true
    }

    function closePowerMenu(screen) {
        if (!screen || requestedScreenName(screen) === powerMenuScreenName)
            powerMenuOpen = false
    }

    function toggleMusic(screen) {
        const requested = requestedScreenName(screen)
        if (musicOpen && musicScreenName === requested) {
            closePanels()
        } else {
            controlCenterOpen = false
            launcherOpen = false
            powerMenuOpen = false
            clockOpen = false
            musicScreenName = requested
            musicOpen = true
        }
    }

    function openMusic(screen) {
        const requested = requestedScreenName(screen)
        controlCenterOpen = false
        launcherOpen = false
        powerMenuOpen = false
        clockOpen = false
        musicScreenName = requested
        musicOpen = true
    }

    function toggleClock(screen) {
        const requested = requestedScreenName(screen)
        if (clockOpen && clockScreenName === requested) {
            closePanels()
        } else {
            controlCenterOpen = false
            launcherOpen = false
            powerMenuOpen = false
            musicOpen = false
            clockScreenName = requested
            clockOpen = true
        }
    }

    function openClock(screen) {
        const requested = requestedScreenName(screen)
        controlCenterOpen = false
        launcherOpen = false
        powerMenuOpen = false
        musicOpen = false
        clockScreenName = requested
        clockOpen = true
    }

    function normalizedSettingsSection(section) {
        const sections = ["home", "connections", "audio", "devices", "notifications",
            "display", "appearance", "lock", "security", "accessibility",
            "assistant", "updates", "system", "developer"]
        if (section === "developer" && !Appearance.developerMode)
            return "system"
        return sections.indexOf(section) >= 0 ? section : "connections"
    }

    function openSettings(section) {
        closePanels()
        if (section !== undefined && String(section).length > 0)
            settingsSection = normalizedSettingsSection(String(section))
        settingsOpen = true
    }

    function openDeviceSettings(category) {
        settingsDeviceCategory = String(category || "")
        openSettings("devices")
    }

    function closeSettings() {
        settingsOpen = false
    }

    function toggleSettings() {
        if (settingsOpen)
            closeSettings()
        else
            openSettings()
    }

    function closePanels() {
        // Keep the current page and its geometry stable until the owning
        // ControlCenter finishes its reverse morph.
        controlCenterOpen = false
        launcherOpen = false
        powerMenuOpen = false
        musicOpen = false
        clockOpen = false
    }
}
