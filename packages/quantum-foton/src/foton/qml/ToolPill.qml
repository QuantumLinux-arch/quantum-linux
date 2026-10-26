import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Píldora de herramienta (modo juego, FPS, Proton-GE…).
Rectangle {
    id: pill
    property string icon
    property string text
    property bool on: false
    signal clicked
    implicitWidth: pillRow.implicitWidth + (window.compact ? 26 : 30); implicitHeight: 44; radius: 22
    color: on ? theme.alpha(theme.primary, 0.18) : pillArea.containsMouse ? theme.high : theme.card
    border.width: 1
    border.color: on ? theme.alpha(theme.primary, 0.6) : theme.alpha(theme.fg, 0.06)
    Behavior on color { ColorAnimation { duration: 150 } }
    RowLayout {
        id: pillRow
        anchors.centerIn: parent
        spacing: 8
        Sym { text: pill.icon; size: 20; fill: pill.on ? 1 : 0; color: pill.on ? theme.primary : theme.fg }
        T { visible: !window.compact || pill.text.indexOf("%") >= 0; text: pill.text; font.pixelSize: 13; font.weight: Font.DemiBold }
        Rectangle { visible: pill.on; implicitWidth: 8; implicitHeight: 8; radius: 4; color: "#22B573" }
    }
    MouseArea { id: pillArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pill.clicked() }
    // en modo compacto el nombre aparece al pasar el mouse
    ToolTip.visible: window.compact && pillArea.containsMouse
    ToolTip.text: pill.text
    ToolTip.delay: 400
}
