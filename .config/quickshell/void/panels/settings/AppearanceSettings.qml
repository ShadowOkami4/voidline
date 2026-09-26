import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../core"
import "../../services"

SettingsMasonry {
    id: root
    width: parent ? parent.width : 0
    spacing: 18

    SettingsSection {
        fullWidth: true
        title: "Wallpaper and color"
        subtitle: "A quiet tonal palette can follow the current background"
        icon: "palette"
        iconContainerColor: Theme.secondaryContainer
        iconColor: Theme.secondary

        SettingsChoice {
            width: parent.width
            title: "Theme"
            subtitle: "Choose the base brightness used by every shell surface"
            options: ["light", "dark", "auto"]
            optionLabels: ["Light", "Dark", "Automatic"]
            value: Appearance.colorMode
            onSelected: value => Appearance.setColorMode(value)
        }
        SettingsToggle {
            width: parent.width
            icon: "auto_awesome"
            title: "Dynamic wallpaper colors"
            subtitle: "Derive balanced surfaces, text, borders and highlights from the wallpaper"
            checked: Appearance.magicColors
            onToggled: value => Appearance.setMagicColors(value)
        }
        SettingsChoice {
            width: parent.width
            maxColumns: 5
            // Only relevant when the palette is not taken from the wallpaper.
            visible: !Appearance.magicColors
            title: "Accent color"
            subtitle: Appearance.magicColors
                ? "Used when dynamic colors are turned off"
                : "Current manual accent"
            options: ["#8FB8AC", "#9CAEDB", "#C3A5C9", "#D0AD87", "#A9BE82"]
            optionLabels: ["Sage", "Sky", "Orchid", "Sand", "Leaf"]
            value: Appearance.accentColor
            onSelected: value => Appearance.setAccentColor(value)
        }
        SettingsAction {
            width: parent.width
            icon: WallpaperService.loading ? "progress_activity" : "wallpaper"
            title: "Wallpaper library"
            subtitle: WallpaperService.currentPath.length > 0
                ? WallpaperService.currentPath : "Choose a background"
            value: WallpaperService.wallpapers.length + " images"
            onClicked: WallpaperService.refresh()
        }
        GridView {
            property int columns: width >= 1080 ? 4 : (width >= 660 ? 3 : 2)
            width: parent.width
            height: Math.min(300,
                Math.ceil(WallpaperService.wallpapers.length / columns) * 142)
            model: WallpaperService.wallpapers
            cellWidth: width / columns
            cellHeight: 142
            interactive: false
            clip: true

            delegate: Item {
                id: wallpaperCell
                required property var modelData
                width: GridView.view.cellWidth
                height: GridView.view.cellHeight

                Rectangle {
                    anchors { fill: parent; margins: 4 }
                    radius: Theme.radiusLarge
                    color: Theme.surfaceLow
                    border.width: WallpaperService.currentPath === wallpaperCell.modelData.path ? 2 : 1
                    border.color: WallpaperService.currentPath === wallpaperCell.modelData.path
                        ? Theme.accent : Theme.outlineSoft
                    clip: true

                    RoundedImage {
                        anchors { fill: parent; margins: 6 }
                        source: "file://" + wallpaperCell.modelData.path
                        radius: Theme.radiusMedium
                        fallbackIcon: "broken_image"
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 6 }
                        height: 30
                        radius: Theme.radiusSmall
                        color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.82)
                        RowLayout {
                            anchors { fill: parent; leftMargin: 9; rightMargin: 8 }
                            Text {
                                Layout.fillWidth: true
                                text: wallpaperCell.modelData.title
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            MaterialIcon {
                                text: WallpaperService.currentPath === wallpaperCell.modelData.path
                                    ? "check_circle" : "wallpaper"
                                size: 16
                                color: Theme.accent
                            }
                        }
                    }
                    TapHandler {
                        onTapped: WallpaperService.applyWallpaper(wallpaperCell.modelData.path)
                    }
                }
            }
        }
    }

    SettingsSection {
        title: "Interface"
        subtitle: "Keep controls compact without sacrificing readability"
        icon: "tune"

        SettingsSlider {
            width: parent.width
            title: "UI scale"
            subtitle: "Scales shell chrome and layout density"
            icon: "zoom_in"
            from: 0.8
            to: 1.4
            step: 0.05
            value: Appearance.uiScale
            suffix: "×"
            onChanged: value => Appearance.setUiScale(value)
        }
        SettingsChoice {
            width: parent.width
            title: "Density"
            subtitle: "Adjust spacing independently from the scale"
            options: ["compact", "comfortable", "spacious"]
            optionLabels: ["Compact", "Comfortable", "Spacious"]
            value: Appearance.uiDensity
            onSelected: value => Appearance.setUiDensity(value)
        }
        SettingsChoice {
            width: parent.width
            title: "Interface font"
            subtitle: "Roboto Flex preserves the intended variable typography"
            options: ["Roboto Flex", "Inter", "Noto Sans"]
            optionLabels: ["Roboto Flex", "Inter", "Noto Sans"]
            value: Appearance.interfaceFont
            onSelected: value => Appearance.setInterfaceFont(value)
        }
        SettingsChoice {
            width: parent.width
            title: "Base icon theme"
            subtitle: "Voidline folders and fallback apps are layered over this theme"
            options: ["Papirus-Dark", "Papirus", "Adwaita"]
            optionLabels: ["Papirus Dark", "Papirus", "Adwaita"]
            value: Appearance.iconTheme
            onSelected: value => {
                Appearance.setIconTheme(value)
                SystemSettingsService.setIconTheme(value)
            }
        }
        SettingsChoice {
            width: parent.width
            title: "Cursor theme"
            subtitle: "The selected theme is applied to the desktop session"
            options: ["Bibata-Modern-Classic", "Bibata-Modern-Ice", "Adwaita"]
            optionLabels: ["Bibata", "Bibata Ice", "Adwaita"]
            value: Appearance.cursorTheme
            onSelected: value => {
                Appearance.setCursorTheme(value)
                SystemSettingsService.setCursorTheme(value)
            }
        }
    }

    SettingsSection {
        title: "Bar and panels"
        subtitle: "Bar style, position, and what lives in the bar"
        icon: "dock_to_bottom"
        iconContainerColor: Theme.secondaryContainer
        iconColor: Theme.secondary

        ShellLayoutPreview {
            width: parent.width
            barPosition: Appearance.requestedBarPosition
            clockStyle: Appearance.clockStyle
            workspacePlacement: Appearance.workspacePlacement
            musicPlacement: Appearance.musicPlacement
        }

        SettingsChoice {
            width: parent.width
            title: "Bar style"
            subtitle: Appearance.barStyle === "frame"
                ? "Connected bar with a screen frame; panels attach to it"
                : "Panels open as floating cards"
            options: Appearance.barStyles
            optionLabels: ["Frame", "Pills", "Floating", "Minimal", "Taskbar"]
            maxColumns: 5
            value: Appearance.pendingBarStyle
            onSelected: value => Appearance.setBarStyle(value)
        }
        SettingsToggle {
            width: parent.width
            visible: Appearance.pendingBarStyle === "taskbar"
            icon: "vertical_align_bottom"
            title: "Auto-hide taskbar"
            subtitle: "Slide the taskbar away until the pointer touches the bottom edge"
            checked: Appearance.taskbarAutoHide
            onToggled: value => Appearance.setTaskbarAutoHide(value)
        }
        SettingsChoice {
            width: parent.width
            // The taskbar always sits at the bottom, so the edge choice is hidden.
            visible: Appearance.pendingBarStyle !== "taskbar"
            title: "Bar position"
            subtitle: Appearance.barTransitioning ? "Moving the bar…"
                : "Optimized layouts are used on every edge"
            options: ["top", "bottom", "left", "right"]
            optionLabels: ["Top", "Bottom", "Left", "Right"]
            value: Appearance.requestedBarPosition
            onSelected: value => Appearance.setBarPosition(value)
        }
        SettingsChoice {
            width: parent.width
            title: "Workspace indicator"
            subtitle: "Choose which bar group owns workspace navigation"
            options: ["clock", "center", "action"]
            optionLabels: ["Clock", "Center", "Actions"]
            value: Appearance.workspacePlacement
            onSelected: value => Appearance.setWorkspacePlacement(value)
        }
        SettingsChoice {
            width: parent.width
            title: "Music widget"
            subtitle: "Place playback controls where they stay useful"
            options: ["bar", "clock", "action", "hidden"]
            optionLabels: ["Bar", "Clock", "Actions", "Hidden"]
            value: Appearance.musicPlacement
            onSelected: value => Appearance.setMusicPlacement(value)
        }
        ClockStylePicker {
            width: parent.width
            title: "Clock design"
            subtitle: "Preview the date and time hierarchy before applying it"
            options: ["split", "compact", "stacked", "minimal"]
            optionLabels: ["Clock with date", "Compact digital", "Stacked", "Minimal"]
            value: Appearance.clockStyle
            onSelected: value => Appearance.setClockStyle(value)
        }
        SettingsChoice {
            width: parent.width
            title: "Clock font"
            subtitle: "Clock typography can differ from the interface"
            options: ["Roboto Flex", "Inter", "monospace"]
            optionLabels: ["Roboto", "Inter", "Mono"]
            value: Appearance.clockFont
            onSelected: value => Appearance.setClockFont(value)
        }
    }

    SettingsSection {
        title: "Windows"
        subtitle: "Hyprland appearance changes are applied immediately"
        icon: "select_window"

        SettingsSlider {
            width: parent.width
            title: "Border size"; subtitle: "Width around tiled and floating windows"
            icon: "border_style"; from: 0; to: 16
            value: SystemSettingsService.borderSize; suffix: " px"
            onChanged: value => SystemSettingsService.updateValue(
                "borderSize", value, "general:border_size")
        }
        SettingsColor {
            width: parent.width
            title: "Active border color"; subtitle: "Primary gradient color"
            value: SystemSettingsService.activeBorderColor
            onChanged: value => SystemSettingsService.setActiveBorder(
                value, SystemSettingsService.activeBorderColor2,
                SystemSettingsService.activeBorderAngle,
                SystemSettingsService.activeBorderGradient)
        }
        SettingsToggle {
            width: parent.width
            icon: "gradient"
            title: "Gradient border"
            subtitle: "Blend a second color around the active window"
            checked: SystemSettingsService.activeBorderGradient
            onToggled: value => SystemSettingsService.setActiveBorder(
                SystemSettingsService.activeBorderColor,
                SystemSettingsService.activeBorderColor2,
                SystemSettingsService.activeBorderAngle, value)
        }
        SettingsColor {
            width: parent.width
            visible: SystemSettingsService.activeBorderGradient
            title: "Gradient end color"
            subtitle: "Secondary active-window border color"
            value: SystemSettingsService.activeBorderColor2
            onChanged: value => SystemSettingsService.setActiveBorder(
                SystemSettingsService.activeBorderColor, value,
                SystemSettingsService.activeBorderAngle, true)
        }
        SettingsSlider {
            width: parent.width
            visible: SystemSettingsService.activeBorderGradient
            title: "Gradient angle"
            subtitle: "Direction of the active-window color blend"
            icon: "rotate_right"
            from: 0; to: 360; step: 5
            value: SystemSettingsService.activeBorderAngle
            suffix: "°"
            onChanged: value => SystemSettingsService.setActiveBorder(
                SystemSettingsService.activeBorderColor,
                SystemSettingsService.activeBorderColor2, value, true)
        }
        SettingsColor {
            width: parent.width
            title: "Inactive border color"; subtitle: "Hyprland rgba() color"
            value: SystemSettingsService.inactiveBorderColor
            onChanged: value => SystemSettingsService.updateValue(
                "inactiveBorderColor", value, "general:col.inactive_border")
        }
        SettingsSlider {
            width: parent.width
            title: "Active window opacity"; icon: "opacity"
            from: 60; to: 100; value: SystemSettingsService.activeOpacity * 100; suffix: "%"
            onChanged: value => SystemSettingsService.updateValue(
                "activeOpacity", value / 100, "decoration:active_opacity")
        }
        SettingsSlider {
            width: parent.width
            title: "Inactive window opacity"; icon: "opacity"
            from: 50; to: 100; value: SystemSettingsService.inactiveOpacity * 100; suffix: "%"
            onChanged: value => SystemSettingsService.updateValue(
                "inactiveOpacity", value / 100, "decoration:inactive_opacity")
        }
        SettingsSlider {
            width: parent.width
            title: "Window rounding"; icon: "rounded_corner"
            from: 0; to: 36; value: SystemSettingsService.windowRounding; suffix: " px"
            onChanged: value => SystemSettingsService.updateValue(
                "windowRounding", value, "decoration:rounding")
        }
        SettingsSlider {
            width: parent.width
            title: "Window gaps"; subtitle: "Space between neighboring windows"
            icon: "space_bar"; from: 0; to: 32
            value: SystemSettingsService.innerGaps; suffix: " px"
            onChanged: value => SystemSettingsService.updateValue(
                "innerGaps", value, "general:gaps_in")
        }
        SettingsSlider {
            width: parent.width
            title: "Workspace outer gaps"; icon: "padding"
            from: 0; to: 48; value: SystemSettingsService.outerGaps; suffix: " px"
            onChanged: value => SystemSettingsService.updateValue(
                "outerGaps", value, "general:gaps_out")
        }
    }

    SettingsSection {
        title: "Shadows and blur"
        subtitle: "Tune depth without editing compositor configuration"
        icon: "blur_medium"
        iconContainerColor: Theme.tertiaryContainer
        iconColor: Theme.tertiary

        SettingsToggle {
            width: parent.width
            icon: "filter_hdr"; title: "Window shadows"
            subtitle: "Draw soft depth behind windows"
            checked: SystemSettingsService.shadowsEnabled
            onToggled: value => SystemSettingsService.updateValue(
                "shadowsEnabled", value, "decoration:shadow:enabled")
        }
        SettingsSlider {
            width: parent.width
            title: "Shadow size"; icon: "shadow"
            from: 0; to: 64; value: SystemSettingsService.shadowSize; suffix: " px"
            enabled: SystemSettingsService.shadowsEnabled
            onChanged: value => SystemSettingsService.updateValue(
                "shadowSize", value, "decoration:shadow:range")
        }
        SettingsSlider {
            width: parent.width
            title: "Shadow strength"; icon: "contrast"
            from: 1; to: 4; value: SystemSettingsService.shadowStrength
            enabled: SystemSettingsService.shadowsEnabled
            onChanged: value => SystemSettingsService.updateValue(
                "shadowStrength", value, "decoration:shadow:render_power")
        }
        SettingsSlider {
            width: parent.width
            title: "Shadow range"; subtitle: "Scale the shadow footprint"
            icon: "expand"; from: 0.4; to: 1.5; step: 0.05
            value: SystemSettingsService.shadowRange; suffix: "×"
            enabled: SystemSettingsService.shadowsEnabled
            onChanged: value => SystemSettingsService.updateValue(
                "shadowRange", value, "decoration:shadow:scale")
        }
        SettingsColor {
            width: parent.width
            title: "Shadow color"; subtitle: "Hyprland rgba() color"
            value: SystemSettingsService.shadowColor
            enabled: SystemSettingsService.shadowsEnabled
            onChanged: value => SystemSettingsService.updateValue(
                "shadowColor", value, "decoration:shadow:color")
        }
        SettingsSlider {
            width: parent.width
            title: "Blur strength"; icon: "blur_on"
            from: 1; to: 24; value: SystemSettingsService.blurStrength
            enabled: SystemSettingsService.blurEnabled
            onChanged: value => SystemSettingsService.updateValue(
                "blurStrength", value, "decoration:blur:size")
        }
        SettingsSlider {
            width: parent.width
            title: "Blur passes"; icon: "layers"
            from: 1; to: 6; value: SystemSettingsService.blurPasses
            enabled: SystemSettingsService.blurEnabled
            onChanged: value => SystemSettingsService.updateValue(
                "blurPasses", value, "decoration:blur:passes")
        }
        SettingsToggle {
            width: parent.width
            icon: "dialogs"; title: "Blur popups"
            subtitle: "Include menus and transient surfaces"
            checked: SystemSettingsService.blurPopups
            enabled: SystemSettingsService.blurEnabled
            onToggled: value => SystemSettingsService.updateValue(
                "blurPopups", value, "decoration:blur:popups")
        }
    }

    SettingsSection {
        title: "Animations"
        subtitle: "One preset keeps compositor motion internally consistent"
        icon: "animation"
        iconContainerColor: Theme.secondaryContainer
        iconColor: Theme.secondary

        SettingsChoice {
            width: parent.width
            title: "Animation preset"
            subtitle: "Changes apply immediately; Reduce motion still overrides shell transitions"
            options: ["off", "calm", "balanced", "expressive"]
            optionLabels: ["Off", "Calm", "Balanced", "Expressive"]
            value: SystemSettingsService.animationPreset
            onSelected: value => SystemSettingsService.setAnimationPreset(value)
        }
    }
}
