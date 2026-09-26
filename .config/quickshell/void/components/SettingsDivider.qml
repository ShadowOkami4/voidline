import QtQuick
import "../core"

Rectangle {
    id: root

    property int leftInset: Metrics.controlS + Metrics.cardPadding + Metrics.spaceM
    property int rightInset: Metrics.cardPadding
    property bool allowed: true

    function hasVisibleRowBefore() {
        if (!parent || !parent.parent)
            return false
        const siblings = parent.parent.children
        const ownIndex = siblings.indexOf(parent)
        for (let index = ownIndex - 1; index >= 0; --index) {
            const candidate = siblings[index]
            if (candidate && candidate.visible
                    && Number(candidate.implicitHeight || candidate.height) > 0)
                return true
        }
        return false
    }

    anchors {
        left: parent.left
        right: parent.right
        top: parent.top
        leftMargin: root.leftInset
        rightMargin: root.rightInset
    }
    height: Metrics.divider
    // Segmented groups separate rows with gaps instead of hairlines.
    visible: allowed && !(parent && parent.parent && parent.parent.segmented === true)
        && hasVisibleRowBefore()
    color: Theme.divider
}
