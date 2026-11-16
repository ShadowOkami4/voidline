import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.core
import qs.services
import qs.settings
import qs.widgets

// App launcher: type to search, arrows to move, Enter to launch, Esc to close.
PanelSurface {
    id: root

    open: Shell.panel === "launcher"
    anchor: Style.launcherAnchor
    panelWidth: Style.launcherWidth
    panelHeight: Style.launcherHeight

    readonly property int columns: Style.launcherColumns
    // "> something" runs it as a command instead of searching apps.
    readonly property bool commandMode: search.text.startsWith(">")
    readonly property string commandText: commandMode ? search.text.slice(1).trim() : ""
    property var results: commandMode ? [] : Apps.search(search.text)
    function run() {
        if (commandText.length === 0) return
        Quickshell.execDetached(["env", "-u", "QT_SCALE_FACTOR", "-u", "VOIDLINE_UI_SCALE", "-u", "MALLOC_CONF", "sh", "-c", commandText])
        Shell.close()
    }

    // ---- more than apps: sums, settings, files, the web ---------------------------
    readonly property string words: commandMode ? "" : search.text.trim()

    // A small calculator: + - * / ^ %, brackets, comma or point. Returns ""
    // when the text is no sum.
    function calc(text) {
        const src = text.replace(/\s+/g, "").replace(/,/g, ".").replace(/[x×]/g, "*").replace(/÷/g, "/")
        if (!/^[-+(]*\d/.test(src) && !/^[-+(]*\.\d/.test(src)) return ""
        if (!/^[\d.+\-*\/^%()]+$/.test(src) || !/[+\-*\/^%]/.test(src.slice(1))) return ""
        let i = 0
        const fail = () => { throw new Error("no sum") }
        const atom = () => {
            if (src[i] === "(") { ++i; const v = sum(); if (src[i] !== ")") fail(); ++i; return v }
            if (src[i] === "-") { ++i; return -power() }
            if (src[i] === "+") { ++i; return power() }
            const m = src.slice(i).match(/^(\d+\.?\d*|\.\d+)/)
            if (!m) fail()
            i += m[0].length
            let v = Number(m[0])
            if (src[i] === "%" && !/[\d(.]/.test(src[i + 1] || "")) { ++i; v /= 100 }
            return v
        }
        const power = () => { const base = atom(); if (src[i] === "^") { ++i; return Math.pow(base, power()) } return base }
        const product = () => {
            let v = power()
            while (src[i] === "*" || src[i] === "/" || src[i] === "%") {
                const op = src[i++]; const r = power()
                v = op === "*" ? v * r : (op === "/" ? v / r : v % r)
            }
            return v
        }
        function sum() {
            let v = product()
            while (src[i] === "+" || src[i] === "-") { const op = src[i++]; const r = product(); v = op === "+" ? v + r : v - r }
            return v
        }
        try {
            const v = sum()
            if (i !== src.length || !isFinite(v)) return ""
            return String(parseFloat(v.toPrecision(12))).replace(".", Lang.locale.decimalPoint)
        } catch (e) { return "" }
    }

    // Files in your home folder whose name contains the words.
    property var files: []
    property string filesFor: ""
    onWordsChanged: { pick = -1; if (words.length >= 3) seek.restart(); else { seek.stop(); files = []; filesFor = "" } }
    Timer {
        id: seek
        interval: 280
        onTriggered: {
            if (finder.running) { restart(); return }
            finder.asked = root.words
            // The words go in as data, never as part of the command.
            finder.command = ["sh", "-c", "find \"$HOME\" -maxdepth 5 \\( -name '.*' -o -name node_modules -o -name __pycache__ \\) -prune -o -iname \"*$1*\" -print 2>/dev/null | head -n 4", "sh", root.words.replace(/[*?\[\]\\]/g, "")]
            finder.running = true
        }
    }
    Process {
        id: finder
        property string asked: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (finder.asked !== root.words) return
                root.files = text.split("\n").filter(l => l.length > 0)
                root.filesFor = finder.asked
            }
        }
    }

    // What the words could mean besides an app, best guess first.
    readonly property var extras: {
        const q = words
        const out = []
        if (q.length === 0) return out
        const answer = calc(q)
        // "timer 10", "25 min", "90s"
        const timed = q.toLowerCase().match(/^timer\b\s*(.*)$/)
        const span = timed ? Countdown.parse(timed[1]) : (/[a-z]/i.test(q) ? Countdown.parse(q) : 0)
        if (Countdown.running && (timed || span > 0))
            out.push({ kind: "timerStop", icon: "timer_off", title: Lang.t("Stop the timer"), hint: Lang.t("%1 left", Countdown.text), value: 0 })
        if (span > 0)
            out.push({ kind: "timer", icon: "timer", title: Lang.t("Start a timer of %1", Countdown.words(span)), hint: Lang.t("The bar counts down, a notification rings."), value: span })
        else if (timed && !Countdown.running)
            out.push({ kind: "hint", icon: "timer", title: Lang.t("Timer: add how long"), hint: Lang.t("For example: timer 10, timer 90s, timer 1,5h"), value: 0 })
        if (answer.length > 0) out.push({ kind: "calc", icon: "calculate", title: answer, hint: Lang.t("Enter copies the result"), value: answer })
        for (const p of Pages.find(q).slice(0, 2))
            out.push({ kind: "page", icon: p.icon, title: p.label, hint: Lang.t("Settings") + "  ·  " + p.hint, value: p.id })
        if (filesFor === q)
            for (const f of files)
                out.push({ kind: "file", icon: "draft", title: f.replace(/^.*\//, ""), hint: f.replace(/\/[^\/]*$/, "").replace(Quickshell.env("HOME"), "~"), value: f })
        if (q.length > 1 && answer.length === 0 && !timed && span === 0) {
            if (results.length === 0 && Packages.available)
                out.push({ kind: "install", icon: "download", title: Lang.t("Look for \"%1\" to install", q), hint: Lang.t("Install apps"), value: q })
            if (Config.webSearch.includes("%s"))
                out.push({ kind: "web", icon: "travel_explore", title: Lang.t("Search the web for \"%1\"", q), hint: Config.webSearch.replace(/^[a-z]+:\/\//, "").replace(/\/.*$/, ""), value: q })
        }
        return out
    }
    // Highlighted extra, or -1 while the app grid has the highlight.
    property int pick: -1
    readonly property int chosen: results.length === 0 ? Math.max(0, pick) : pick
    function act(x) {
        if (!x || x.kind === "hint") return
        Shell.close()
        if (x.kind === "timer") Countdown.start(x.value)
        else if (x.kind === "timerStop") Countdown.stop()
        else if (x.kind === "calc") Quickshell.execDetached(["wl-copy", "--", x.value])
        else if (x.kind === "page") Shell.openSettings(x.value)
        else if (x.kind === "file") Apps.openUrl(x.value)
        else if (x.kind === "install") Shell.findApp(x.value)
        else if (x.kind === "web") Apps.openUrl(Config.webSearch.replace("%s", encodeURIComponent(x.value)))
    }
    function enter() {
        if (commandMode) run()
        else if (chosen >= 0 && extras[chosen]) act(extras[chosen])
        else launch(results[grid.currentIndex])
    }
    // Down from the last row of apps goes on into the list underneath.
    function down() {
        if (chosen >= 0) { pick = Math.min(extras.length - 1, chosen + 1); return }
        const before = grid.currentIndex
        grid.moveCurrentIndexDown()
        if (grid.currentIndex === before && extras.length > 0) pick = 0
    }
    function up() {
        if (chosen > 0) pick = chosen - 1
        else if (chosen === 0 && results.length > 0) pick = -1
        else if (chosen < 0) grid.moveCurrentIndexUp()
    }

    onOpenChanged: {
        if (open) { search.text = ""; grid.currentIndex = 0; search.forceActiveFocus() }
    }
    onResultsChanged: grid.currentIndex = 0

    function launch(entry) {
        if (!entry) return
        Apps.launch(entry)
        Shell.close()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 52
            radius: height / 2
            color: Theme.surfaceContainerHighest

            MIcon {
                id: searchIcon
                x: 18
                anchors.verticalCenter: parent.verticalCenter
                icon: "search"
                size: 22
                color: Theme.inkMuted
            }
            TextInput {
                id: search
                anchors.left: searchIcon.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.ink
                selectionColor: Theme.primaryContainer
                selectedTextColor: Theme.inkOnPrimaryContainer
                font.family: Theme.font
                font.pixelSize: Theme.textTitle
                clip: true

                Keys.onEscapePressed: Shell.close()
                Keys.onReturnPressed: root.enter()
                Keys.onEnterPressed: root.enter()
                Keys.onRightPressed: grid.moveCurrentIndexRight()
                Keys.onLeftPressed: grid.moveCurrentIndexLeft()
                Keys.onDownPressed: root.down()
                Keys.onUpPressed: root.up()
                Keys.onTabPressed: root.pick = root.pick < 0 && root.extras.length > 0 ? 0 : -1

                Label {
                    visible: search.text.length === 0
                    text: Lang.t("Search apps, settings and files, or work out a sum")
                    color: Theme.inkMuted
                    font.pixelSize: Theme.textTitle
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 104
            // With no app to show, the list underneath moves up.
            visible: count > 0 || root.extras.length === 0
            clip: true
            cellWidth: Math.floor(width / root.columns)
            cellHeight: 104
            model: root.results
            boundsBehavior: Flickable.StopAtBounds
            highlightFollowsCurrentItem: true
            highlightMoveDuration: Motion.effects
            highlight: Rectangle {
                radius: Theme.cornerLInc
                color: Theme.secondaryContainer
                opacity: root.chosen < 0 ? 1 : 0
                Behavior on opacity { Fade {} }
            }

            delegate: Pressable {
                id: cell
                required property var modelData
                required property int index
                width: grid.cellWidth
                height: grid.cellHeight
                restRadius: Theme.cornerLInc
                pressedRadius: Theme.cornerM
                onClicked: root.launch(modelData)
                onHoveredChanged: if (hovered) { grid.currentIndex = index; root.pick = -1 }
                // The icons pop in row by row when the launcher opens.
                readonly property real arrived: root.shown(1 + Math.min(6, Math.floor(index / root.columns) * 0.8 + (index % root.columns) * 0.15))
                opacity: arrived
                scale: 0.8 + 0.2 * arrived

                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    AppIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: 44
                        icon: cell.modelData.icon
                        name: cell.modelData.name
                        scale: cell.pressed ? 0.88 : 1
                        Behavior on scale { Spring {} }
                    }
                    Label {
                        width: cell.width - 12
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.name
                        font.pixelSize: Theme.textLabel
                        font.weight: Font.Medium
                        color: grid.currentIndex === cell.index ? Theme.inkOnSecondaryContainer : Theme.ink
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                visible: grid.count === 0 && root.extras.length === 0
                text: !root.commandMode ? Lang.t("No apps found")
                    : (root.commandText.length > 0 ? Lang.t("Press Enter to run:  ") + root.commandText : Lang.t("Type a command, then press Enter"))
                color: Theme.inkMuted
            }
        }

        // Sums, settings, files, the web.
        Column {
            Layout.fillWidth: true
            visible: root.extras.length > 0
            spacing: 4
            Repeater {
                model: root.extras
                Pressable {
                    id: extra
                    required property var modelData
                    required property int index
                    readonly property bool on: root.chosen === index
                    width: parent.width
                    height: modelData.kind === "calc" ? 64 : 50
                    color: on ? Theme.secondaryContainer : (modelData.kind === "calc" ? Theme.surfaceContainerHighest : "transparent")
                    restRadius: on ? Theme.cornerL : Theme.cornerXL
                    Behavior on color { Tint {} }
                    onClicked: root.act(modelData)
                    onHoveredChanged: if (hovered) root.pick = index
                    NumberAnimation on opacity { from: 0; to: 1; duration: Motion.effects }

                    MIcon {
                        id: sign
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        icon: extra.modelData.icon
                        size: extra.modelData.kind === "calc" ? 28 : 22
                        color: extra.on ? Theme.inkOnSecondaryContainer : Theme.primary
                    }
                    Column {
                        anchors.left: sign.right
                        anchors.leftMargin: 14
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        Label {
                            width: parent.width
                            elide: Text.ElideMiddle
                            text: (extra.modelData.kind === "calc" ? "= " : "") + extra.modelData.title
                            font.pixelSize: extra.modelData.kind === "calc" ? Theme.textHeadline : Theme.textBody
                            font.weight: extra.modelData.kind === "calc" ? Font.Black : Font.DemiBold
                            color: extra.on ? Theme.inkOnSecondaryContainer : Theme.ink
                        }
                        Label {
                            width: parent.width
                            elide: Text.ElideMiddle
                            text: extra.modelData.hint
                            font.pixelSize: Theme.textLabelS
                            color: extra.on ? Theme.inkOnSecondaryContainer : Theme.inkMuted
                        }
                    }
                }
            }
        }
        Item { Layout.fillHeight: true; visible: !grid.visible }
    }
}
