import QtQuick
import QtQuick.Window
Item { id: w; property var color; property var screen: ({ name: "DP-1", width: 1920, height: 1080 }); property var mask; property int exclusionMode; property int exclusiveZone
  property bool focusable; property bool grabFocus; property bool aboveWindows; property string title; property var parentWindow; property var anchor; property var relativeX; property var relativeY
  property WindowAnchors windowAnchors: WindowAnchors {}; property WindowMargins margins: WindowMargins {}
  readonly property bool fillH: windowAnchors.left && windowAnchors.right
  readonly property bool fillV: windowAnchors.top && windowAnchors.bottom
  width: fillH && Window.window ? Window.window.width : implicitWidth
  height: fillV && Window.window ? Window.window.height : implicitHeight }
