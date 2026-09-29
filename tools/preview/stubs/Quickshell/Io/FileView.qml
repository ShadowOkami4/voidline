import QtQuick
QtObject {
    id: f
    default property list<QtObject> data
    property string path; property bool watchChanges; property bool printErrors; property bool blockLoading
    property string _text: ""
    signal loaded(); signal fileChanged(); signal loadFailed(var error)
    function text() { return _text }
    function setText(t) {}
    function reload() {
        if (!path) return
        const r = new XMLHttpRequest()
        r.open("GET", path.startsWith("file:") ? path : "file://" + path, false)
        try { r.send(); if (r.responseText) { _text = r.responseText; loaded() } } catch (e) {}
    }
    onPathChanged: Qt.callLater(reload)
}
