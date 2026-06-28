pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    readonly property string timeString: {
        Qt.formatDateTime(clock.date, "h:mm AP")
    }

    readonly property string dateString: {
        Qt.formatDateTime(clock.date, "dd/MM/yyyy")
    }

    // ── Hijri date (from API) ───────────────────────────────
    property string hijriDay: ""
    property string hijriMonth: ""
    property string hijriYear: ""
    property bool hijriLoaded: false

    function fetchHijri() {
        const d = new Date();
        const dd = ("0" + d.getDate()).slice(-2);
        const mm = ("0" + (d.getMonth() + 1)).slice(-2);
        const yyyy = d.getFullYear();

        const req = new XMLHttpRequest();
        req.open("GET", "https://api.aladhan.com/v1/gToH?date=" + dd + "-" + mm + "-" + yyyy);
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.DONE && req.status === 200) {
                try {
                    const data = JSON.parse(req.responseText);
                    if (data.code === 200) {
                        root.hijriDay = data.data.hijri.day;
                        root.hijriMonth = data.data.hijri.month.en;
                        root.hijriYear = data.data.hijri.year;
                        root.hijriLoaded = true;
                    }
                } catch (e) {}
            }
        };
        req.send();
    }

    Timer {
        interval: 3600000
        running: true
        repeat: true
        onTriggered: root.fetchHijri()
    }

    Component.onCompleted: root.fetchHijri()

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
}
