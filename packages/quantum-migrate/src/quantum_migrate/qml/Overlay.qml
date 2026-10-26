import QtQuick

// Fondo oscuro con una tarjeta que aparece al centro (OutBack al abrir, InCubic al cerrar).
Item {
    id: ov
    property bool shown: false
    default property alias content: card.data
    property real cardWidth: 860
    property real cardHeight: 560
    visible: shown || closeAnim.running
    z: 50

    function open() { shown = true; }
    function close() { shown = false; }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.01, 0.05, 0.7)
        opacity: ov.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220 } }
        MouseArea { anchors.fill: parent; onClicked: ov.close(); hoverEnabled: true; onWheel: w => w.accepted = true }
    }
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(ov.cardWidth, ov.width - 60)
        height: Math.min(ov.cardHeight, ov.height - 60)
        radius: 28
        color: theme.low
        clip: true
        border.width: 1
        border.color: theme.alpha(theme.fg, 0.06)
        opacity: ov.shown ? 1 : 0
        scale: ov.shown ? 1 : 0.92
        Behavior on opacity { NumberAnimation { duration: 220 } }
        Behavior on scale { NumberAnimation { duration: ov.shown ? 320 : 200; easing.type: ov.shown ? Easing.OutBack : Easing.InCubic } }
        MouseArea { anchors.fill: parent }   // no cerrar al hacer clic dentro
    }
    NumberAnimation { id: closeAnim; running: !ov.shown && card.opacity > 0; duration: 220 }
    Keys.onEscapePressed: close()
}
