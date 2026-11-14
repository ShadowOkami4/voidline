import QtQuick
import QtQuick.Layouts
import qs.core
import qs.compositor
import qs.widgets

// Window-manager settings. The shared part looks the same on every
// compositor; below it are the extras of the one that is running.
ColumnLayout {
    id: page
    spacing: 24

    readonly property bool hypr: Compositor.name === "hyprland"
    readonly property bool niri: Compositor.name === "niri"
    readonly property string wmName: hypr ? "Hyprland" : (niri ? "Niri" : "")
    readonly property var d: Config.desktop
    readonly property bool live: d.managed

    Label {
        Layout.fillWidth: true
        visible: !Compositor.supported
        wrapMode: Text.Wrap
        color: Theme.inkMuted
        text: Lang.t("No supported window manager is running. Start Voidline inside Hyprland or Niri to change these settings.")
    }

    // ---- master switch ---------------------------------------------------------
    Pressable {
        visible: Compositor.supported
        Layout.fillWidth: true
        implicitHeight: 92
        color: page.live ? Theme.primaryContainer : Theme.surfaceContainerHigh
        restRadius: page.live ? Theme.cornerXXL : Theme.cornerXL
        pressedRadius: Theme.cornerL
        Behavior on color { Tint {} }
        onClicked: page.d.managed = !page.d.managed

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            spacing: 16
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label {
                    Layout.fillWidth: true
                    text: Lang.t("Let Voidline manage ") + page.wmName
                    font.pixelSize: Theme.textTitle + 4
                    font.weight: Font.Black
                    color: page.live ? Theme.inkOnPrimaryContainer : Theme.ink
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.textLabel + 1
                    color: page.live ? Theme.inkOnPrimaryContainer : Theme.inkMuted
                    opacity: 0.85
                    text: page.live ? Lang.t("These settings override your own ") + (page.hypr ? "hyprland.lua" : "config.kdl") + "."
                        : Lang.t("Off: your own ") + (page.hypr ? "hyprland.lua" : "config.kdl") + Lang.t(" decides everything on this page.")
                }
            }
            Toggle { checked: page.live; onToggled: v => page.d.managed = v }
        }
    }

    ColumnLayout {
        visible: Compositor.supported
        Layout.fillWidth: true
        spacing: 24
        enabled: page.live
        opacity: page.live ? 1 : 0.45
        Behavior on opacity { Fade {} }

        // ---- windows (shared) ----------------------------------------------------
        SegGroup {
            title: Lang.t("Windows##wm")
            SliderItem {
                icon: "space_dashboard"
                hue: 0
                lobes: 4
                title: Lang.t("Gaps")
                description: Lang.t("Space between windows and around the screen edge.")
                from: 0; to: 40; step: 1; suffix: " px"
                value: page.d.gaps
                onChanged: v => page.d.gaps = v
            }
            SliderItem {
                icon: "border_style"
                hue: 1
                lobes: 8
                title: page.niri ? Lang.t("Focus ring") : Lang.t("Border")
                description: Lang.t("Outline around windows. 0 hides it.")
                from: 0; to: 8; step: 1; suffix: " px"
                value: page.d.border
                onChanged: v => page.d.border = v
            }
            SliderItem {
                icon: "rounded_corner"
                hue: 2
                lobes: 0
                title: Lang.t("Corner rounding")
                from: 0; to: 30; step: 1; suffix: " px"
                value: page.d.rounding
                onChanged: v => page.d.rounding = v
            }
            SegItem {
                icon: "format_color_fill"
                hue: 3
                lobes: 5
                title: Lang.t("Borders follow the theme")
                description: Lang.t("Use the accent colour for the focused window.")
                Toggle { checked: page.d.themedBorders; onToggled: v => page.d.themedBorders = v }
            }
            SegItem {
                icon: "animation"
                hue: 4
                lobes: 8
                title: Lang.t("Window animations")
                description: page.niri ? Lang.t("Switching this on only works if your config.kdl does not turn animations off.") : ""
                Toggle { checked: page.d.animations; onToggled: v => page.d.animations = v }
            }
        }

        // ---- input (shared) --------------------------------------------------------
        SegGroup {
            title: Lang.t("Keyboard and pointer")
            SegItem {
                icon: "keyboard"
                hue: 5
                lobes: 4
                title: Lang.t("Keyboard layout")
                description: Lang.t("XKB layout code such as us, de or us,de. Empty keeps your current one.")
                Rectangle {
                    width: 150
                    height: 44
                    radius: layoutField.activeFocus ? Theme.cornerM : height / 2
                    color: Theme.surfaceContainerHighest
                    border.width: layoutField.activeFocus ? 2 : 0
                    border.color: Theme.primary
                    Behavior on radius { Spring {} }
                    TextInput {
                        id: layoutField
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        verticalAlignment: TextInput.AlignVCenter
                        text: page.d.kbLayout
                        color: Theme.ink
                        selectionColor: Theme.primaryContainer
                        font.family: Theme.font
                        font.pixelSize: Theme.textBody
                        clip: true
                        validator: RegularExpressionValidator { regularExpression: /[A-Za-z0-9_,]*/ }
                        onEditingFinished: page.d.kbLayout = text.trim()
                    }
                }
            }
            SliderItem {
                icon: "speed"
                hue: 0
                lobes: 0
                title: Lang.t("Pointer speed")
                from: -1; to: 1; step: 0.05; decimals: 2
                value: page.d.pointerSpeed
                onChanged: v => page.d.pointerSpeed = v
            }
            SegItem {
                icon: "touch_app"
                hue: 1
                lobes: 8
                title: Lang.t("Tap to click")
                description: page.niri ? Lang.t("Niri: can be switched on here, but not off if config.kdl enables it.") : ""
                Toggle { checked: page.d.tapToClick; onToggled: v => page.d.tapToClick = v }
            }
            SegItem {
                icon: "swipe_vertical"
                hue: 2
                lobes: 4
                title: Lang.t("Natural scrolling")
                description: page.niri ? Lang.t("Niri: can be switched on here, but not off if config.kdl enables it.") : Lang.t("Touchpad content follows your fingers.")
                Toggle { checked: page.d.naturalScroll; onToggled: v => page.d.naturalScroll = v }
            }
            SegItem {
                icon: "ads_click"
                hue: 3
                lobes: 5
                title: Lang.t("Focus follows the pointer")
                description: Lang.t("The window under the pointer gets keyboard focus.")
                Toggle { checked: page.d.focusFollowsMouse; onToggled: v => page.d.focusFollowsMouse = v }
            }
        }

        // ---- Hyprland only -------------------------------------------------------
        SegGroup {
            visible: page.hypr
            title: "Hyprland"
            SegItem {
                icon: "view_quilt"
                hue: 4
                lobes: 8
                title: "Layout"
                description: Config.hyprland.layout === "master" ? Lang.t("One main window with a stack beside it.")
                    : (Config.hyprland.layout === "scrolling" ? Lang.t("Columns on an endless strip, like Niri.")
                        : Lang.t("Each new window splits the focused one."))
                extra: Choice {
                    Layout.fillWidth: true
                    value: Config.hyprland.layout
                    options: [
                        { value: "dwindle", label: "Dwindle" },
                        { value: "master", label: "Master" },
                        { value: "scrolling", label: "Scrolling" }
                    ]
                    onPicked: v => Config.hyprland.layout = v
                }
            }
            SegItem {
                icon: "blur_on"
                hue: 5
                lobes: 0
                title: Lang.t("Blur")
                description: Lang.t("Blur what is behind transparent windows.")
                Toggle { checked: Config.hyprland.blur; onToggled: v => Config.hyprland.blur = v }
            }
            SegItem {
                icon: "ev_shadow"
                hue: 0
                lobes: 4
                title: Lang.t("Shadows")
                Toggle { checked: Config.hyprland.shadows; onToggled: v => Config.hyprland.shadows = v }
            }
            SegItem {
                icon: "opacity"
                hue: 1
                lobes: 5
                title: Lang.t("Dim unfocused windows")
                description: Lang.t("Makes windows without focus slightly transparent.")
                Toggle { checked: Config.hyprland.dimInactive; onToggled: v => Config.hyprland.dimInactive = v }
            }
            SegItem {
                icon: "display_settings"
                hue: 2
                lobes: 8
                title: Lang.t("Adaptive sync (VRR)")
                description: Lang.t("Let the display follow the frame rate on screens that support it.")
                Toggle { checked: Config.hyprland.vrr; onToggled: v => Config.hyprland.vrr = v }
            }
        }

        // ---- Niri only -------------------------------------------------------------
        SegGroup {
            visible: page.niri
            title: "Niri"
            SegItem {
                icon: "web_asset_off"
                hue: 4
                lobes: 8
                title: Lang.t("Hide app title bars")
                description: Lang.t("Ask apps not to draw their own title bar and buttons. Applies to newly opened windows.")
                Toggle { checked: Config.niri.hideTitleBars; onToggled: v => Config.niri.hideTitleBars = v }
            }
            SegItem {
                icon: "width_normal"
                hue: 5
                lobes: 4
                title: Lang.t("New window width")
                description: Lang.t("Share of the screen a new column takes.")
                extra: Choice {
                    Layout.fillWidth: true
                    value: Config.niri.columnWidth
                    options: [
                        { value: 0.33, label: Lang.t("Third") },
                        { value: 0.5, label: Lang.t("Half") },
                        { value: 0.67, label: Lang.t("Two thirds") },
                        { value: 1.0, label: Lang.t("Full") }
                    ]
                    onPicked: v => Config.niri.columnWidth = v
                }
            }
            SegItem {
                icon: "align_horizontal_center"
                hue: 0
                lobes: 0
                title: Lang.t("Centre the focused column")
                extra: Choice {
                    Layout.fillWidth: true
                    value: Config.niri.centerColumn
                    options: [
                        { value: "never", label: Lang.t("Never") },
                        { value: "on-overflow", label: Lang.t("When it overflows") },
                        { value: "always", label: Lang.t("Always") }
                    ]
                    onPicked: v => Config.niri.centerColumn = v
                }
            }
        }
    }
}
