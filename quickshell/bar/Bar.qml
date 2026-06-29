import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../notifications" as Notif

Scope {
    id: root
    property var theme: DefaultTheme {}
    property string font: "SF Pro Display"
    property bool barVisible: true

    // MPRIS active player
    property var activePlayer: {
        const players = Mpris.players.values;
        if (!players || players.length === 0) return null;
        for (const p of players) {
            if (p.playbackState === MprisPlaybackState.Playing) return p;
        }
        return players[0];
    }

    IpcHandler {
        target: "bar"
        function toggle(): void { root.barVisible = !root.barVisible; }
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    // Brightness state
    property real brightnessValue: 0
    property real brightnessMax: 1
    property bool micRecording: false
    property int pkgCount: 0
    property int pkgUpdates: 0
    property real mediaProgress: 0

    FileView {
        id: brightnessFile
        path: ""
        watchChanges: true
        onFileChanged: brightnessReadProc.running = true
    }

    Process {
        id: brightnessReadProc
        command: ["brightnessctl", "get"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const val = parseInt(text.trim());
                if (!isNaN(val) && root.brightnessMax > 0)
                root.brightnessValue = val / root.brightnessMax;
            }
        }
    }

    Process {
        id: brightnessSetProc
        running: false
    }

    Process {
        id: backlightDiscovery
        command: ["sh", "-c", "p=$(ls -d /sys/class/backlight/*/brightness 2>/dev/null | head -1); [ -n \"$p\" ] && echo \"$p\" && cat \"${p%brightness}max_brightness\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length >= 2) {
                    const max = parseInt(lines[1]);
                    if (!isNaN(max) && max > 0) root.brightnessMax = max;
                    brightnessFile.path = lines[0];
                    brightnessReadProc.running = true;
                }
            }
        }
    }

    // ── Mic recording detection ──────────────────────────
    Process {
        id: micRecProc
        command: ["sh", "-c", "pactl list source-outputs short 2>/dev/null | wc -l"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const count = parseInt(text.trim());
                root.micRecording = !isNaN(count) && count > 0;
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: micRecProc.running = true
    }

    Process { id: soundSettingsProc; running: false }

    // ── Package count & updates ───────────────────────────
    Process {
        id: pkgProc
        command: ["sh", "-c", "echo \"$(pacman -Q | wc -l):$(pacman -Qu 2>/dev/null | wc -l)\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(":");
                root.pkgCount = parseInt(parts[0]) || 0;
                root.pkgUpdates = parseInt(parts[1]) || 0;
            }
        }
    }

    Timer {
        interval: 300000 // 5 min
        running: true
        repeat: true
        onTriggered: pkgProc.running = true
    }

    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            if (root.activePlayer) {
                const pos = Number(root.activePlayer.position) || 0;
                const len = Number(root.activePlayer.length) || Number(root.activePlayer.metadata?.["mpris:length"]) || 0;
                root.mediaProgress = len > 0 ? pos / len : 0;
            } else {
                root.mediaProgress = 0;
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barPanel
            required property var modelData
            screen: modelData
            visible: root.barVisible

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: 32
            color: root.theme.bgBase

            Item {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10

                // Left section: Workspaces
                Row {
                    id: leftSection
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Workspaces
                    Row {
                        spacing: 3

                        Repeater {
                            model: 9

                            Rectangle {
                                id: wsPill
                                required property int index
                                readonly property int wsId: index + 1
                                readonly property var ws: Hyprland.workspaces.values.find(w => w.id === wsId)
                                readonly property bool isFocused: Hyprland.focusedWorkspace?.id === wsId
                                readonly property bool isUrgent: ws?.urgent ?? false
                                readonly property bool isOtherActive: (ws?.active ?? false) && !isFocused
                                readonly property bool hasWindows: ws != null && ws.toplevels.values.length > 0

                                property bool urgentBlink: false

                                Accessible.role: Accessible.Button
                                Accessible.name: "Workspace " + wsId + (isFocused ? ", active" : "") + (isUrgent ? ", urgent" : "")

                                width: isFocused ? 32 : 24
                                height: 24
                                radius: 12
                                border.width: isOtherActive ? 1 : 0
                                border.color: root.theme.accentPrimary
                                color: isFocused ? root.theme.accentPrimary :
                                isUrgent && urgentBlink ? root.theme.accentRed :
                                hasWindows ? root.theme.bgSelected :
                                root.theme.bgSurface

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                SequentialAnimation {
                                    loops: Animation.Infinite
                                    running: isUrgent && !isFocused

                                    PropertyAction { target: wsPill; property: "urgentBlink"; value: true }
                                    PauseAnimation { duration: 500 }
                                    PropertyAction { target: wsPill; property: "urgentBlink"; value: false }
                                    PauseAnimation { duration: 500 }

                                    onStopped: wsPill.urgentBlink = false
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: wsPill.wsId
                                    color: isFocused ? root.theme.textFocused : root.theme.textPrimary
                                    font.pixelSize: 11
                                    font.family: root.font
                                    font.bold: isFocused
                                }

                                Rectangle {
                                    width: 3
                                    height: 3
                                    radius: 1.5
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 3
                                    color: root.theme.accentPrimary
                                    visible: hasWindows && !isFocused
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: Hyprland.dispatch("workspace " + wsPill.wsId)
                                }

                                Behavior on width {
                                    NumberAnimation { duration: 150 }
                                }
                            }
                        }
                    }

                    // Now Playing
                    Rectangle {
                        height: 24
                        width: nowPlayingRow.width + 16
                        radius: 12
                        color: root.theme.bgSurface
                        visible: root.activePlayer !== null
                        clip: true

                        Accessible.role: Accessible.Button
                        Accessible.name: {
                            if (!root.activePlayer) return "No media";
                            const artist = root.activePlayer.trackArtist || "";
                            const title = root.activePlayer.trackTitle || "";
                            return "Now playing: " + (artist ? artist + " - " : "") + title;
                        }

                        Row {
                            id: nowPlayingRow
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            spacing: 2

                            Item {
                                width: 22
                                height: 22
                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    color: root.theme.textSecondary
                                    font.pixelSize: 11
                                    font.family: root.font
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activePlayer?.previous()
                                }
                            }

                            Item {
                                width: 22
                                height: 22
                                Text {
                                    anchors.centerIn: parent
                                    text: root.activePlayer?.isPlaying ? "" : ""
                                    color: root.theme.accentPrimary
                                    font.pixelSize: 11
                                    font.family: root.font
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activePlayer?.togglePlaying()
                                }
                            }

                            Item {
                                width: 22
                                height: 22
                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    color: root.theme.textSecondary
                                    font.pixelSize: 11
                                    font.family: root.font
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activePlayer?.next()
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    if (!root.activePlayer) return "";
                                    const artist = root.activePlayer.trackArtist || "";
                                    const title = root.activePlayer.trackTitle || "";
                                    return artist ? artist + " - " + title : title;
                                }
                                color: root.theme.textPrimary
                                font.pixelSize: 11
                                font.family: root.font
                                elide: Text.ElideRight
                                width: Math.min(implicitWidth, 160)
                            }

                            Row {
                                spacing: 2
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.activePlayer?.isPlaying ?? false

                                Repeater {
                                    model: 4

                                    Rectangle {
                                        width: 3
                                        height: 6
                                        radius: 1.5
                                        color: root.theme.accentPrimary
                                        anchors.verticalCenter: parent.verticalCenter

                                        NumberAnimation on height {
                                            duration: 300 + index * 100
                                            loops: Animation.Infinite
                                            from: 4
                                            to: 14
                                            running: root.activePlayer?.isPlaying ?? false
                                            easing.type: Easing.InOutSine
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Center section: Time (truly centered in bar)
                // Time
                Rectangle {
                    anchors.centerIn: parent
                    height: 24
                    width: timeDate.width + 16
                    radius: 12
                    color: root.theme.bgSurface

                    Row {
                        id: timeDate
                        anchors.centerIn: parent
                        spacing: 8

                        // Notification bell
                        Item {
                            width: 22
                            height: 24

                            Text {
                                anchors.centerIn: parent
                                text: Notif.NotificationService.count > 0 ? "󰂚" : "󰂛"
                                color: Notif.NotificationService.count > 0 ? root.theme.accentPrimary : root.theme.textSecondary
                                font.pixelSize: 14
                                font.family: root.font
                            }

                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                width: 14
                                height: 14
                                radius: 7
                                color: root.theme.accentRed
                                visible: Notif.NotificationService.count > 0

                                Text {
                                    anchors.centerIn: parent
                                    text: Math.min(Notif.NotificationService.count, 99)
                                    color: "#ffffff"
                                    font.pixelSize: 8
                                    font.bold: true
                                    font.family: root.font
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Notif.NotificationService.activeScreen = barPanel.screen;
                                    Notif.NotificationService.toggleCenter();
                                }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Time.timeString
                            color: root.theme.textPrimary
                            font.pixelSize: 12
                            font.family: root.font
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Time.dateString
                            color: root.theme.textSecondary
                            font.pixelSize: 12
                            font.family: root.font
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "●"
                            color: root.theme.textMuted
                            font.pixelSize: 6
                            visible: Time.hijriLoaded
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Time.hijriLoaded
                                  ? Time.hijriDay + " " + Time.hijriMonth + " " + Time.hijriYear + " AH"
                                  : ""
                            color: root.theme.textSecondary
                            font.pixelSize: 11
                            font.family: root.font
                            visible: Time.hijriLoaded
                        }
                    }

                    MouseArea {
                        id: clockHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Notif.NotificationService.activeScreen = barPanel.screen;
                            Notif.NotificationService.toggleCenter();
                        }
                    }
                }

                // Right section: System Info + System Tray
                Row {
                    id: rightSection
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // ── Volume | Brightness ─────────────────
                    Rectangle {
                        height: 24
                        width: volBrightRow.width + 12
                        radius: 12
                        color: root.theme.bgSurface

                        Row {
                            id: volBrightRow
                            anchors.centerIn: parent
                            spacing: 0

                            // ── Volume half ──────────────
                            MouseArea {
                                height: parent.height
                                width: volHalfRow.width + 6
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        soundSettingsProc.command = ["pavucontrol"];
                                        soundSettingsProc.running = true;
                                        return;
                                    }
                                    const sink = Pipewire.defaultAudioSink;
                                    if (sink && sink.audio) sink.audio.muted = !sink.audio.muted;
                                }
                                onWheel: (wheel) => {
                                    const sink = Pipewire.defaultAudioSink;
                                    if (!sink || !sink.audio) return;
                                    const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                                    sink.audio.volume = Math.max(0, Math.min(1.5, sink.audio.volume + delta));
                                }

                                Row {
                                    id: volHalfRow
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 6
                                    spacing: 6

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: {
                                            const sink = Pipewire.defaultAudioSink;
                                            if (!sink || !sink.audio || sink.audio.muted || sink.audio.volume <= 0) return "󰖁";
                                            if (sink.audio.volume < 0.33) return "󰕿";
                                            if (sink.audio.volume < 0.66) return "󰖀";
                                            return "󰕾";
                                        }
                                        color: {
                                            const sink = Pipewire.defaultAudioSink;
                                            if (!sink || !sink.audio || sink.audio.muted) return root.theme.textMuted;
                                            return root.theme.accentPrimary;
                                        }
                                        font.pixelSize: 14
                                        font.family: root.font
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: {
                                            const sink = Pipewire.defaultAudioSink;
                                            if (!sink || !sink.audio) return "–";
                                            if (sink.audio.muted) return "Mute";
                                            return Math.round(sink.audio.volume * 100) + "%";
                                        }
                                        color: root.theme.textPrimary
                                        font.pixelSize: 11
                                        font.family: root.font
                                    }
                                }
                            }

                            // Separator
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "|"
                                color: root.theme.textMuted
                                font.pixelSize: 11
                                font.family: root.font
                            }

                            // ── Mic half ──────────────────
                            MouseArea {
                                height: parent.height
                                width: micHalfRow.width + 6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const source = Pipewire.defaultAudioSource;
                                    if (source && source.audio) source.audio.muted = !source.audio.muted;
                                }

                                Row {
                                    id: micHalfRow
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 6
                                    spacing: 6

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: ""
                                        color: {
                                            const source = Pipewire.defaultAudioSource;
                                            if (!source || !source.audio) return root.theme.textMuted;
                                            if (source.audio.muted) return root.theme.textMuted;
                                            if (root.micRecording) return root.theme.accentRed;
                                            return root.theme.textMuted;
                                        }
                                        font.pixelSize: 14
                                        font.family: root.font
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: {
                                            const source = Pipewire.defaultAudioSource;
                                            if (!source || !source.audio) return "–";
                                            if (source.audio.muted) return "Mute";
                                            if (root.micRecording) return "On";
                                            return "–";
                                        }
                                        color: root.theme.textPrimary
                                        font.pixelSize: 11
                                        font.family: root.font
                                    }
                                }
                            }

                            // Separator
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "|"
                                color: root.theme.textMuted
                                font.pixelSize: 11
                                font.family: root.font
                            }

                            // ── Brightness half ─────────────
                            MouseArea {
                                height: parent.height
                                width: brightHalfRow.width + 6
                                cursorShape: Qt.PointingHandCursor
                                visible: brightnessFile.path !== ""
                                onWheel: (wheel) => {
                                    brightnessSetProc.command = wheel.angleDelta.y > 0
                                    ? ["brightnessctl", "set", "5%+"]
                                    : ["brightnessctl", "set", "5%-"];
                                    brightnessSetProc.running = true;
                                }

                                Row {
                                    id: brightHalfRow
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 6
                                    spacing: 6

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "󰃠"
                                        color: root.theme.accentOrange
                                        font.pixelSize: 14
                                        font.family: root.font
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Math.round(root.brightnessValue * 100) + "%"
                                        color: root.theme.textPrimary
                                        font.pixelSize: 11
                                        font.family: root.font
                                    }
                                }
                            }
                        }
                    }

                    // ── Packages ────────────────────────────
                    Rectangle {
                        height: 24
                        width: pkgHalfRow.width + 12
                        radius: 12
                        color: root.theme.bgSurface
                        visible: root.pkgCount > 0

                        Row {
                            id: pkgHalfRow
                            anchors.centerIn: parent
                            spacing: 6
                            anchors.leftMargin: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.pkgUpdates > 0 ? "" : ""
                                color: root.pkgUpdates > 0 ? root.theme.accentOrange : root.theme.textMuted
                                font.pixelSize: 14
                                font.family: root.font
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.pkgUpdates > 0 ? root.pkgUpdates + "" : root.pkgCount + ""
                                color: root.pkgUpdates > 0 ? root.theme.accentOrange : root.theme.textPrimary
                                font.pixelSize: 11
                                font.family: root.font
                            }
                        }
                    }

                    // System Info
                    Row {
                        id: sysInfo

                        readonly property color batteryColor: {
                            if (SystemInfo.batteryCharging) return root.theme.accentGreen;
                            if (SystemInfo.batteryLevelRaw > 20) return root.theme.batteryGood;
                            if (SystemInfo.batteryLevelRaw > 10) return root.theme.batteryWarning;
                            return root.theme.batteryCritical;
                        }

                        spacing: 4

                        Rectangle {
                            height: 24
                            width: cpuRamContent.width + 12
                            radius: 12
                            color: root.theme.bgSurface
                            Accessible.role: Accessible.StaticText
                            Accessible.name: "CPU: " + SystemInfo.cpuUsage

                            Row {
                                id: cpuRamContent
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰻠"
                                    color: root.theme.accentOrange
                                    font.pixelSize: 14
                                    font.family: root.font
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: SystemInfo.cpuUsage
                                    color: root.theme.textPrimary
                                    font.pixelSize: 11
                                    font.family: root.font
                                }

                                // Separator
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "|"
                                    color: root.theme.textMuted
                                    font.pixelSize: 11
                                    font.family: root.font
                                }

                                // RAM
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰍛"
                                    color: root.theme.accentCyan
                                    font.pixelSize: 14
                                    font.family: root.font
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: SystemInfo.memoryUsage
                                    color: root.theme.textPrimary
                                    font.pixelSize: 11
                                    font.family: root.font
                                }
                            }
                        }

                        // Network
                        Rectangle {
                            height: 24
                            width: netContent.width + 12
                            radius: 12
                            color: root.theme.bgSurface
                            Accessible.role: Accessible.StaticText
                            Accessible.name: {
                                if (SystemInfo.networkType === "ethernet") return "Network: Ethernet"
                                if (SystemInfo.networkType === "wifi") return "Network: WiFi " + SystemInfo.networkInfo
                                return "Network: Disconnected"
                            }

                            Row {
                                id: netContent
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        if (SystemInfo.networkType === "ethernet") return "󰈀"
                                        if (SystemInfo.networkType === "wifi") return "󰖩"
                                        return "󰖪"
                                    }
                                    color: SystemInfo.networkType === "disconnected" ? root.theme.textMuted : root.theme.accentGreen
                                    font.pixelSize: 14
                                    font.family: root.font
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: SystemInfo.networkInfo
                                    color: root.theme.textPrimary
                                    font.pixelSize: 11
                                    font.family: root.font
                                }
                            }
                        }

                        // Battery
                        Rectangle {
                            height: 24
                            width: battContent.width + 12
                            radius: 12
                            color: root.theme.bgSurface
                            Accessible.role: Accessible.StaticText
                            Accessible.name: "Battery: " + SystemInfo.batteryLevel

                            Row {
                                id: battContent
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: SystemInfo.batteryPlugged ? SystemInfo.pluggedIcon : SystemInfo.batteryIcon
                                    color: SystemInfo.batteryPlugged ? root.theme.accentGreen : sysInfo.batteryColor
                                    font.pixelSize: 14
                                    font.family: root.font
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: SystemInfo.batteryLevel
                                    color: root.theme.textPrimary
                                    font.pixelSize: 11
                                    font.family: root.font
                                    visible: !SystemInfo.batteryPlugged
                                }
                            }
                        }
                    }

                    // System Tray
                    Rectangle {
                        implicitHeight: 24
                        implicitWidth: trayIcons.implicitWidth + 4
                        radius: 12
                        color: root.theme.bgSurface

                        RowLayout {
                            id: trayIcons
                            anchors.centerIn: parent
                            spacing: 2

                            Repeater {
                                model: SystemTray.items

                                MouseArea {
                                    id: trayDelegate
                                    required property SystemTrayItem modelData

                                    Accessible.role: Accessible.Button
                                    Accessible.name: modelData.tooltipTitle || modelData.title || "System tray item"

                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24

                                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.LeftButton) {
                                            modelData.activate()
                                        } else if (mouse.button === Qt.RightButton) {
                                            if (modelData.hasMenu) {
                                                menuAnchor.open()
                                            }
                                        } else if (mouse.button === Qt.MiddleButton) {
                                            modelData.secondaryActivate()
                                        }
                                    }

                                    IconImage {
                                        anchors.centerIn: parent
                                        source: trayDelegate.modelData.icon
                                        implicitSize: 16
                                    }

                                    QsMenuAnchor {
                                        id: menuAnchor
                                        menu: trayDelegate.modelData.menu

                                        anchor.window: trayDelegate.QsWindow.window
                                        anchor.adjustment: PopupAdjustment.Flip
                                        anchor.onAnchoring: {
                                            const window = trayDelegate.QsWindow.window;
                                            const widgetRect = window.contentItem.mapFromItem(
                                            trayDelegate, 0, trayDelegate.height,
                                            trayDelegate.width, trayDelegate.height);
                                            menuAnchor.anchor.rect = widgetRect;
                                        }
                                    }
                                }
                            }
                        }
                    }


                }
            }
        }
    }
}
