pragma Singleton
import QtQuick
QtObject { property var focusedMonitor: null; property var monitors: ({ values: [] }); property var workspaces: ({ values: [] }); property var focusedWorkspace: ({ id: 2 }); function dispatch(x) {} }
