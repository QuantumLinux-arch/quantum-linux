import QtQuick
import qs.services
import qs.components

// «Mostrar escritorio»: minimiza todas las ventanas (otra vez las devuelve), como en Windows.
DockButton {
    tip: "Mostrar escritorio"
    implicitWidth: Math.round(38 * Theme.dockScale)
    onClicked: Wm.toggleDesktop()
    Icon { anchors.centerIn: parent; text: "select_window_2"; size: Math.round(21 * Theme.dockScale); color: Theme.fg }
}
