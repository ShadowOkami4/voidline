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

    // One file serves three Settings pages: "appearance" (wallpaper and
    // style), "desktop" (bar and clock), and "windows" (borders and effects).
    property string page: "appearance"

    // ---------------- Wallpaper & style ----------------
    SettingsSection {
        visible: root.page === "appearance"
        fullWidth: true
        title: "Wallpaper"
        icon: "wallpaper"

        // Current wallpaper with the shell's live palette underneath.
        Item {
            width: parent.width
            height: Math.round(196 * Metrics.scale)

            RoundedImage {
                id: currentWallpaper
                x: Metrics.spaceXL
                width: Math.round(height * 16 / 10)
                height: parent.height - Metrics.spaceS
                radius: Metrics.radiusXL
                source: WallpaperService.currentPath.length > 0
                    ? "file://" + WallpaperService.currentPath : ""
                fallbackIcon: "wallpaper"
            }

            ColumnLayout {
                anchors {
                    left: currentWallpaper.right
                    leftMargin: Metrics.spaceXL
                    right: parent.right
                    rightMargin: Metrics.spaceXL
                    verticalCenter: currentWallpaper.verticalCenter
                }
                spacing: Metrics.spaceS

                Text {
                    Layout.fillWidth: true
                    text: WallpaperService.currentPath.length > 0
                        ? WallpaperService.currentPath.split("/").pop() : "No wallpaper"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.appTextTitle
                    elide: Text.ElideMiddle
                }
                Row {
                    spacing: Metrics.spaceXS
                    Repeater {
                        model: [Theme.accent, Theme.secondary, Theme.tertiary, Theme.accentContainer]
                        Rectangle {
                            required property color modelData
                            width: Math.round(28 * Metrics.scale)
                            height: width
                            radius: width / 2
                            color: modelData
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: WallpaperService.wallpapers.length + " wallpapers in the library"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Metrics.appTextSupporting
                }
            }
        }

        GridView {
            id: wallpaperGrid
            property int columns: width >= 1000 ? 5 : (width >= 640 ? 4 : 3)
            x: Metrics.spaceXL - Metrics.spaceXS
            width: parent.width - (Metrics.spaceXL - Metrics.spaceXS) * 2
            height: Math.ceil(WallpaperService.wallpapers.length / columns) * cellHeight
            model: WallpaperService.wallpapers
            cellWidth: width / columns
            cellHeight: Math.round(cellWidth * 10 / 16)
            interactive: false

            delegate: Item {
                id: wallpaperCell
                required property var modelData
                readonly property bool current: WallpaperService.currentPath === modelData.path
                width: GridView.view.cellWidth
                height: GridView.view.cellHeight

                RoundedImage {
                    anchors { fill: parent; margins: Metrics.spaceXS }
                    source: "file://" + wallpaperCell.modelData.path
                    // Selected wallpaper morphs to a tighter shape.
                    radius: wallpaperCell.current ? Metrics.radiusM : Metrics.radiusL
                    fallbackIcon: "broken_image"
                }
                Rectangle {
                    anchors { fill: parent; margins: Metrics.spaceXS }
                    radius: wallpaperCell.current ? Metrics.radiusM : Metrics.radiusL
                    color: "transparent"
                    border.width: wallpaperCell.current ? 3 : 0
                    border.color: Theme.accent
                }
                Rectangle {
                    visible: wallpaperCell.current
                    anchors { right: parent.right; bottom: parent.bottom; margins: Metrics.spaceM }
                    width: Math.round(26 * Metrics.scale)
                    height: width
                    radius: width / 2
                    color: Theme.accent
                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "check"
                        fill: 1
                        size: Math.round(18 * Metrics.scale)
                        color: Theme.accentInk
                    }
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: WallpaperService.applyWallpaper(wallpaperCell.modelData.path)
                }
            }
        }

        SettingsAction {
            width: parent.width
            icon: WallpaperService.loading ? "progress_activity" : "refresh"
            title: "Reload wallpaper library"
            onClicked: WallpaperService.refresh()
        }
    }

    SettingsSection {
        visible: root.page === "appearance"
        title: "Colors"
        icon: "palette"

        SettingsChoice {
            width: parent.width
            title: "Theme"
            options: ["light", "dark", "auto"]
            optionLabels: ["Light", "Dark", "Automatic"]
            value: Appearance.colorMode
            onSelected: value => Appearance.setColorMode(value)
        }
        SettingsToggle {
            width: parent.width
            icon: "auto_awesome"
            title: "Colors from wallpaper"
            subtitle: "Build the palette from the current wallpaper"
            checked: Appearance.magicColors
            onToggled: value => Appearance.setMagicColors(value)
        }
        SettingsChoice {
            width: parent.width
            maxColumns: 5
            // Only relevant when the palette is not taken from the wallpaper.
            visible: !Appearance.magicColors
            title: "Accent color"
            options: ["#8FB8AC", "#9CAEDB", "#C3A5C9", "#D0AD87", "#A9BE82"]
            optionLabels: ["Sage", "Sky", "Orchid", "Sand", "Leaf"]
            value: Appearance.accentColor
            onSelected: value => Appearance.setAccentColor(value)
        }
    }

    SettingsSection {
        visible: root.page === "appearance"
        title: "Fonts and icons"
        icon: "font_download"

        SettingsChoice {
            width: parent.width
            title: "Interface font"
            options: ["Roboto Flex", "Inter", "Noto Sans"]
            optionLabels: ["Roboto Flex", "Inter", "Noto Sans"]
            value: Appearance.interfaceFont
            onSelected: value => Appearance.setInterfaceFont(value)
        }
        SettingsChoice {
            width: parent.width
            title: "Icon theme"
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
            title: "Cursor"
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
        visible: root.page === "appearance"
        title: "Size"
        icon: "format_size"

        SettingsSlider {
            width: parent.width
            title: "Interface size"
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
            title: "Spacing"
            options: ["compact", "comfortable", "spacious"]
            optionLabels: ["Compact", "Comfortable", "Spacious"]
            value: Appearance.uiDensity
            onSelected: value => Appearance.setUiDensity(value)
        }
    }

    // ---------------- Bar & desktop ----------------
    SettingsSection {
        visible: root.page === "desktop"
        fullWidth: true
        title: "Bar"
        icon: "dock_to_bottom"

        ShellLayoutPreview {
            x: Metrics.spaceXL
            width: parent.width - Metrics.spaceXL * 2
            barPosition: Appearance.requestedBarPosition
            clockStyle: Appearance.clockStyle
            workspacePlacement: Appearance.workspacePlacement
            musicPlacement: Appearance.musicPlacement
        }
        SettingsChoice {
            width: parent.width
            title: "Style"
            subtitle: Appearance.pendingBarStyle === "frame"
                ? "Panels attach to the bar and screen frame"
                : "Panels open as floating cards"
            options: Appearance.barStyles
            optionLabels: ["Frame", "Pills", "Floating", "Minimal", "Taskbar"]
            maxColumns: 5
            value: Appearance.pendingBarStyle
            onSelected: value => Appearance.setBarStyle(value)
        }
        SettingsChoice {
            width: parent.width
            // The taskbar always sits at the bottom, so the edge choice is hidden.
            visible: Appearance.pendingBarStyle !== "taskbar"
            title: "Position"
            subtitle: Appearance.barTransitioning ? "Moving the bar…" : ""
            options: ["top", "bottom", "left", "right"]
            optionLabels: ["Top", "Bottom", "Left", "Right"]
            value: Appearance.requestedBarPosition
            onSelected: value => Appearance.setBarPosition(value)
        }
        SettingsToggle {
            width: parent.width
            visible: Appearance.pendingBarStyle === "taskbar"
            icon: "vertical_align_bottom"
            title: "Auto-hide taskbar"
            subtitle: "Show it when the pointer touches the bottom edge"
            checked: Appearance.taskbarAutoHide
            onToggled: value => Appearance.setTaskbarAutoHide(value)
        }
    }

    SettingsSection {
        visible: root.page === "desktop"
        title: "In the bar"
        icon: "view_week"

        SettingsChoice {
            width: parent.width
            title: "Workspaces"
            options: ["clock", "center", "action"]
            optionLabels: ["Next to clock", "Center", "Next to status"]
            value: Appearance.workspacePlacement
            onSelected: value => Appearance.setWorkspacePlacement(value)
        }
        SettingsChoice {
            width: parent.width
            title: "Media controls"
            options: ["bar", "clock", "action", "hidden"]
            optionLabels: ["Bar", "Clock", "Quick Settings", "Off"]
            value: Appearance.musicPlacement
            onSelected: value => Appearance.setMusicPlacement(value)
        }
    }

    SettingsSection {
        visible: root.page === "desktop"
        fullWidth: true
        title: "Clock"
        icon: "schedule"

        ClockStylePicker {
            width: parent.width
            title: "Clock style"
            maxColumns: 4
            options: ["split", "compact", "stacked", "minimal"]
            optionLabels: ["Clock with date", "Compact", "Stacked", "Minimal"]
            value: Appearance.clockStyle
            onSelected: value => Appearance.setClockStyle(value)
        }
        SettingsChoice {
            width: parent.width
            title: "Clock font"
            options: ["Roboto Flex", "Inter", "monospace"]
            optionLabels: ["Roboto", "Inter", "Mono"]
            value: Appearance.clockFont
            onSelected: value => Appearance.setClockFont(value)
        }
    }

    // ---------------- Windows & effects ----------------
    SettingsSection {
        visible: root.page === "windows"
        title: "Layout"
        icon: "select_window"

        SettingsSlider {
            width: parent.width
            title: "Corner rounding"; icon: "rounded_corner"
            from: 0; to: 36; value: SystemSettingsService.windowRounding; suffix: " px"
            onChanged: value => SystemSettingsService.updateValue(
                "windowRounding", value, "decoration:rounding")
        }
        SettingsSlider {
            width: parent.width
            title: "Gaps between windows"; icon: "space_bar"
            from: 0; to: 32; value: SystemSettingsService.innerGaps; suffix: " px"
            onChanged: value => SystemSettingsService.updateValue(
                "innerGaps", value, "general:gaps_in")
        }
        SettingsSlider {
            width: parent.width
            title: "Gaps to screen edge"; icon: "padding"
            from: 0; to: 48; value: SystemSettingsService.outerGaps; suffix: " px"
            onChanged: value => SystemSettingsService.updateValue(
                "outerGaps", value, "general:gaps_out")
        }
    }

    SettingsSection {
        visible: root.page === "windows"
        title: "Borders"
        icon: "border_style"

        SettingsSlider {
            width: parent.width
            title: "Border width"; icon: "border_style"
            from: 0; to: 16; value: SystemSettingsService.borderSize; suffix: " px"
            onChanged: value => SystemSettingsService.updateValue(
                "borderSize", value, "general:border_size")
        }
        SettingsColor {
            width: parent.width
            title: "Focused window"
            value: SystemSettingsService.activeBorderColor
            onChanged: value => SystemSettingsService.setActiveBorder(
                value, SystemSettingsService.activeBorderColor2,
                SystemSettingsService.activeBorderAngle,
                SystemSettingsService.activeBorderGradient)
        }
        SettingsColor {
            width: parent.width
            title: "Other windows"
            value: SystemSettingsService.inactiveBorderColor
            onChanged: value => SystemSettingsService.updateValue(
                "inactiveBorderColor", value, "general:col.inactive_border")
        }
        SettingsToggle {
            width: parent.width
            icon: "gradient"
            title: "Gradient border"
            subtitle: "Blend a second color around the focused window"
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
            value: SystemSettingsService.activeBorderColor2
            onChanged: value => SystemSettingsService.setActiveBorder(
                SystemSettingsService.activeBorderColor, value,
                SystemSettingsService.activeBorderAngle, true)
        }
        SettingsSlider {
            width: parent.width
            visible: SystemSettingsService.activeBorderGradient
            title: "Gradient angle"; icon: "rotate_right"
            from: 0; to: 360; step: 5
            value: SystemSettingsService.activeBorderAngle
            suffix: "°"
            onChanged: value => SystemSettingsService.setActiveBorder(
                SystemSettingsService.activeBorderColor,
                SystemSettingsService.activeBorderColor2, value, true)
        }
    }

    SettingsSection {
        visible: root.page === "windows"
        title: "Transparency"
        icon: "opacity"

        SettingsSlider {
            width: parent.width
            title: "Focused window"; icon: "opacity"
            from: 60; to: 100; value: SystemSettingsService.activeOpacity * 100; suffix: "%"
            onChanged: value => SystemSettingsService.updateValue(
                "activeOpacity", value / 100, "decoration:active_opacity")
        }
        SettingsSlider {
            width: parent.width
            title: "Other windows"; icon: "opacity"
            from: 50; to: 100; value: SystemSettingsService.inactiveOpacity * 100; suffix: "%"
            onChanged: value => SystemSettingsService.updateValue(
                "inactiveOpacity", value / 100, "decoration:inactive_opacity")
        }
    }

    SettingsSection {
        visible: root.page === "windows"
        title: "Shadows"
        icon: "shadow"

        SettingsToggle {
            width: parent.width
            icon: "shadow"; title: "Window shadows"
            checked: SystemSettingsService.shadowsEnabled
            onToggled: value => SystemSettingsService.updateValue(
                "shadowsEnabled", value, "decoration:shadow:enabled")
        }
        SettingsSlider {
            width: parent.width
            visible: SystemSettingsService.shadowsEnabled
            title: "Size"; icon: "blur_circular"
            from: 0; to: 64; value: SystemSettingsService.shadowSize; suffix: " px"
            onChanged: value => SystemSettingsService.updateValue(
                "shadowSize", value, "decoration:shadow:range")
        }
        SettingsSlider {
            width: parent.width
            visible: SystemSettingsService.shadowsEnabled
            title: "Strength"; icon: "contrast"
            from: 1; to: 4; value: SystemSettingsService.shadowStrength
            onChanged: value => SystemSettingsService.updateValue(
                "shadowStrength", value, "decoration:shadow:render_power")
        }
        SettingsSlider {
            width: parent.width
            visible: SystemSettingsService.shadowsEnabled
            title: "Spread"; icon: "expand"
            from: 0.4; to: 1.5; step: 0.05
            value: SystemSettingsService.shadowRange; suffix: "×"
            onChanged: value => SystemSettingsService.updateValue(
                "shadowRange", value, "decoration:shadow:scale")
        }
        SettingsColor {
            width: parent.width
            visible: SystemSettingsService.shadowsEnabled
            title: "Shadow color"
            value: SystemSettingsService.shadowColor
            onChanged: value => SystemSettingsService.updateValue(
                "shadowColor", value, "decoration:shadow:color")
        }
    }

    SettingsSection {
        visible: root.page === "windows"
        title: "Blur"
        icon: "blur_on"

        SettingsToggle {
            width: parent.width
            icon: "blur_on"; title: "Background blur"
            subtitle: "Blur what is behind transparent windows"
            checked: SystemSettingsService.blurEnabled
            onToggled: value => SystemSettingsService.updateValue(
                "blurEnabled", value, "decoration:blur:enabled")
        }
        SettingsSlider {
            width: parent.width
            visible: SystemSettingsService.blurEnabled
            title: "Strength"; icon: "blur_medium"
            from: 1; to: 24; value: SystemSettingsService.blurStrength
            onChanged: value => SystemSettingsService.updateValue(
                "blurStrength", value, "decoration:blur:size")
        }
        SettingsSlider {
            width: parent.width
            visible: SystemSettingsService.blurEnabled
            title: "Quality"; icon: "layers"
            from: 1; to: 6; value: SystemSettingsService.blurPasses
            onChanged: value => SystemSettingsService.updateValue(
                "blurPasses", value, "decoration:blur:passes")
        }
        SettingsToggle {
            width: parent.width
            visible: SystemSettingsService.blurEnabled
            icon: "dialogs"; title: "Blur menus and popups"
            checked: SystemSettingsService.blurPopups
            onToggled: value => SystemSettingsService.updateValue(
                "blurPopups", value, "decoration:blur:popups")
        }
    }

    SettingsSection {
        visible: root.page === "windows"
        title: "Animations"
        icon: "animation"

        SettingsChoice {
            width: parent.width
            title: "Window animations"
            subtitle: "Reduce motion in Accessibility still shortens shell transitions"
            options: ["off", "calm", "balanced", "expressive"]
            optionLabels: ["Off", "Calm", "Balanced", "Expressive"]
            value: SystemSettingsService.animationPreset
            onSelected: value => SystemSettingsService.setAnimationPreset(value)
        }
    }
}
