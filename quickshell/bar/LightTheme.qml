import QtQuick

QtObject {
    readonly property color bgBase:       '#44f5f5f5'
    readonly property color bgSurface:    "#ffffff"
    readonly property color bgOverlay:    "#aa000000"
    readonly property color bgHover:      "#e0e0e0"
    readonly property color bgSelected:   "#d4d4d4"
    readonly property color bgBorder:     "#c8c8c8"

    readonly property color textFocused:  "#1a1a1a"
    readonly property color textPrimary:  "#1a1a1a"
    readonly property color textSecondary: "#555555"
    readonly property color textMuted:    "#777777"

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
