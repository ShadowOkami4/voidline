import Quickshell
import Quickshell.Wayland
import QtQuick
import "../components"
import "../core"

// Taskbar dock: App Center button, then pinned applications followed by any
// other running applications. A long indicator marks the focused app, a dot
// marks apps with open windows. Right-click pins or unpins an application.
Row {
    id: root

    property var shellScreen
    readonly property int iconSize: Math.round(44 * Metrics.scale)
    readonly property var toplevels: ToplevelManager.toplevels.values || []

    spacing: Metrics.spaceS

    function normalized(value) {
        return String(value || "").toLowerCase().replace(/\.desktop$/, "")
    }

    function entryFor(appId) {
        if (!appId)
            return null
        return DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId)
    }

    function windowsFor(appId) {
        const wanted = normalized(appId)
        const result = []
        for (let index = 0; index < toplevels.length; ++index) {
            const toplevel = toplevels[index]
            const id = normalized(toplevel.appId)
            if (id === wanted || id.endsWith("." + wanted) || wanted.endsWith("." + id))
                result.push(toplevel)
        }
        return result
    }

    function iconSource(entry, appId) {
        const name = entry && entry.icon ? entry.icon : appId
        if (!name)
            return ""
        return String(name).startsWith("/") ? "file://" + name
            : (Quickshell.hasThemeIcon(name) ? Quickshell.iconPath(name) : "")
    }

    // Pinned first (in the user's order), then unpinned running apps.
    readonly property var items: {
        const result = []
        const seen = {}
        const pinned = Appearance.pinnedApps
        for (let index = 0; index < pinned.length; ++index) {
            const entry = entryFor(pinned[index])
            if (!entry)
                continue
            seen[normalized(entry.id)] = true
            result.push({ appId: entry.id, entry: entry, pinned: true })
        }
        for (let index = 0; index < toplevels.length; ++index) {
            const appId = toplevels[index].appId
            const entry = entryFor(appId)
            const key = normalized(entry ? entry.id : appId)
            if (!appId || seen[key])
                continue
            seen[key] = true
            result.push({ appId: entry ? entry.id : appId, entry: entry, pinned: false })
        }
        return result
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: root.iconSize
        height: root.iconSize
        radius: launcherTap.pressed ? Metrics.radiusM : width / 2
        color: ShellState.isLauncherScreen(root.shellScreen) ? Theme.accentStrong : Theme.accent

        Behavior on radius {
            NumberAnimation {
                duration: Motion.springFast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spatialFast
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: "apps"
            size: Math.round(root.iconSize * 0.55)
            fill: 1
            color: Theme.accentInk
        }
        TapHandler {
            id: launcherTap
            onTapped: ShellState.toggleLauncher(root.shellScreen)
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    Rectangle {
        visible: root.items.length > 0
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(2, Math.round(2 * Metrics.scale))
        height: Math.round(root.iconSize * 0.6)
        radius: width / 2
        color: Theme.outlineSoft
    }

    Repeater {
        model: root.items

        Item {
            id: dockItem
            required property var modelData
            readonly property var windows: root.windowsFor(modelData.appId)
            readonly property bool running: windows.length > 0
            readonly property bool focused: windows.some(toplevel => toplevel.activated)

            anchors.verticalCenter: parent.verticalCenter
            width: root.iconSize
            height: root.iconSize + Math.round(10 * Metrics.scale)

            Rectangle {
                id: iconSurface
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.iconSize
                height: root.iconSize
                radius: dockTap.pressed ? Metrics.radiusS
                    : (dockItem.focused ? Metrics.radiusM : width / 2)
                color: dockHover.hovered || dockItem.focused
                    ? Theme.surfaceHover : "transparent"

                Behavior on radius {
                    NumberAnimation {
                        duration: Motion.springFast
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.spatialFast
                    }
                }
                Behavior on color { ColorAnimation { duration: Motion.effectsFastDuration } }

                ApplicationIcon {
                    anchors.centerIn: parent
                    width: Math.round(root.iconSize * 0.72)
                    height: width
                    source: root.iconSource(dockItem.modelData.entry, dockItem.modelData.appId)
                }
            }

            Rectangle {
                visible: dockItem.running
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                }
                width: dockItem.focused ? Math.round(18 * Metrics.scale) : Math.round(5 * Metrics.scale)
                height: Math.round(4 * Metrics.scale)
                radius: height / 2
                color: dockItem.focused ? Theme.accent : Theme.textMuted

                Behavior on width {
                    NumberAnimation {
                        duration: Motion.springFast
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.spatialFast
                    }
                }
            }

            HoverHandler {
                id: dockHover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                id: dockTap
                acceptedButtons: Qt.LeftButton
                onTapped: {
                    if (dockItem.running) {
                        const focusedIndex = dockItem.windows.findIndex(toplevel => toplevel.activated)
                        const next = dockItem.windows[(focusedIndex + 1) % dockItem.windows.length]
                        next.activate()
                    } else if (dockItem.modelData.entry) {
                        dockItem.modelData.entry.execute()
                    }
                }
            }
            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: Appearance.togglePinnedApp(dockItem.modelData.appId)
            }
        }
    }
}
