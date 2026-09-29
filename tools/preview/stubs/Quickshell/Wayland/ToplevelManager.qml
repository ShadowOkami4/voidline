pragma Singleton
import QtQuick
QtObject { property var toplevels: ({ values: [
    { appId: "voidline-terminal", activated: true, activate: function() {} },
    { appId: "firefox", activated: false, activate: function() {} },
    { appId: "spotify", activated: false, activate: function() {} },
    { appId: "code", activated: false, activate: function() {} } ] }) }
