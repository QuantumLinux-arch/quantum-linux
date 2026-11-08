import QtQuick
import qs.services

// Fondo translúcido de los paneles del shell. Con el shell Atomic, es de Cristal Cuántico.
Rectangle {
    id: card
    radius: Theme.radiusLarge
    color: Theme.alpha(Theme.panelBase, Theme.glassOpacity("panels"))
    border.width: Atomic.on ? 0 : 1
    border.color: Theme.alpha(Theme.fg, 0.08)
    Loader {
        anchors.fill: parent
        active: Atomic.on          // primer hijo: queda encima del color y debajo del contenido
        sourceComponent: Glass { radius: card.radius }
    }
}
