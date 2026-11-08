import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// «Más opciones»: muestra las opciones menos usadas de la sección (las marcadas como avanzadas).
Rectangle {
    id: root
    property string hint: ""
    Layout.fillWidth: true
    implicitHeight: 54
    radius: Theme.radiusLarge
    color: area.containsMouse ? Theme.alpha(Theme.fg, 0.04) : "transparent"
    border.width: 1
    border.color: Theme.alpha(Theme.fg, 0.14)
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18; anchors.rightMargin: 18
        spacing: 12
        Icon { text: "tune"; size: 20; color: Theme.fgMuted }
        Txt {
            Layout.fillWidth: true
            text: (Settings.ui.advanced ? "Menos opciones" : "Más opciones") + (root.hint && !Settings.ui.advanced ? " · " + root.hint : "")
            color: Theme.fgMuted; font.weight: Font.DemiBold; elide: Text.ElideRight
        }
        Icon { text: Settings.ui.advanced ? "expand_less" : "expand_more"; size: 22; color: Theme.fgMuted }
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: Settings.setUi("advanced", !Settings.ui.advanced) }
}
