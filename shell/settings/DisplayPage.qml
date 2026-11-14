import QtQuick
import QtQuick.Layouts
import qs.core
import qs.compositor
import qs.services
import qs.widgets

// Displays. On top a picture of how the screens sit next to each other: click
// one to select it, drag it to where it really stands. Below, the selected
// screen's resolution, refresh rate and scale as dropdown menus.
// A new mode is applied first and saved only once confirmed, so a mode the
// screen cannot show never locks you out. Moving screens needs no confirmation.
ColumnLayout {
    id: page
    spacing: 24

    readonly property var outputs: Compositor.outputs
    property string selected: ""
    readonly property var current: outputs.find(o => o.name === selected) ?? (outputs[0] ?? null)
    readonly property bool several: outputs.length > 1

    Component.onCompleted: Compositor.refreshOutputs()

    // ---- mode changes: apply, then keep or revert ----------------------------------------
    // Pending confirmation: { name, mode, scale, oldMode, oldScale }
    property var pending: null
    property int secondsLeft: 0

    function resolutionOf(mode) { return mode.split("@")[0] }
    function rateOf(mode) { return parseFloat(mode.split("@")[1]) }
    function saveMode(name, mode, scale) {
        Config.displays = Config.displays.filter(e => e.split("|")[0] !== name).concat([name + "|" + mode + "|" + scale])
    }

    function apply(output, mode, scale) {
        pending = { name: output.name, mode: mode, scale: scale, oldMode: output.mode, oldScale: output.scale }
        secondsLeft = 15
        Compositor.applyOutput(output.name, mode, scale)
        countdown.restart()
    }
    function keep() {
        countdown.stop()
        saveMode(pending.name, pending.mode, pending.scale)
        pending = null
    }
    function revert() {
        countdown.stop()
        if (pending) Compositor.applyOutput(pending.name, pending.oldMode, pending.oldScale)
        pending = null
    }
    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: { page.secondsLeft -= 1; if (page.secondsLeft <= 0) page.revert() }
    }

    // ---- arrangement ---------------------------------------------------------------------
    // Positions just set by dragging, shown until the compositor reports them back.
    property var draft: ({})
    onOutputsChanged: draft = ({})
    Timer { id: reread; interval: 1200; onTriggered: Compositor.refreshOutputs() }

    function rectOf(o) {
        const d = draft[o.name]
        return { x: d ? d.x : o.x, y: d ? d.y : o.y, w: Math.max(1, o.w), h: Math.max(1, o.h) }
    }
    readonly property var placed: outputs.filter(o => !o.mirror)
    readonly property bool mirrorable: Compositor.name === "hyprland" && several

    // Finds the nearest spot where screen `name` touches another one without
    // overlapping any, lining its edges up when they are close.
    function snap(name, x, y) {
        const me = rectOf(outputs.find(o => o.name === name))
        const others = placed.filter(o => o.name !== name).map(o => rectOf(o))
        if (others.length === 0) return { x: 0, y: 0 }
        const near = 90
        const overlaps = (cx, cy) => others.some(o => cx < o.x + o.w && cx + me.w > o.x && cy < o.y + o.h && cy + me.h > o.y)
        let best = null
        const consider = (cx, cy) => {
            if (overlaps(cx, cy)) return
            const d = Math.hypot(cx - x, cy - y)
            if (!best || d < best.d) best = { x: Math.round(cx), y: Math.round(cy), d: d }
        }
        for (const o of others) {
            let cy = Math.max(o.y - me.h + 60, Math.min(o.y + o.h - 60, y))
            for (const a of [o.y, o.y + o.h - me.h, o.y + (o.h - me.h) / 2]) if (Math.abs(a - cy) < near) cy = a
            consider(o.x - me.w, cy)
            consider(o.x + o.w, cy)
            let cx = Math.max(o.x - me.w + 60, Math.min(o.x + o.w - 60, x))
            for (const a of [o.x, o.x + o.w - me.w, o.x + (o.w - me.w) / 2]) if (Math.abs(a - cx) < near) cx = a
            consider(cx, o.y - me.h)
            consider(cx, o.y + o.h)
        }
        return best ?? { x: others[0].x + others[0].w, y: others[0].y }
    }

    // Saves where every screen sits (top-left screen at 0,0) and applies it.
    function place(name, x, y) {
        const spot = snap(name, x, y)
        const next = {}
        for (const o of placed) { const r = rectOf(o); next[o.name] = { x: r.x, y: r.y } }
        next[name] = { x: spot.x, y: spot.y }
        const minX = Math.min(...Object.values(next).map(p => p.x)), minY = Math.min(...Object.values(next).map(p => p.y))
        const entries = []
        for (const n of Object.keys(next)) {
            next[n] = { x: next[n].x - minX, y: next[n].y - minY }
            entries.push(n + "=" + next[n].x + "," + next[n].y)
        }
        for (const o of outputs) {
            if (o.mirror) entries.push(o.name + "=mirror")
            // A position needs the screen's mode written next to it.
            if (!Config.displays.some(e => e.split("|")[0] === o.name) && o.mode) saveMode(o.name, o.mode, o.scale)
        }
        draft = next
        Config.displayPlaces = entries
        reread.restart()
    }
    function setMirror(name, on) {
        const rest = Config.displayPlaces.filter(e => !e.startsWith(name + "="))
        for (const o of outputs)
            if (!Config.displays.some(e => e.split("|")[0] === o.name) && o.mode) saveMode(o.name, o.mode, o.scale)
        Config.displayPlaces = on ? rest.concat([name + "=mirror"]) : rest
        reread.restart()
    }

    // ---- keep / revert banner ----------------------------------------------------------
    Rectangle {
        Layout.fillWidth: true
        visible: !!page.pending
        implicitHeight: 96
        radius: Theme.cornerXXL
        color: Theme.tertiaryContainer

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 18
            spacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label {
                    Layout.fillWidth: true
                    text: "Keep these display settings?"
                    font.pixelSize: Theme.textTitle + 4
                    font.weight: Font.Black
                    color: Theme.inkOnTertiaryContainer
                }
                Label {
                    Layout.fillWidth: true
                    text: "Reverting in " + page.secondsLeft + " seconds."
                    color: Theme.inkOnTertiaryContainer
                    opacity: 0.85
                }
            }
            Pressable {
                implicitWidth: 104
                implicitHeight: 52
                color: Theme.surfaceContainerHigh
                onClicked: page.revert()
                Label { anchors.centerIn: parent; text: "Revert"; font.weight: Font.Bold }
            }
            Pressable {
                implicitWidth: 104
                implicitHeight: 52
                color: Theme.tertiary
                tint: Theme.surface
                onClicked: page.keep()
                Label { anchors.centerIn: parent; text: "Keep"; font.weight: Font.Bold; color: Theme.surface }
            }
        }
    }

    // ---- the picture of the screens ---------------------------------------------------
    Rectangle {
        id: stage
        Layout.fillWidth: true
        implicitHeight: 300
        radius: Theme.cornerXXL
        color: Theme.surfaceContainerHigh
        clip: true

        // Bounding box of all screens and the factor that fits it in here.
        readonly property var box: {
            let x0 = 0, y0 = 0, x1 = 1, y1 = 1, first = true
            for (const o of page.placed) {
                const r = page.rectOf(o)
                if (first) { x0 = r.x; y0 = r.y; x1 = r.x + r.w; y1 = r.y + r.h; first = false }
                else { x0 = Math.min(x0, r.x); y0 = Math.min(y0, r.y); x1 = Math.max(x1, r.x + r.w); y1 = Math.max(y1, r.y + r.h) }
            }
            return { x: x0, y: y0, w: Math.max(1, x1 - x0), h: Math.max(1, y1 - y0) }
        }
        readonly property real k: Math.min((width - 140) / box.w, (height - 96) / box.h, 0.16)
        readonly property real ox: (width - box.w * k) / 2 - box.x * k
        readonly property real oy: (height - 30 - box.h * k) / 2 - box.y * k

        Label {
            visible: page.outputs.length === 0
            anchors.centerIn: parent
            text: Compositor.supported ? "Looking for displays…" : "No supported window manager is running."
            color: Theme.inkMuted
        }

        Repeater {
            model: page.placed

            Rectangle {
                id: screen
                required property var modelData
                readonly property var r: page.rectOf(modelData)
                readonly property bool current: page.current && page.current.name === modelData.name
                property real dx: 0
                property real dy: 0

                x: stage.ox + r.x * stage.k + dx
                y: stage.oy + r.y * stage.k + dy
                width: r.w * stage.k
                height: r.h * stage.k
                z: grip.pressed ? 10 : (current ? 2 : 1)
                radius: Theme.cornerM
                color: current ? Theme.primary : Theme.surfaceContainerHighest
                border.width: 2
                border.color: current ? Theme.primary : Theme.outline
                scale: grip.pressed ? 1.04 : 1
                Behavior on scale { Spring {} }
                Behavior on x { enabled: !grip.pressed; Spring {} }
                Behavior on y { enabled: !grip.pressed; Spring {} }
                Behavior on color { Tint {} }

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 12
                    spacing: 2
                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: screen.modelData.name
                        font.weight: Font.Black
                        font.pixelSize: Theme.textTitle
                        color: screen.current ? Theme.inkOnPrimary : Theme.ink
                    }
                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: page.resolutionOf(screen.modelData.mode).replace("x", " × ")
                        font.pixelSize: Theme.textLabelS
                        color: screen.current ? Theme.inkOnPrimary : Theme.inkMuted
                        opacity: 0.9
                    }
                }

                MouseArea {
                    id: grip
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: page.several ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.PointingHandCursor
                    property point start
                    onPressed: mouse => { page.selected = screen.modelData.name; start = mapToItem(stage, mouse.x, mouse.y) }
                    onPositionChanged: mouse => {
                        if (!pressed || !page.several) return
                        const now = mapToItem(stage, mouse.x, mouse.y)
                        screen.dx = now.x - start.x
                        screen.dy = now.y - start.y
                    }
                    onReleased: {
                        const moved = Math.abs(screen.dx) + Math.abs(screen.dy) > 6
                        const x = screen.r.x + screen.dx / stage.k, y = screen.r.y + screen.dy / stage.k
                        screen.dx = 0
                        screen.dy = 0
                        if (moved && page.several) page.place(screen.modelData.name, x, y)
                    }
                }
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            visible: page.outputs.length > 0
            text: page.placed.length > 1 ? "Drag a screen to where it stands on your desk. Click one to change its settings."
                : (page.several ? "The other screen shows the same picture." : "One screen connected.")
            font.pixelSize: Theme.textLabel
            color: Theme.inkMuted
        }
    }

    // ---- the selected screen -------------------------------------------------------------
    SegGroup {
        id: group
        visible: !!page.current
        title: page.current ? page.current.name + (page.current.description ? "  ·  " + page.current.description : "") : ""

        readonly property var output: page.current ?? ({ name: "", mode: "0x0@0", scale: 1, modes: [], mirror: false })
        // What is selected in the menus; follows the screen until changed.
        property string resolution: page.resolutionOf(output.mode)
        property real rate: page.rateOf(output.mode)
        property real zoom: output.scale
        function reset() {
            resolution = Qt.binding(() => page.resolutionOf(output.mode))
            rate = Qt.binding(() => page.rateOf(output.mode))
            zoom = Qt.binding(() => output.scale)
        }
        onOutputChanged: reset()

        readonly property var resolutions: {
            const seen = []
            for (const m of output.modes) {
                const r = page.resolutionOf(m)
                if (!seen.includes(r)) seen.push(r)
            }
            return seen.sort((a, b) => parseInt(b) - parseInt(a) || parseInt(b.split("x")[1]) - parseInt(a.split("x")[1])).slice(0, 12)
        }
        readonly property var rates: {
            const seen = [], out = []
            for (const m of output.modes.filter(m => page.resolutionOf(m) === resolution).sort((a, b) => page.rateOf(b) - page.rateOf(a))) {
                const hz = Math.round(page.rateOf(m))
                if (!seen.includes(hz)) { seen.push(hz); out.push(m) }
            }
            return out
        }
        readonly property string mode: {
            const exact = rates.find(m => Math.abs(page.rateOf(m) - rate) < 0.6)
            return exact ?? rates[0] ?? output.mode
        }
        // Scales that give a whole number of pixels at this resolution.
        readonly property var scales: {
            const w = parseInt(resolution), h = parseInt(resolution.split("x")[1])
            const ok = [1, 1.25, 4 / 3, 1.5, 1.6, 5 / 3, 1.75, 2, 2.5, 3].filter(s =>
                Math.abs(w / s - Math.round(w / s)) < 0.01 && Math.abs(h / s - Math.round(h / s)) < 0.01 && w / s >= 960)
            if (!ok.some(s => Math.abs(s - output.scale) < 0.01)) ok.push(output.scale)
            return ok.sort((a, b) => a - b)
        }
        readonly property bool dirty: mode !== output.mode || Math.abs(zoom - output.scale) > 0.01

        SegItem {
            icon: "aspect_ratio"
            hue: 0
            lobes: 4
            title: "Resolution"
            description: "How many pixels the screen shows. The top entry is its sharpest."
            Dropdown {
                width: 230
                value: group.resolution
                options: group.resolutions.map(r => ({ value: r, label: r.replace("x", " × ") }))
                onPicked: v => group.resolution = v
            }
        }
        SegItem {
            icon: "speed"
            hue: 1
            lobes: 8
            title: "Refresh rate"
            description: "Higher is smoother and uses a little more power."
            Dropdown {
                width: 230
                value: page.rateOf(group.mode)
                options: group.rates.map(m => ({ value: page.rateOf(m), label: Math.round(page.rateOf(m)) + " Hz" }))
                onPicked: v => group.rate = v
            }
        }
        SegItem {
            icon: "zoom_in"
            hue: 2
            lobes: 0
            title: "Scale"
            description: "How large apps and text appear. Voidline's own size is under Interface."
            Dropdown {
                width: 230
                value: group.zoom
                options: group.scales.map(s => ({ value: s, label: Math.round(s * 100) + "%" }))
                onPicked: v => group.zoom = v
            }
        }
        SegItem {
            visible: group.dirty || !!page.pending
            icon: "done_all"
            hue: 4
            lobes: 5
            title: "Apply changes"
            description: "You will be asked to confirm; otherwise it reverts after 15 seconds."
            Row {
                spacing: 8
                Pressable {
                    width: 96
                    height: 46
                    enabledInput: !page.pending
                    color: Theme.surfaceContainerHighest
                    onClicked: group.reset()
                    Label { anchors.centerIn: parent; text: "Reset"; font.weight: Font.DemiBold }
                }
                Pressable {
                    width: 110
                    height: 46
                    enabledInput: group.dirty && !page.pending
                    opacity: enabledInput ? 1 : 0.5
                    color: Theme.primary
                    tint: Theme.inkOnPrimary
                    onClicked: page.apply(group.output, group.mode, Math.round(group.zoom * 1000000) / 1000000)
                    Label { anchors.centerIn: parent; text: "Apply"; font.weight: Font.Bold; color: Theme.inkOnPrimary }
                }
            }
        }
        SegItem {
            // Not on the main screen: that is the one the others copy.
            visible: page.mirrorable && (group.output.mirror || (page.placed.length > 1 && group.output.name !== WmConfig.primary))
            icon: "content_copy"
            hue: 3
            lobes: 5
            title: "Same picture as the main screen"
            description: "Shows a copy instead of extending the desktop. Good for presenting."
            Toggle { checked: !!group.output.mirror; onToggled: v => page.setMirror(group.output.name, v) }
        }
    }

    // A mirrored screen is not in the picture above; this is how to select it.
    SegGroup {
        visible: page.outputs.some(o => o.mirror)
        title: "Showing the same picture"
        Repeater {
            model: page.outputs.filter(o => o.mirror)
            SegItem {
                required property var modelData
                icon: "content_copy"
                hue: 5
                lobes: 0
                title: modelData.name
                description: modelData.description || ""
                clickable: true
                onClicked: page.selected = modelData.name
            }
        }
    }

    // ---- brightness -----------------------------------------------------------------
    SegGroup {
        visible: Brightness.available
        title: "Brightness"
        SliderItem {
            icon: "brightness_medium"
            hue: 3
            lobes: 8
            title: "Laptop screen"
            from: 2; to: 100; step: 1; suffix: "%"
            value: Math.round(Brightness.value * 100)
            onChanged: v => Brightness.set(v / 100)
        }
    }
}
