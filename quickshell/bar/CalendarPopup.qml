import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: calWin

    required property var screen
    signal closeRequested()

    focusable: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-calendar"

    exclusionMode: ExclusionMode.Ignore
    mask: Region {}

    // Anchor only to top, centered — does NOT cover the bar
    anchors { top: true }
    implicitWidth: 320
    implicitHeight: card.height + 8

    // ── State ────────────────────────────────────────────────────────────
    property int viewYear:  Qt.formatDateTime(new Date(), "yyyy") * 1
    property int viewMonth: Qt.formatDateTime(new Date(), "M")    * 1

    readonly property var monthNames: [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
    ]
    readonly property var dayNames: ["Mo","Tu","We","Th","Fr","Sa","Su"]

    readonly property int todayYear:  Qt.formatDateTime(new Date(), "yyyy") * 1
    readonly property int todayMonth: Qt.formatDateTime(new Date(), "M")    * 1
    readonly property int todayDay:   Qt.formatDateTime(new Date(), "d")    * 1

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

    property var theme: DefaultTheme {}
    property string font: "SF Pro Display"

    // ── Calendar card ─────────────────────────────────────────────────────
    Rectangle {
        id: card
        width: 308
        height: cardContent.implicitHeight + 24

        anchors.top: parent.top
        anchors.topMargin: 36   // just below the 32px bar + gap
        anchors.horizontalCenter: parent.horizontalCenter

        radius: 14
        color: calWin.theme.bgBase
        border.color: calWin.theme.bgBorder
        border.width: 1

        ColumnLayout {
            id: cardContent
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            spacing: 8

            // ── Header ───────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Rectangle {
                    width: 26; height: 26; radius: 13
                    color: prevHov.containsMouse ? calWin.theme.bgBorder : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                        anchors.centerIn: parent
                        text: "󰍞"
                        color: calWin.theme.textMuted
                        font.pixelSize: 14
                        font.family: calWin.font
                    }
                    MouseArea {
                        id: prevHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (calWin.viewMonth === 1) { calWin.viewMonth = 12; calWin.viewYear -= 1; }
                            else calWin.viewMonth -= 1;
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: calWin.monthNames[calWin.viewMonth - 1] + "  " + calWin.viewYear
                    color: calWin.theme.textPrimary
                    font.pixelSize: 13
                    font.bold: true
                    font.family: calWin.font
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    width: 26; height: 26; radius: 13
                    color: nextHov.containsMouse ? calWin.theme.bgBorder : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                        anchors.centerIn: parent
                        text: "󰍟"
                        color: calWin.theme.textMuted
                        font.pixelSize: 14
                        font.family: calWin.font
                    }
                    MouseArea {
                        id: nextHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (calWin.viewMonth === 12) { calWin.viewMonth = 1; calWin.viewYear += 1; }
                            else calWin.viewMonth += 1;
                        }
                    }
                }
            }

            // ── Day-of-week headers ───────────────────────────────────
            Grid {
                columns: 7
                Layout.fillWidth: true
                columnSpacing: 0
                rowSpacing: 0

                Repeater {
                    model: calWin.dayNames
                    delegate: Item {
                        width: (card.width - 24) / 7
                        height: 24
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: (index === 5 || index === 6)
                                   ? calWin.theme.accentRed : calWin.theme.textMuted
                            font.pixelSize: 10
                            font.family: calWin.font
                            font.bold: true
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: calWin.theme.bgBorder
            }

            // ── Day grid ──────────────────────────────────────────────
            Grid {
                id: dayGrid
                columns: 7
                Layout.fillWidth: true
                columnSpacing: 0
                rowSpacing: 2

                property var cells: calWin.buildCells(calWin.viewYear, calWin.viewMonth)

                Repeater {
                    model: dayGrid.cells.length
                    delegate: Item {
                        required property int index
                        readonly property int day:        dayGrid.cells[index]
                        readonly property int col:        index % 7
                        readonly property bool isWeekend: col === 5 || col === 6
                        readonly property bool isToday:   day > 0
                                                          && day === calWin.todayDay
                                                          && calWin.viewMonth === calWin.todayMonth
                                                          && calWin.viewYear  === calWin.todayYear

                        width:  (card.width - 24) / 7
                        height: 28

                        Rectangle {
                            anchors.centerIn: parent
                            width: 26; height: 26; radius: 13
                            color: isToday ? calWin.theme.accentPrimary : "transparent"
                        }

                        Text {
                            anchors.centerIn: parent
                            text: day > 0 ? day : ""
                            color: isToday   ? calWin.theme.bgBase
                                 : isWeekend ? calWin.theme.accentRed
                                 :              calWin.theme.textPrimary
                            font.pixelSize: 12
                            font.family: calWin.font
                            font.bold: isToday
                        }
                    }
                }
            }

            // ── Today jump ────────────────────────────────────────────
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                height: 22
                width: todayLabel.width + 20
                radius: 11
                color: todayJumpHov.containsMouse ? calWin.theme.accentPrimary : calWin.theme.bgSurface
                Behavior on color { ColorAnimation { duration: 120 } }
                visible: calWin.viewMonth !== calWin.todayMonth || calWin.viewYear !== calWin.todayYear

                Text {
                    id: todayLabel
                    anchors.centerIn: parent
                    text: "Today"
                    color: todayJumpHov.containsMouse ? calWin.theme.bgBase : calWin.theme.textMuted
                    font.pixelSize: 11
                    font.family: calWin.font
                }
                MouseArea {
                    id: todayJumpHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        calWin.viewYear  = calWin.todayYear;
                        calWin.viewMonth = calWin.todayMonth;
                    }
                }
            }

            Item { height: 4 }
        }
    }
}