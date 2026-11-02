import QtQuick
import QtQuick.Layouts
import QtQuick.Window

// Ayuda y sugerencias: a la izquierda se elige «Algo no funciona» o «Tengo una idea»; a la derecha
// el formulario, con lo que se envía siempre a la vista (y cada parte se puede quitar).
Window {
    id: win
    width: 1120
    height: 800
    minimumWidth: 920
    minimumHeight: 640
    visible: true
    title: "Ayuda y sugerencias"
    color: theme.bg

    Theme { id: theme }

    property string kind: ayuda.startKind || "problema"
    readonly property bool problem: kind === "problema"
    property string area: ""
    property bool withInfo: true
    property bool withLogs: true
    property string preview: ""              // "" | info | logs
    readonly property bool ready: titleF.input.text.trim().length >= 3 && bodyF.input.text.trim().length >= 10 && area !== ""
    readonly property var areas: problem
        ? ["Escritorio", "Apps", "Juegos", "Internet y Wi-Fi", "Instalación", "Otra cosa"]
        : ["Escritorio", "Apps", "Juegos", "Diseño", "Nueva función", "Otra cosa"]
    onKindChanged: area = ""

    component Grad: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: theme.cyan }
        GradientStop { position: 0.5; color: theme.indigo }
        GradientStop { position: 1; color: theme.violet }
    }
    component Toggle: Rectangle {
        id: tg
        property bool on: false
        signal toggled
        implicitWidth: 46; implicitHeight: 26; radius: 13
        color: on ? theme.indigo : theme.cardHi
        Behavior on color { ColorAnimation { duration: 150 } }
        Rectangle {
            x: tg.on ? 23 : 3; y: 3; width: 20; height: 20; radius: 10; color: "white"
            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tg.toggled() }
    }
    component Field: Rectangle {
        property alias input: ed
        property string hint: ""
        property bool multi: false
        radius: 14
        color: theme.card
        border.width: ed.activeFocus ? 2 : 1
        border.color: ed.activeFocus ? theme.indigo : theme.line
        Behavior on border.color { ColorAnimation { duration: 150 } }
        TextEdit {
            id: ed
            anchors.fill: parent
            anchors.margins: 14
            wrapMode: TextEdit.Wrap
            font.family: theme.font; font.pixelSize: 15
            color: theme.fg
            selectionColor: theme.indigo
            clip: true
            Keys.onReturnPressed: e => { if (!parent.multi) e.accepted = true; else e.accepted = false; }
            Keys.onTabPressed: e => { nextItemInFocusChain().forceActiveFocus(); e.accepted = true; }
        }
        T { anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 14; visible: !ed.text && !ed.activeFocus
            text: parent.hint; color: theme.muted; font.pixelSize: 15 }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ------------------------------------------------------------ elegir
        Rectangle {
            Layout.preferredWidth: 400
            Layout.fillHeight: true
            color: theme.side
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 30
                spacing: 14
                RowLayout {
                    spacing: 12
                    Image { source: assetsDir + "/quantum-ayuda.svg"; sourceSize: Qt.size(96, 96); Layout.preferredWidth: 48; Layout.preferredHeight: 48 }
                    ColumnLayout {
                        spacing: 0
                        T { text: "Ayuda y sugerencias"; font.pixelSize: 22; font.weight: Font.Black }
                        T { text: "Lo lee quien hace Quantum"; color: theme.muted; font.pixelSize: 13 }
                    }
                }
                Item { implicitHeight: 6 }
                Repeater {
                    model: [
                        { k: "problema", icon: "build", t: "Algo no funciona", d: "Cuéntanos qué pasó y lo arreglamos.", c: "#4FD8FF" },
                        { k: "sugerencia", icon: "lightbulb", t: "Tengo una idea", d: "Funciones, diseño o lo que se te ocurra.", c: "#B14DFF" },
                    ]
                    Rectangle {
                        id: choice
                        required property var modelData
                        readonly property bool on: win.kind === modelData.k
                        Layout.fillWidth: true
                        implicitHeight: 108
                        radius: 22
                        color: on ? theme.alpha(modelData.c, 0.12) : choiceArea.containsMouse ? theme.card : "transparent"
                        border.width: on ? 2 : 1
                        border.color: on ? modelData.c : theme.line
                        scale: choiceArea.pressed ? 0.97 : 1
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: 180 } }
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 16
                            Rectangle {
                                implicitWidth: 56; implicitHeight: 56; radius: 18
                                color: theme.alpha(choice.modelData.c, 0.2)
                                Sym { anchors.centerIn: parent; text: choice.modelData.icon; size: 30; fill: 1; color: choice.modelData.c }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                T { text: choice.modelData.t; font.pixelSize: 18; font.weight: Font.Bold }
                                T { Layout.fillWidth: true; text: choice.modelData.d; color: theme.muted; font.pixelSize: 13; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                            }
                        }
                        MouseArea { id: choiceArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.kind = choice.modelData.k }
                    }
                }
                Item { Layout.fillHeight: true }
                // privacidad
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: privCol.implicitHeight + 28
                    radius: 18
                    color: theme.card
                    ColumnLayout {
                        id: privCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 6
                        RowLayout {
                            spacing: 8
                            Sym { text: "shield_lock"; size: 20; fill: 1; color: theme.cyan }
                            T { text: "Tu privacidad"; font.weight: Font.Bold }
                        }
                        T {
                            Layout.fillWidth: true
                            text: "Nunca se envía tu nombre, tus archivos ni tus contraseñas. Antes de enviar ves todo lo que va y puedes quitarlo."
                            color: theme.muted; font.pixelSize: 12; wrapMode: Text.WordWrap; elide: Text.ElideNone
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44; radius: 22
                    color: dcArea.containsMouse ? theme.card : "transparent"
                    border.width: 1; border.color: theme.line
                    Row {
                        anchors.centerIn: parent; spacing: 8
                        Sym { anchors.verticalCenter: parent.verticalCenter; text: "forum"; size: 19; color: theme.accent }
                        T { anchors.verticalCenter: parent.verticalCenter; text: "Preguntar en el Discord"; font.weight: Font.DemiBold }
                    }
                    MouseArea { id: dcArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ayuda.openUrl("https://discord.gg/qWmEb9xHkZ") }
                }
            }
        }

        // ----------------------------------------------------------- formulario
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: form.implicitHeight + 60
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: form
                x: 34; y: 26
                width: parent.width - 68
                spacing: 14

                // si el escritorio se acaba de caer
                Rectangle {
                    visible: ayuda.crash
                    Layout.fillWidth: true
                    implicitHeight: crashRow.implicitHeight + 26
                    radius: 18
                    color: theme.alpha(theme.danger, 0.12)
                    border.width: 1; border.color: theme.alpha(theme.danger, 0.4)
                    RowLayout {
                        id: crashRow
                        anchors.fill: parent; anchors.margins: 14
                        spacing: 12
                        Sym { text: "sentiment_dissatisfied"; size: 26; fill: 1; color: theme.danger }
                        T {
                            Layout.fillWidth: true
                            text: "El escritorio se cerró hace un momento. Si nos cuentas qué estabas haciendo, nos ayudas mucho a arreglarlo."
                            wrapMode: Text.WordWrap; elide: Text.ElideNone
                        }
                    }
                }

                T { text: win.problem ? "¿Qué no funciona?" : "¿Cuál es tu idea?"; font.pixelSize: 28; font.weight: Font.Black }

                // área
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: win.areas
                        Rectangle {
                            id: chip
                            required property string modelData
                            readonly property bool on: win.area === modelData
                            width: chipT.implicitWidth + 30; height: 38; radius: 19
                            color: on ? "transparent" : chipArea.containsMouse ? theme.cardHi : theme.card
                            gradient: on ? chipGrad : null
                            border.width: on ? 0 : 1; border.color: theme.line
                            Grad { id: chipGrad }
                            T { id: chipT; anchors.centerIn: parent; text: chip.modelData; font.weight: Font.DemiBold; color: chip.on ? "white" : theme.fg }
                            MouseArea { id: chipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.area = chip.modelData }
                        }
                    }
                }

                Field {
                    id: titleF
                    Layout.fillWidth: true
                    implicitHeight: 50
                    hint: win.problem ? "En pocas palabras (por ejemplo: «El Wi-Fi se desconecta»)" : "En pocas palabras (por ejemplo: «Un modo oscuro para Archivos»)"
                }
                Field {
                    id: bodyF
                    Layout.fillWidth: true
                    implicitHeight: 118
                    multi: true
                    hint: win.problem ? "¿Qué estabas haciendo? ¿Qué esperabas que pasara y qué pasó?" : "Cuéntanos tu idea con todo el detalle que quieras."
                }
                Field {
                    id: contactF
                    Layout.fillWidth: true
                    implicitHeight: 50
                    hint: "Tu correo o usuario de Discord (opcional, para responderte)"
                }

                // qué se envía
                T { Layout.topMargin: 6; text: "Qué se envía"; font.pixelSize: 17; font.weight: Font.Bold }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: sendCol.implicitHeight + 16
                    radius: 18
                    color: theme.card
                    ColumnLayout {
                        id: sendCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 0
                        Repeater {
                            model: [
                                { id: "text", icon: "edit_note", t: "Tu mensaje", d: "Lo que escribiste arriba", fixed: true },
                                { id: "info", icon: "computer", t: "Datos del PC", d: "Versión de Quantum, procesador, gráfica y memoria" },
                                { id: "logs", icon: "receipt_long", t: "Registros del error", d: "Los últimos avisos del sistema, sin tu nombre ni tus redes", onlyProblem: true },
                            ]
                            RowLayout {
                                id: row
                                required property var modelData
                                visible: !modelData.onlyProblem || win.problem
                                Layout.fillWidth: true
                                Layout.margins: 8
                                spacing: 12
                                Rectangle {
                                    implicitWidth: 40; implicitHeight: 40; radius: 12
                                    color: theme.alpha(theme.indigo, 0.16)
                                    Sym { anchors.centerIn: parent; text: row.modelData.icon; size: 21; color: theme.accent }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    T { text: row.modelData.t; font.weight: Font.DemiBold }
                                    T { Layout.fillWidth: true; text: row.modelData.d; color: theme.muted; font.pixelSize: 12 }
                                }
                                T {
                                    visible: !row.modelData.fixed
                                    text: "<a href='#'>Ver</a>"
                                    textFormat: Text.StyledText; linkColor: theme.accent
                                    onLinkActivated: win.preview = row.modelData.id
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                }
                                Toggle {
                                    visible: !row.modelData.fixed
                                    on: row.modelData.id === "info" ? win.withInfo : win.withLogs
                                    onToggled: if (row.modelData.id === "info") win.withInfo = !win.withInfo; else win.withLogs = !win.withLogs
                                }
                                Sym { visible: !!row.modelData.fixed; text: "check_circle"; size: 22; fill: 1; color: theme.cyan }
                            }
                        }
                    }
                }

                // enviar
                Rectangle {
                    Layout.alignment: Qt.AlignRight
                    Layout.topMargin: 4
                    implicitWidth: sendRow.implicitWidth + 52
                    implicitHeight: 52
                    radius: 26
                    opacity: win.ready ? 1 : 0.4
                    gradient: Grad {}
                    scale: sendArea.pressed && win.ready ? 0.95 : sendArea.containsMouse && win.ready ? 1.03 : 1
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    Row {
                        id: sendRow
                        anchors.centerIn: parent; spacing: 8
                        Sym { anchors.verticalCenter: parent.verticalCenter; text: "send"; size: 20; fill: 1; color: "white" }
                        T { anchors.verticalCenter: parent.verticalCenter; text: win.problem ? "Enviar reporte" : "Enviar idea"; font.pixelSize: 16; font.weight: Font.Bold; color: "white" }
                    }
                    MouseArea {
                        id: sendArea
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: win.ready ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (win.ready) ayuda.send(win.kind, win.area, titleF.input.text.trim(), bodyF.input.text.trim(),
                                                             contactF.input.text.trim(), win.withInfo, win.withLogs)
                    }
                }
                T {
                    Layout.alignment: Qt.AlignRight
                    visible: !win.ready
                    text: win.area === "" ? "Elige de qué se trata para poder enviar" : "Escribe un poco más para poder enviar"
                    color: theme.muted; font.pixelSize: 12
                }
            }
        }
    }

    // ---------------------------------------------------- ver lo que se envía
    Rectangle {
        anchors.fill: parent
        visible: opacity > 0
        opacity: win.preview !== "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        color: Qt.rgba(0, 0, 0, 0.6)
        MouseArea { anchors.fill: parent; onClicked: win.preview = "" }
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, 820); height: Math.min(parent.height - 80, 560)
            radius: 24; color: theme.card; border.width: 1; border.color: theme.line
            scale: win.preview !== "" ? 1 : 0.94
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
            MouseArea { anchors.fill: parent }
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 24
                spacing: 12
                RowLayout {
                    T { Layout.fillWidth: true; text: win.preview === "info" ? "Datos del PC" : "Registros del error"; font.pixelSize: 20; font.weight: Font.Black }
                    Rectangle {
                        implicitWidth: 36; implicitHeight: 36; radius: 18
                        color: closeArea.containsMouse ? theme.cardHi : "transparent"
                        Sym { anchors.centerIn: parent; text: "close"; size: 20 }
                        MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.preview = "" }
                    }
                }
                // datos del PC en filas
                ColumnLayout {
                    visible: win.preview === "info"
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: ayuda.info
                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 14
                            T { Layout.preferredWidth: 150; text: modelData[0]; color: theme.muted }
                            T { Layout.fillWidth: true; text: modelData[1]; wrapMode: Text.WrapAnywhere; elide: Text.ElideNone }
                        }
                    }
                }
                // registros tal cual se envían
                Rectangle {
                    visible: win.preview === "logs"
                    Layout.fillWidth: true; Layout.fillHeight: true
                    radius: 14; color: theme.bg
                    Flickable {
                        anchors.fill: parent; anchors.margins: 14
                        contentHeight: logT.implicitHeight
                        clip: true
                        Text {
                            id: logT
                            width: parent.width
                            text: ayuda.logs
                            font.family: "JetBrains Mono"; font.pixelSize: 12
                            color: theme.muted
                            wrapMode: Text.WrapAnywhere
                        }
                    }
                }
                Item { visible: win.preview === "info"; Layout.fillHeight: true }
            }
        }
    }

    // --------------------------------------------------- enviando / enviado
    Rectangle {
        anchors.fill: parent
        visible: opacity > 0
        opacity: ayuda.state !== "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 260 } }
        color: theme.bg
        MouseArea { anchors.fill: parent }
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 180; implicitHeight: 180
                // anillos que salen al llegar
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        anchors.centerIn: parent
                        property real k: 0
                        width: 90 + 120 * k; height: width; radius: width / 2
                        color: "transparent"; border.width: 3
                        border.color: [theme.cyan, theme.indigo, theme.violet][index]
                        opacity: (1 - k) * 0.8
                        SequentialAnimation on k {
                            running: ayuda.state === "sent"
                            PauseAnimation { duration: index * 160 }
                            NumberAnimation { from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }
                        }
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 96; height: 96; radius: 48
                    gradient: Gradient {
                        GradientStop { position: 0; color: theme.cyan }
                        GradientStop { position: 0.5; color: theme.indigo }
                        GradientStop { position: 1; color: theme.violet }
                    }
                    scale: ayuda.state === "sending" ? 0.9 + 0.06 * Math.sin(pulse.t * 6) : 1
                    QtObject { id: pulse; property real t: 0 }
                    FrameAnimation { running: ayuda.state === "sending"; onTriggered: pulse.t += frameTime }
                    Sym {
                        anchors.centerIn: parent
                        text: ayuda.state === "sent" ? "check" : ayuda.state === "queued" ? "schedule_send"
                            : ayuda.state === "sending" ? "send" : "error"
                        size: 48; fill: 1; color: "white"
                    }
                }
            }
            T {
                Layout.alignment: Qt.AlignHCenter
                text: ayuda.state === "sending" ? "Enviando…" : ayuda.state === "sent" ? "Gracias, ya nos llegó"
                    : ayuda.state === "queued" ? "Quedó guardado" : "No se pudo enviar"
                font.pixelSize: 30; font.weight: Font.Black
            }
            T {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 520
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap; elide: Text.ElideNone
                color: theme.muted
                text: ayuda.state === "sent" ? (win.problem ? "Lo vamos a revisar. Si dejaste tu contacto, te avisamos cuando esté arreglado."
                                                              : "Cada idea ayuda a decidir qué llega en la próxima versión de Quantum.")
                    : ayuda.state === "queued" ? "No hay internet ahora. Se enviará solo la próxima vez que abras esta ventana con internet."
                    : ayuda.message
            }
            Rectangle {
                visible: ayuda.state !== "sending"
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                implicitWidth: 160; implicitHeight: 46; radius: 23
                color: doneArea.containsMouse ? theme.cardHi : theme.card
                border.width: 1; border.color: theme.line
                T { anchors.centerIn: parent; text: ayuda.state === "error" || ayuda.state === "limit" ? "Volver" : "Cerrar"; font.weight: Font.DemiBold }
                MouseArea {
                    id: doneArea
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: ayuda.state === "error" || ayuda.state === "limit" ? ayuda.reset() : Qt.quit()
                }
            }
        }
    }
}
