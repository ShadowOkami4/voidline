import QtQuick
import QtQuick.Layouts
import qs.core
import qs.services
import qs.widgets

// How apps look next to the shell: dark or light, icons, mouse pointer, and
// which apps start with the session.
ColumnLayout {
    id: page
    spacing: 24

    property string open: ""
    property bool adding: false
    Component.onCompleted: Autostart.refresh()

    component Pick: Pressable {
        id: pick
        property string label: ""
        property bool current: false
        Layout.fillWidth: true
        implicitHeight: 46
        color: current ? Theme.secondaryContainer : Theme.surfaceContainerHighest
        restRadius: current ? Theme.cornerFull : Theme.cornerM
        pressedRadius: Theme.cornerS
        Behavior on color { Tint {} }
        Label {
            x: 18
            anchors.verticalCenter: parent.verticalCenter
            text: pick.label
            font.weight: pick.current ? Font.Bold : Font.Normal
            color: pick.current ? Theme.inkOnSecondaryContainer : Theme.ink
        }
        MIcon {
            visible: pick.current
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            icon: "check"
            size: 20
            color: Theme.inkOnSecondaryContainer
        }
    }

    SegGroup {
        visible: Appearance.available
        title: "Apps"
        SegItem {
            icon: "routine"
            hue: 5
            lobes: 5
            title: Lang.t("Dark at night")
            description: Lang.t("Light theme from 7:00, dark theme from 19:00.")
            Toggle { checked: Config.autoTheme; onToggled: v => Config.autoTheme = v }
        }
        SegItem {
            icon: "contrast"
            hue: 0
            lobes: 8
            title: Lang.t("Apps follow dark and light")
            description: Lang.t("Tells apps to use the same dark or light look as the shell.")
            Toggle { checked: Config.syncAppTheme; onToggled: v => Config.syncAppTheme = v }
        }
        SegItem {
            icon: "format_color_fill"
            hue: 4
            lobes: 4
            title: Lang.t("Apps use Voidline's colours")
            description: Lang.t("The file manager and other GTK apps take the shell's colours. Restart an app to see it.")
            Toggle { checked: Config.appColors; onToggled: v => Config.appColors = v }
        }
        SegItem {
            id: icons
            readonly property bool expanded: page.open === "icons"
            icon: "category"
            hue: 1
            lobes: 0
            title: Lang.t("Icons")
            description: Appearance.iconTheme || Lang.t("Default")
            clickable: true
            onClicked: page.open = expanded ? "" : "icons"
            MIcon { icon: icons.expanded ? "expand_less" : "expand_more"; size: 24; color: Theme.inkMuted }
            extra: ColumnLayout {
                visible: icons.expanded
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: icons.expanded ? Appearance.iconThemes : []
                    Pick {
                        required property string modelData
                        label: modelData
                        current: modelData === Appearance.iconTheme
                        onClicked: Appearance.setIconTheme(modelData)
                    }
                }
            }
        }
        SegItem {
            id: pointer
            readonly property bool expanded: page.open === "cursor"
            icon: "arrow_selector_tool"
            hue: 2
            lobes: 4
            title: Lang.t("Mouse pointer")
            description: (Appearance.cursorTheme || Lang.t("Default")) + Lang.t(", size ") + Appearance.cursorSize
            clickable: true
            onClicked: page.open = expanded ? "" : "cursor"
            MIcon { icon: pointer.expanded ? "expand_less" : "expand_more"; size: 24; color: Theme.inkMuted }
            extra: ColumnLayout {
                visible: pointer.expanded
                Layout.fillWidth: true
                spacing: 4
                Choice {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 6
                    value: Appearance.cursorSize
                    options: [
                        { value: 16, label: Lang.t("Small") },
                        { value: 24, label: "Normal" },
                        { value: 32, label: Lang.t("Large") },
                        { value: 48, label: Lang.t("Huge") }
                    ]
                    onPicked: v => Appearance.setCursor(Appearance.cursorTheme, v)
                }
                Repeater {
                    model: pointer.expanded ? Appearance.cursorThemes : []
                    Pick {
                        required property string modelData
                        label: modelData
                        current: modelData === Appearance.cursorTheme
                        onClicked: Appearance.setCursor(modelData, Appearance.cursorSize)
                    }
                }
            }
        }
    }

    SegGroup {
        title: Lang.t("Night light")
        SegItem {
            icon: "nightlight"
            hue: 3
            lobes: 5
            title: Lang.t("Warmer screen")
            description: Appearance.nightAvailable ? Lang.t("Less blue light, easier on the eyes at night.")
                : Lang.t("Needs the package “hyprsunset” (Hyprland) or “gammastep”.")
            Toggle {
                enabled: Appearance.nightAvailable
                opacity: enabled ? 1 : 0.4
                checked: Config.nightLight
                onToggled: v => Config.nightLight = v
            }
            extra: Choice {
                visible: Appearance.nightAvailable && Config.nightLight
                Layout.fillWidth: true
                value: Config.nightLightTemp
                options: [
                    { value: 5000, label: Lang.t("Slightly warm") },
                    { value: 4000, label: "Warm" },
                    { value: 3200, label: Lang.t("Very warm") }
                ]
                onPicked: v => Config.nightLightTemp = v
            }
        }
        SegItem {
            visible: Appearance.nightAvailable
            icon: "schedule"
            hue: 4
            lobes: 8
            title: Lang.t("By the clock")
            description: Config.nightLightAuto ? Lang.t("Switches on at %1 and off at %2.", Config.nightLightFrom, Config.nightLightTo)
                : Lang.t("Switch the night light on in the evening by itself.")
            Row {
                spacing: 8
                TimeField { visible: Config.nightLightAuto; anchors.verticalCenter: parent.verticalCenter; value: Config.nightLightFrom; onPicked: v => Config.nightLightFrom = v }
                TimeField { visible: Config.nightLightAuto; anchors.verticalCenter: parent.verticalCenter; value: Config.nightLightTo; onPicked: v => Config.nightLightTo = v }
                Toggle { anchors.verticalCenter: parent.verticalCenter; checked: Config.nightLightAuto; onToggled: v => Config.nightLightAuto = v }
            }
        }
    }

    SegGroup {
        title: Lang.t("Start with the session")
        Repeater {
            model: Autostart.entries
            SegItem {
                id: startItem
                required property var modelData
                required property int index
                icon: "rocket_launch"
                hue: index + 4
                lobes: [8, 0, 4, 5][index % 4]
                title: modelData.name
                description: modelData.exec
                IconBtn { icon: "delete"; size: 40; tonal: true; onClicked: Autostart.remove(startItem.modelData.file) }
            }
        }
        SegItem {
            icon: "add"
            hue: 0
            lobes: 4
            title: Lang.t("Add an app")
            description: Autostart.entries.length === 0 ? Lang.t("Nothing starts on its own yet.") : ""
            clickable: true
            onClicked: page.adding = !page.adding
            MIcon { icon: page.adding ? "expand_less" : "expand_more"; size: 24; color: Theme.inkMuted }
            extra: ListView {
                visible: page.adding
                Layout.fillWidth: true
                implicitHeight: 280
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: page.adding ? Apps.all : []
                delegate: Pressable {
                    id: appRow
                    required property var modelData
                    width: ListView.view.width
                    height: 46
                    restRadius: Theme.cornerM
                    pressedRadius: Theme.cornerS
                    onClicked: { Autostart.add(modelData); page.adding = false }
                    AppIcon { id: appIcon; x: 12; anchors.verticalCenter: parent.verticalCenter; size: 26; icon: appRow.modelData.icon; name: appRow.modelData.name }
                    Label { anchors.left: appIcon.right; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: appRow.modelData.name }
                }
            }
        }
    }
}
