pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../core"

QtObject {
    id: root

    property var games: []
    property bool loading: false
    property bool artworkRefreshing: false
    property bool apiConfigured: false
    property bool artworkAttempted: false
    property var artworkChoices: []
    property var artworkChoiceGame: null
    property bool artworkChoicesLoading: false
    property bool artworkSelecting: false
    property string artworkChoiceMessage: ""
    property string pendingArtworkAppId: ""
    property string pendingArtworkGridId: ""
    property string pendingArtworkUrl: ""
    property string message: ""
    property int revision: 0

    signal artworkApplied(string appId)

    function imageUrl(path) {
        if (!path || path.length === 0)
            return ""
        return path.startsWith("/") ? "file://" + path : path
    }

    function refresh(forceArtwork) {
        if (forceArtwork)
            artworkAttempted = false
        if (scanProcess.running)
            return
        loading = true
        message = "Scanning Steam libraries…"
        scanProcess.running = true
    }

    function parseLibrary(contents) {
        const rows = contents.trim().length > 0 ? contents.trim().split("\n") : []
        const next = []
        let configured = false
        for (let index = 0; index < rows.length; ++index) {
            const fields = rows[index].split("\t")
            if (fields[0] === "status" && fields[1] === "api") {
                configured = fields[2] === "1"
                continue
            }
            if (fields[0] !== "game" || fields.length < 5)
                continue
            next.push({
                appId: fields[1],
                name: fields[2],
                image: imageUrl(fields[3]),
                artworkSource: fields[4] === "steamgriddb" ? "SteamGridDB" : "Steam",
                key: "steam:" + fields[1]
            })
        }
        next.sort((left, right) => left.name.toLowerCase().localeCompare(right.name.toLowerCase()))
        games = next
        apiConfigured = configured
        loading = false
        message = next.length === 0 ? "No installed Steam games found" : ""
        revision++

        if (apiConfigured && !artworkAttempted && !artworkProcess.running) {
            artworkAttempted = true
            artworkRefreshing = true
            artworkProcess.running = true
        }
    }

    function filteredGames(query) {
        const currentRevision = revision
        const needle = String(query || "").toLowerCase().trim()
        if (needle.length === 0)
            return games
        const matches = []
        for (let index = 0; index < games.length; ++index) {
            if (games[index].name.toLowerCase().indexOf(needle) >= 0)
                matches.push(games[index])
        }
        return matches
    }

    function launch(game) {
        if (!game || !game.appId)
            return
        Quickshell.execDetached({ command: ["steam", "-applaunch", game.appId] })
    }

    function requestArtworkChoices(game) {
        if (!game || !game.appId || artworkChoicesProcess.running)
            return
        artworkChoiceGame = game
        artworkChoices = []
        artworkChoiceMessage = ""
        if (!apiConfigured) {
            artworkChoiceMessage = "Configure a SteamGridDB API key first"
            return
        }
        artworkChoicesLoading = true
        artworkChoicesProcess.running = true
    }

    function parseArtworkChoices(contents) {
        const rows = contents.trim().length > 0 ? contents.trim().split("\n") : []
        const next = []
        for (let index = 0; index < rows.length; ++index) {
            const fields = rows[index].split("\t")
            if (fields[0] !== "choice" || fields.length < 4)
                continue
            next.push({
                gridId: fields[1],
                url: fields[2],
                thumb: fields[3],
                key: "grid:" + fields[1]
            })
        }
        artworkChoices = next
        artworkChoiceMessage = next.length === 0
            ? "No alternate static portrait grids were found" : ""
    }

    function selectArtwork(choice) {
        if (!artworkChoiceGame || !choice || artworkSelecting)
            return
        pendingArtworkAppId = artworkChoiceGame.appId
        pendingArtworkGridId = choice.gridId
        pendingArtworkUrl = choice.url
        artworkSelecting = true
        artworkChoiceMessage = "Saving selected artwork…"
        artworkSelectProcess.running = true
    }

    property var scanProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/steam-library.sh", "scan"]
        stdout: StdioCollector { id: scanOutput }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                root.parseLibrary(scanOutput.text)
            else {
                root.loading = false
                root.message = "Steam libraries could not be read"
                root.games = []
                root.revision++
            }
        }
    }

    property var artworkProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/steam-library.sh", "artwork"]
        stdout: StdioCollector { id: artworkOutput }
        onExited: (exitCode, exitStatus) => {
            root.artworkRefreshing = false
            if (artworkOutput.text.trim().length > 0)
                root.refresh(false)
        }
    }

    property var artworkChoicesProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/steam-library.sh",
            "choices", root.artworkChoiceGame ? root.artworkChoiceGame.appId : ""]
        stdout: StdioCollector { id: artworkChoicesOutput }
        onExited: (exitCode, exitStatus) => {
            root.artworkChoicesLoading = false
            if (exitCode === 0)
                root.parseArtworkChoices(artworkChoicesOutput.text)
            else
                root.artworkChoiceMessage = "SteamGridDB artwork could not be loaded"
        }
    }

    property var artworkSelectProcess: Process {
        command: ["sh", Paths.shellRoot + "/scripts/steam-library.sh",
            "select-art", root.pendingArtworkAppId, root.pendingArtworkGridId,
            root.pendingArtworkUrl]
        onExited: (exitCode, exitStatus) => {
            root.artworkSelecting = false
            if (exitCode === 0) {
                const selectedAppId = root.pendingArtworkAppId
                root.artworkChoiceMessage = "Artwork updated"
                root.refresh(false)
                root.artworkApplied(selectedAppId)
            } else {
                root.artworkChoiceMessage = "The selected artwork could not be saved"
            }
            root.pendingArtworkAppId = ""
            root.pendingArtworkGridId = ""
            root.pendingArtworkUrl = ""
        }
    }
}
