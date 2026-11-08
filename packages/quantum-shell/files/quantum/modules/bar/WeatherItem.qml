import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// Clima en la barra: ícono y temperatura. Clic: actualizar.
DockButton {
    id: root
    tip: Weather.ready ? Weather.text + " · sensación " + Math.round(Weather.feels) + "°" : "Clima"
    implicitWidth: row.implicitWidth + 18
    Component.onCompleted: Weather.refresh()
    Timer { interval: 30 * 60 * 1000; repeat: true; running: true; onTriggered: Weather.refresh() }
    onClicked: Weather.refresh()
    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Icon { text: Weather.ready ? Weather.icon : "cloud"; size: Math.round(21 * Theme.dockScale); fill: 1; color: Theme.fg }
        Txt { visible: Weather.ready; text: Math.round(Weather.temp) + "°"; font.weight: Font.Bold }
    }
}
