import QtQuick
import QtQuick.Layouts

// Botón de la tienda: Instalar / Instalar con Steam / Instalando… / Jugar.
Rectangle {
    id: ib
    property var g: null
    property bool big: false
    readonly property bool installed: !!g && g.installed
    readonly property bool busy: !!g && g.progress >= 0
    implicitWidth: row.implicitWidth + (big ? 56 : 36); implicitHeight: big ? 56 : 46; radius: height / 2
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: ib.busy ? theme.high : theme.cyan }
        GradientStop { position: 0.5; color: ib.busy ? theme.high : theme.indigo }
        GradientStop { position: 1; color: ib.busy ? theme.high : theme.violet }
    }
    clip: true
    Rectangle {
        visible: ib.busy
        height: parent.height; width: parent.width * Math.max(0.04, ib.g ? ib.g.progress : 0)
        radius: parent.radius
        color: theme.indigo
        Behavior on width { NumberAnimation { duration: 300 } }
    }
    scale: area.pressed ? 0.95 : area.containsMouse ? 1.04 : 1
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
    RowLayout {
        id: row
        anchors.centerIn: parent; spacing: 8
        Sym {
            text: ib.installed ? "play_arrow" : ib.busy ? "downloading" : "download"
            size: ib.big ? 28 : 22; fill: 1; color: "white"
        }
        T {
            text: !ib.g ? "" : ib.installed ? "Jugar"
                : ib.busy ? "Instalando " + Math.round(ib.g.progress * 100) + " %"
                : ib.g.kind === "steam" ? "Instalar con Steam" : "Instalar gratis"
            color: "white"; font.pixelSize: ib.big ? 18 : 14; font.weight: Font.Bold
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (!ib.g || ib.busy) return;
            if (ib.installed) foton.play(ib.g.key); else foton.install(ib.g.id);
        }
    }
}
