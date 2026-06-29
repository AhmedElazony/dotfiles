import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../notifications" as Notif
import "../bar" as BarTime

Scope {
    id: root
    property var theme: DefaultTheme {}
    property var themeSwitcher: null
    property string font: "SF Pro Display"

    property var activePlayer: {
        const players = Mpris.players.values;
        if (!players || players.length === 0) return null;
        for (const p of players) {
            if (p.playbackState === MprisPlaybackState.Playing) return p;
        }
        return players[0];
    }

    readonly property bool hasPlayer: root.activePlayer !== null

    Process {
        id: themeProcess
        running: false
    }

    // ── Calendar state ──────────────────────────────────────
    property int calYear:  Qt.formatDateTime(new Date(), "yyyy") * 1
    property int calMonth: Qt.formatDateTime(new Date(), "M")    * 1
    property bool calExpanded: false

    readonly property var monthNames: [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
    ]
    readonly property var dayNames: ["Mo","Tu","We","Th","Fr","Sa","Su"]
    readonly property var hijriMonthNames: [
        "Muharram","Safar","Rabi' I","Rabi' II",
        "Jumada I","Jumada II","Rajab","Sha'ban",
        "Ramadan","Shawwal","Dhu al-Qi'dah","Dhu al-Hijjah"
    ]

    readonly property int todayYear:  Qt.formatDateTime(new Date(), "yyyy") * 1
    readonly property int todayMonth: Qt.formatDateTime(new Date(), "M")    * 1
    readonly property int todayDay:   Qt.formatDateTime(new Date(), "d")    * 1

    // Hijri today reference
    property var hijriToday: ({})
    property var hijriMonthData: []
    property int hijriFetchId: 0

    function fetchHijriMonth() {
        const id = ++root.hijriFetchId;
        const req = new XMLHttpRequest();
        req.open("GET", "https://api.aladhan.com/v1/gToHCalendar/" + root.calMonth + "/" + root.calYear);
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.DONE && req.status === 200) {
                if (id !== root.hijriFetchId) return;
                try {
                    const data = JSON.parse(req.responseText);
                    if (data.code === 200) root.hijriMonthData = data.data;
                } catch (e) {}
            }
        };
        req.send();
    }

    function fetchHijriToday() {
        const dd = ("0" + root.todayDay).slice(-2);
        const mm = ("0" + root.todayMonth).slice(-2);
        const req = new XMLHttpRequest();
        req.open("GET", "https://api.aladhan.com/v1/gToH?date=" + dd + "-" + mm + "-" + root.todayYear);
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.DONE && req.status === 200) {
                try {
                    const data = JSON.parse(req.responseText);
                    if (data.code === 200) {
                        root.hijriToday = {
                            day: data.data.hijri.day,
                            month: data.data.hijri.month.number,
                            year: data.data.hijri.year
                        };
                    }
                } catch (e) {}
            }
        };
        req.send();
    }

    function firstWeekday(year, month) {
        const d = new Date(year, month - 1, 1).getDay();
        return (d + 6) % 7;
    }

    function daysInMonth(year, month) {
        return new Date(year, month, 0).getDate();
    }

    function buildCells(year, month) {
        const cells = [];
        const offset = firstWeekday(year, month);
        const total  = daysInMonth(year, month);
        for (let i = 0; i < offset; i++) cells.push(0);
        for (let d = 1; d <= total; d++) cells.push(d);
        while (cells.length < 42) cells.push(0);
        return cells;
    }

    property var cells: root.buildCells(root.calYear, root.calMonth)

    onCalYearChanged: root.fetchHijriMonth()
    onCalMonthChanged: root.fetchHijriMonth()

    Component.onCompleted: {
        root.fetchHijriMonth();
        root.fetchHijriToday();
    }

    // ── Media helpers ───────────────────────────────────────
    function formatTime(us) {
        if (!us || us <= 0) return "0:00";
        const totalSec = Math.floor(Number(us) / 1000000);
        const m = Math.floor(totalSec / 60);
        const s = totalSec % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function posText() {
        if (!root.hasPlayer) return "0:00";
        return root.formatTime(Number(root.activePlayer.position) || 0);
    }

    function lenText() {
        if (!root.hasPlayer) return "0:00";
        const player = root.activePlayer;
        let l = Number(player.length) || 0;
        if ((!l || l <= 0) && player.metadata)
            l = Number(player.metadata["mpris:length"]) || 0;
        return root.formatTime(l);
    }

    property double mediaProgress: 0
    property int mediaTick: 0

    // ── Power ───────────────────────────────────────────────
    property bool powerExpanded: false
    Process { id: powerProc; running: false }

    function powerAction(cmd) {
        powerExpanded = false;
        powerProc.command = cmd;
        powerProc.running = true;
    }

    // ── Window ──────────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: centerWin
            required property var modelData
            screen: modelData

            visible: Notif.NotificationService.centerVisible
                     && (Notif.NotificationService.activeScreen === null
                         || screen === Notif.NotificationService.activeScreen)
            focusable: true
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Automatic
            WlrLayershell.namespace: "quickshell-control-center"
            exclusionMode: ExclusionMode.Ignore

            anchors { top: true; left: true; right: true; bottom: true }

            // Backdrop — close when clicking outside the panel
            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => {
                    const pos = mapToItem(panel, mouse.x, mouse.y);
                    if (pos.x < 0 || pos.y < 0
                        || pos.x > panel.width || pos.y > panel.height) {
                        Notif.NotificationService.centerVisible = false;
                        Notif.NotificationService.activeScreen = null;
                    }
                }
            }

            // ── Main Panel ──────────────────────────────────
            Rectangle {
                id: panel
                anchors.top: parent.top
                anchors.topMargin: 36
                anchors.horizontalCenter: parent.horizontalCenter
                width: 420
                radius: 16
                clip: true
                color: root.theme.bgBase
                border.color: root.theme.bgBorder
                border.width: 1

                implicitHeight: Math.min(Math.max(flickable.contentHeight, 200), 960)

                Flickable {
                    id: flickable
                    anchors.fill: parent
                    contentHeight: layout.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height

                    ColumnLayout {
                        id: layout
                        width: parent.width
                        spacing: 0

                    // ════════════════════════════════════════
                    //  HEADER
                    // ════════════════════════════════════════
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 18
                        Layout.rightMargin: 10
                        Layout.topMargin: 14
                        Layout.bottomMargin: 10
                        spacing: 8

                        Text {
                            text: "Control Center"
                            color: root.theme.textPrimary
                            font.pixelSize: 15
                            font.family: root.font
                            font.bold: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: dndLabel.width + 26
                            radius: 15
                            color: Notif.NotificationService.doNotDisturb
                                   ? root.theme.accentRed : root.theme.bgSurface
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text {
                                id: dndLabel
                                anchors.centerIn: parent
                                text: Notif.NotificationService.doNotDisturb
                                      ? "󰞃  DND" : "󰂛  DND"
                                color: Notif.NotificationService.doNotDisturb
                                       ? "#ffffff" : root.theme.textPrimary
                                font.pixelSize: 11
                                font.family: root.font
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Notif.NotificationService.doNotDisturb
                                    = !Notif.NotificationService.doNotDisturb
                            }
                        }

                        // ── Theme toggle ─────────────────────
                        Rectangle {
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: 30
                            radius: 15
                            color: themeBtn.containsMouse
                                   ? root.theme.bgHover : root.theme.bgSurface
                            Layout.alignment: Qt.AlignVCenter
                            Text {
                                anchors.centerIn: parent
                                text: root.themeSwitcher
                                      ? (root.themeSwitcher.darkMode ? "" : "") : ""
                                color: root.theme.textSecondary
                                font.pixelSize: 12
                                font.family: root.font
                            }
                            MouseArea {
                                id: themeBtn
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.themeSwitcher) {
                                        const wasDark = root.themeSwitcher.darkMode;
                                        root.themeSwitcher.toggle();
                                        themeProcess.command = [
                                            "/home/ahmedelazony/.config/quickshell/theme-switcher/switch-theme.sh",
                                            wasDark ? "light" : "dark"
                                        ];
                                        themeProcess.running = true;
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 30; height: 30; radius: 15
                            color: closeHover.containsMouse
                                   ? root.theme.bgBorder : "transparent"
                            Layout.alignment: Qt.AlignVCenter
                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                color: closeHover.containsMouse
                                       ? root.theme.accentRed : root.theme.textMuted
                                font.pixelSize: 14
                                font.family: root.font
                            }
                            MouseArea {
                                id: closeHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Notif.NotificationService.centerVisible = false;
                                    Notif.NotificationService.activeScreen = null;
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: root.theme.bgBorder
                    }

                    // ════════════════════════════════════════
                    //  DATE ROW  (Gregorian + Hijri)
                    // ════════════════════════════════════════
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 18
                        Layout.rightMargin: 14
                        Layout.topMargin: 10
                        Layout.bottomMargin: 6
                        spacing: 8

                        Text {
                            text: Qt.formatDateTime(new Date(), "dddd, d MMMM yyyy")
                            color: root.theme.textPrimary
                            font.pixelSize: 13
                            font.family: root.font
                            font.bold: true
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: BarTime.Time.hijriLoaded
                                  ? BarTime.Time.hijriDay + " " + BarTime.Time.hijriMonth + " " + BarTime.Time.hijriYear + " AH"
                                  : ""
                            color: root.theme.textSecondary
                            font.pixelSize: 12
                            font.family: root.font
                            horizontalAlignment: Text.AlignRight
                            visible: BarTime.Time.hijriLoaded
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: root.theme.bgBorder
                    }

                    // ════════════════════════════════════════
                    //  MEDIA CARD  (expanded)
                    // ════════════════════════════════════════
                    Rectangle {
                        id: mediaCard
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.hasPlayer ? 180 : 0
                        clip: true
                        visible: root.hasPlayer

                        // Background album art
                        Image {
                            anchors.fill: parent
                            source: root.hasPlayer && root.activePlayer.trackArtUrl
                                    ? root.activePlayer.trackArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: root.activePlayer && root.activePlayer.trackArtUrl !== ""
                        }

                        // Dark overlay
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0.0; color: "#dd000000" }
                                GradientStop { position: 0.5; color: "#99000000" }
                                GradientStop { position: 1.0; color: "#cc000000" }
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 0

                            // ── Top row: album art + info ──
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                // Album art
                                Item {
                                    Layout.preferredWidth: 80
                                    Layout.preferredHeight: 80

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 12
                                        clip: true
                                        color: root.theme.bgSurface
                                        visible: root.activePlayer
                                                 && root.activePlayer.trackArtUrl !== ""
                                        Image {
                                            anchors.fill: parent
                                            source: root.activePlayer
                                                    ? root.activePlayer.trackArtUrl || "" : ""
                                            fillMode: Image.PreserveAspectCrop
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 12
                                        color: root.theme.bgSurface
                                        visible: !root.activePlayer
                                                 || root.activePlayer.trackArtUrl === ""
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰓇"
                                            color: root.theme.accentPrimary
                                            font.pixelSize: 34
                                            font.family: root.font
                                        }
                                    }
                                }

                                // Track info
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 3

                                    Text {
                                        text: root.activePlayer
                                              ? root.activePlayer.trackTitle || "Unknown" : ""
                                        color: "#ffffff"
                                        font.pixelSize: 15
                                        font.family: root.font
                                        font.bold: true
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: root.activePlayer
                                              ? root.activePlayer.trackArtist || "" : ""
                                        color: "#cccccc"
                                        font.pixelSize: 12
                                        font.family: root.font
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        visible: text !== ""
                                    }

                                    Text {
                                        text: root.activePlayer
                                              ? root.activePlayer.identity || "" : ""
                                        color: "#999999"
                                        font.pixelSize: 10
                                        font.family: root.font
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        visible: root.activePlayer
                                                 && root.activePlayer.identity !== ""
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }

                            // ── Progress bar ────────────────
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: root.mediaTick ? root.posText() : "0:00"
                                    color: "#aaaaaa"
                                    font.pixelSize: 10
                                    font.family: root.font
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 18
                                    Layout.alignment: Qt.AlignVCenter

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width
                                        height: 4
                                        radius: 2
                                        color: "#33ffffff"

                                        Rectangle {
                                            width: parent.width * root.mediaProgress
                                            height: parent.height
                                            radius: 2
                                            color: root.theme.accentPrimary
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (!root.hasPlayer) return;
                                            const player = root.activePlayer;
                                            let l = Number(player.length) || 0;
                                            if ((!l || l <= 0) && player.metadata)
                                                l = Number(player.metadata["mpris:length"]) || 0;
                                            if (l > 0) {
                                                const ratio = mouse.x / width;
                                                player.setPosition(ratio * l);
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: root.mediaTick ? root.lenText() : "0:00"
                                    color: "#aaaaaa"
                                    font.pixelSize: 10
                                    font.family: root.font
                                }
                            }

                            Item { height: 10 }

                            // ── Controls ────────────────────
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 8

                                Item { Layout.fillWidth: true }

                                // Shuffle
                                Rectangle {
                                    width: 36; height: 36; radius: 18
                                    color: root.theme.bgOverlay
                                    visible: false
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰒝"
                                        color: "#ffffff"
                                        font.pixelSize: 15
                                        font.family: root.font
                                    }
                                }

                                // Previous
                                Rectangle {
                                    width: 36; height: 36; radius: 18
                                    color: prevHov.containsMouse
                                           ? root.theme.accentPrimary : root.theme.bgOverlay
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: ""
                                        color: "#ffffff"
                                        font.pixelSize: 16
                                        font.family: root.font
                                    }
                                    MouseArea {
                                        id: prevHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (root.activePlayer)
                                                root.activePlayer.previous();
                                        }
                                    }
                                }

                                // Play / Pause
                                Rectangle {
                                    width: 42; height: 42; radius: 21
                                    color: playHov.containsMouse
                                           ? root.theme.accentPrimary : root.theme.bgOverlay
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.activePlayer
                                              && root.activePlayer.isPlaying
                                              ? "" : ""
                                        color: "#ffffff"
                                        font.pixelSize: 16
                                        font.family: root.font
                                    }
                                    MouseArea {
                                        id: playHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (root.activePlayer)
                                                root.activePlayer.togglePlaying();
                                        }
                                    }
                                }

                                // Next
                                Rectangle {
                                    width: 36; height: 36; radius: 18
                                    color: nextHov.containsMouse
                                           ? root.theme.accentPrimary : root.theme.bgOverlay
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: ""
                                        color: "#ffffff"
                                        font.pixelSize: 16
                                        font.family: root.font
                                    }
                                    MouseArea {
                                        id: nextHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (root.activePlayer)
                                                root.activePlayer.next();
                                        }
                                    }
                                }

                                // Repeat
                                Rectangle {
                                    width: 36; height: 36; radius: 18
                                    color: root.theme.bgOverlay
                                    visible: false
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰕇"
                                        color: "#ffffff"
                                        font.pixelSize: 15
                                        font.family: root.font
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: root.hasPlayer ? 1 : 0
                        color: root.theme.bgBorder
                        visible: root.hasPlayer
                    }

                    // ════════════════════════════════════════
                    //  CALENDAR  (collapsible)
                    // ════════════════════════════════════════
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: calHeader.height
                        color: "transparent"

                        RowLayout {
                            id: calHeader
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 18
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            height: 40
                            spacing: 8

                            Text {
                                text: "󰸗  Calendar"
                                color: root.theme.textPrimary
                                font.pixelSize: 13
                                font.family: root.font
                                font.bold: true
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: root.calExpanded ? "󰼽" : "󰼾"
                                color: root.theme.textMuted
                                font.pixelSize: 12
                                font.family: root.font
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.calExpanded = !root.calExpanded
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        Layout.bottomMargin: 8
                        spacing: 6
                        visible: root.calExpanded

                        // Month navigation
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Rectangle {
                                width: 28; height: 28; radius: 14
                                color: calPrevHov.containsMouse
                                       ? root.theme.bgBorder : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰍞"
                                    color: root.theme.textMuted
                                    font.pixelSize: 14
                                    font.family: root.font
                                }
                                MouseArea {
                                    id: calPrevHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.calMonth === 1) {
                                            root.calMonth = 12;
                                            root.calYear -= 1;
                                        } else {
                                            root.calMonth -= 1;
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: root.monthNames[root.calMonth - 1] + "  " + root.calYear
                                    color: root.theme.textPrimary
                                    font.pixelSize: 13
                                    font.bold: true
                                    font.family: root.font
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: {
                                        if (root.hijriMonthData.length === 0) return "";
                                        const d = root.hijriMonthData;
                                        const first = d[0].hijri;
                                        const last = d[d.length - 1].hijri;
                                        const firstM = Number(first.month.number);
                                        const lastM = Number(last.month.number);
                                        if (firstM !== lastM || first.year !== last.year) {
                                            return root.hijriMonthNames[firstM - 1] + " " + first.year
                                                + "  –  " + root.hijriMonthNames[lastM - 1] + " " + last.year + " AH";
                                        }
                                        return root.hijriMonthNames[firstM - 1] + " " + first.year + " AH";
                                    }
                                    color: root.theme.textMuted
                                    font.pixelSize: 10
                                    font.family: root.font
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            Rectangle {
                                width: 28; height: 28; radius: 14
                                color: calNextHov.containsMouse
                                       ? root.theme.bgBorder : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰍟"
                                    color: root.theme.textMuted
                                    font.pixelSize: 14
                                    font.family: root.font
                                }
                                MouseArea {
                                    id: calNextHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.calMonth === 12) {
                                            root.calMonth = 1;
                                            root.calYear += 1;
                                        } else {
                                            root.calMonth += 1;
                                        }
                                    }
                                }
                            }
                        }

                        // Day-of-week headers
                        Grid {
                            columns: 7
                            Layout.fillWidth: true
                            columnSpacing: 0
                            rowSpacing: 0

                            Repeater {
                                model: root.dayNames
                                delegate: Item {
                                    required property string modelData
                                    required property int index
                                    width: (parent.width) / 7
                                    height: 24
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: index >= 5
                                               ? root.theme.accentRed
                                               : root.theme.textMuted
                                        font.pixelSize: 10
                                        font.family: root.font
                                        font.bold: true
                                    }
                                }
                            }
                        }

                        // Day grid
                        Grid {
                            id: dayGrid
                            columns: 7
                            Layout.fillWidth: true
                            columnSpacing: 0
                            rowSpacing: 2

                            Repeater {
                                model: root.cells.length
                                delegate: Item {
                                    required property int index
                                    readonly property int dayVal: root.cells[index]
                                    readonly property int col: index % 7
                                    readonly property bool isWeekend: col >= 5
                                    readonly property bool isToday: dayVal > 0
                                        && dayVal === root.todayDay
                                        && root.calMonth === root.todayMonth
                                        && root.calYear === root.todayYear
                                    readonly property bool hijriMonthStart: dayVal > 1
                                        && root.hijriMonthData.length >= dayVal
                                        && Number(root.hijriMonthData[dayVal - 1].hijri.month.number)
                                           !== Number(root.hijriMonthData[dayVal - 2].hijri.month.number)

                                    width: dayGrid.width / 7
                                    height: 36

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 28; height: 28; radius: 14
                                        color: isToday
                                               ? root.theme.accentPrimary : "transparent"
                                    }

                                    Rectangle {
                                        width: 14
                                        height: 2
                                        radius: 1
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: parent.top
                                        anchors.topMargin: 3
                                        color: root.theme.accentPrimary
                                        visible: hijriMonthStart
                                    }

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: -1

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: dayVal > 0 ? dayVal : ""
                                            color: isToday   ? root.theme.bgBase
                                                 : isWeekend ? root.theme.accentRed
                                                 :              root.theme.textPrimary
                                            font.pixelSize: 12
                                            font.family: root.font
                                            font.bold: isToday
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: dayVal > 0 && root.hijriMonthData.length >= dayVal
                                                ? root.hijriMonthData[dayVal - 1].hijri.day
                                                : ""
                                            color: root.theme.textMuted
                                            font.pixelSize: 8
                                            font.family: root.font
                                        }
                                    }
                                }
                            }
                        }

                        // Today jump
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            height: 24
                            width: todayLabel.width + 24
                            radius: 12
                            color: todayJumpHov.containsMouse
                                   ? root.theme.accentPrimary : root.theme.bgSurface
                            Behavior on color { ColorAnimation { duration: 120 } }
                            visible: root.calMonth !== root.todayMonth
                                     || root.calYear !== root.todayYear

                            Text {
                                id: todayLabel
                                anchors.centerIn: parent
                                text: "Today"
                                color: todayJumpHov.containsMouse
                                       ? root.theme.bgBase : root.theme.textMuted
                                font.pixelSize: 11
                                font.family: root.font
                            }
                            MouseArea {
                                id: todayJumpHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.calYear  = root.todayYear;
                                    root.calMonth = root.todayMonth;
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: root.theme.bgBorder
                    }

                    // ════════════════════════════════════════
                    //  NOTIFICATIONS
                    // ════════════════════════════════════════
                    Text {
                        Layout.leftMargin: 18
                        Layout.topMargin: 10
                        Layout.bottomMargin: 4
                        text: "Notifications"
                        color: root.theme.textMuted
                        font.pixelSize: 11
                        font.family: root.font
                        font.bold: true
                        visible: Notif.NotificationService.notifications.length > 0
                    }

                    // ── Scrollable list ─────────────────────
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(notifList.implicitHeight, 320)
                        clip: true
                        visible: Notif.NotificationService.notifications.length > 0

                        Flickable {
                            anchors.fill: parent
                            contentHeight: notifList.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: notifList
                                width: parent.width
                                spacing: 4

                                Repeater {
                                    model: ScriptModel {
                                        values: Notif.NotificationService.notifications
                                        objectProp: "seqId"
                                    }

                                    Rectangle {
                                        id: notifCard
                                        required property var modelData
                                        required property int index

                                        Layout.fillWidth: true
                                        Layout.preferredHeight: notifBody.implicitHeight + 24
                                        Layout.leftMargin: 10
                                        Layout.rightMargin: 10
                                        radius: 10
                                        color: root.theme.bgSurface

                                        Rectangle {
                                            width: 3
                                            height: parent.height - 14
                                            radius: 2
                                            anchors.left: parent.left
                                            anchors.leftMargin: 5
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: modelData.urgency
                                                   === NotificationUrgency.Critical
                                                   ? root.theme.urgencyCritical
                                                   : modelData.urgency
                                                     === NotificationUrgency.Low
                                                   ? root.theme.urgencyLow
                                                   : root.theme.urgencyNormal
                                        }

                                        ColumnLayout {
                                            id: notifBody
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 10
                                            anchors.topMargin: 12
                                            anchors.bottomMargin: 12
                                            spacing: 5

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                Item {
                                                    Layout.preferredWidth: 16
                                                    Layout.preferredHeight: 16
                                                    Layout.alignment: Qt.AlignVCenter
                                                    IconImage {
                                                        anchors.centerIn: parent
                                                        source: Quickshell.iconPath(
                                                            modelData.appIcon, true)
                                                        implicitSize: 16
                                                        visible: modelData.appIcon !== ""
                                                    }
                                                    Text {
                                                        anchors.centerIn: parent
                                                        visible: modelData.appIcon === ""
                                                        text: "󰂚"
                                                        color: root.theme.urgencyNormal
                                                        font.pixelSize: 14
                                                        font.family: root.font
                                                    }
                                                }

                                                Text {
                                                    text: modelData.appName || "Notification"
                                                    color: root.theme.textMuted
                                                    font.pixelSize: 11
                                                    font.family: root.font
                                                    Layout.alignment: Qt.AlignVCenter
                                                }

                                                Item { Layout.fillWidth: true }

                                                Rectangle {
                                                    width: 22; height: 22; radius: 11
                                                    color: closeNotifHover.containsMouse
                                                           ? root.theme.bgBorder
                                                           : "transparent"
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "󰅖"
                                                        color: closeNotifHover.containsMouse
                                                               ? root.theme.accentRed
                                                               : root.theme.textMuted
                                                        font.pixelSize: 12
                                                        font.family: root.font
                                                    }
                                                    MouseArea {
                                                        id: closeNotifHover
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: modelData.dismiss()
                                                    }
                                                }
                                            }

                                            Text {
                                                text: modelData.summary
                                                color: root.theme.textPrimary
                                                font.pixelSize: 13
                                                font.family: root.font
                                                font.bold: true
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                                visible: text !== ""
                                            }

                                            Text {
                                                text: modelData.body
                                                color: root.theme.textSecondary
                                                font.pixelSize: 12
                                                font.family: root.font
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 3
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                                visible: text !== ""
                                                textFormat: Text.PlainText
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6
                                                visible: modelData.actions.length > 0
                                                Repeater {
                                                    model: modelData.actions
                                                    Rectangle {
                                                        id: actionBtn
                                                        required property var modelData
                                                        Layout.preferredHeight: 26
                                                        Layout.preferredWidth: actionText.width + 16
                                                        radius: 6
                                                        color: actHover.containsMouse
                                                               ? root.theme.bgBorder
                                                               : root.theme.bgSurface
                                                        Behavior on color {
                                                            ColorAnimation { duration: 100 }
                                                        }
                                                        Text {
                                                            id: actionText
                                                            anchors.centerIn: parent
                                                            text: actionBtn.modelData.text || ""
                                                            color: root.theme.accentPrimary
                                                            font.pixelSize: 11
                                                            font.family: root.font
                                                        }
                                                        MouseArea {
                                                            id: actHover
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: notifCard.modelData
                                                                .invokeAction(
                                                                    actionBtn.modelData.identifier)
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

                    // ── Empty state ─────────────────────────
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 24
                        Layout.bottomMargin: 24
                        text: "No notifications"
                        color: root.theme.textMuted
                        font.pixelSize: 12
                        font.family: root.font
                        visible: Notif.NotificationService.notifications.length === 0
                    }

                    // ── Clear All ───────────────────────────
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 4
                        Layout.bottomMargin: 6
                        height: 30
                        width: clearLabel.width + 28
                        radius: 15
                        color: clearHover.containsMouse
                               ? root.theme.bgBorder : "transparent"
                        visible: Notif.NotificationService.notifications.length > 0
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            id: clearLabel
                            anchors.centerIn: parent
                            text: "Clear All"
                            color: clearHover.containsMouse
                                   ? root.theme.accentRed : root.theme.textMuted
                            font.pixelSize: 11
                            font.family: root.font
                        }
                        MouseArea {
                            id: clearHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notif.NotificationService.dismissAll()
                        }
                    }

                    // ════════════════════════════════════════
                    //  POWER GRID  (collapsible)
                    // ════════════════════════════════════════
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: root.theme.bgBorder
                        Layout.topMargin: 4
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        color: "transparent"

                        RowLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 18
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Text {
                                text: "󰐥  Power"
                                color: root.theme.textPrimary
                                font.pixelSize: 13
                                font.family: root.font
                                font.bold: true
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: root.powerExpanded ? "󰼽" : "󰼾"
                                color: root.theme.textMuted
                                font.pixelSize: 12
                                font.family: root.font
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.powerExpanded = !root.powerExpanded
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        Layout.bottomMargin: 14
                        columns: 3
                        columnSpacing: 6
                        rowSpacing: 6
                        visible: root.powerExpanded

                        // Lock
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: 10
                            color: lockHov.containsMouse
                                   ? root.theme.accentCyan : root.theme.bgSurface
                            Behavior on color { ColorAnimation { duration: 120 } }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    text: "󰌾"
                                    color: lockHov.containsMouse
                                           ? root.theme.bgBase : root.theme.accentCyan
                                    font.pixelSize: 16
                                    font.family: root.font
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    text: "Lock"
                                    color: lockHov.containsMouse
                                           ? root.theme.bgBase : root.theme.textSecondary
                                    font.pixelSize: 10
                                    font.family: root.font
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            MouseArea {
                                id: lockHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.powerAction(["loginctl", "lock-session"])
                            }
                        }

                        // Suspend
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: 10
                            color: suspendHov.containsMouse
                                   ? root.theme.accentCyan : root.theme.bgSurface
                            Behavior on color { ColorAnimation { duration: 120 } }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    text: "󰤄"
                                    color: suspendHov.containsMouse
                                           ? root.theme.bgBase : root.theme.accentCyan
                                    font.pixelSize: 16
                                    font.family: root.font
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    text: "Suspend"
                                    color: suspendHov.containsMouse
                                           ? root.theme.bgBase : root.theme.textSecondary
                                    font.pixelSize: 10
                                    font.family: root.font
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            MouseArea {
                                id: suspendHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.powerAction(["systemctl", "suspend"])
                            }
                        }

                        // Hibernate
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: 10
                            color: hibernateHov.containsMouse
                                   ? root.theme.accentCyan : root.theme.bgSurface
                            Behavior on color { ColorAnimation { duration: 120 } }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    text: "󰒲"
                                    color: hibernateHov.containsMouse
                                           ? root.theme.bgBase : root.theme.accentCyan
                                    font.pixelSize: 16
                                    font.family: root.font
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    text: "Hibernate"
                                    color: hibernateHov.containsMouse
                                           ? root.theme.bgBase : root.theme.textSecondary
                                    font.pixelSize: 10
                                    font.family: root.font
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            MouseArea {
                                id: hibernateHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.powerAction(["systemctl", "hibernate"])
                            }
                        }

                        // Reboot
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: 10
                            color: rebootHov.containsMouse
                                   ? root.theme.accentOrange : root.theme.bgSurface
                            Behavior on color { ColorAnimation { duration: 120 } }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    text: "󰑓"
                                    color: rebootHov.containsMouse
                                           ? root.theme.bgBase : root.theme.accentOrange
                                    font.pixelSize: 16
                                    font.family: root.font
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    text: "Reboot"
                                    color: rebootHov.containsMouse
                                           ? root.theme.bgBase : root.theme.textSecondary
                                    font.pixelSize: 10
                                    font.family: root.font
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            MouseArea {
                                id: rebootHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.powerAction(["systemctl", "reboot"])
                            }
                        }

                        // Shutdown
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: 10
                            color: shutdownHov.containsMouse
                                   ? root.theme.accentRed : root.theme.bgSurface
                            Behavior on color { ColorAnimation { duration: 120 } }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    text: "󰐥"
                                    color: shutdownHov.containsMouse
                                           ? "#ffffff" : root.theme.accentRed
                                    font.pixelSize: 16
                                    font.family: root.font
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    text: "Shutdown"
                                    color: shutdownHov.containsMouse
                                           ? "#ffffff" : root.theme.textSecondary
                                    font.pixelSize: 10
                                    font.family: root.font
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            MouseArea {
                                id: shutdownHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.powerAction(["systemctl", "poweroff"])
                            }
                        }

                        // Log Out
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: 10
                            color: logoutHov.containsMouse
                                   ? root.theme.accentOrange : root.theme.bgSurface
                            Behavior on color { ColorAnimation { duration: 120 } }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    text: "󰗽"
                                    color: logoutHov.containsMouse
                                           ? root.theme.bgBase : root.theme.accentOrange
                                    font.pixelSize: 16
                                    font.family: root.font
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    text: "Log Out"
                                    color: logoutHov.containsMouse
                                           ? root.theme.bgBase : root.theme.textSecondary
                                    font.pixelSize: 10
                                    font.family: root.font
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            MouseArea {
                                id: logoutHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.powerAction(["hyprctl", "dispatch", "exit"])
                            }
                        }
                    }
                }
            }
        }
    }
}

    // ── Position poller ─────────────────────────────────────
    Timer {
        interval: 500
        running: root.hasPlayer
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.hasPlayer) return;
            const player = root.activePlayer;
            const p = Number(player.position) || 0;
            let l = Number(player.length) || 0;
            if ((!l || l <= 0) && player.metadata)
                l = Number(player.metadata["mpris:length"]) || 0;
            if (l > 0)
                root.mediaProgress = Math.min(1, Math.max(0, p / l));
            root.mediaTick++;
        }
    }
}
