pragma Singleton

import Quickshell
import QtQuick
import qs.core
import qs.compositor

// The pages of Settings: what the list in the window shows, and what the
// launcher finds when you type "bluetooth" or "wallpaper".
Singleton {
    readonly property string wmName: Compositor.name === "niri" ? "Niri" : (Compositor.name === "hyprland" ? "Hyprland" : Lang.t("Window manager"))
    readonly property var all: [
        { section: Lang.t("Connections") },
        { id: "network", icon: "wifi", lobes: 8, label: Lang.t("Network"), hint: Lang.t("Wi-Fi and wired"), words: Lang.t("network wifi wlan internet ethernet lan password"), view: "NetworkPage.qml" },
        { id: "bluetooth", icon: "bluetooth", lobes: 0, label: "Bluetooth", hint: Lang.t("Headphones, mice, keyboards"), words: Lang.t("bluetooth pair headphones speaker mouse keyboard device"), view: "BluetoothPage.qml" },
        { section: Lang.t("Device") },
        { id: "display", icon: "monitor", lobes: 4, label: Lang.t("Display"), hint: Lang.t("Resolution, refresh rate, scale"), words: Lang.t("display monitor screen resolution refresh rate hz scale brightness"), view: "DisplayPage.qml" },
        { id: "sound", icon: "volume_up", lobes: 5, label: Lang.t("Sound"), hint: Lang.t("Volume, devices, apps"), words: Lang.t("sound audio volume speaker microphone output input mute"), view: "SoundPage.qml" },
        { id: "lock", icon: "lock", lobes: 0, label: Lang.t("Lock & sleep"), hint: Lang.t("Auto lock, screen off"), words: Lang.t("lock screen sleep idle timeout suspend lid password automatic"), view: "LockPage.qml" },
        { id: "power", icon: "battery_full", lobes: 8, label: Lang.t("Battery & power"), hint: Lang.t("Power mode, sleep, shut down"), words: Lang.t("battery power mode performance saver sleep suspend restart shutdown logout"), view: "PowerPage.qml" },
        { id: "drives", icon: "hard_drive", lobes: 5, label: Lang.t("Storage & drives"), hint: Lang.t("Disk space, USB drives"), words: Lang.t("storage disk drive usb stick mount eject unmount space free removable sd card"), view: "DrivesPage.qml" },
        { id: "games", icon: "sports_esports", lobes: 4, label: Lang.t("Games"), hint: Lang.t("Game mode, library"), words: Lang.t("games gaming game mode steam library performance fps"), view: "GamesPage.qml" },
        { section: Lang.t("Personalisation") },
        { id: "style", icon: "dashboard_customize", lobes: 8, label: Lang.t("Style"), hint: "Voidline, Windows, macOS", words: Lang.t("style layout taskbar dock bar windows macos voidline"), view: "StylePage.qml" },
        { id: "colours", icon: "palette", lobes: 4, label: Lang.t("Wallpaper & colours"), hint: Lang.t("Theme, accent, wallpaper"), words: Lang.t("wallpaper colour color accent dark light theme palette"), view: "ColoursPage.qml" },
        { id: "wm", icon: "select_window", lobes: 0, label: wmName, hint: Lang.t("Windows, layout, input"), words: Lang.t("window manager hyprland niri gaps border rounding corner keyboard layout touchpad mouse pointer blur shadow animation vrr focus"), view: "WmPage.qml" },
        { id: "appslook", icon: "format_paint", lobes: 8, label: Lang.t("Apps & startup"), hint: Lang.t("App theme, icons, pointer"), words: Lang.t("apps theme gtk qt dark light icons icon theme cursor pointer mouse night light warm autostart startup start login"), view: "AppsLookPage.qml" },
        { id: "interface", icon: "tune", lobes: 5, label: Lang.t("Interface"), hint: Lang.t("Size, bar, motion"), words: Lang.t("interface size scale workspaces motion animation bar"), view: "InterfacePage.qml" },
        { section: "System" },
        { id: "notifications", icon: "notifications", lobes: 8, label: Lang.t("Notifications"), hint: Lang.t("Popups, do not disturb"), words: Lang.t("notifications popup do not disturb dnd urgent bell alert"), view: "NotificationsPage.qml" },
        { id: "shortcuts", icon: "keyboard", lobes: 0, label: Lang.t("Keyboard shortcuts"), hint: Lang.t("Launcher, minimise, styles"), words: Lang.t("keyboard shortcuts keybinds hotkeys keys bind launcher minimise minimize restore"), view: "ShortcutsPage.qml" },
        { id: "apps", icon: "apps", lobes: 4, label: Lang.t("Default apps"), hint: Lang.t("Browser, files, terminal"), words: Lang.t("default apps applications browser file manager terminal editor image video music pdf mail open with"), view: "DefaultAppsPage.qml" },
        { id: "install", icon: "download", lobes: 8, label: Lang.t("Install apps"), hint: Lang.t("Find, install, update"), words: Lang.t("install apps software store package pacman flatpak flathub update upgrade remove uninstall download program"), view: "InstallPage.qml" },
        { id: "datetime", icon: "schedule", lobes: 5, label: Lang.t("Date & time"), hint: Lang.t("Time zone, clock"), words: Lang.t("date time clock timezone zone ntp automatic seconds 24 hour"), view: "DateTimePage.qml" },
        { id: "users", icon: "person", lobes: 5, label: Lang.t("Users & region"), hint: Lang.t("Password, language, printers"), words: Lang.t("user account password language region locale printer printers scanner name"), view: "UsersPage.qml" },
        { id: "access", icon: "accessibility_new", lobes: 0, label: Lang.t("Accessibility"), hint: Lang.t("Larger text, less motion"), words: Lang.t("accessibility large text size zoom pointer motion contrast screen reader keyboard a11y"), view: "AccessPage.qml" },
        { id: "about", icon: "info", lobes: 4, label: Lang.t("About"), hint: "Version " + Shell.version, words: Lang.t("about version system computer processor memory graphics kernel"), view: "AboutPage.qml" }
    ]
    // Pages whose name or keywords contain the words, best first.
    function find(query) {
        const q = String(query).trim().toLowerCase()
        if (q.length < 2) return []
        const hits = []
        for (const p of all) {
            if (p.section) continue
            const label = p.label.toLowerCase()
            const score = label.startsWith(q) ? 0 : (label.includes(q) ? 1 : ((" " + p.words.toLowerCase()).includes(" " + q) ? 2 : -1))
            if (score >= 0) hits.push({ p: p, s: score })
        }
        return hits.sort((x, y) => x.s - y.s).map(h => h.p)
    }
}
