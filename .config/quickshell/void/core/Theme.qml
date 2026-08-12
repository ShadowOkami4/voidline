pragma Singleton

import Quickshell
import QtQuick

QtObject {
    id: root

    readonly property bool darkMode: Appearance.darkMode

    readonly property color defaultAccent: Appearance.accentColor
    readonly property color wallpaperSeed: pickWallpaperAccent(quantizer.colors)
    readonly property bool magicAccentAvailable: Appearance.magicColors && quantizer.colors.length > 0

    // Magic Colors now produces a complete tonal scheme. Neutrals carry only
    // a quiet trace of wallpaper hue while accents deliberately cap chroma,
    // keeping text contrast calm and avoiding neon-looking containers.
    readonly property color background: magicAccentAvailable
        ? neutralTone(wallpaperSeed, darkMode ? 0.045 : 0.985, 0.07)
        : (darkMode ? "#141218" : "#FFFBFE")
    // Connected shell surfaces stay opaque. Their shared colour makes the bar,
    // frame joins, and attached panels read as one uninterrupted shape.
    readonly property color panel: magicAccentAvailable
        ? neutralTone(wallpaperSeed, darkMode ? 0.095 : 0.95, 0.085)
        : (darkMode ? "#211F26" : "#F3EDF7")
    readonly property color panelRaised: magicAccentAvailable
        ? neutralTone(wallpaperSeed, darkMode ? 0.145 : 0.91, 0.095)
        : (darkMode ? "#2B2930" : "#ECE6F0")
    readonly property color surface: panelRaised
    readonly property color surfaceHover: magicAccentAvailable
        ? neutralTone(wallpaperSeed, darkMode ? 0.225 : 0.84, 0.11)
        : (darkMode ? "#36333B" : "#E7E0EC")
    readonly property color surfaceLow: magicAccentAvailable
        ? neutralTone(wallpaperSeed, darkMode ? 0.075 : 0.97, 0.065)
        : (darkMode ? "#1D1B20" : "#F7F2FA")
    readonly property color surfaceHigh: magicAccentAvailable
        ? neutralTone(wallpaperSeed, darkMode ? 0.235 : 0.83, 0.115)
        : (darkMode ? "#36333A" : "#E6E0E9")
    // Shared application/panel group surfaces. These sit between the panel
    // canvas and interactive highlights, avoiding both black list wells and
    // a stack of competing outlined rectangles.
    readonly property color groupSurface: magicAccentAvailable
        ? neutralTone(wallpaperSeed, darkMode ? 0.155 : 0.925, 0.085)
        : (darkMode ? "#252229" : "#F3EDF7")
    readonly property color groupSurfaceRaised: magicAccentAvailable
        ? neutralTone(wallpaperSeed, darkMode ? 0.205 : 0.875, 0.105)
        : (darkMode ? "#302D34" : "#EAE4EE")
    readonly property color text: magicAccentAvailable
        ? neutralTone(wallpaperSeed, darkMode ? 0.91 : 0.11, 0.055)
        : (darkMode ? "#E6E1E5" : "#1D1B20")
    readonly property color textMuted: magicAccentAvailable
        ? neutralTone(wallpaperSeed, darkMode ? 0.72 : 0.32, 0.075)
        : (darkMode ? "#CAC4D0" : "#49454F")
    readonly property color outline: magicAccentAvailable
        ? neutralTone(wallpaperSeed,
            Appearance.highContrast ? (darkMode ? 0.76 : 0.28)
                : (darkMode ? 0.57 : 0.46), 0.12)
        : (darkMode ? "#77727D" : "#87818C")
    readonly property color outlineSoft: magicAccentAvailable
        ? neutralTone(wallpaperSeed,
            Appearance.highContrast ? (darkMode ? 0.52 : 0.50)
                : (darkMode ? 0.29 : 0.78), 0.10)
        : (darkMode ? "#454149" : "#CEC8D1")
    readonly property color divider: withAlpha(outlineSoft,
        Appearance.highContrast ? 0.78 : (darkMode ? 0.46 : 0.58))
    readonly property color danger: darkMode ? "#E6B8B5" : "#A93F3B"
    readonly property color dangerContainer: magicAccentAvailable
        ? shiftedTone(wallpaperSeed, -0.025, darkMode ? 0.22 : 0.91, 0.20)
        : (darkMode ? "#5C3535" : "#FFDAD6")
    readonly property color shadow: "#000000"

    readonly property color accent: magicAccentAvailable
        ? chromaTone(wallpaperSeed, darkMode ? 0.73 : 0.40, 0.32)
        : defaultAccent
    readonly property color accentStrong: magicAccentAvailable
        ? chromaTone(wallpaperSeed, darkMode ? 0.65 : 0.34, 0.36)
        : (darkMode ? "#B69DF8" : "#57408F")
    readonly property color accentContainer: magicAccentAvailable
        ? chromaTone(wallpaperSeed, darkMode ? 0.255 : 0.91, 0.20)
        : (darkMode ? "#4F378B" : "#EADDFF")
    readonly property color secondary: magicAccentAvailable
        ? shiftedTone(wallpaperSeed, 0.055, darkMode ? 0.71 : 0.42, 0.25)
        : (darkMode ? "#CCC2DC" : "#625B71")
    readonly property color secondaryContainer: magicAccentAvailable
        ? shiftedTone(wallpaperSeed, 0.055, darkMode ? 0.245 : 0.90, 0.16)
        : (darkMode ? "#4A4458" : "#E8DEF8")
    readonly property color tertiary: magicAccentAvailable
        ? shiftedTone(wallpaperSeed, -0.075, darkMode ? 0.72 : 0.42, 0.25)
        : (darkMode ? "#EFB8C8" : "#7D5260")
    readonly property color tertiaryContainer: magicAccentAvailable
        ? shiftedTone(wallpaperSeed, -0.075, darkMode ? 0.25 : 0.90, 0.16)
        : (darkMode ? "#633B48" : "#FFD8E4")
    readonly property color surfaceActive: accentContainer
    readonly property color accentInk: darkMode ? "#211F26" : "#FFFFFF"

    readonly property string fontFamily: Appearance.interfaceFont
    readonly property string symbolFont: "Material Symbols Rounded"

    readonly property real densityScale: Appearance.uiScale
        * Math.max(1, Appearance.textScale * 0.94)
        * (Appearance.uiDensity === "compact" ? 0.92
            : (Appearance.uiDensity === "spacious" ? 1.08 : 1.0))
    readonly property int barHeight: Math.round(42 * densityScale)
    readonly property int sideBarWidth: Math.round(58 * densityScale)
    // One UI-inspired shape scale. Containers keep a clear hierarchy instead
    // of choosing a new radius for every component or interaction state.
    // Compatibility aliases. New components use Metrics so geometry can be
    // changed independently from the wallpaper color system.
    readonly property int radiusSmall: Metrics.radiusS
    readonly property int radiusMedium: Metrics.radiusM
    readonly property int radiusLarge: Metrics.radiusL
    readonly property int radiusExtraLarge: Metrics.radiusXL
    readonly property int panelRadius: Metrics.panelRadius
    readonly property int cardRadius: Metrics.cardRadius
    readonly property int pillRadius: 999
    readonly property int concaveRadius: Metrics.concaveRadius
    readonly property int screenFrameWidth: Metrics.screenFrame
    readonly property int panelPadding: Metrics.panelPadding
    readonly property int gap: Metrics.spaceS

    property var quantizer: ColorQuantizer {
        source: Appearance.magicColors && Appearance.wallpaperPath.length > 0
            ? "file://" + Appearance.wallpaperPath
            : ""
        depth: 3
        rescaleSize: 64
    }

    function colorStats(colorValue) {
        const red = colorValue.r
        const green = colorValue.g
        const blue = colorValue.b
        const maximum = Math.max(red, green, blue)
        const minimum = Math.min(red, green, blue)
        const delta = maximum - minimum
        const lightness = (maximum + minimum) / 2
        let hue = 0

        if (delta > 0.0001) {
            if (maximum === red)
                hue = ((green - blue) / delta) % 6
            else if (maximum === green)
                hue = (blue - red) / delta + 2
            else
                hue = (red - green) / delta + 4
            hue = ((hue * 60) + 360) % 360 / 360
        }

        const saturation = delta === 0 ? 0 : delta / (1 - Math.abs(2 * lightness - 1))
        return { hue: hue, saturation: saturation, lightness: lightness }
    }

    function withAlpha(colorValue, alphaValue) {
        return Qt.rgba(colorValue.r, colorValue.g, colorValue.b, alphaValue)
    }

    function pickWallpaperAccent(colors) {
        if (!colors || colors.length === 0)
            return defaultAccent

        let best = colors[0]
        let bestScore = -1
        for (let i = 0; i < colors.length; ++i) {
            const stats = colorStats(colors[i])
            const usableLightness = 1 - Math.min(1, Math.abs(stats.lightness - 0.52) * 1.5)
            const score = stats.saturation * 0.8 + usableLightness * 0.2
            if (score > bestScore) {
                bestScore = score
                best = colors[i]
            }
        }
        return best
    }

    function tone(colorValue, lightness) {
        return chromaTone(colorValue, lightness, 0.5)
    }

    function neutralTone(colorValue, lightness, saturation) {
        const stats = colorStats(colorValue)
        return Qt.hsla(stats.hue, saturation, lightness, 1)
    }

    function chromaTone(colorValue, lightness, maximumSaturation) {
        const stats = colorStats(colorValue)
        const saturation = Math.max(0.12,
            Math.min(maximumSaturation, stats.saturation * 0.62))
        return Qt.hsla(stats.hue, saturation, lightness, 1)
    }

    function shiftedTone(colorValue, hueShift, lightness, maximumSaturation) {
        const stats = colorStats(colorValue)
        const hue = (stats.hue + hueShift + 1) % 1
        const saturation = Math.max(0.10,
            Math.min(maximumSaturation || 0.34, stats.saturation * 0.52))
        return Qt.hsla(hue, saturation, lightness, 1)
    }
}
