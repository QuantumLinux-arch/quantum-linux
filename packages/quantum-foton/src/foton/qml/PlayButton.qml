import QtQuick
import QtQuick.Layouts

// Botón «Jugar» con el degradado de Quantum.
Rectangle {
    id: pb
    property bool big: false
    signal clicked
    implicitWidth: pbRow.implicitWidth + (big ? 56 : 30); implicitHeight: big ? 56 : 40; radius: height / 2
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: theme.cyan }
        GradientStop { position: 0.5; color: theme.indigo }
        GradientStop { position: 1; color: theme.violet }
    }
    scale: pbArea.pressed ? 0.95 : pbArea.containsMouse ? 1.04 : 1
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
    RowLayout {
        id: pbRow
        anchors.centerIn: parent; spacing: 8
        Sym { text: "play_arrow"; size: pb.big ? 30 : 22; fill: 1; color: "white" }
        T { text: "Jugar"; color: "white"; font.pixelSize: pb.big ? 19 : 14; font.weight: Font.Bold }
    }
    MouseArea { id: pbArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pb.clicked() }
}
