import QtQuick
import Quickshell
import "../bar" as Bar
import "../center" as Center
import "../osd" as OSD
import "../notifications" as Notif

QtObject {
    id: root

    readonly property string themeStateFile: Quickshell.shellDir + "/theme-switcher/theme-state"

    property bool darkMode: true

    property QtObject darkBarTheme: Bar.DefaultTheme {}
    property QtObject lightBarTheme: Bar.LightTheme {}
    property QtObject barTheme: root.darkMode ? darkBarTheme : lightBarTheme

    property QtObject darkCenterTheme: Center.DefaultTheme {}
    property QtObject lightCenterTheme: Center.LightTheme {}
    property QtObject centerTheme: root.darkMode ? darkCenterTheme : lightCenterTheme

    property QtObject darkOsdTheme: OSD.DefaultTheme {}
    property QtObject lightOsdTheme: OSD.LightTheme {}
    property QtObject osdTheme: root.darkMode ? darkOsdTheme : lightOsdTheme

    property QtObject darkNotifTheme: Notif.DefaultTheme {}
    property QtObject lightNotifTheme: Notif.LightTheme {}
    property QtObject notifTheme: root.darkMode ? darkNotifTheme : lightNotifTheme

    Component.onCompleted: {
        readThemeState()
    }

    function readThemeState() {
        var cmd = "cat " + root.themeStateFile + " 2>/dev/null || echo dark"
        var reader = Qt.createQmlObject(
            'import Quickshell.Io; Process { command: ["sh", "-c", ' + JSON.stringify(cmd) + ']; stdout: StdioCollector { onStreamFinished: { root.darkMode = this.text.trim() !== "light" } } }',
            root,
            "themeReader"
        )
        if (reader) {
            reader.running = true
        }
    }

    function writeThemeState(dark) {
        var cmd = "mkdir -p $(dirname " + root.themeStateFile + ") && echo " + (dark ? "dark" : "light") + " > " + root.themeStateFile
        var writer = Qt.createQmlObject(
            'import Quickshell.Io; Process { command: ["sh", "-c", ' + JSON.stringify(cmd) + '] }',
            root,
            "themeWriter"
        )
        if (writer) {
            writer.running = true
        }
    }

    function toggle() {
        root.darkMode = !root.darkMode
        root.writeThemeState(root.darkMode)
    }
}
