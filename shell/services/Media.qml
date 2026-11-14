pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// The media player to show and control: whichever is playing, otherwise the
// one used last. Works with anything that speaks MPRIS (browsers, Spotify,
// mpv, VLC, ...).
Singleton {
    id: root

    readonly property var players: Mpris.players.values.filter(p => p.canControl || p.trackTitle)
    property var last: null
    readonly property var player: players.find(p => p.isPlaying)
        ?? (last && players.includes(last) ? last : (players[0] ?? null))
    onPlayerChanged: if (player) last = player

    readonly property bool available: !!player
    readonly property bool playing: !!player && player.isPlaying
    readonly property string title: player ? (player.trackTitle || player.identity || "") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""
    readonly property string art: player ? (player.trackArtUrl || "") : ""
    readonly property string source: player ? (player.identity || "") : ""

    function toggle() { if (player && player.canTogglePlaying) player.togglePlaying() }
    function next() { if (player && player.canGoNext) player.next() }
    function previous() { if (player && player.canGoPrevious) player.previous() }
}
