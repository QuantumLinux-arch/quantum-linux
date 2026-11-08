import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// Personalizar (Super + P): cambia cómo se ve y se comporta el escritorio.
// Una portada con tu estilo y una tarjeta por sección; cada sección es una página corta con lo importante
// primero y lo menos usado en «Más opciones». Los cambios se aplican al instante; «Deshacer» vuelve a como
// estaba al abrirla. Es una ventana normal y solo existe mientras está abierta.
Scope {
    LazyLoader {
        active: Shell.personalizeOpen

        FloatingWindow {
            id: win

            title: "Personalizar"
            implicitWidth: 1180
            implicitHeight: 780
            minimumSize: Qt.size(860, 600)
            color: Theme.surface
            visible: true
            onVisibleChanged: if (!visible) Shell.personalizeOpen = false

            readonly property var pages: [
                { id: "styles", t: "Estilos", h: "Cambia todo el escritorio con un clic.", c: stylesPage },
                { id: "colors", t: "Fondo y colores", h: "Fondo de pantalla, modo claro u oscuro, acento, íconos y efecto vidrio.", c: colorsPage, preview: true },
                { id: "bar", t: "Barra de tareas", h: "Dónde va, cómo se ve y qué aparece en ella.", c: taskbarPage, preview: true },
                { id: "desktop", t: "Escritorio", h: "Íconos de archivos y apps sobre el fondo, como en Windows.", c: desktopPage },
                { id: "windows", t: "Ventanas", h: "Esquinas, botones y animaciones de las ventanas.", c: windowsPage, preview: true },
                { id: "lock", t: "Pantalla de bloqueo", h: "Qué tarjetas se ven y en qué orden.", c: lockPage },
                { id: "sounds", t: "Sonidos", h: "Los sonidos del sistema y su volumen.", c: soundsPage },
                { id: "display", t: "Pantalla", h: "Luz nocturna, brillo, contraste, gamma y saturación.", c: displayPage },
                { id: "input", t: "Mouse y touchpad", h: "Velocidad, aceleración, desplazamiento y clics.", c: inputPage },
            ]
            // nombres viejos de páginas (IPC y ajustes guardados)
            readonly property var aliases: ({ "bar-old": "bar" })
            property string current: "home"
            readonly property var page: pages.find(p => p.id === current) ?? null
            function go(id: string): void {
                id = aliases[id] ?? id;
                current = pages.some(p => p.id === id) ? id : "home";
                Settings.setUi("advanced", false);
                search.text = "";
            }

            // buscador: qué opción está en qué sección
            readonly property var index: [
                ["transparente transparencia barra", "bar", "Transparencia de la barra"], ["arriba abajo posición barra", "bar", "Barra arriba o abajo"],
                ["flotante pegada dock forma barra", "bar", "Forma de la barra"], ["reloj hora fecha segundos 24", "bar", "Reloj"],
                ["clima tiempo temperatura", "bar", "Clima en la barra"], ["uso pc cpu ram memoria procesador", "bar", "Uso del PC en la barra"],
                ["mostrar escritorio minimizar todo", "bar", "Botón «Mostrar escritorio»"], ["ocultar automáticamente esconder", "bar", "Ocultar la barra"],
                ["inicio buscar quarki botones elementos orden", "bar", "Qué aparece en la barra"], ["isla dinámica", "bar", "Isla dinámica"],
                ["fondo pantalla wallpaper imagen video", "colors", "Fondo de pantalla"], ["oscuro claro modo", "colors", "Modo claro u oscuro"],
                ["acento color", "colors", "Color de acento"], ["íconos iconos tema carpetas", "colors", "Tema de íconos"],
                ["vidrio desenfoque blur opacidad cristal tinte", "colors", "Efecto vidrio"], ["texto tamaño letra fuente", "colors", "Tamaño del texto"],
                ["escritorio íconos iconos papelera anclar", "desktop", "Íconos en el escritorio"],
                ["esquinas redondas ventanas", "windows", "Esquinas de las ventanas"], ["botones cerrar minimizar izquierda", "windows", "Botones de las ventanas"],
                ["animaciones abrir minimizar gelatina estela", "windows", "Animaciones"], ["mosaico tiling organizar", "windows", "Mosaico automático"],
                ["bloqueo tarjetas privacidad clima ciudad", "lock", "Pantalla de bloqueo"], ["sonidos volumen inicio", "sounds", "Sonidos"],
                ["luz nocturna brillo contraste gamma saturación", "display", "Pantalla y luz nocturna"],
                ["mouse ratón touchpad velocidad rueda zurdo puntero cursor", "input", "Mouse y touchpad"],
                ["estilo estilos shell serpantium atomic caelestial compartir exportar", "styles", "Estilos y forma del shell"]
            ]
            readonly property var results: {
                const q = search.text.trim().toLowerCase();
                if (q.length < 2) return [];
                const words = q.split(/\s+/);
                return index.filter(e => words.every(w => (e[0] + " " + e[2].toLowerCase()).includes(w))).slice(0, 6);
            }

            Component.onCompleted: { Settings.snapshot(); Settings.setUi("advanced", false); }

            Component { id: homePage; Home { onGo: id => win.go(id) } }
            Component { id: stylesPage; StylesPage {} }
            Component { id: colorsPage; ColorsPage {} }
            Component { id: taskbarPage; TaskbarPage {} }
            Component { id: desktopPage; DesktopPage {} }
            Component { id: windowsPage; WindowsPage {} }
            Component { id: lockPage; LockPage {} }
            Component { id: soundsPage; SoundsPage {} }
            Component { id: displayPage; DisplayPage {} }
            Component { id: inputPage; InputPage {} }

            Shortcut { sequence: "Escape"; onActivated: { if (win.current === "home") Shell.personalizeOpen = false; else win.go("home"); } }
            Shortcut { sequence: "Alt+Left"; onActivated: win.go("home") }

            // Para probar sin mouse: qs ipc call personalize page bar
            IpcHandler {
                target: "personalize"
                function page(id: string): void { win.go(id); }
                function advanced(on: bool): void { Settings.setUi("advanced", on); }
                function scroll(y: real): void { flick.contentY = y; }
                function find(text: string): void { win.go("home"); search.text = text; }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // ---------------------------------------------------- encabezado
                RowLayout {
                    z: 10
                    Layout.fillWidth: true
                    Layout.leftMargin: 30; Layout.rightMargin: 30; Layout.topMargin: 22; Layout.bottomMargin: 14
                    spacing: 14

                    // atrás (en una sección) o el ícono de Personalizar (en la portada)
                    Rectangle {
                        implicitWidth: 46; implicitHeight: 46; radius: 14
                        color: win.page ? (backArea.containsMouse ? Theme.surfaceHighest : Theme.surfaceHigh) : "transparent"
                        Image {
                            visible: !win.page
                            anchors.fill: parent
                            source: Quickshell.shellDir + "/assets/quantum-personalize.svg"
                            sourceSize: Qt.size(92, 92)
                        }
                        Icon { visible: !!win.page; anchors.centerIn: parent; text: "arrow_back"; size: 22; color: Theme.fg }
                        MouseArea { id: backArea; anchors.fill: parent; enabled: !!win.page; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor; onClicked: win.go("home") }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Txt { visible: !!win.page; text: "Personalizar"; color: Theme.fgMuted; font.pixelSize: Theme.textSmall }
                        Txt { text: win.page ? win.page.t : "Personalizar"; font.pixelSize: Theme.textTitle + 6; font.weight: Font.Black }
                        Txt { Layout.fillWidth: true; text: win.page ? win.page.h : "Elige qué quieres cambiar"; color: Theme.fgMuted; elide: Text.ElideRight }
                    }

                    // buscador (en la portada)
                    Rectangle {
                        id: searchBox
                        visible: !win.page
                        implicitWidth: 340; implicitHeight: 46; radius: 15
                        color: Theme.surfaceContainer
                        border.width: search.activeFocus ? 2 : 1
                        border.color: search.activeFocus ? Theme.alpha(Theme.primary, 0.7) : Theme.alpha(Theme.fg, 0.08)
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                            spacing: 10
                            Icon { text: "search"; size: 20; color: Theme.fgMuted }
                            TextInput {
                                id: search
                                Layout.fillWidth: true
                                color: Theme.fg; font.family: Theme.font; font.pixelSize: Theme.textNormal
                                selectionColor: Theme.alpha(Theme.primary, 0.4)
                                clip: true
                                onAccepted: if (win.results.length) win.go(win.results[0][1])
                                Txt { visible: !search.text; anchors.verticalCenter: parent.verticalCenter
                                      text: "Buscar: «transparente», «reloj», «fondo»…"; color: Theme.fgMuted }
                            }
                        }
                    }
                    PillButton {
                        text: "Deshacer"; icon: "undo"
                        enabled_: Settings.changed
                        onClicked: Settings.undo()
                    }
                }

                // ---------------------------------------------------- contenido
                Flickable {
                    id: flick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: body.implicitHeight + 40
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: body
                        x: 30
                        width: flick.width - 60
                        spacing: 18

                        // vista previa en vivo, arriba de las secciones visuales
                        MiniDesktop {
                            visible: !!win.page && !!win.page.preview
                            Layout.fillWidth: true
                            Layout.preferredHeight: visible ? 170 : 0
                            v: Settings.visualState()
                        }
                        Loader {
                            id: loader
                            Layout.fillWidth: true
                            sourceComponent: win.page ? win.page.c : homePage
                            // entrada suave al cambiar de sección
                            opacity: 0
                            onLoaded: { flick.contentY = 0; fade.restart(); }
                            NumberAnimation on opacity { id: fade; from: 0; to: 1; duration: Theme.anim; easing.type: Easing.OutCubic }
                            transform: Translate { y: (1 - loader.opacity) * 14 }
                        }
                    }

                    // barra de desplazamiento fina
                    Rectangle {
                        visible: flick.contentHeight > flick.height
                        x: flick.width - 8
                        y: flick.contentY + flick.visibleArea.yPosition * flick.height
                        width: 4
                        height: flick.visibleArea.heightRatio * flick.height
                        radius: 2
                        color: Theme.alpha(Theme.fg, 0.25)
                    }
                }
            }


            // resultados del buscador (debajo de la caja)
            Rectangle {
                visible: !win.page && win.results.length > 0
                // se recalcula al cambiar los resultados o el tamaño (mapToItem no avisa solo)
                x: { win.results; win.width; return searchBox.mapToItem(win.contentItem, 0, 0).x; }
                y: { win.results; win.width; return searchBox.mapToItem(win.contentItem, 0, 0).y + searchBox.height + 6; }
                width: searchBox.width
                height: resCol.implicitHeight + 12
                radius: 14
                color: Theme.surfaceHigh
                border.width: 1; border.color: Theme.alpha(Theme.fg, 0.1)
                z: 50
                Column {
                    id: resCol
                    x: 6; y: 6; width: parent.width - 12
                    Repeater {
                        model: win.results
                        Rectangle {
                            id: res
                            required property var modelData
                            width: resCol.width; height: 44; radius: 10
                            color: resArea.containsMouse ? Theme.surfaceHighest : "transparent"
                            Column {
                                anchors.verticalCenter: parent.verticalCenter; x: 12
                                Txt { text: res.modelData[2]; font.weight: Font.DemiBold }
                                Txt { text: (win.pages.find(p => p.id === res.modelData[1])?.t ?? ""); color: Theme.fgMuted; font.pixelSize: Theme.textSmall }
                            }
                            MouseArea { id: resArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: win.go(res.modelData[1]) }
                        }
                    }
                }
            }
        }
    }
}
