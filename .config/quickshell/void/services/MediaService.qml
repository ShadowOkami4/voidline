pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

QtObject {
    id: root

    property var selectedPlayer: null
    property bool panelActive: false
    readonly property var players: Mpris.players.values || []
    readonly property var activePlayer: {
        if (selectedPlayer && players.indexOf(selectedPlayer) >= 0)
            return selectedPlayer
        for (let index = 0; index < players.length; ++index) {
            if (players[index] && players[index].isPlaying)
                return players[index]
        }
        return players.length > 0 ? players[0] : null
    }
    readonly property bool available: activePlayer !== null
    readonly property bool playing: available && activePlayer.isPlaying
    readonly property string title: available && activePlayer.trackTitle
        ? activePlayer.trackTitle : "Nothing playing"
    readonly property string artist: available && activePlayer.trackArtist
        ? activePlayer.trackArtist : (available ? activePlayer.identity : "Open a media app to begin")
    readonly property string album: available ? (activePlayer.trackAlbum || "") : ""
    readonly property string identity: available && activePlayer.identity
        ? activePlayer.identity : "Media"
    readonly property url artwork: available ? (activePlayer.trackArtUrl || "") : ""
    readonly property real position: available ? Math.max(0, activePlayer.position || 0) : 0
    readonly property real length: available ? Math.max(0, activePlayer.length || 0) : 0
    readonly property real progress: length > 0 ? Math.min(1, position / length) : 0
    readonly property bool shuffleSupported: available
        && activePlayer.shuffleSupported && activePlayer.canControl
    readonly property bool shuffled: shuffleSupported && activePlayer.shuffle
    readonly property bool loopSupported: available
        && activePlayer.loopSupported && activePlayer.canControl
    readonly property int loopState: loopSupported ? activePlayer.loopState : 0
    readonly property string lyrics: {
        if (!available || !activePlayer.metadata)
            return ""
        const value = activePlayer.metadata["xesam:asText"]
            || activePlayer.metadata["xesam:comment"] || ""
        return Array.isArray(value) ? value.join("\n") : String(value)
    }

    function selectPlayer(player) {
        if (player)
            selectedPlayer = player
    }

    function selectNextPlayer() {
        if (players.length < 2)
            return
        const index = players.indexOf(activePlayer)
        selectedPlayer = players[(index + 1) % players.length]
    }

    function previous() {
        if (activePlayer && activePlayer.canGoPrevious)
            activePlayer.previous()
    }

    function next() {
        if (activePlayer && activePlayer.canGoNext)
            activePlayer.next()
    }

    function togglePlaying() {
        if (activePlayer && activePlayer.canTogglePlaying)
            activePlayer.togglePlaying()
    }

    function seekTo(value) {
        if (!activePlayer || !activePlayer.canSeek || !activePlayer.positionSupported
                || length <= 0)
            return
        activePlayer.position = Math.max(0, Math.min(length, value * length))
    }

    function seekRelative(seconds) {
        if (!activePlayer || !activePlayer.canSeek || !activePlayer.positionSupported)
            return
        activePlayer.position = Math.max(0, Math.min(length,
            position + Number(seconds || 0)))
    }

    function raise() {
        if (activePlayer && activePlayer.canRaise)
            activePlayer.raise()
    }

    function toggleShuffle() {
        if (shuffleSupported)
            activePlayer.shuffle = !activePlayer.shuffle
    }

    function cycleLoop() {
        if (!loopSupported)
            return
        if (activePlayer.loopState === MprisLoopState.None)
            activePlayer.loopState = MprisLoopState.Track
        else if (activePlayer.loopState === MprisLoopState.Track)
            activePlayer.loopState = MprisLoopState.Playlist
        else
            activePlayer.loopState = MprisLoopState.None
    }

    function setPlayerVolume(value) {
        if (available && activePlayer.volumeSupported && activePlayer.canControl)
            activePlayer.volume = Math.max(0, Math.min(1, Number(value)))
    }

    function formatTime(seconds) {
        const safe = Math.max(0, Math.floor(Number(seconds) || 0))
        const minutes = Math.floor(safe / 60)
        const remainder = safe % 60
        return minutes + ":" + (remainder < 10 ? "0" : "") + remainder
    }

    property var positionTimer: Timer {
        interval: 1000
        repeat: true
        running: root.panelActive && root.playing && root.activePlayer !== null
        onTriggered: {
            // MPRIS position is intentionally non-reactive. Ask only while
            // the panel is visible to keep idle CPU use at zero.
            if (root.activePlayer)
                root.activePlayer.positionChanged()
        }
    }
}
