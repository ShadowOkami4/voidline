pragma Singleton

import Quickshell
import QtQuick

QtObject {
    id: root

    readonly property bool darkMode: Appearance.darkMode

    readonly property color defaultAccent: Appearance.accentColor
    readonly property color wallpaperSeed: pickWallpaperAccent(quantizer.colors)
    readonly property bool magicAccentAvailable: Appearance.magicColors && quantizer.colors.length > 0
    // Material 3 Expressive: every role is a tone of one seed colour. The
    // wallpaper seeds the scheme when Magic Colors is on; otherwise the chosen
    // accent does, so containers always belong to the same hue family as the
    // accent instead of falling back to an unrelated baseline palette.
    readonly property color seed: magicAccentAvailable ? wallpaperSeed : defaultAccent
    readonly property bool highContrast: Appearance.highContrast

    // Neutral surfaces carry a quiet trace of the seed hue. The container
    // ladder follows the M3 surface-container roles from lowest to highest.
    readonly property color background: neutralTone(seed, darkMode ? 0.045 : 0.985, 0.07)
    readonly property color surfaceContainerLowest: neutralTone(seed, darkMode ? 0.035 : 1.0, 0.06)
    readonly property color surfaceContainerLow: neutralTone(seed, darkMode ? 0.075 : 0.965, 0.065)
    readonly property color surfaceContainer: neutralTone(seed, darkMode ? 0.095 : 0.945, 0.085)
    readonly property color surfaceContainerHigh: neutralTone(seed, darkMode ? 0.145 : 0.915, 0.095)
    readonly property color surfaceContainerHighest: neutralTone(seed, darkMode ? 0.2 : 0.885, 0.105)
    readonly property color surfaceBright: neutralTone(seed, darkMode ? 0.24 : 0.985, 0.11)

    // Connected shell surfaces stay opaque. Their shared colour makes the bar,
    // frame joins, and attached panels read as one uninterrupted shape.
    readonly property color panel: surfaceContainer
    readonly property color panelRaised: surfaceContainerHigh
    readonly property color surface: panelRaised
    readonly property color surfaceHover: neutralTone(seed, darkMode ? 0.225 : 0.84, 0.11)
    readonly property color surfaceLow: surfaceContainerLow
    readonly property color surfaceHigh: neutralTone(seed, darkMode ? 0.235 : 0.83, 0.115)
    // Shared application/panel group surfaces. Segmented list groups use
    // these between the panel canvas and interactive highlights.
    readonly property color groupSurface: neutralTone(seed, darkMode ? 0.155 : 0.93, 0.085)
    readonly property color groupSurfaceRaised: neutralTone(seed, darkMode ? 0.205 : 0.875, 0.105)
    readonly property color text: neutralTone(seed, darkMode ? 0.91 : 0.11, 0.055)
    readonly property color textMuted: neutralTone(seed, darkMode ? 0.72 : 0.32, 0.075)
    readonly property color outline: neutralTone(seed,
        highContrast ? (darkMode ? 0.76 : 0.28) : (darkMode ? 0.57 : 0.46), 0.12)
    readonly property color outlineSoft: neutralTone(seed,
        highContrast ? (darkMode ? 0.52 : 0.50) : (darkMode ? 0.29 : 0.78), 0.10)
    readonly property color divider: withAlpha(outlineSoft,
        highContrast ? 0.78 : (darkMode ? 0.46 : 0.58))
    readonly property color danger: darkMode ? "#FFB4AB" : "#BA1A1A"
    readonly property color dangerInk: darkMode ? "#690005" : "#FFFFFF"
    readonly property color dangerContainer: darkMode ? "#93000A" : "#FFDAD6"
    readonly property color dangerContainerInk: darkMode ? "#FFDAD6" : "#410002"
    readonly property color shadow: "#000000"
    readonly property color scrim: withAlpha("#000000", darkMode ? 0.56 : 0.32)

    readonly property color accent: chromaTone(seed, darkMode ? 0.76 : 0.40, 0.42)
    readonly property color accentStrong: chromaTone(seed, darkMode ? 0.66 : 0.33, 0.46)
    readonly property color accentContainer: chromaTone(seed, darkMode ? 0.27 : 0.9, 0.3)
    readonly property color accentContainerInk: chromaTone(seed, darkMode ? 0.9 : 0.14, 0.34)
    readonly property color secondary: shiftedTone(seed, 0.04, darkMode ? 0.74 : 0.40, 0.26)
    readonly property color secondaryContainer: shiftedTone(seed, 0.04, darkMode ? 0.25 : 0.9, 0.2)
    readonly property color secondaryContainerInk: shiftedTone(seed, 0.04, darkMode ? 0.9 : 0.14, 0.26)
    readonly property color tertiary: shiftedTone(seed, -0.1, darkMode ? 0.76 : 0.40, 0.3)
    readonly property color tertiaryContainer: shiftedTone(seed, -0.1, darkMode ? 0.27 : 0.9, 0.24)
    readonly property color tertiaryContainerInk: shiftedTone(seed, -0.1, darkMode ? 0.9 : 0.14, 0.3)
    readonly property color surfaceActive: accentContainer
    // "On primary": readable content placed on an accent-filled shape.
    readonly property color accentInk: darkMode ? chromaTone(seed, 0.15, 0.36) : "#FFFFFF"

    // Material role aliases for new components; the Voidline names above stay
    // for existing callers.
    // ("on*" names are reserved for signal handlers in QML, so content colours
    // use the Voidline "*Ink" suffix instead.)
    readonly property color primary: accent
    readonly property color primaryContainer: accentContainer
    readonly property color outlineVariant: outlineSoft
    readonly property color error: danger
    readonly property color errorContainer: dangerContainer

    readonly property string fontFamily: Appearance.interfaceFont
    readonly property string symbolFont: "Material Symbols Rounded"

    readonly property real densityScale: Appearance.uiScale
        * Math.max(1, Appearance.textScale * 0.94)
        * (Appearance.uiDensity === "compact" ? 0.92
            : (Appearance.uiDensity === "spacious" ? 1.08 : 1.0))
    readonly property int barHeight: Math.round(42 * densityScale)
    readonly property int sideBarWidth: Math.round(58 * densityScale)
    readonly property int taskbarHeight: Math.round(64 * densityScale)
    // Bar-style geometry shared by the bar and every panel it opens.
    // In the "frame" style panels attach flush to the bar and join it with
    // concave corners; in every other style they float as rounded cards with
    // a gap from the bar and the screen edges.
    readonly property bool panelsAttached: Appearance.panelsAttached
    readonly property bool barHorizontal: Appearance.barPosition === "top"
        || Appearance.barPosition === "bottom"
    readonly property int barEdgeGap: Appearance.barStyle === "frame"
        || Appearance.barStyle === "minimal" ? 0 : Metrics.spaceS
    readonly property int barThickness: Appearance.barStyle === "taskbar"
        ? taskbarHeight : (barHorizontal ? barHeight : sideBarWidth)
    readonly property int panelGap: panelsAttached ? 0 : Metrics.spaceS
    // Distance from the bar's screen edge to where a panel begins.
    readonly property int panelInset: panelsAttached ? barThickness - 1
        : barThickness + barEdgeGap + panelGap
    // Margin between a floating panel and the other screen edges.
    readonly property int panelSideGap: panelsAttached ? 0 : Metrics.spaceS
    // Material 3 Expressive shape scale lives in Metrics. Compatibility aliases. New components use Metrics so geometry can be
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

    // Accent roles keep a confident, fixed-feeling chroma (as M3 tonal
    // palettes do) so muted seeds still produce a clearly coloured scheme.
    // Near-grey seeds stay monochrome instead of inventing a hue.
    function accentSaturation(stats, maximumSaturation, floor) {
        if (stats.saturation < 0.06)
            return 0.04
        return Math.max(floor, Math.min(maximumSaturation, stats.saturation * 0.85))
    }

    function chromaTone(colorValue, lightness, maximumSaturation) {
        const stats = colorStats(colorValue)
        return Qt.hsla(stats.hue, accentSaturation(stats, maximumSaturation, 0.3),
            lightness, 1)
    }

    function shiftedTone(colorValue, hueShift, lightness, maximumSaturation) {
        const stats = colorStats(colorValue)
        const hue = (stats.hue + hueShift + 1) % 1
        return Qt.hsla(hue, accentSaturation(stats, maximumSaturation || 0.34, 0.2),
            lightness, 1)
    }
}
