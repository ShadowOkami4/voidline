pragma Singleton
import QtQuick
QtObject {
    property var applications: ({ values: [] })
    function byId(id) { const known = { "org.gnome.Nautilus": "folder", "firefox": "public", "voidline-terminal": "terminal", "voidline-settings": "settings", "spotify": "music_note", "code": "code" }
        return known[id] ? { id: id, name: id, icon: "", execute: function() {} } : null }
    function heuristicLookup(id) { return byId(id) }
}
