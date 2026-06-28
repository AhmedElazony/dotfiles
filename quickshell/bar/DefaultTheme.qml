import QtQuick

QtObject {
    readonly property color bgBase:       '#920e0e10'
    readonly property color bgSurface:    "#161618"
    readonly property color bgOverlay:    "#aa000000"
    readonly property color bgHover:      "#1e1e20"
    readonly property color bgSelected:   "#262628"
    readonly property color bgBorder:     "#222224"

    readonly property color textFocused:  "#e8e8ea"
    readonly property color textPrimary:  "#e8e8ea"
    readonly property color textSecondary: "#a0a0a4"
    readonly property color textMuted:    "#606064"

    readonly property color accentPrimary: "#7c8cf0"
    readonly property color accentCyan:    "#6fc9e8"
    readonly property color accentGreen:   "#8bd68a"
    readonly property color accentOrange:  "#f0a86c"
    readonly property color accentRed:     "#e86c7c"

    readonly property color urgencyLow:     textMuted
    readonly property color urgencyNormal:  accentPrimary
    readonly property color urgencyCritical: accentRed
    readonly property color batteryGood:    accentGreen
    readonly property color batteryWarning: accentOrange
    readonly property color batteryCritical: accentRed
}
