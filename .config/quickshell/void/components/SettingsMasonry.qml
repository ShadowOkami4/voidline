import QtQuick
import "../core"

// Responsive settings content grid. Pages keep declaring SettingsSection
// children directly, while Flow owns positioning and eliminates the previous
// hand-written x/y masonry calculations and binding races.
Item {
    id: root

    property real spacing: Metrics.settingsSectionGap
    property real columnThreshold: Metrics.settingsTwoColumn
    property bool forceSingleColumn: false
    property int maximumColumns: 2
    readonly property bool twoColumns: width >= columnThreshold
        && !forceSingleColumn && maximumColumns > 1
    readonly property real pageColumnWidth: twoColumns
        ? Math.floor((width - spacing) / 2) : width
    default property alias contentData: contentFlow.data

    implicitHeight: Math.max(0, contentFlow.childrenRect.height)

    Flow {
        id: contentFlow
        width: parent.width
        spacing: root.spacing
        flow: Flow.LeftToRight

        // SettingsSection reads these values from its actual visual parent.
        property bool isSettingsMasonry: true
        property bool twoColumns: root.twoColumns
        property real pageColumnWidth: root.pageColumnWidth

        function itemWidth(fullWidth) {
            return !twoColumns || fullWidth ? width : pageColumnWidth
        }
    }
}
