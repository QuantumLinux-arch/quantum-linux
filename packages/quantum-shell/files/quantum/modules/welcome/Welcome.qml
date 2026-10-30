import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.components

// Bienvenida del primer inicio (después de instalar): en 2 pasos se elige cómo se ve el
// escritorio (estilo) y luego los colores y el fondo. Todo se aplica al instante y se puede
// cambiar después en Personalizar. No aparece en el sistema en vivo.
// Para probar: qs ipc call welcome open
PanelWindow {
    id: win

    property bool open: false
    property real progress: 0
    property int step: 0
    property string chosen: "quantum"
    property bool live: true                         // hasta saber si es el sistema en vivo

    readonly property string wallDir: Quickshell.env("QUANTUM_WALLPAPERS") || "/usr/share/backgrounds/quantum"
    readonly property string beako: wallDir + "/beako.jpg"

    visible: open || progress > 0.001
    screen: Wm.screen
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quantum-welcome"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    onOpenChanged: {
        anim.to = open ? 1 : 0;
        anim.duration = open ? 700 : 260;
        anim.easing.type = open ? Easing.OutCubic : Easing.InCubic;
        anim.restart();
    }
    NumberAnimation { id: anim; target: win; property: "progress" }
    function stage(i: int): real { return Math.max(0, Math.min(1, (progress - 0.15 - i * 0.1) / 0.45)); }

    // Se abre sola la primera vez (si no es el sistema en vivo)
    Process {
        running: true
        command: ["sh", "-c", "test -d /run/archiso && echo live || echo installed"]
        stdout: StdioCollector {
            onStreamFinished: {
                win.live = text.trim() === "live";
                if (!win.live && !Settings.ui.welcomed) openTimer.start();
            }
        }
    }
    Timer { id: openTimer; interval: 1800; onTriggered: win.show() }

    function show(): void { step = 0; chosen = Settings.ui.style === "custom" ? "quantum" : chosen; open = true; }
    function finish(): void { Settings.setUi("welcomed", true); open = false; }

    IpcHandler {
        target: "welcome"
        function open(): void { win.show(); }
        function close(): void { win.open = false; }
        function next(): void { win.step = Math.min(2, win.step + 1); }
        function shell(id: string): void { Serp.choose(id); }
        function pick(id: string): void { win.pick(id); }
    }

    // ---------------------------------------------------------------- estilos (paso 1)
    // Usan los mismos valores que los estilos de un clic de Personalizar (styles/*.json).
    readonly property var options: [
        { id: "windows", name: "Windows", tag: "Lo de siempre",
          desc: "Barra pegada abajo con los íconos a la izquierda. Como siempre.",
          style: "clasico", values: { appearance: { accent: "#2F7BFF", panelOpacity: 0.95 }, layout: { style: "single" },
                                      dock: { floating: false, align: "left" }, windows: { corners: "sharp", animations: "fast" } } },
        { id: "quantum", name: "Quantum", tag: "Recomendado",
          desc: "Barra flotante, animaciones y los colores de tu fondo.",
          style: "quantum", values: { appearance: { dynamicColors: true, wallpaper: win.beako } } },
        { id: "macos", name: "macOS", tag: "",
          desc: "Barra arriba y un dock centrado, limpio y elegante.",
          style: "muelle", values: { appearance: { accent: "#FF6B8B" }, layout: { style: "split", topBar: { floating: false, showApp: true } },
                                     dock: { floating: true, align: "center", size: "large", showSearch: false },
                                     windows: { corners: "round", buttonsLeft: true, animations: "smooth" } } },
        { id: "minimal", name: "Minimal", tag: "",
          desc: "Claro y limpio: la barra se esconde sola.",
          style: "minimal", values: { appearance: { mode: "light", accent: "#5B5BD6", panelOpacity: 0.92 },
                                      layout: { topBar: { floating: false, showApp: false } },
                                      dock: { autohide: true, showSearch: false },
                                      windows: { corners: "round", animations: "smooth", openAnimation: "fade" } } },
    ]
    function pick(id: string): void {
        const o = options.find(x => x.id === id);
        if (!o) return;
        chosen = id;
        Settings.applyStyle(o.style, o.values);     // se ve al instante detrás
    }

    // ---------------------------------------------------------------- fondo
    Rectangle { anchors.fill: parent; color: "#0E0C14"; opacity: Math.min(1, win.progress * 1.4) }
    Image {
        anchors.fill: parent
        opacity: 0.55 * Math.min(1, win.progress * 1.4)
        fillMode: Image.PreserveAspectCrop
        source: Settings.appearance.wallpaper && Settings.appearance.wallpaper !== "quantum:live" ? "file://" + Settings.appearance.wallpaper : ""
        sourceSize: Qt.size(960, 540)
        asynchronous: true
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64; saturation: -0.2 }
    }
    Rectangle { anchors.fill: parent; color: Qt.rgba(0.06, 0.05, 0.09, 0.55); opacity: Math.min(1, win.progress * 1.4) }
    MouseArea { anchors.fill: parent }   // no deja tocar el escritorio de atrás

    // ---------------------------------------------------------------- encabezado
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.1)
        spacing: 12
        opacity: win.stage(0)
        transform: Translate { y: (1 - win.stage(0)) * -24 }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            Image { source: Quickshell.shellDir + "/assets/quantum-mark.svg"; width: 40; height: 40; sourceSize: Qt.size(80, 80) }
            Txt { anchors.verticalCenter: parent.verticalCenter; text: "¡Bienvenido a Quantum!"; color: "#C5C0FF"; font.pixelSize: 24; font.weight: Font.DemiBold }
        }
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ["Elige cómo se ve tu escritorio", "Elige tus colores y tu fondo", "Elige tu Quantum Shell"][win.step]
            color: "#EDE9F7"; font.pixelSize: 58; font.weight: Font.Black
        }
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Puedes cambiarlo cuando quieras desde Personalizar."
            color: "#A39DB8"; font.pixelSize: 20
        }
    }

    // ---------------------------------------------------------------- vista previa dibujada de cada estilo
    component Mini: Item {
        id: mini
        property string kind: "windows"
        clip: true
        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(480, 270)
            asynchronous: true
            source: "file://" + win.wallDir + "/thumbs/" + (mini.kind === "quantum" ? "beako" : mini.kind === "macos" ? "aurora" : mini.kind === "minimal" ? "nucleo" : "orbita") + ".jpg"
        }
        Rectangle { anchors.fill: parent; color: mini.kind === "minimal" ? Qt.rgba(1, 1, 1, 0.35) : "transparent" }
        Rectangle {
            x: parent.width * 0.16; y: parent.height * (mini.kind === "macos" ? 0.2 : 0.14)
            width: parent.width * 0.56; height: parent.height * 0.5; radius: mini.kind === "windows" ? 4 : 9
            color: mini.kind === "minimal" ? Qt.rgba(1, 1, 1, 0.94) : Qt.rgba(0.1, 0.1, 0.13, 0.92)
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
            Row {
                anchors.right: mini.kind === "macos" ? undefined : parent.right; anchors.rightMargin: 8
                x: mini.kind === "macos" ? 8 : 0; y: 6; spacing: 5
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        width: mini.kind === "macos" ? 8 : 9; height: mini.kind === "macos" ? 8 : 3; radius: mini.kind === "macos" ? 4 : 1
                        color: mini.kind === "macos" ? ["#FF5F57", "#FEBC2E", "#28C840"][index] : mini.kind === "minimal" ? "#9A98A8" : Qt.rgba(1, 1, 1, 0.55)
                    }
                }
            }
            Column {
                x: 12; y: 24; spacing: 7
                Repeater {
                    model: 3
                    Rectangle { required property int index; width: [110, 80, 95][index]; height: 6; radius: 3; color: mini.kind === "minimal" ? "#D9D7E3" : Qt.rgba(1, 1, 1, 0.16) }
                }
            }
        }
        Rectangle {   // barra superior
            visible: mini.kind === "quantum" || mini.kind === "macos" || mini.kind === "minimal"
            width: parent.width; height: 14; color: mini.kind === "minimal" ? Qt.rgba(1, 1, 1, 0.8) : Qt.rgba(0.06, 0.06, 0.08, mini.kind === "macos" ? 0.55 : 0.7)
            Rectangle { x: 6; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 6; radius: 3; color: mini.kind === "minimal" ? "#8E8BA0" : Qt.rgba(1, 1, 1, 0.5) }
            Rectangle { anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter; width: 40; height: 6; radius: 3; color: mini.kind === "minimal" ? "#8E8BA0" : Qt.rgba(1, 1, 1, 0.5) }
        }
        Rectangle {   // Windows: barra pegada abajo
            visible: mini.kind === "windows"
            anchors.bottom: parent.bottom; width: parent.width; height: 24; color: Qt.rgba(0.08, 0.08, 0.1, 0.94)
            Row {
                x: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                Rectangle { width: 14; height: 14; radius: 3; color: "#4FB6FF" }
                Rectangle { width: 46; height: 12; radius: 6; color: Qt.rgba(1, 1, 1, 0.14) }
                Repeater { model: 4; Rectangle { required property int index; width: 14; height: 14; radius: 3; color: ["#FF9F43", "#F7D046", "#7BD88F", "#B39DFF"][index] } }
            }
            Rectangle { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; width: 44; height: 8; radius: 4; color: Qt.rgba(1, 1, 1, 0.45) }
        }
        Rectangle {   // Quantum y macOS: barra flotante centrada (Minimal: escondida)
            visible: mini.kind === "quantum" || mini.kind === "macos"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 6; anchors.horizontalCenter: parent.horizontalCenter
            width: dockRow.width + 14; height: mini.kind === "macos" ? 28 : 24; radius: 9
            color: Qt.rgba(0.12, 0.1, 0.15, mini.kind === "macos" ? 0.55 : 0.85)
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14)
            Row {
                id: dockRow; anchors.centerIn: parent; spacing: 5
                Repeater {
                    model: mini.kind === "macos" ? 6 : 5
                    Rectangle { required property int index; width: mini.kind === "macos" ? 18 : 15; height: width; radius: 4; color: ["#C5C0FF", "#FF9F43", "#F7D046", "#7BD88F", "#FF8A5B", "#60A5FA"][index] }
                }
            }
        }
        Rectangle {   // Minimal: una rayita donde aparece la barra
            visible: mini.kind === "minimal"
            anchors.bottom: parent.bottom; anchors.bottomMargin: 5; anchors.horizontalCenter: parent.horizontalCenter
            width: 60; height: 4; radius: 2; color: "#8E8BA0"
        }
    }

    // ---------------------------------------------------------------- paso 1: estilos
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.35)
        spacing: 28
        visible: win.step === 0
        Repeater {
            model: win.options
            Rectangle {
                id: c
                required property var modelData
                required property int index
                readonly property bool on: win.chosen === modelData.id
                readonly property real k: win.stage(1 + index)
                width: Math.min(400, (win.width - 240) / 4 - 21); height: width * 1.1; radius: 28
                color: on ? Qt.rgba(0.2, 0.18, 0.28, 0.92) : area.containsMouse ? Qt.rgba(0.17, 0.15, 0.22, 0.9) : Qt.rgba(0.13, 0.12, 0.17, 0.86)
                border.width: on ? 3 : 1
                border.color: on ? "#C5C0FF" : Qt.rgba(1, 1, 1, 0.08)
                opacity: k
                scale: area.pressed ? 0.97 : (on ? 1.03 : area.containsMouse ? 1.015 : 1)
                transform: Translate { y: (1 - c.k) * 50 }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: 150 } }
                Mini { x: 18; y: 18; width: parent.width - 36; height: (parent.width - 36) * 0.6; kind: c.modelData.id }
                Column {
                    x: 26; y: (c.width - 36) * 0.6 + 42; width: parent.width - 52; spacing: 10
                    Row {
                        spacing: 12
                        Txt { text: c.modelData.name; color: "#EDE9F7"; font.pixelSize: 28; font.weight: Font.Bold }
                        Rectangle {
                            visible: c.modelData.tag !== ""
                            anchors.verticalCenter: parent.verticalCenter
                            width: tagTxt.implicitWidth + 22; height: 28; radius: 14
                            color: c.modelData.tag === "Recomendado" ? Qt.rgba(0.77, 0.75, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                            Txt { id: tagTxt; anchors.centerIn: parent; text: c.modelData.tag; color: c.modelData.tag === "Recomendado" ? "#C5C0FF" : "#A39DB8"; font.pixelSize: 14; font.weight: Font.DemiBold }
                        }
                    }
                    Txt { width: parent.width; wrapMode: Text.WordWrap; text: c.modelData.desc; color: "#A39DB8"; font.pixelSize: 18 }
                }
                Rectangle {
                    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 30
                    width: 40; height: 40; radius: 20; color: "#C5C0FF"
                    scale: c.on ? 1 : 0
                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                    Icon { anchors.centerIn: parent; text: "check"; size: 24; color: "#2A1A9A" }
                }
                MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.pick(c.modelData.id) }
            }
        }
    }

    // ---------------------------------------------------------------- paso 2: colores y fondo
    readonly property var walls: ["quantum:live", wallDir + "/beako.jpg", wallDir + "/orbita.png", wallDir + "/nucleo.png", wallDir + "/aurora.png"]
    readonly property var accents: ["#6A5CFF", "#2F7BFF", "#14B8A6", "#22C55E", "#F59E0B", "#FF6B8B", "#E5484D"]
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.33)
        spacing: 30
        visible: win.step === 1
        opacity: win.step === 1 ? 1 : 0

        // claro / oscuro
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 18
            Repeater {
                model: [{ v: "dark", n: "Oscuro", i: "dark_mode" }, { v: "light", n: "Claro", i: "light_mode" }]
                Rectangle {
                    id: m
                    required property var modelData
                    readonly property bool on: Settings.appearance.mode === modelData.v
                    width: 230; height: 70; radius: 35
                    color: on ? "#C5C0FF" : Qt.rgba(0.13, 0.12, 0.17, 0.86)
                    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Row {
                        anchors.centerIn: parent; spacing: 10
                        Icon { text: m.modelData.i; size: 24; fill: 1; color: m.on ? "#2A1A9A" : "#EDE9F7" }
                        Txt { anchors.verticalCenter: parent.verticalCenter; text: m.modelData.n; font.pixelSize: 20; font.weight: Font.Bold; color: m.on ? "#2A1A9A" : "#EDE9F7" }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Settings.set("appearance", "mode", m.modelData.v) }
                }
            }
        }

        // fondos
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 18
            Repeater {
                model: win.walls
                Rectangle {
                    id: w
                    required property string modelData
                    readonly property bool on: Settings.appearance.wallpaper === modelData
                    width: 260; height: 146; radius: 18
                    color: "#1C1A24"
                    border.width: on ? 3 : 1; border.color: on ? "#C5C0FF" : Qt.rgba(1, 1, 1, 0.1)
                    scale: wa.pressed ? 0.95 : on ? 1.04 : 1
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                    clip: true
                    Image {
                        anchors.fill: parent; anchors.margins: 3
                        visible: w.modelData !== "quantum:live"
                        fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(520, 292)
                        source: w.modelData === "quantum:live" ? "" : "file://" + win.wallDir + "/thumbs/" + w.modelData.split("/").pop().replace(/\.(png|jpg)$/, ".jpg")
                    }
                    Item {
                        anchors.fill: parent
                        visible: w.modelData === "quantum:live"
                        Rectangle { anchors.fill: parent; anchors.margins: 3; radius: 15; gradient: Gradient { GradientStop { position: 0; color: "#1B1640" } GradientStop { position: 1; color: "#06050C" } } }
                        Image { anchors.centerIn: parent; width: 70; height: 70; source: Quickshell.shellDir + "/assets/quantum-mark.svg"; sourceSize: Qt.size(140, 140) }
                        Txt { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 10; text: "Fondo vivo"; color: "white"; font.pixelSize: 14; font.weight: Font.DemiBold }
                    }
                    MouseArea { id: wa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Settings.set("appearance", "wallpaper", w.modelData) }
                }
            }
        }

        // colores
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 26
            Rectangle {
                id: dyn
                readonly property bool on: Settings.appearance.dynamicColors
                width: 300; height: 62; radius: 31
                color: on ? Qt.rgba(0.77, 0.75, 1, 0.2) : Qt.rgba(0.13, 0.12, 0.17, 0.86)
                border.width: 1; border.color: on ? "#C5C0FF" : Qt.rgba(1, 1, 1, 0.1)
                Row {
                    anchors.centerIn: parent; spacing: 10
                    Icon { text: "palette"; size: 22; fill: 1; color: "#EDE9F7" }
                    Txt { anchors.verticalCenter: parent.verticalCenter; text: "Colores de tu fondo"; font.pixelSize: 18; font.weight: Font.DemiBold; color: "#EDE9F7" }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter; width: 42; height: 24; radius: 12
                        color: dyn.on ? "#C5C0FF" : Qt.rgba(1, 1, 1, 0.2)
                        Rectangle { width: 18; height: 18; radius: 9; y: 3; x: dyn.on ? 21 : 3; color: dyn.on ? "#2A1A9A" : "white"; Behavior on x { NumberAnimation { duration: 150 } } }
                    }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Settings.set("appearance", "dynamicColors", !dyn.on) }
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                opacity: Settings.appearance.dynamicColors ? 0.35 : 1
                Repeater {
                    model: win.accents
                    Rectangle {
                        id: sw
                        required property string modelData
                        readonly property bool on: !Settings.appearance.dynamicColors && Settings.appearance.accent.toLowerCase() === modelData.toLowerCase()
                        width: 44; height: 44; radius: 22; color: modelData
                        border.width: on ? 4 : 0; border.color: "white"
                        scale: on ? 1.12 : 1
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: Settings.setMany({ appearance: { dynamicColors: false, accent: sw.modelData } })
                        }
                    }
                }
            }
        }
    }


    // ---------------------------------------------------------------- paso 3: la forma del shell
    readonly property var shells: [
        { id: "caelestial", name: "Caelestial", tag: "El de siempre",
          desc: "Inspirado en Caelestia Shell, pero más liviano: barra arriba, dock flotante y paneles de vidrio con tus colores." },
        { id: "serpantium", name: "Serpantium", tag: "Nuevo",
          desc: "Inspirado en Serpantinum de ilyamiro: barra de píldoras, paneles oscuros que bajan, letra monoespaciada y tonos rosados." },
    ]
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.33)
        spacing: 36
        visible: win.step === 2
        Repeater {
            model: win.shells
            Rectangle {
                id: sc
                required property var modelData
                readonly property bool on: Settings.ui.shell === modelData.id
                readonly property bool serp: modelData.id === "serpantium"
                width: Math.min(620, (win.width - 300) / 2); height: width * 0.8; radius: 30
                color: on ? Qt.rgba(0.2, 0.18, 0.28, 0.92) : sa.containsMouse ? Qt.rgba(0.17, 0.15, 0.22, 0.9) : Qt.rgba(0.13, 0.12, 0.17, 0.86)
                border.width: on ? 3 : 1
                border.color: on ? (serp ? "#F4A7C9" : "#C5C0FF") : Qt.rgba(1, 1, 1, 0.08)
                scale: sa.pressed ? 0.97 : on ? 1.02 : 1
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

                // vista previa dibujada
                Item {
                    id: pv
                    x: 20; y: 20; width: parent.width - 40; height: width * 0.56
                    clip: true
                    Image {
                        anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(480, 270)
                        source: "file://" + win.wallDir + "/thumbs/" + (sc.serp ? "serpantium" : "orbita") + ".jpg"
                    }
                    // Caelestial: barra arriba, dock flotante, panel de vidrio
                    Item {
                        anchors.fill: parent; visible: !sc.serp
                        Rectangle { x: 8; y: 6; width: parent.width - 16; height: 16; radius: 8; color: Qt.rgba(0.08, 0.07, 0.12, 0.75) }
                        Rectangle {
                            anchors.right: parent.right; anchors.rightMargin: 14; y: 30; width: parent.width * 0.3; height: parent.height * 0.55; radius: 12
                            color: Qt.rgba(0.12, 0.1, 0.2, 0.75); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
                            Grid { x: 10; y: 10; columns: 2; spacing: 6; Repeater { model: 4; Rectangle { width: (pv.width * 0.3 - 26) / 2; height: 20; radius: 8; color: index === 0 ? "#6A5CFF" : Qt.rgba(1, 1, 1, 0.12) } } }
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.horizontalCenter: parent.horizontalCenter
                            width: 170; height: 30; radius: 12; color: Qt.rgba(0.1, 0.09, 0.15, 0.85); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14)
                            Row { anchors.centerIn: parent; spacing: 6; Repeater { model: 6; Rectangle { width: 18; height: 18; radius: 5; color: ["#4FD8FF", "#6A5CFF", "#B14DFF", "#7BD88F", "#FF9F43", "#F7D046"][index] } } }
                        }
                    }
                    // Serpantium: píldoras arriba y un panel oscuro que baja
                    Item {
                        anchors.fill: parent; visible: sc.serp
                        Row {
                            x: 6; y: 6; spacing: 4
                            Repeater { model: [14, 14, 44, 70]; Rectangle { required property var modelData; width: modelData; height: 14; radius: 4; color: "#1F171D" } }
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter; y: 6; spacing: 4
                            Rectangle { width: 48; height: 14; radius: 4; color: "#1F171D"; Text { anchors.centerIn: parent; text: "23:40"; font.family: "JetBrains Mono"; font.pixelSize: 8; color: "#F3E7ED" } }
                            Rectangle { width: 30; height: 14; radius: 4; color: "#1F171D" }
                        }
                        Row {
                            anchors.right: parent.right; anchors.rightMargin: 6; y: 6; spacing: 4
                            Repeater { model: [40, 30, 26, 26, 14]; Rectangle { required property var modelData; required property int index; width: modelData; height: 14; radius: 4; color: index === 4 ? "#F4A7C9" : "#1F171D" } }
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter; y: 26; width: parent.width * 0.55; height: parent.height * 0.5; radius: 10
                            color: "#17111A"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                            Text { x: parent.width * 0.38; anchors.verticalCenter: parent.verticalCenter; text: "23:40"; font.family: "JetBrains Mono"; font.pixelSize: 26; font.bold: true; color: "#F3E7ED" }
                            Grid {
                                x: 10; y: 12; columns: 7; spacing: 3
                                Repeater { model: 28; Rectangle { width: 7; height: 7; radius: 2; color: index === 17 ? "#F4A7C9" : Qt.rgba(1, 1, 1, 0.14) } }
                            }
                            Text { anchors.right: parent.right; anchors.rightMargin: 10; y: 10; text: "12°"; font.family: "JetBrains Mono"; font.pixelSize: 18; font.bold: true; color: "#F3E7ED" }
                        }
                    }
                }

                Column {
                    x: 30; y: pv.y + pv.height + 22; width: parent.width - 60; spacing: 10
                    Row {
                        spacing: 12
                        Txt { text: sc.modelData.name; color: "#EDE9F7"; font.pixelSize: 30; font.weight: Font.Bold; font.family: sc.serp ? "JetBrains Mono" : "Inter" }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: st.implicitWidth + 22; height: 28; radius: 14
                            color: sc.serp ? Qt.rgba(0.96, 0.65, 0.79, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                            Txt { id: st; anchors.centerIn: parent; text: sc.modelData.tag; color: sc.serp ? "#F4A7C9" : "#A39DB8"; font.pixelSize: 14; font.weight: Font.DemiBold }
                        }
                    }
                    Txt { width: parent.width; wrapMode: Text.WordWrap; text: sc.modelData.desc; color: "#A39DB8"; font.pixelSize: 18; elide: Text.ElideNone }
                }
                Rectangle {
                    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 34
                    width: 40; height: 40; radius: 20; color: sc.serp ? "#F4A7C9" : "#C5C0FF"
                    scale: sc.on ? 1 : 0
                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                    Icon { anchors.centerIn: parent; text: "check"; size: 24; color: sc.serp ? "#3A1028" : "#2A1A9A" }
                }
                MouseArea { id: sa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Serp.choose(sc.modelData.id) }
            }
        }
    }

    // ---------------------------------------------------------------- pie
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: Math.round(parent.height * 0.16)
        spacing: 10
        opacity: win.stage(5)
        Repeater {
            model: 3
            Rectangle {
                required property int index
                width: index === win.step ? 30 : 10; height: 10; radius: 5
                color: index === win.step ? "#C5C0FF" : Qt.rgba(1, 1, 1, 0.25)
                Behavior on width { NumberAnimation { duration: 200 } }
            }
        }
    }
    Row {
        anchors.right: parent.right; anchors.rightMargin: 120
        anchors.bottom: parent.bottom; anchors.bottomMargin: Math.round(parent.height * 0.06)
        spacing: 18
        opacity: win.stage(5)
        Rectangle {
            width: 170; height: 60; radius: 30; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.2)
            scale: backMa.pressed ? 0.93 : 1
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
            Txt { anchors.centerIn: parent; text: win.step === 0 ? "Saltar" : "Atrás"; color: "#EDE9F7"; font.pixelSize: 19; font.weight: Font.DemiBold }
            MouseArea { id: backMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.step === 0 ? win.finish() : win.step-- }
        }
        Rectangle {
            width: goRow.implicitWidth + 64; height: 60; radius: 30; color: goMa.containsMouse ? "#D6D2FF" : "#C5C0FF"
            scale: goMa.pressed ? 0.93 : 1
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Row {
                id: goRow
                anchors.centerIn: parent; spacing: 8
                Txt { text: win.step < 2 ? "Continuar" : "Empezar a usar Quantum"; color: "#2A1A9A"; font.pixelSize: 19; font.weight: Font.Bold }
                Icon { anchors.verticalCenter: parent.verticalCenter; text: win.step < 2 ? "arrow_forward" : "check"; size: 20; color: "#2A1A9A" }
            }
            MouseArea { id: goMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.step < 2 ? win.step++ : win.finish() }
        }
    }

    // teclado: flechas para elegir, Enter para seguir, Esc para saltar
    Item {
        focus: win.open
        Keys.onLeftPressed: if (win.step === 2) Serp.choose("caelestial"); else if (win.step === 0) { const i = win.options.findIndex(o => o.id === win.chosen); win.pick(win.options[Math.max(0, i - 1)].id); }
        Keys.onRightPressed: if (win.step === 2) Serp.choose("serpantium"); else if (win.step === 0) { const i = win.options.findIndex(o => o.id === win.chosen); win.pick(win.options[Math.min(win.options.length - 1, i + 1)].id); }
        Keys.onReturnPressed: win.step < 2 ? win.step++ : win.finish()
        Keys.onEscapePressed: win.finish()
    }
}
