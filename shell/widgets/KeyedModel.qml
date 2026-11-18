import QtQuick

// A list model that follows a JavaScript list by keys: entries that are new
// are inserted, gone ones removed, the rest moved into place. Unlike handing
// a ListView the plain list, nothing is rebuilt, so the view can animate
// single entries coming and going.
//
//   KeyedModel { id: m; keys: someList.map(x => x.id) }
//   delegate: Item { required property string key; readonly property var item: lookup[key] }
ListModel {
    id: model

    property var keys: []
    onKeysChanged: sync()

    function find(key, from) {
        for (let i = from; i < count; ++i) if (get(i).key === key) return i
        return -1
    }
    function sync() {
        const want = (keys || []).map(k => String(k))
        const wanted = {}
        for (const k of want) wanted[k] = true
        for (let i = count - 1; i >= 0; --i) if (!wanted[get(i).key]) remove(i)
        for (let i = 0; i < want.length; ++i) {
            if (i < count && get(i).key === want[i]) continue
            const at = find(want[i], i)
            if (at < 0) insert(i, { key: want[i] })
            else move(at, i, 1)
        }
    }
}
