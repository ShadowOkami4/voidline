import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.core
import qs.compositor
import qs.services

// Drawn only when a wallpaper is set in the config. Otherwise the
// compositor's own background (or another wallpaper tool) stays in charge.
//
// Still wallpapers are an image. Live wallpapers are a QML package
// (wallpaper.qml) loaded on top of their preview image. The shell hands them
// `theme` and `options` and drives their animation by calling advance(dt) at a
// capped frame rate, and not at all while paused (see docs/live-wallpapers.md).
PanelWindow {
    id: paper

    readonly property string liveId: Config.liveId
    // Windows on the workspace in view hide the wallpaper on a tiling desktop.
    readonly property var activeWorkspace: Compositor.workspaces.find(w => w.active) ?? null
    readonly property bool covered: !!activeWorkspace
        && Compositor.windows.some(w => !w.minimized && w.workspace === activeWorkspace.id)
    readonly property bool paused: Config.gameMode || (Config.livePauseOnBattery && Battery.onBattery)
        || (Config.livePauseWhenCovered && covered)

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: Shell.coverZone
    color: Theme.surface
    WlrLayershell.namespace: "voidline-wallpaper"
    WlrLayershell.layer: WlrLayer.Background

    Image {
        anchors.fill: parent
        source: "file://" + Config.wallpaperFor(paper.screen)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: parent.width
        sourceSize.height: parent.height
        visible: live.status !== Loader.Ready
    }

    Loader {
        id: live
        anchors.fill: parent
        active: paper.liveId.length > 0
        asynchronous: true
        source: active ? "file://" + Config.liveDir + "/" + paper.liveId + "/wallpaper.qml" : ""

        // Wallpapers declare only the properties they use.
        function feed() {
            if (!item) return
            if ("theme" in item) item.theme = Qt.binding(() => ({
                dark: Theme.dark,
                primary: Theme.primary,
                secondary: Theme.secondary,
                tertiary: Theme.tertiary,
                primaryContainer: Theme.primaryContainer,
                tertiaryContainer: Theme.tertiaryContainer,
                surface: Theme.surface,
                ink: Theme.ink
            }))
            if ("options" in item) item.options = Qt.binding(() => Wallpapers.liveValues(paper.liveId))
            if ("paused" in item) item.paused = Qt.binding(() => paper.paused)
        }

        // The clock: a timer instead of per-frame animation, so the wallpaper
        // redraws at the chosen rate rather than at the display refresh rate.
        property real last: 0
        Timer {
            interval: Math.round(1000 / Math.max(5, Math.min(120, Config.liveFps)))
            repeat: true
            running: live.status === Loader.Ready && !paper.paused && typeof live.item.advance === "function"
            onRunningChanged: live.last = Date.now()
            onTriggered: {
                const now = Date.now()
                live.item.advance(Math.min(0.25, (now - live.last) / 1000))
                live.last = now
            }
        }
        onLoaded: feed()
        onStatusChanged: if (status === Loader.Error) console.warn("live wallpaper", paper.liveId, "failed to load")
    }
}
