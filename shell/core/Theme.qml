pragma Singleton

import Quickshell
import QtQuick

// Material 3 Expressive tokens: colour roles, shape scale, type scale.
// Colours are derived from one seed (the accent, or the wallpaper when
// "wallpaperColors" is on) with a small HSL tonal generator, so the shell
// needs no external palette tool.
Singleton {
    id: root

    readonly property bool dark: Config.dark
    readonly property color seed: (Config.wallpaperColors && Config.wallpaper.length > 0 && quantizer.colors.length > 0)
        ? pickSeed(quantizer.colors) : Config.accent

    // --- colour roles -----------------------------------------------------
    readonly property color primary: tone(seed, 0, dark ? 0.76 : 0.42, 0.70)
    readonly property color inkOnPrimary: tone(seed, 0, dark ? 0.16 : 0.99, 0.45)
    readonly property color primaryContainer: tone(seed, 0, dark ? 0.30 : 0.90, 0.48)
    readonly property color inkOnPrimaryContainer: tone(seed, 0, dark ? 0.92 : 0.16, 0.60)
    readonly property color secondary: tone(seed, 0.04, dark ? 0.78 : 0.40, 0.26)
    readonly property color secondaryContainer: tone(seed, 0.04, dark ? 0.26 : 0.90, 0.22)
    readonly property color inkOnSecondaryContainer: tone(seed, 0.04, dark ? 0.90 : 0.16, 0.30)
    readonly property color tertiary: tone(seed, 0.16, dark ? 0.78 : 0.42, 0.48)
    readonly property color tertiaryContainer: tone(seed, 0.16, dark ? 0.28 : 0.90, 0.36)
    readonly property color inkOnTertiaryContainer: tone(seed, 0.16, dark ? 0.92 : 0.16, 0.45)
    readonly property color error: dark ? "#FFB4AB" : "#BA1A1A"
    readonly property color errorContainer: dark ? "#93000A" : "#FFDAD6"
    readonly property color inkOnErrorContainer: dark ? "#FFDAD6" : "#410002"

    readonly property color surface: tone(seed, 0, dark ? 0.065 : 0.975, 0.10)
    readonly property color surfaceContainerLow: tone(seed, 0, dark ? 0.095 : 0.955, 0.10)
    readonly property color surfaceContainer: tone(seed, 0, dark ? 0.125 : 0.935, 0.10)
    readonly property color surfaceContainerHigh: tone(seed, 0, dark ? 0.165 : 0.905, 0.10)
    readonly property color surfaceContainerHighest: tone(seed, 0, dark ? 0.21 : 0.875, 0.10)
    readonly property color ink: Config.highContrast ? (dark ? "#FFFFFF" : "#000000") : tone(seed, 0, dark ? 0.92 : 0.10, 0.08)
    readonly property color inkMuted: Config.highContrast ? (dark ? "#E6E6E6" : "#1E1E1E") : tone(seed, 0, dark ? 0.74 : 0.30, 0.10)
    readonly property color outline: tone(seed, 0, dark ? 0.52 : 0.48, 0.08)
    readonly property color outlineVariant: Config.highContrast ? (dark ? "#B4B4B4" : "#4A4A4A") : tone(seed, 0, dark ? 0.26 : 0.80, 0.10)
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.32)
    readonly property color shadow: "#000000"

    // --- shape scale (M3 Expressive corner tokens) ------------------------
    readonly property int cornerXS: 4
    readonly property int cornerS: 8
    readonly property int cornerM: 12
    readonly property int cornerL: 16
    readonly property int cornerLInc: 20
    readonly property int cornerXL: 28
    readonly property int cornerXLInc: 32
    readonly property int cornerXXL: 48
    readonly property int cornerFull: 999

    // --- type --------------------------------------------------------------
    readonly property var families: Qt.fontFamilies()
    readonly property string font: Config.font.length > 0 && families.includes(Config.font) ? Config.font
        : families.includes("Roboto Flex") ? "Roboto Flex"
        : (families.includes("Roboto") ? "Roboto"
            : (families.includes("Inter") ? "Inter" : "Noto Sans"))
    readonly property string iconFont: families.includes("Material Symbols Rounded")
        ? "Material Symbols Rounded" : "Material Symbols Outlined"
    readonly property bool iconFontAvailable: families.includes("Material Symbols Rounded")
        || families.includes("Material Symbols Outlined")

    readonly property int textLabelS: 11
    readonly property int textLabel: 12
    readonly property int textBody: 14
    readonly property int textTitle: 16
    readonly property int textHeadline: 24
    readonly property int textDisplay: 44

    // --- wallpaper palette --------------------------------------------------
    property ColorQuantizer quantizer: ColorQuantizer {
        source: (Config.wallpaperColors && Config.wallpaper.length > 0) ? "file://" + Config.wallpaperPath : ""
        depth: 3
        rescaleSize: 64
    }

    function hsl(c) {
        const max = Math.max(c.r, c.g, c.b), min = Math.min(c.r, c.g, c.b), d = max - min
        const l = (max + min) / 2
        let h = 0
        if (d > 0.0001) {
            if (max === c.r) h = ((c.g - c.b) / d) % 6
            else if (max === c.g) h = (c.b - c.r) / d + 2
            else h = (c.r - c.g) / d + 4
            h = ((h * 60) + 360) % 360 / 360
        }
        return { h: h, s: d === 0 ? 0 : d / (1 - Math.abs(2 * l - 1)), l: l }
    }

    // Same hue family as the seed, at a fixed lightness, saturation scaled by
    // `chroma` (0..1) so a grey seed gives a grey theme.
    function tone(c, hueShift, lightness, chroma) {
        const v = hsl(c)
        return Qt.hsla((v.h + hueShift + 1) % 1, Math.min(1, v.s * chroma + (v.s > 0.05 ? chroma * 0.12 : 0)), lightness, 1)
    }

    function pickSeed(colors) {
        let best = colors[0], bestScore = -1
        for (let i = 0; i < colors.length; ++i) {
            const v = hsl(colors[i])
            const score = v.s * 0.8 + (1 - Math.min(1, Math.abs(v.l - 0.52) * 1.5)) * 0.2
            if (score > bestScore) { bestScore = score; best = colors[i] }
        }
        return best
    }

    // Colour families for icon containers: the same tone at different hues,
    // so a list of settings is colourful but still belongs to the palette.
    readonly property var hueShifts: [0, 0.14, 0.30, 0.52, 0.68, 0.84]
    function hueContainer(i) { return tone(seed, hueShifts[i % hueShifts.length], dark ? 0.30 : 0.86, 0.55) }
    function hueInk(i) { return tone(seed, hueShifts[i % hueShifts.length], dark ? 0.90 : 0.20, 0.65) }

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
}
