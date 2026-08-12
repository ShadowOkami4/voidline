import Quickshell
import Quickshell.Wayland
import QtQuick
import "../core"
import "../services"

Scope {
    WlSessionLock {
        id: sessionLock
        locked: LockService.locked

        WlSessionLockSurface {
            color: Theme.background

            LockSurface {
                anchors.fill: parent
            }
        }
    }
}
