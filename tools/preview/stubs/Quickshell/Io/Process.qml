import QtQuick
QtObject { default property list<QtObject> data; property var command: []; property bool running; property var stdout; property var stderr; property var environment
  signal exited(int exitCode, int exitStatus); signal started() }
