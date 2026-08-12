pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Optional packages advertise themselves with a tiny manifest. The core shell
// never probes Ollama, downloads a model, or starts an AI process when this
// manifest is absent.
QtObject {
    id: root

    property bool aiInstalled: false
    property string aiDisplayName: "Lyra"
    property string aiPackageId: "voidline-ai"
    property string aiVersion: ""

    readonly property string userFeatureDir: Paths.dataRoot + "/features"
    readonly property string aiManifestPath: userFeatureDir + "/ai.json"
    readonly property string systemAiManifestPath: "/usr/share/voidline/features/ai.json"
    property string userAiManifest: ""
    property string systemAiManifest: ""

    function loadAiManifest(contents) {
        aiInstalled = false
        aiVersion = ""
        try {
            const manifest = JSON.parse(String(contents || "{}"))
            if (manifest.id !== "voidline-ai" || manifest.enabled === false)
                return
            aiInstalled = true
            aiDisplayName = String(manifest.name || "Lyra")
            aiVersion = String(manifest.version || "")
        } catch (error) {
            // A missing or malformed optional manifest is equivalent to the
            // feature not being installed; it is not a shell startup error.
        }
    }

    function refresh() {
        aiManifest.reload()
        systemAiManifestFile.reload()
    }

    function refreshAiState() {
        loadAiManifest(userAiManifest.length > 0
            ? userAiManifest : systemAiManifest)
    }

    property var aiManifest: FileView {
        path: root.aiManifestPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.userAiManifest = text()
            root.refreshAiState()
        }
    }

    property var systemAiManifestFile: FileView {
        path: root.systemAiManifestPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.systemAiManifest = text()
            root.refreshAiState()
        }
    }
}
