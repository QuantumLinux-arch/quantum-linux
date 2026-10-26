import QtQuick

// Ícono Material Symbols por nombre (ligadura).
Text {
    property int size: 22
    property real fill: 0
    font.family: theme.icons
    font.pixelSize: size
    font.variableAxes: ({ "FILL": fill, "opsz": Math.min(48, Math.max(20, size)), "wght": 450 })
    color: theme.fg
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    Behavior on fill { NumberAnimation { duration: theme.anim } }
}
