import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// Barra de tareas: forma, posición, transparencia, tamaño, elementos (en orden) y reloj.
// Con Serpantium la barra es otra: se muestran sus opciones (BarPage).
ColumnLayout {
    id: page
    spacing: 16

    readonly property bool single: Settings.layout.style === "single" || Settings.dock.position === "top"
    // la forma que se ve ahora (con «auto» depende del estilo)
    readonly property string shapeNow: Settings.dock.shape && Settings.dock.shape !== "auto" ? Settings.dock.shape
        : !Settings.dock.floating && !Atomic.on ? "attached" : page.single ? "floating" : "dock"
    function setShape(v: string): void {
        Settings.set("dock", "shape", v);
        Settings.set("dock", "floating", v !== "attached");
    }
    readonly property real autoOpacity: Math.min(0.97, Theme.glassOpacity("dock") + 0.04)
    readonly property real transparency: Math.round((1 - ((Settings.dock.opacity ?? -1) >= 0 ? Settings.dock.opacity : autoOpacity)) * 100)

    Loader { Layout.fillWidth: true; active: Serp.on; visible: active; sourceComponent: BarPage {} }

    // ------------------------------------------------------------ forma
    ColumnLayout {
        visible: !Serp.on
        Layout.fillWidth: true
        spacing: 10
        Txt { text: "¿Cómo quieres tu barra?"; font.pixelSize: Theme.textLarge; font.weight: Font.Bold }
        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Repeater {
                model: [
                    { v: "floating", t: "Flotante", h: "Separada del borde, con esquinas redondas." },
                    { v: "attached", t: "Pegada", h: "De borde a borde, como Windows 10." },
                    { v: "dock", t: "Dock", h: "Solo lo justo, al centro, como macOS." }
                ]
                ChoiceCard {
                    id: sc
                    required property var modelData
                    title: modelData.t; help: modelData.h
                    previewHeight: 78
                    selected: page.shapeNow === modelData.v
                    onClicked: page.setShape(modelData.v)
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius
                        gradient: Gradient {
                            GradientStop { position: 0; color: Theme.alpha(Theme.primary, 0.10) }
                            GradientStop { position: 1; color: Theme.alpha(Theme.primary, 0.24) }
                        }
                        Rectangle {
                            readonly property bool atTop: Settings.dock.position === "top"
                            readonly property real m: sc.modelData.v === "attached" ? 0 : 8
                            x: sc.modelData.v === "dock" ? parent.width * 0.28 : m
                            width: sc.modelData.v === "dock" ? parent.width * 0.44 : parent.width - 2 * m
                            height: 14
                            y: atTop ? m : parent.height - height - m
                            radius: sc.modelData.v === "attached" ? 0 : 7
                            color: sc.selected ? Theme.primary : Theme.alpha(Theme.primary, 0.55)
                            Row {
                                anchors.centerIn: parent; spacing: 4
                                Repeater { model: 5; Rectangle { width: 6; height: 6; radius: 2; color: Theme.primaryFg; opacity: 0.8 } }
                            }
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ lo principal
    GridLayout {
        visible: !Serp.on
        Layout.fillWidth: true
        columns: page.width > 820 ? 2 : 1
        columnSpacing: 14; rowSpacing: 14
        Group {
            Layout.alignment: Qt.AlignTop
            OptionRow {
                title: "Posición"; icon: "swap_vert"
                Segmented {
                    options: [{ v: "bottom", t: "Abajo" }, { v: "top", t: "Arriba" }]
                    value: Settings.dock.position ?? "bottom"
                    onPicked: v => Settings.set("dock", "position", v)
                }
            }
            OptionRow {
                title: "Transparencia"; icon: "opacity"
                help: page.transparency >= 100 ? "Solo se ven los íconos." : ""
                Slider {
                    Layout.preferredWidth: 200
                    from: 0; to: 100; step: 5
                    value: page.transparency
                    text: Math.round(value) + " %"
                    onMoved: v => Settings.set("dock", "opacity", Math.max(0, Math.min(1, 1 - v / 100)))
                }
            }
            OptionRow {
                title: "Tamaño"; icon: "height"
                Segmented {
                    options: [{ v: "small", t: "Chica" }, { v: "medium", t: "Mediana" }, { v: "large", t: "Grande" }]
                    value: Settings.dock.size
                    onPicked: v => Settings.set("dock", "size", v)
                }
            }
        }
        Group {
            Layout.alignment: Qt.AlignTop
            OptionRow {
                title: "Ocultar automáticamente"; icon: "visibility_off"
                help: Settings.dock.position === "top" ? "Aparece al llevar el mouse arriba." : "Aparece al llevar el mouse abajo."
                Toggle { checked: Settings.dock.autohide; onToggled: c => Settings.set("dock", "autohide", c) }
            }
            OptionRow {
                title: "Apps"; icon: "format_align_center"
                visible: page.shapeNow !== "dock"
                Segmented {
                    options: [{ v: "center", t: "Al centro" }, { v: "left", t: "A la izquierda" }]
                    value: Settings.dock.align
                    onPicked: v => Settings.set("dock", "align", v)
                }
            }
            OptionRow {
                title: "Barra de arriba"; icon: "top_panel_open"
                help: Settings.dock.position === "top" ? "No se usa con la barra de tareas arriba."
                                                       : "La hora, el estado y la app activa arriba de la pantalla."
                Toggle {
                    enabled: Settings.dock.position !== "top"
                    opacity: enabled ? 1 : 0.4
                    checked: Settings.layout.style !== "single" && Settings.dock.position !== "top"
                    onToggled: c => Settings.setPath("layout.style", c ? "split" : "single")
                }
            }
        }
    }

    // ------------------------------------------------------------ elementos
    Group {
        visible: !Serp.on
        title: "Qué aparece en la barra"
        help: "Toca para mostrar u ocultar. Arrastra para cambiar el orden: lo que quede después de «Tus apps» va a la derecha."
        icon: "widgets"
        OrderChips {}
    }

    // ------------------------------------------------------------ reloj
    Group {
        visible: !Serp.on
        title: "Reloj"
        icon: "schedule"
        OptionRow {
            title: "Formato"
            Segmented {
                options: [{ v: true, t: "24 horas" }, { v: false, t: "12 horas" }]
                value: Settings.clock.format24h
                onPicked: v => Settings.set("clock", "format24h", v)
            }
        }
        OptionRow { title: "Mostrar la fecha"; Toggle { checked: Settings.clock.showDate; onToggled: c => Settings.set("clock", "showDate", c) } }
        OptionRow { title: "Mostrar los segundos"; advanced: true
                    Toggle { checked: Settings.clock.showSeconds; onToggled: c => Settings.set("clock", "showSeconds", c) } }
    }

    // ------------------------------------------------------------ más opciones
    Group {
        visible: !Serp.on && Settings.ui.advanced
        advanced: true
        title: "Más ajustes de las barras"
        icon: "tune"
        OptionRow {
            title: "Isla dinámica"
            help: "La píldora de arriba al centro: música, volumen y avisos."
            Toggle { checked: Settings.layout.topBar.island; onToggled: c => Settings.setPath("layout.topBar.island", c) }
        }
        OptionRow {
            visible: !page.single
            title: "Barra de arriba flotante"
            Toggle { checked: Settings.layout.topBar.floating; onToggled: c => Settings.setPath("layout.topBar.floating", c) }
        }
        OptionRow {
            visible: !page.single
            title: "Mostrar la app activa en la barra de arriba"
            Toggle { checked: Settings.layout.topBar.showApp; onToggled: c => Settings.setPath("layout.topBar.showApp", c) }
        }
        OptionRow {
            title: "Aviso de actualizaciones"
            help: "Un botón con la cantidad de actualizaciones pendientes."
            Toggle { checked: Settings.dock.showUpdates; onToggled: c => Settings.set("dock", "showUpdates", c) }
        }
        OptionRow {
            title: "Transparencia automática"
            help: "Vuelve a usar la del efecto vidrio (Fondo y colores)."
            PillButton { text: "Restablecer"; icon: "restart_alt"; enabled_: (Settings.dock.opacity ?? -1) >= 0
                         onClicked: Settings.set("dock", "opacity", -1) }
        }
    }
    MoreOptions { visible: !Serp.on; hint: "isla dinámica, segundos, barra de arriba" }
}
