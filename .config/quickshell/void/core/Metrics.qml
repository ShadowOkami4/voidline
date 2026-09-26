pragma Singleton

import Quickshell
import QtQuick

// Voidline's single geometry contract. Components should use these tokens
// instead of inventing local radii, spacing, control heights, or panel sizes.
QtObject {
    readonly property real scale: Appearance.uiScale
        * Math.max(1, Appearance.textScale * 0.94)
        * (Appearance.uiDensity === "compact" ? 0.92
            : (Appearance.uiDensity === "spacious" ? 1.08 : 1.0))

    // Material 3 Expressive shape scale: extra-small 4, small 8, medium 12,
    // large 16, large-increased 20, extra-large 28, extra-large-increased 32,
    // extra-extra-large 48. Voidline maps its four historic steps onto the
    // roomier end of that scale so containers read as soft, confident shapes.
    readonly property int radiusXS: Math.round(4 * scale)
    readonly property int radiusS: Math.round(12 * scale)
    readonly property int radiusM: Math.round(16 * scale)
    readonly property int radiusL: Math.round(24 * scale)
    readonly property int radiusXL: Math.round(32 * scale)
    readonly property int radiusXXL: Math.round(48 * scale)
    readonly property int panelRadius: radiusXL
    readonly property int cardRadius: radiusL
    readonly property int tileRadius: radiusL
    readonly property int buttonRadius: radiusM
    readonly property int stateRadius: radiusM
    readonly property int iconContainerRadius: radiusM
    // Shape morphing: pressed controls tighten to this radius, and segmented
    // groups use it on the inner corners that face a neighbour.
    readonly property int pressedRadius: Math.round(8 * scale)
    readonly property int segmentInnerRadius: radiusXS
    readonly property int segmentGap: Math.max(2, Math.round(2 * scale))
    readonly property int pillRadius: 999

    readonly property int space2XS: Math.round(3 * scale)
    readonly property int spaceXS: Math.round(5 * scale)
    readonly property int spaceS: Math.round(8 * scale)
    readonly property int spaceM: Math.round(12 * scale)
    readonly property int spaceL: Math.round(18 * scale)
    readonly property int spaceXL: Math.round(24 * scale)
    readonly property int spaceXXL: Math.round(32 * scale)
    readonly property int panelPadding: spaceL
    readonly property int pagePadding: spaceXL
    readonly property int sectionGap: spaceL
    readonly property int rowGap: spaceS

    // Shared layout contract. These values describe relationships between
    // content instead of component-specific geometry, so text and controls
    // remain aligned when density or text scale changes.
    readonly property int cardPadding: spaceM
    readonly property int cardPaddingWide: spaceL
    readonly property int contentInset: spaceM
    readonly property int titleSubtitleGap: space2XS
    readonly property int labelControlGap: spaceS
    readonly property int sliderLabelGap: spaceS
    readonly property int sectionHeaderGap: spaceS
    readonly property int tooltipPaddingX: spaceM
    readonly property int tooltipPaddingY: spaceS
    readonly property int inputPaddingX: spaceM
    readonly property int inputPaddingY: spaceS

    readonly property int controlS: Math.round(36 * scale)
    readonly property int controlM: Math.round(46 * scale)
    readonly property int controlL: Math.round(58 * scale)
    readonly property int tileHeight: Math.round(68 * scale)
    readonly property int heroTileHeight: Math.round(78 * scale)
    readonly property int sliderHeight: Math.round(76 * scale)
    readonly property int settingRowHeight: Math.round(66 * scale)
    readonly property int settingRowCompact: Math.round(60 * scale)
    readonly property int settingRowComfortable: Math.round(72 * scale)
    readonly property int sectionHeaderHeight: Math.round(44 * scale)
    readonly property int panelHeaderHeight: Math.round(62 * scale)
    readonly property int inputHeight: Math.round(48 * scale)
    readonly property int minimumHitSize: Math.round(44 * scale)

    readonly property int iconS: Math.round(16 * scale)
    readonly property int iconM: Math.round(20 * scale)
    readonly property int iconL: Math.round(26 * scale)
    readonly property int iconXL: Math.round(34 * scale)

    readonly property int textCaption: Math.round(10 * scale)
    readonly property int textSupporting: Math.round(11 * scale)
    readonly property int textBody: Math.round(13 * scale)
    readonly property int textTitle: Math.round(14 * scale)
    readonly property int textHeader: Math.round(21 * scale)

    // Application-sized typography. Shell panels deliberately remain denser,
    // while Settings and Lyra use these tokens to stay readable on a desktop.
    readonly property int appTextCaption: Math.round(12 * scale)
    readonly property int appTextSupporting: Math.round(13 * scale)
    readonly property int appTextBody: Math.round(14 * scale)
    readonly property int appTextTitle: Math.round(16 * scale)
    readonly property int appTextHeader: Math.round(30 * scale)

    readonly property int responsiveCompact: Math.round(620 * scale)
    readonly property int responsiveWide: Math.round(960 * scale)

    // Shared Settings content grid. Pages may opt into a single-column layout,
    // but they must not invent their own desktop breakpoints or content caps.
    readonly property int settingsNarrow: Math.round(820 * scale)
    readonly property int settingsTwoColumn: Math.round(980 * scale)
    readonly property int settingsContentMax: Math.round(1680 * scale)
    readonly property int settingsColumnMin: Math.round(460 * scale)
    readonly property int settingsColumnMax: Math.round(820 * scale)
    readonly property int settingsPageGap: spaceL
    readonly property int settingsSectionGap: spaceL
    readonly property int settingsHeaderHeight: Math.round(116 * scale)

    readonly property int panelCompact: Math.round(430 * scale)
    readonly property int panelMedium: Math.round(540 * scale)
    readonly property int panelWide: Math.round(600 * scale)
    readonly property int powerDrawerWidth: Math.round(330 * scale)
    readonly property int powerDrawerHeight: Math.round(416 * scale)
    readonly property int launcherWidth: Math.round(450 * scale)
    readonly property int launcherWideWidth: Math.round(620 * scale)
    readonly property int launcherFileWidth: Math.round(760 * scale)
    readonly property int launcherHeight: Math.round(574 * scale)
    readonly property int launcherFileHeight: Math.round(660 * scale)
    readonly property int launcherCollapsedWidth: Math.round(132 * scale)
    readonly property int launcherFileHeaderHeight: Math.round(194 * scale)
    readonly property int edgeTriggerHeight: Math.round(210 * scale)
    readonly property int settingsSidebar: Math.round(360 * scale)
    readonly property int contextMenuWidth: Math.round(304 * scale)

    readonly property int concaveRadius: Math.round(20 * scale)
    readonly property int connectionOverlap: 1
    readonly property int screenFrame: Math.max(4, Math.round(4 * scale))
    readonly property int border: Math.max(1, Math.round(scale))
    readonly property int divider: Math.max(1, Math.round(scale))
    readonly property int focusBorder: Math.max(2, Math.round(2 * scale))
    readonly property int hairlineRadius: Math.max(2, Math.round(2 * scale))
    readonly property int trackRadius: Math.max(4, Math.round(5 * scale))

    readonly property real shadowOpacity: Appearance.darkMode ? 0.32 : 0.18
    readonly property int shadowBlur: Math.round(28 * scale)
    readonly property int shadowOffset: Math.round(8 * scale)
}
