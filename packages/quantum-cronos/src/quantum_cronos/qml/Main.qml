import QtQuick
import QtQuick.Layouts
import QtQuick.Window

// Cronos: a la izquierda el portal del tiempo y el momento elegido; a la derecha la línea de
// tiempo con todos los momentos a los que se puede volver.
Window {
    id: win
    width: 1180
    height: 740
    minimumWidth: 900
    minimumHeight: 600
    visible: true
    title: "Cronos"
    color: theme.bg

    Theme { id: theme }

    property int sel: 0                       // índice en cronos.moments
    readonly property var moment: (cronos.moments || [])[sel] ?? null
    property bool asking: false               // confirmación abierta
    readonly property var icons: ({ update: "system_update_alt", install: "download", remove: "delete",
                                    origin: "rocket_launch", jump: "history", save: "bookmark" })

    // ------------------------------------------------------------------ fondo
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: theme.alpha(theme.indigo, 0.10) }
            GradientStop { position: 0.6; color: "transparent" }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ------------------------------------------------------------ portal
        Item {
            Layout.preferredWidth: Math.round(win.width * 0.46)
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 32
                spacing: 6
                RowLayout {
                    spacing: 12
                    Image { source: assetsDir + "/quantum-cronos.svg"; sourceSize: Qt.size(84, 84); Layout.preferredWidth: 42; Layout.preferredHeight: 42 }
                    ColumnLayout {
                        spacing: 0
                        T { text: "Cronos"; font.pixelSize: 26; font.weight: Font.Black }
                        T { text: "Vuelve tu PC a cualquier momento"; color: theme.muted; font.pixelSize: 13 }
                    }
                }
                Portal {
                    id: portal
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.min(parent.width, win.height * 0.48)
                    Layout.preferredHeight: Layout.preferredWidth
                    Layout.topMargin: 6
                    speed: 0.05
                }
                // el momento elegido
                ColumnLayout {
                    visible: !!win.moment
                    Layout.fillWidth: true
                    spacing: 4
                    T {
                        Layout.alignment: Qt.AlignHCenter
                        text: win.moment ? win.moment.when : ""
                        font.pixelSize: 24; font.weight: Font.Black
                    }
                    T {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: win.moment ? win.moment.title + " · " + win.moment.ago : ""
                        color: theme.muted
                    }
                    Item { implicitHeight: 12 }
                    Rectangle {
                        id: goBtn
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: goRow.implicitWidth + 48
                        implicitHeight: 52
                        radius: 26
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: theme.cyan }
                            GradientStop { position: 0.5; color: theme.indigo }
                            GradientStop { position: 1; color: theme.violet }
                        }
                        scale: goArea.pressed ? 0.95 : goArea.containsMouse ? 1.03 : 1
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                        Row {
                            id: goRow
                            anchors.centerIn: parent
                            spacing: 8
                            Sym { anchors.verticalCenter: parent.verticalCenter; text: "history"; size: 22; color: "white" }
                            T { anchors.verticalCenter: parent.verticalCenter; text: "Viajar a este momento"; font.pixelSize: 16; font.weight: Font.Bold; color: "white" }
                        }
                        MouseArea { id: goArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.asking = true }
                    }
                    T {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 6
                        text: "Tus documentos, fotos y juegos no cambian."
                        color: theme.muted; font.pixelSize: 12
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }

        // ---------------------------------------------------- línea de tiempo
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: theme.side
            radius: 0
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 28
                spacing: 14
                RowLayout {
                    Layout.fillWidth: true
                    T { Layout.fillWidth: true; text: "Línea del tiempo"; font.pixelSize: 22; font.weight: Font.Bold }
                    Rectangle {
                        implicitWidth: saveRow.implicitWidth + 28; implicitHeight: 40; radius: 20
                        color: saveArea.containsMouse ? theme.cardHi : theme.card
                        border.width: 1; border.color: theme.line
                        Row {
                            id: saveRow
                            anchors.centerIn: parent
                            spacing: 6
                            Sym { anchors.verticalCenter: parent.verticalCenter; text: "bookmark_add"; size: 19; color: theme.accent }
                            T { anchors.verticalCenter: parent.verticalCenter; text: "Guardar este momento"; font.weight: Font.DemiBold }
                        }
                        MouseArea { id: saveArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cronos.saveNow() }
                    }
                }
                T {
                    Layout.fillWidth: true
                    text: "Quantum guarda un momento antes y después de cada actualización. Elige uno para volver a él."
                    color: theme.muted; wrapMode: Text.WordWrap; elide: Text.ElideNone
                }

                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 0
                    visible: cronos.status === "ready"
                    model: cronos.moments
                    header: Item {
                        width: list.width
                        height: 64
                        // «Ahora»: el presente, latiendo
                        Rectangle {
                            x: 18 - width / 2; y: 22
                            width: 20; height: 20; radius: 10
                            color: theme.cyan
                            SequentialAnimation on scale { loops: Animation.Infinite; NumberAnimation { to: 1.25; duration: 900 } NumberAnimation { to: 1; duration: 900 } }
                        }
                        Rectangle { x: 17; y: 42; width: 2; height: 22; color: theme.alpha(theme.cyan, 0.5) }
                        Column {
                            x: 48; y: 14
                            T { text: "Ahora"; font.weight: Font.Bold; font.pixelSize: 16 }
                            T { text: "Así está tu PC en este momento"; color: theme.muted; font.pixelSize: 12 }
                        }
                    }
                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool on: win.sel === index
                        width: list.width
                        height: 78
                        // la línea y el nodo
                        Rectangle {
                            x: 17; width: 2; height: parent.height
                            gradient: Gradient {
                                GradientStop { position: 0; color: theme.alpha(theme.indigo, 0.6) }
                                GradientStop { position: 1; color: theme.alpha(theme.violet, row.index === list.count - 1 ? 0 : 0.6) }
                            }
                        }
                        Rectangle {
                            x: 18 - width / 2; y: 39 - height / 2
                            width: row.on ? 22 : 14; height: width; radius: width / 2
                            color: row.on ? theme.violet : theme.side
                            border.width: 3; border.color: row.modelData.important ? theme.cyan : theme.indigo
                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                        }
                        Rectangle {
                            x: 40; y: 6
                            width: parent.width - 44; height: parent.height - 12
                            radius: theme.r
                            color: row.on ? theme.alpha(theme.indigo, 0.22) : rowArea.containsMouse ? theme.card : "transparent"
                            border.width: row.on ? 1 : 0
                            border.color: theme.alpha(theme.violet, 0.6)
                            Behavior on color { ColorAnimation { duration: 140 } }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14; anchors.rightMargin: 14
                                spacing: 12
                                Rectangle {
                                    implicitWidth: 40; implicitHeight: 40; radius: 12
                                    color: theme.alpha(theme.indigo, 0.18)
                                    Sym { anchors.centerIn: parent; text: win.icons[row.modelData.kind] ?? "bookmark"; size: 21; color: theme.accent; fill: 1 }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    RowLayout {
                                        spacing: 8
                                        T { text: row.modelData.title; font.weight: Font.Bold; font.pixelSize: 15 }
                                        Rectangle {
                                            visible: row.modelData.important
                                            implicitWidth: impT.implicitWidth + 14; implicitHeight: 20; radius: 10
                                            color: theme.alpha(theme.cyan, 0.16)
                                            T { id: impT; anchors.centerIn: parent; text: "Importante"; color: theme.cyan; font.pixelSize: 11; font.weight: Font.DemiBold }
                                        }
                                    }
                                    T {
                                        Layout.fillWidth: true
                                        visible: text !== ""
                                        text: row.modelData.detail
                                        color: theme.muted; font.pixelSize: 12
                                    }
                                }
                                T { text: row.modelData.when; color: theme.muted; font.pixelSize: 12 }
                            }
                            MouseArea { id: rowArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.sel = row.index }
                        }
                    }
                }
                // sin Btrfs o con algún problema
                ColumnLayout {
                    visible: cronos.status !== "ready"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10
                    Item { Layout.fillHeight: true }
                    Sym { Layout.alignment: Qt.AlignHCenter; text: cronos.status === "loading" ? "hourglass_top" : "error"; size: 48; color: theme.accent }
                    T {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap; elide: Text.ElideNone
                        text: cronos.status === "loading" ? "Buscando tus momentos…"
                            : cronos.status === "unsupported" ? "Cronos necesita que Quantum esté instalado con Btrfs, como viene al instalarlo. En este PC el sistema usa otro formato."
                            : "No pude leer los momentos guardados. Revisa que el servicio de Snapper esté activo."
                        color: theme.muted
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }

    // ------------------------------------------------------------ confirmar
    Rectangle {
        anchors.fill: parent
        visible: opacity > 0
        opacity: win.asking ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        color: Qt.rgba(0, 0, 0, 0.6)
        MouseArea { anchors.fill: parent; onClicked: win.asking = false }
        Rectangle {
            anchors.centerIn: parent
            width: 520
            height: askCol.implicitHeight + 56
            radius: 24
            color: theme.card
            border.width: 1; border.color: theme.line
            scale: win.asking ? 1 : 0.92
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            MouseArea { anchors.fill: parent }
            ColumnLayout {
                id: askCol
                anchors.fill: parent
                anchors.margins: 28
                spacing: 12
                Sym { text: "history"; size: 40; color: theme.accent }
                T { Layout.fillWidth: true; text: "¿Viajar a " + (win.moment ? win.moment.when.toLowerCase() : "") + "?"; font.pixelSize: 22; font.weight: Font.Black; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                T {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap; elide: Text.ElideNone
                    color: theme.muted
                    text: "Las apps y los ajustes del sistema vuelven a como estaban en ese momento (" + (win.moment ? win.moment.title.toLowerCase() : "") + "). " +
                          "Tus documentos, fotos, descargas y juegos no cambian.\n\n" +
                          "Antes de viajar guardo el presente, así puedes volver si te arrepientes. Al terminar hay que reiniciar el PC."
                }
                RowLayout {
                    Layout.topMargin: 8
                    Layout.alignment: Qt.AlignRight
                    spacing: 10
                    Rectangle {
                        implicitWidth: 120; implicitHeight: 44; radius: 22
                        color: cancelArea.containsMouse ? theme.cardHi : "transparent"
                        border.width: 1; border.color: theme.line
                        T { anchors.centerIn: parent; text: "Cancelar"; font.weight: Font.DemiBold }
                        MouseArea { id: cancelArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.asking = false }
                    }
                    Rectangle {
                        implicitWidth: 150; implicitHeight: 44; radius: 22
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: theme.cyan }
                            GradientStop { position: 0.5; color: theme.indigo }
                            GradientStop { position: 1; color: theme.violet }
                        }
                        T { anchors.centerIn: parent; text: "Viajar"; font.weight: Font.Bold; color: "white" }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { win.asking = false; cronos.travelTo(win.moment.number); }
                        }
                    }
                }
            }
        }
    }

    // --------------------------------------------------------------- el viaje
    Rectangle {
        anchors.fill: parent
        visible: opacity > 0
        opacity: cronos.travel !== "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 400 } }
        color: theme.bg
        MouseArea { anchors.fill: parent }
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 18
            Portal {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(win.width, win.height) * 0.5
                Layout.preferredHeight: Layout.preferredWidth
                // hacia atrás y rápido mientras viaja; tranquilo al llegar
                speed: cronos.travel === "running" ? -0.9 : 0.05
                Behavior on speed { NumberAnimation { duration: 900; easing.type: Easing.InOutQuad } }
            }
            T {
                Layout.alignment: Qt.AlignHCenter
                text: cronos.travel === "done" ? "Llegaste" : cronos.travel === "error" ? "El viaje no pudo terminar" : "Viajando en el tiempo…"
                font.pixelSize: 30; font.weight: Font.Black
            }
            // los pasos
            Column {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                visible: cronos.travel !== "error"
                Repeater {
                    model: ["Guardando el presente", "Volviendo en el tiempo", "Preparando el arranque"]
                    Row {
                        id: stepRow
                        required property string modelData
                        required property int index
                        readonly property bool ok: cronos.step > index + 1 || cronos.travel === "done"
                        readonly property bool now: cronos.step === index + 1 && cronos.travel === "running"
                        spacing: 10
                        Sym { text: stepRow.ok ? "check_circle" : stepRow.now ? "progress_activity" : "radio_button_unchecked"; size: 20; fill: stepRow.ok ? 1 : 0
                              color: stepRow.ok ? theme.cyan : stepRow.now ? theme.accent : theme.muted
                              RotationAnimation on rotation { running: stepRow.now; from: 0; to: 360; duration: 1000; loops: Animation.Infinite } }
                        T { text: stepRow.modelData; color: stepRow.ok || stepRow.now ? theme.fg : theme.muted; font.pixelSize: 15 }
                    }
                }
            }
            T {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 520
                visible: cronos.travel === "done" || cronos.travel === "error"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap; elide: Text.ElideNone
                color: theme.muted
                text: cronos.travel === "done" ? "Reinicia el PC para terminar el viaje. Si algo no te gusta, abre Cronos y vuelve a «Antes de un viaje con Cronos»."
                                               : (cronos.stepText || "Algo salió mal.") + " Tu sistema no se reinició: puedes intentarlo de nuevo."
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                visible: cronos.travel === "done" || cronos.travel === "error"
                spacing: 10
                Rectangle {
                    implicitWidth: 140; implicitHeight: 46; radius: 23
                    color: laterArea.containsMouse ? theme.cardHi : "transparent"
                    border.width: 1; border.color: theme.line
                    T { anchors.centerIn: parent; text: cronos.travel === "done" ? "Más tarde" : "Cerrar"; font.weight: Font.DemiBold }
                    MouseArea { id: laterArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cronos.resetTravel() }
                }
                Rectangle {
                    visible: cronos.travel === "done"
                    implicitWidth: 180; implicitHeight: 46; radius: 23
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: theme.cyan }
                        GradientStop { position: 0.5; color: theme.indigo }
                        GradientStop { position: 1; color: theme.violet }
                    }
                    Row {
                        anchors.centerIn: parent; spacing: 8
                        Sym { anchors.verticalCenter: parent.verticalCenter; text: "restart_alt"; size: 20; color: "white" }
                        T { anchors.verticalCenter: parent.verticalCenter; text: "Reiniciar ahora"; font.weight: Font.Bold; color: "white" }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cronos.reboot() }
                }
            }
        }
    }

    // aviso flotante
    Rectangle {
        id: toast
        property string msg: ""
        property bool shown: false
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: shown ? 24 : -60
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        width: toastT.implicitWidth + 44; height: 44; radius: 22
        color: theme.cardHi
        T { id: toastT; anchors.centerIn: parent; text: toast.msg; font.weight: Font.DemiBold }
        Timer { id: toastTimer; interval: 3000; onTriggered: toast.shown = false }
        Connections { target: cronos; function onToast(m) { toast.msg = m; toast.shown = true; toastTimer.restart(); } }
    }

}
