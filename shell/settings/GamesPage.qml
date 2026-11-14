import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.compositor
import qs.services
import qs.widgets

// Game mode and the games found on this computer (installed apps in the
// "Game" category and the Steam library).
ColumnLayout {
    id: page
    spacing: 24

    // [{ name, id }] from Steam's library files.
    property var steam: []
    readonly property var apps: DesktopEntries.applications.values
        .filter(e => !e.noDisplay && (e.categories || []).includes("Game") && e.id !== "steam")
        .sort((a, b) => a.name.localeCompare(b.name))

    Process {
        running: true
        command: ["sh", "-c", "for d in \"$HOME/.local/share/Steam/steamapps\" \"$HOME/.steam/steam/steamapps\" \"$HOME/.var/app/com.valvesoftware.Steam/data/Steam/steamapps\"; do for f in \"$d\"/appmanifest_*.acf; do [ -f \"$f\" ] || continue; id=$(sed -n 's/^\\s*\"appid\"\\s*\"\\(.*\\)\"/\\1/p' \"$f\" | head -1); name=$(sed -n 's/^\\s*\"name\"\\s*\"\\(.*\\)\"/\\1/p' \"$f\" | head -1); printf '%s\\t%s\\n' \"$id\" \"$name\"; done; done | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {}
                page.steam = text.split("\n").map(l => l.split("\t")).filter(p => {
                    // Runtimes and tools are not games.
                    if (p.length !== 2 || !p[0] || seen[p[0]] || /Proton|Steam Linux Runtime|Steamworks/.test(p[1])) return false
                    seen[p[0]] = true
                    return true
                }).map(p => ({ id: p[0], name: p[1] })).sort((a, b) => a.name.localeCompare(b.name))
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 124
        radius: Theme.cornerXXL
        color: Config.gameMode ? Theme.primary : Theme.primaryContainer
        Behavior on color { Tint {} }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 28
            anchors.rightMargin: 24
            spacing: 18
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label {
                    text: "Game mode"
                    font.pixelSize: 28
                    font.weight: Font.Black
                    color: Config.gameMode ? Theme.inkOnPrimary : Theme.inkOnPrimaryContainer
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    opacity: 0.85
                    color: Config.gameMode ? Theme.inkOnPrimary : Theme.inkOnPrimaryContainer
                    text: "Switches off blur, shadows and window animations, pauses the live wallpaper and holds back notification popups."
                }
            }
            Toggle { checked: Config.gameMode; onToggled: v => Config.gameMode = v }
        }
    }

    SegGroup {
        visible: Compositor.name === "hyprland"
        title: "Display"
        SegItem {
            icon: "autorenew"
            hue: 1
            lobes: 0
            title: "Variable refresh rate"
            description: "The screen follows the game's frame rate (FreeSync / G-Sync)."
            Toggle { checked: Config.hyprland.vrr; onToggled: v => Config.hyprland.vrr = v }
        }
    }

    component GameRow: Pressable {
        id: row
        property string name: ""
        property string iconName: ""
        Layout.fillWidth: true
        implicitHeight: 56
        color: Theme.surfaceContainerHigh
        restRadius: Theme.cornerL
        pressedRadius: Theme.cornerM
        AppIcon { id: art; x: 14; anchors.verticalCenter: parent.verticalCenter; size: 32; icon: row.iconName; name: row.name }
        Label { anchors.left: art.right; anchors.leftMargin: 14; anchors.right: play.left; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; text: row.name; font.weight: Font.DemiBold }
        MIcon { id: play; anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter; icon: "play_arrow"; filled: true; size: 24; color: Theme.primary }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        Label { leftPadding: 8; text: "Library"; font.weight: Font.Bold; color: Theme.primary }

        Repeater {
            model: page.steam
            GameRow {
                required property var modelData
                name: modelData.name
                iconName: "steam_icon_" + modelData.id
                onClicked: Apps.openUrl("steam://rungameid/" + modelData.id)
            }
        }
        Repeater {
            model: page.apps
            GameRow {
                required property var modelData
                name: modelData.name
                iconName: modelData.icon
                onClicked: Apps.launch(modelData)
            }
        }
        Label {
            visible: page.steam.length === 0 && page.apps.length === 0
            leftPadding: 8
            topPadding: 6
            text: "No games found. Games from Steam and installed game apps show up here."
            color: Theme.inkMuted
        }
    }
}
