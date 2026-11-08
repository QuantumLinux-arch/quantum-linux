import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// Escritorio: íconos (carpeta Escritorio + Papelera) como en Windows.
ColumnLayout {
    id: page
    spacing: 16

    Group {
        title: "Íconos en el escritorio"
        help: "Lo que hay en tu carpeta Escritorio y la Papelera. Doble clic para abrir, arrastra para moverlos y clic derecho para más opciones."
        icon: "desktop_windows"
        OptionRow {
            title: "Mostrar los íconos"
            Toggle { checked: Settings.appearance.desktopIcons ?? true; onToggled: c => Settings.set("appearance", "desktopIcons", c) }
        }
        OptionRow {
            title: "Anclar una app"
            help: "En el menú Inicio, clic derecho sobre la app → «Anclar al escritorio»."
            PillButton { text: "Abrir el menú Inicio"; icon: "grid_view"; onClicked: Shell.toggleLauncher(false) }
        }
        RowLayout {
            spacing: 10
            PillButton { text: "Abrir la carpeta Escritorio"; icon: "folder_open"; onClicked: Desktop.open(Desktop.dir, false) }
            PillButton { text: "Ordenar los íconos"; icon: "grid_on"; onClicked: Desktop.resetPositions() }
        }
    }
}
