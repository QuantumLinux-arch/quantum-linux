import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

// Pasar desde Windows: trae a Quantum lo que «Pasar a Quantum» guardó en un pendrive.
ApplicationWindow {
    id: window
    width: 1040
    height: 720
    minimumWidth: 900
    minimumHeight: 640
    visible: true
    title: "Pasar desde Windows"
    color: theme.bg

    Theme { id: theme }

    readonly property var s: migrate.summary || ({})
    readonly property string first: (s.name || "").split(" ")[0] || ""
    function gb(b) {
        if (!b) return "nada";
        const g = b / 1073741824;
        return (g >= 100 ? g.toFixed(0) : g >= 1 ? g.toFixed(1) : Math.max(1, Math.round(b / 1048576)) + "").replace(".", ",") + (g >= 1 ? " GB" : " MB");
    }
    function when(iso) {
        if (!iso) return "";
        const d = new Date(iso);
        const m = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
        return d.getDate() + " de " + m[d.getMonth()];
    }
    function plural(n, one, many) { return n === 1 ? "1 " + one : n + " " + many; }

    // -------------------------------------------------------------- cabecera
    RowLayout {
        id: header
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 28
        spacing: 12
        Rectangle {
            implicitWidth: 42; implicitHeight: 42; radius: 14
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: theme.cyan }
                GradientStop { position: 0.5; color: theme.indigo }
                GradientStop { position: 1; color: theme.violet }
            }
            Sym { anchors.centerIn: parent; text: "move_to_inbox"; size: 24; fill: 1; color: "white" }
        }
        T { text: "Pasar desde Windows"; font.pixelSize: 20; font.weight: Font.Bold }
        Item { Layout.fillWidth: true }
        // pasos (solo en el flujo principal)
        Row {
            visible: ["encontrado", "elegir", "pasando", "listo"].indexOf(migrate.state) >= 0
            spacing: 8
            Repeater {
                model: ["Revisar", "Pasar", "Listo"]
                Row {
                    required property string modelData
                    required property int index
                    readonly property int cur: ({ encontrado: 0, elegir: 0, pasando: 1, listo: 2 })[migrate.state] ?? 0
                    spacing: 8
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        anchors.verticalCenter: parent.verticalCenter
                        color: index < parent.cur ? theme.primaryContainer : index === parent.cur ? theme.primary : "transparent"
                        border.width: index > parent.cur ? 1.5 : 0
                        border.color: theme.outline
                        Sym { anchors.centerIn: parent; visible: index < parent.parent.cur; text: "check"; size: 16; color: theme.onPrimaryContainer }
                        T { anchors.centerIn: parent; visible: index >= parent.parent.cur; text: index + 1; font.pixelSize: 12; font.weight: Font.Bold
                            color: index === parent.parent.cur ? theme.onPrimary : theme.muted }
                    }
                    T { anchors.verticalCenter: parent.verticalCenter; text: modelData; font.pixelSize: 13
                        font.weight: index === parent.cur ? Font.Bold : Font.Normal; color: index <= parent.cur ? theme.fg : theme.muted }
                    Rectangle { visible: index < 2; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 1.5; color: index < parent.cur ? theme.primary : theme.outline }
                }
            }
        }
    }

    // ------------------------------------------------------------ contenido
    Item {
        id: body
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: header.bottom; anchors.bottom: parent.bottom
        anchors.leftMargin: 40; anchors.rightMargin: 40; anchors.bottomMargin: 28; anchors.topMargin: 10

        // ================= buscando el pendrive
        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width, 620)
            visible: migrate.state === "buscando"
            spacing: 14
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 170; implicitHeight: 170
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        anchors.centerIn: parent
                        property real p: 0
                        width: 90 + p * 80; height: width; radius: width / 2
                        color: "transparent"; border.width: 2; border.color: theme.primary
                        opacity: 0.6 * (1 - p)
                        SequentialAnimation on p {
                            loops: Animation.Infinite
                            PauseAnimation { duration: index * 600 }
                            NumberAnimation { from: 0; to: 1; duration: 1800; easing.type: Easing.OutCubic }
                        }
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 96; height: 96; radius: 48
                    color: theme.alpha(theme.primary, 0.16)
                    Sym { anchors.centerIn: parent; text: "usb"; size: 52; fill: 1; color: theme.primary }
                }
            }
            T { Layout.alignment: Qt.AlignHCenter; text: "Conecta tu pendrive"; font.pixelSize: 30; font.weight: Font.Black }
            T {
                Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                text: "El que usaste con «Pasar a Quantum» en tu PC con Windows. Lo vamos a detectar solos apenas lo conectes."
                color: theme.muted; font.pixelSize: 15
            }
            Rectangle {
                Layout.fillWidth: true; Layout.topMargin: 14
                implicitHeight: noUsb.implicitHeight + 36; radius: 20
                color: theme.card
                RowLayout {
                    id: noUsb
                    anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.margins: 20
                    spacing: 14
                    Sym { text: "help"; size: 28; color: theme.primary }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        T { text: "¿Todavía no copiaste tus cosas?"; font.weight: Font.Bold; font.pixelSize: 15 }
                        T { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: theme.muted; font.pixelSize: 13
                            text: "Te dejamos «Pasar a Quantum» en un pendrive: lo abres en Windows y copia todo con un par de clics." }
                    }
                    Btn { text: "Preparar un pendrive"; icon: "install_desktop"; style: "tonal"; onClicked: migrate.go("preparar") }
                }
            }
        }

        // ================= encontrado
        ColumnLayout {
            anchors.fill: parent
            visible: migrate.state === "encontrado"
            spacing: 16
            RowLayout {
                spacing: 22
                Layout.topMargin: 10
                Avatar { size: 112; src: window.s.picture ? "file://" + window.s.picture : ""; letter: window.first }
                ColumnLayout {
                    spacing: 4
                    T { text: window.first ? "¡Hola, " + window.first + "!" : "¡Hola!"; font.pixelSize: 18; font.weight: Font.Bold; color: theme.primary }
                    T { text: "Encontramos tus cosas de Windows"; font.pixelSize: 32; font.weight: Font.Black }
                    T {
                        text: (window.s.computer ? "De " + window.s.computer : "De tu PC") + (window.s.created ? " · copiadas el " + window.when(window.s.created) : "")
                        color: theme.muted; font.pixelSize: 14
                    }
                }
            }
            // aviso si la copia quedó a medias o ya se pasó
            Rectangle {
                visible: !window.s.complete || !!window.s.done
                Layout.fillWidth: true
                implicitHeight: warnRow.implicitHeight + 24; radius: 16
                color: theme.alpha(theme.tertiary, 0.14)
                RowLayout {
                    id: warnRow
                    anchors.fill: parent; anchors.margins: 12; anchors.leftMargin: 16; spacing: 10
                    Sym { text: window.s.done ? "info" : "warning"; color: theme.tertiary; size: 22 }
                    T {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 13
                        text: window.s.done ? "Ya pasaste este pendrive antes. Si lo pasas otra vez, solo se agrega lo que falte: nada se duplica."
                            : "La copia en Windows no terminó. Puedes pasar lo que alcanzó a copiarse, o terminarla en Windows primero."
                    }
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 14; rowSpacing: 14
                Found { icon: "folder"; t: 0.0; title: window.plural(window.s.files || 0, "archivo", "archivos"); detail: window.gb(window.s.bytes) + " · " + (window.s.folders || []).join(", "); show: (window.s.folders || []).length > 0 }
                Found { icon: "account_circle"; t: 0.4; title: "Tu cuenta"; detail: [window.s.picture ? "tu foto" : "", window.s.wallpaper ? "tu fondo" : "", window.s.settings ? "tus ajustes" : ""].filter(x => x).join(", "); show: !!(window.s.picture || window.s.wallpaper || window.s.settings) }
                Found { icon: "public"; t: 0.2; title: "Navegadores"; detail: (window.s.browsers || []).join(", "); show: (window.s.browsers || []).length > 0 }
                Found { icon: "wifi"; t: 0.6; title: window.plural((window.s.wifi || []).length, "red Wi-Fi", "redes Wi-Fi"); detail: (window.s.wifi || []).slice(0, 3).join(", "); show: (window.s.wifi || []).length > 0 }
                Found { icon: "sports_esports"; t: 0.8; title: window.plural((window.s.steam || []).length, "juego de Steam", "juegos de Steam"); detail: (window.s.steam || []).map(g => g.name).slice(0, 3).join(", "); show: (window.s.steam || []).length > 0 }
                Found { icon: "apps"; t: 1.0; title: window.plural((window.s.apps || []).length, "app que usabas", "apps que usabas"); detail: (window.s.apps || []).map(a => a.name).slice(0, 4).join(", "); show: (window.s.apps || []).length > 0 }
            }
            Item { Layout.fillHeight: true }
            Running {}
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                T { Layout.fillWidth: true; text: "Nada se borra del pendrive ni de Quantum. Si algo ya existe, se guarda al lado."; color: theme.muted; font.pixelSize: 13; wrapMode: Text.WordWrap }
                Btn { text: "Ahora no"; style: "outline"; onClicked: migrate.quit() }
                Btn { text: "Elegir qué pasar"; icon: "tune"; style: "tonal"; onClicked: migrate.go("elegir") }
                Big { text: "Pasar todo"; icon: "arrow_forward"; onClicked: migrate.start() }
            }
        }

        // ================= elegir
        ColumnLayout {
            anchors.fill: parent
            visible: migrate.state === "elegir"
            spacing: 10
            T { text: "¿Qué pasamos?"; font.pixelSize: 28; font.weight: Font.Black }
            T { text: "Toca para quitar o agregar. Así sabes a dónde va cada cosa."; color: theme.muted; font.pixelSize: 14 }
            Flickable {
                id: chooseFlick
                Layout.fillWidth: true; Layout.fillHeight: true
                contentHeight: chooseCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                ColumnLayout {
                    id: chooseCol
                    width: chooseFlick.width - 14
                    spacing: 10
                    Choice { key: "folders"; icon: "folder"; t: 0.0; title: "Tus archivos"; detail: "A tus carpetas de siempre: " + (window.s.folders || []).join(", ") + ". Las partidas guardadas, a Juegos."; show: (window.s.folders || []).length > 0 }
                    Choice { key: "account"; icon: "account_circle"; t: 0.4; title: "Tu cuenta y tus ajustes"; detail: "Tu foto, tu fondo de pantalla, modo oscuro o claro, formato de hora, teclado y zona horaria."; show: !!(window.s.picture || window.s.wallpaper || window.s.settings) }
                    Choice { key: "wifi"; icon: "wifi"; t: 0.6; title: "Redes Wi-Fi"; detail: "Te conectarás solo a: " + (window.s.wifi || []).join(", ") + "."; show: (window.s.wifi || []).length > 0 }
                    Choice { key: "browsers"; icon: "public"; t: 0.2; title: "Favoritos y contraseñas"; detail: "De " + (window.s.browsers || []).join(" y ") + ". También quedan como archivo en Documentos por si los quieres en otro navegador."; show: (window.s.browsers || []).length > 0 }
                    Choice { key: "steam"; icon: "sports_esports"; t: 0.8; title: "Juegos de Steam"; detail: (window.s.steam || []).map(g => g.name).join(", ") + ". Steam los revisa al abrirlo y los abre con Proton."; show: (window.s.steam || []).length > 0 }
                    T { visible: migrate.apps.length > 0; Layout.topMargin: 12; text: "Tus apps"; font.pixelSize: 19; font.weight: Font.Bold }
                    T { visible: migrate.apps.length > 0; text: "Las que usabas en Windows, en su versión para Quantum (se instalan desde internet)."; color: theme.muted; font.pixelSize: 13 }
                    Flow {
                        Layout.fillWidth: true
                        Layout.preferredWidth: chooseCol.width
                        Layout.preferredHeight: childrenRect.height
                        spacing: 10
                        Repeater {
                            model: migrate.apps
                            AppChip { required property var modelData; a: modelData }
                        }
                    }
                }
            }
            Running {}
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Item { Layout.fillWidth: true }
                Btn { text: "Atrás"; icon: "arrow_back"; style: "outline"; onClicked: migrate.go("encontrado") }
                Big { text: "Pasar lo elegido"; icon: "arrow_forward"; onClicked: migrate.start() }
            }
        }

        // ================= pasando
        RowLayout {
            anchors.fill: parent
            visible: migrate.state === "pasando"
            spacing: 40
            ColumnLayout {
                Layout.preferredWidth: 340
                Layout.alignment: Qt.AlignVCenter
                spacing: 14
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 220; implicitHeight: 220
                    // anillo de avance
                    Canvas {
                        id: ring
                        anchors.fill: parent
                        property real k: migrate.progress
                        onKChanged: requestPaint()
                        onPaint: {
                            const c = getContext("2d"); c.reset();
                            const r = width / 2 - 12;
                            c.lineWidth = 14; c.lineCap = "round";
                            c.strokeStyle = theme.high; c.beginPath(); c.arc(width / 2, height / 2, r, 0, Math.PI * 2); c.stroke();
                            const g = c.createLinearGradient(0, 0, width, height);
                            g.addColorStop(0, theme.cyan); g.addColorStop(0.5, theme.indigo); g.addColorStop(1, theme.violet);
                            c.strokeStyle = g; c.beginPath();
                            c.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0.01, k)); c.stroke();
                        }
                    }
                    T { anchors.centerIn: parent; anchors.verticalCenterOffset: -8; text: Math.round(migrate.progress * 100) + " %"; font.pixelSize: 42; font.weight: Font.Black }
                    T { anchors.centerIn: parent; anchors.verticalCenterOffset: 28; text: "pasado"; color: theme.muted; font.pixelSize: 14 }
                }
                T { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: migrate.progressText; color: theme.muted; font.pixelSize: 13; elide: Text.ElideMiddle }
                T { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; text: "Puedes seguir usando Quantum. No desconectes el pendrive."; color: theme.muted; font.pixelSize: 13 }
                Btn { Layout.alignment: Qt.AlignHCenter; text: "Cancelar"; icon: "close"; style: "outline"; onClicked: migrate.cancel() }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 10
                T { text: "Acomodando tus cosas"; font.pixelSize: 28; font.weight: Font.Black; Layout.bottomMargin: 6 }
                Repeater {
                    model: migrate.steps
                    StepRow { required property var modelData; st: modelData }
                }
            }
        }

        // ================= listo
        ColumnLayout {
            anchors.fill: parent
            visible: migrate.state === "listo"
            spacing: 12
            RowLayout {
                spacing: 18
                Rectangle {
                    implicitWidth: 84; implicitHeight: 84; radius: 42
                    color: theme.alpha("#34D399", 0.18)
                    Sym { anchors.centerIn: parent; text: "celebration"; size: 46; fill: 1; color: "#34D399" }
                }
                ColumnLayout {
                    spacing: 2
                    T { text: window.first ? "¡Bienvenido a casa, " + window.first + "!" : "¡Bienvenido a casa!"; font.pixelSize: 32; font.weight: Font.Black }
                    T { text: "Tus cosas de Windows ya están en Quantum."; color: theme.muted; font.pixelSize: 15 }
                }
            }
            Repeater {
                model: migrate.steps
                StepRow { required property var modelData; st: modelData; Layout.leftMargin: 4 }
            }
            // contraseñas Wi-Fi en el pendrive
            Rectangle {
                visible: (window.s.wifi || []).length > 0 && !window.s.wifiDeleted
                Layout.fillWidth: true; Layout.topMargin: 8
                implicitHeight: wifiRow.implicitHeight + 28; radius: 18
                color: theme.alpha(theme.tertiary, 0.12)
                RowLayout {
                    id: wifiRow
                    anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.margins: 18
                    spacing: 12
                    Sym { text: "lock"; size: 26; color: theme.tertiary }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        T { text: "Tus contraseñas Wi-Fi siguen en el pendrive"; font.weight: Font.Bold }
                        T { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: theme.muted; font.pixelSize: 13; text: "Ya quedaron guardadas en Quantum. Bórralas del pendrive para que nadie más las lea." }
                    }
                    Btn { text: "Borrarlas del pendrive"; icon: "delete"; style: "danger"; onClicked: migrate.deleteWifi() }
                }
            }
            T { visible: !!window.s.wifiDeleted; text: "Listo: las contraseñas Wi-Fi se borraron del pendrive."; color: "#34D399"; font.pixelSize: 13 }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                T { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: theme.muted; font.pixelSize: 13
                    text: "Ya puedes desconectar el pendrive. Si cambiaste algo en Windows, vuelve a pasarlo: solo se agrega lo nuevo." }
                Btn { text: "Abrir mis archivos"; icon: "folder_open"; style: "tonal"; onClicked: migrate.openHome() }
                Big { text: "Listo"; icon: "check"; onClicked: migrate.quit() }
            }
        }

        // ================= preparar un pendrive
        ColumnLayout {
            anchors.fill: parent
            visible: migrate.state === "preparar"
            spacing: 12
            T { text: "Prepara un pendrive"; font.pixelSize: 30; font.weight: Font.Black }
            T { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: theme.muted; font.pixelSize: 15
                text: "Copiamos «Pasar a Quantum» al pendrive. Después lo abres en tu PC con Windows y él copia tus cosas al mismo pendrive." }
            RowLayout {
                Layout.fillWidth: true; Layout.topMargin: 8
                spacing: 14
                Repeater {
                    model: [{ i: "usb", t: "Elige un pendrive", d: "Con espacio para tus archivos (sus cosas no se borran)." },
                            { i: "desktop_windows", t: "Ábrelo en Windows", d: "Doble clic en «Pasar a Quantum» y elige qué llevar." },
                            { i: "celebration", t: "Vuelve a Quantum", d: "Conéctalo aquí y se acomoda todo solo." }]
                    Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 128; radius: 20; color: theme.card
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 18; spacing: 4
                            RowLayout {
                                spacing: 10
                                Rectangle { implicitWidth: 30; implicitHeight: 30; radius: 15; color: theme.primaryContainer
                                    T { anchors.centerIn: parent; text: index + 1; font.weight: Font.Black; color: theme.onPrimaryContainer } }
                                Sym { text: modelData.i; size: 24; color: theme.primary }
                            }
                            T { text: modelData.t; font.pixelSize: 16; font.weight: Font.Bold; Layout.topMargin: 4 }
                            T { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: modelData.d; color: theme.muted; font.pixelSize: 13 }
                        }
                    }
                }
            }
            T { Layout.topMargin: 10; text: migrate.drives.length ? "Tus pendrives" : ""; font.pixelSize: 18; font.weight: Font.Bold }
            Rectangle {
                visible: migrate.drives.length === 0
                Layout.fillWidth: true
                implicitHeight: 90; radius: 20; color: theme.card
                RowLayout {
                    anchors.fill: parent; anchors.margins: 20; spacing: 14
                    Sym { text: "usb"; size: 30; color: theme.muted }
                    T { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "Conecta un pendrive: aparecerá aquí."; color: theme.muted; font.pixelSize: 15 }
                }
            }
            Repeater {
                model: migrate.drives
                Rectangle {
                    id: drv
                    required property var modelData
                    readonly property bool doneHere: migrate.prep.done === modelData.path
                    Layout.fillWidth: true
                    implicitHeight: 76; radius: 20
                    color: doneHere ? theme.alpha("#34D399", 0.12) : theme.card
                    border.width: doneHere ? 2 : 1
                    border.color: doneHere ? "#34D399" : theme.alpha(theme.fg, 0.06)
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 16; spacing: 14
                        Sym { text: drv.doneHere ? "check_circle" : "usb"; size: 30; fill: 1; color: drv.doneHere ? "#34D399" : theme.primary }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            T { text: drv.modelData.name; font.pixelSize: 16; font.weight: Font.Bold }
                            T { text: drv.doneHere ? "Listo: ya tiene «Pasar a Quantum». Ahora ábrelo en Windows." : window.gb(drv.modelData.free) + " libres"
                                color: drv.doneHere ? "#34D399" : theme.muted; font.pixelSize: 13 }
                        }
                        Big {
                            Layout.alignment: Qt.AlignRight
                            visible: !drv.doneHere
                            enabled: migrate.hasExe && !migrate.prep.busy
                            text: migrate.prep.busy ? "Copiando…" : "Copiar aquí"; icon: "download"
                            onClicked: migrate.prepareCopy(drv.modelData.path)
                        }
                    }
                }
            }
            T { visible: !!migrate.prep.error; text: migrate.prep.error || ""; color: theme.error }
            T { visible: !migrate.hasExe; text: "Falta «Pasar a Quantum.exe» en este sistema: descárgalo desde quantumlinux-arch.github.io."; color: theme.error; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillWidth: true
                T { Layout.fillWidth: true; text: "También puedes descargarlo en Windows desde quantumlinux-arch.github.io."; color: theme.muted; font.pixelSize: 13 }
                Btn { text: migrate.prep.done ? "Listo" : "Cerrar"; style: migrate.prep.done ? "filled" : "outline"; onClicked: migrate.quit() }
            }
        }
    }

    // ---------------------------------------------------------- componentes
    component Big: Rectangle {
        id: big
        property string text
        property string icon
        signal clicked
        implicitWidth: bigRow.implicitWidth + 56; implicitHeight: 52; radius: 26
        Layout.preferredWidth: implicitWidth
        Layout.fillWidth: false
        opacity: enabled ? 1 : 0.45
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: theme.cyan }
            GradientStop { position: 0.5; color: theme.indigo }
            GradientStop { position: 1; color: theme.violet }
        }
        scale: bigArea.pressed ? 0.96 : bigArea.containsMouse ? 1.03 : 1
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
        RowLayout {
            id: bigRow
            anchors.centerIn: parent; spacing: 8
            T { text: big.text; color: "white"; font.pixelSize: 16; font.weight: Font.Bold }
            Sym { visible: big.icon !== ""; text: big.icon; size: 22; color: "white" }
        }
        MouseArea { id: bigArea; anchors.fill: parent; hoverEnabled: true; enabled: big.enabled; cursorShape: Qt.PointingHandCursor; onClicked: big.clicked() }
    }

    // foto de la cuenta en un círculo (o la inicial si no hay foto)
    component Avatar: Item {
        id: av
        property real size: 96
        property string src
        property string letter
        implicitWidth: size; implicitHeight: size
        Rectangle {
            anchors.fill: parent; radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0; color: theme.cyan }
                GradientStop { position: 1; color: theme.violet }
            }
        }
        Image {
            id: avImg
            anchors.fill: parent; anchors.margins: 4
            source: av.src
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(av.size * 2, av.size * 2)
            visible: false
            layer.enabled: true
        }
        Rectangle { id: avMask; anchors.fill: avImg; radius: width / 2; visible: false; layer.enabled: true }
        MultiEffect {
            anchors.fill: avImg
            visible: avImg.status === Image.Ready
            source: avImg
            maskEnabled: true
            maskSource: avMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
        T { anchors.centerIn: parent; visible: avImg.status !== Image.Ready; text: (av.letter || "?").charAt(0).toUpperCase()
            font.pixelSize: av.size * 0.42; font.weight: Font.Black; color: "white" }
    }

    // tarjeta de «lo que encontramos»
    component Found: Rectangle {
        property string icon
        property real t: 0
        property string title
        property string detail
        property bool show: true
        visible: show
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 96; radius: 20
        color: theme.card
        border.width: 1; border.color: theme.alpha(theme.fg, 0.06)
        RowLayout {
            anchors.fill: parent; anchors.margins: 18; spacing: 14
            Rectangle {
                implicitWidth: 48; implicitHeight: 48; radius: 24
                color: theme.alpha(Qt.tint(theme.cyan, Qt.rgba(0.69, 0.3, 1, parent.parent.t)), 0.2)
                Sym { anchors.centerIn: parent; text: parent.parent.parent.icon; size: 26; fill: 1; color: Qt.tint(theme.cyan, Qt.rgba(0.69, 0.3, 1, parent.parent.parent.t)) }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                T { Layout.fillWidth: true; text: parent.parent.parent.title; font.pixelSize: 16; font.weight: Font.Bold }
                T { Layout.fillWidth: true; text: parent.parent.parent.detail; color: theme.muted; font.pixelSize: 13; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
            }
        }
    }

    // opción con interruptor (pantalla «elegir»)
    component Choice: Rectangle {
        id: ch
        property string key
        property string icon
        property real t: 0
        property string title
        property string detail
        property bool show: true
        readonly property bool on: !!migrate.choices[key]
        visible: show
        Layout.fillWidth: true
        implicitHeight: chRow.implicitHeight + 32; radius: 20
        color: on ? theme.alpha(theme.primary, 0.10) : chArea.containsMouse ? theme.high : theme.card
        border.width: on ? 2 : 1
        border.color: on ? theme.alpha(theme.primary, 0.6) : theme.alpha(theme.fg, 0.06)
        Behavior on color { ColorAnimation { duration: 150 } }
        RowLayout {
            id: chRow
            anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.margins: 18
            spacing: 14
            Rectangle {
                implicitWidth: 46; implicitHeight: 46; radius: 23
                color: theme.alpha(Qt.tint(theme.cyan, Qt.rgba(0.69, 0.3, 1, ch.t)), 0.2)
                Sym { anchors.centerIn: parent; text: ch.icon; size: 24; fill: 1; color: Qt.tint(theme.cyan, Qt.rgba(0.69, 0.3, 1, ch.t)) }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                T { text: ch.title; font.pixelSize: 16; font.weight: Font.Bold }
                T { Layout.fillWidth: true; text: ch.detail; color: theme.muted; font.pixelSize: 13; wrapMode: Text.WordWrap }
            }
            Switch { checked: ch.on; onToggled: migrate.setChoice(ch.key, checked) }
        }
        MouseArea { id: chArea; anchors.fill: parent; hoverEnabled: true; z: -1; cursorShape: Qt.PointingHandCursor; onClicked: migrate.setChoice(ch.key, !ch.on) }
    }

    // app sugerida
    component AppChip: Rectangle {
        id: ac
        property var a
        readonly property bool fixed: !a.flatpak || a.installed
        readonly property bool on: fixed || a.on
        implicitWidth: acRow.implicitWidth + 32; implicitHeight: 62; radius: 18
        color: on && !fixed ? theme.alpha(theme.primary, 0.12) : theme.card
        border.width: on && !fixed ? 2 : 1
        border.color: on && !fixed ? theme.alpha(theme.primary, 0.6) : theme.alpha(theme.fg, 0.06)
        RowLayout {
            id: acRow
            anchors.centerIn: parent; spacing: 10
            Rectangle {
                implicitWidth: 26; implicitHeight: 26; radius: 13
                color: ac.on ? (ac.fixed ? theme.high : theme.primary) : "transparent"
                border.width: ac.on ? 0 : 2; border.color: theme.outline
                Sym { anchors.centerIn: parent; visible: ac.on; text: "check"; size: 16; color: ac.fixed ? theme.muted : theme.onPrimary }
            }
            ColumnLayout {
                spacing: 0
                T { text: ac.a.name; font.weight: Font.Bold; font.pixelSize: 14 }
                T { text: ac.fixed ? (ac.a.installed && ac.a.flatpak ? "Ya está instalada" : ac.a.note) : ac.a.note; color: theme.muted; font.pixelSize: 12 }
            }
        }
        MouseArea { anchors.fill: parent; enabled: !ac.fixed; cursorShape: Qt.PointingHandCursor; onClicked: migrate.setApp(ac.a.flatpak, !ac.a.on) }
    }

    // fila de un paso (pasando / listo)
    component StepRow: Rectangle {
        id: sr
        property var st
        Layout.fillWidth: true
        implicitHeight: 64; radius: 18
        color: st.state === "running" ? theme.alpha(theme.primary, 0.10) : theme.card
        border.width: st.state === "running" ? 2 : 1
        border.color: st.state === "running" ? theme.alpha(theme.primary, 0.6) : theme.alpha(theme.fg, 0.06)
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 18; spacing: 14
            Item {
                implicitWidth: 30; implicitHeight: 30
                BusyIndicator { anchors.fill: parent; running: sr.st.state === "running"; visible: running }
                Sym { anchors.centerIn: parent; visible: sr.st.state !== "running"; size: 28; fill: 1
                      text: sr.st.state === "ok" ? "check_circle" : sr.st.state === "error" ? "error" : "radio_button_unchecked"
                      color: sr.st.state === "ok" ? "#34D399" : sr.st.state === "error" ? theme.tertiary : theme.outline }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                T { text: sr.st.title; font.pixelSize: 15; font.weight: Font.Bold; color: sr.st.state === "waiting" ? theme.muted : theme.fg }
                T { visible: !!sr.st.detail; Layout.fillWidth: true; text: sr.st.detail; color: theme.muted; font.pixelSize: 13; elide: Text.ElideRight }
            }
        }
    }

    // avisos de apps abiertas que hay que cerrar
    component Running: Rectangle {
        readonly property bool fx: migrate.running.firefox && migrate.choices.browsers && (window.s.browsers || []).indexOf("Firefox") >= 0
        readonly property bool st: migrate.running.steam && migrate.choices.steam && (window.s.steam || []).length > 0
        visible: fx || st
        Layout.fillWidth: true
        implicitHeight: runRow.implicitHeight + 22; radius: 16
        color: theme.alpha(theme.tertiary, 0.14)
        RowLayout {
            id: runRow
            anchors.fill: parent; anchors.margins: 11; anchors.leftMargin: 16; spacing: 10
            Sym { text: "info"; color: theme.tertiary; size: 22 }
            T {
                Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 13
                text: "Cierra " + [parent.parent.fx ? "Firefox" : "", parent.parent.st ? "Steam" : ""].filter(x => x).join(" y ")
                      + " antes de empezar, para poder pasar " + (parent.parent.fx && parent.parent.st ? "sus datos." : parent.parent.fx ? "tu perfil." : "tus juegos.")
            }
        }
    }
}
