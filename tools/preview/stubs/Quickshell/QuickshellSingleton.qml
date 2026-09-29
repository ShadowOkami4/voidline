pragma Singleton
import QtQuick
QtObject { property string shellDir: "@SHELL_DIR@"; property var screens: []
  function env(n) { return n === "HOME" ? "@HOME@" : "" } function execDetached(c) {} function hasThemeIcon(n) { return false } function iconPath(n, f) { return "" } function reload() {} }
