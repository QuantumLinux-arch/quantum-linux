import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Ventana para abrir un programa de Windows con Wine.
ApplicationWindow {
    id: win
    width: 640
    height: 470
    minimumWidth: 560
    minimumHeight: 440
    visible: true
    title: "Programa de Windows"
    color: theme.bg

    Theme { id: theme }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 30
        spacing: 18

        RowLayout {
            spacing: 18
            Rectangle {
                implicitWidth: 76; implicitHeight: 76; radius: 22
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: theme.cyan }
                    GradientStop { position: 0.5; color: theme.indigo }
                    GradientStop { position: 1; color: theme.violet }
                }
                Sym { anchors.centerIn: parent; text: exe.installer ? "install_desktop" : "desktop_windows"; size: 42; fill: 1; color: "white" }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                T { text: "Programa de Windows"; font.pixelSize: 24; font.weight: Font.ExtraBold }
                T { Layout.fillWidth: true; text: exe.fileName; color: theme.muted; font.pixelSize: 14 }
            }
        }

        T {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 15
            elide: Text.ElideNone
            text: exe.installer
                ? "Parece un instalador. Quantum lo abrirá con Wine y, cuando termine, el programa aparecerá en tu menú de apps."
                : "Quantum puede abrirlo con Wine, que permite usar muchos programas de Windows en Linux."
        }

        // Qué esperar
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: tips.implicitHeight + 28
            radius: 18
            color: theme.card
            ColumnLayout {
                id: tips
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 14
                spacing: 8
                Repeater {
                    model: [
                        { i: "check_circle", c: "#22B573", t: "Muchos programas y juegos funcionan bien." },
                        { i: "info", c: "#E5A50A", t: "Algunos no: antitrampas, drivers o programas muy nuevos." },
                        { i: "storefront", c: theme.primary, t: "Si existe una versión para Linux, suele ir mejor: búscala en la Store." },
                    ]
                    RowLayout {
                        required property var modelData
                        spacing: 10
                        Sym { text: parent.modelData.i; size: 20; fill: 1; color: parent.modelData.c }
                        T { Layout.fillWidth: true; text: parent.modelData.t; font.pixelSize: 13; wrapMode: Text.WordWrap; elide: Text.ElideNone }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Progreso (instalar Wine / preparar el prefijo / abriendo)
        ColumnLayout {
            visible: exe.state !== "ask"
            Layout.fillWidth: true
            spacing: 8
            RowLayout {
                spacing: 10
                BusyIndicator { running: exe.state === "installing" || exe.state === "preparing"; implicitWidth: 28; implicitHeight: 28 }
                Sym { visible: exe.state === "done"; text: "check_circle"; size: 26; fill: 1; color: "#22B573" }
                Sym { visible: exe.state === "error"; text: "error"; size: 26; fill: 1; color: theme.error }
                T {
                    Layout.fillWidth: true
                    font.weight: Font.Bold
                    text: exe.state === "done" ? "Abriendo " + exe.fileName + "…"
                        : exe.state === "error" ? exe.line
                        : exe.state === "installing" ? "Instalando Wine (solo esta vez)…" : "Preparando Wine por primera vez…"
                }
            }
            T { visible: exe.state === "installing" || exe.state === "preparing"; Layout.fillWidth: true; text: exe.line; color: theme.muted; font.pixelSize: 12 }
        }

        CheckBox {
            id: remember
            visible: exe.state === "ask"
            text: "Abrir siempre los programas de Windows sin preguntar"
            contentItem: T { leftPadding: remember.indicator.width + 8; text: remember.text; font.pixelSize: 13; color: theme.muted }
        }

        RowLayout {
            visible: exe.state === "ask" || exe.state === "error"
            Layout.fillWidth: true
            spacing: 10
            Btn { text: "Buscar en la Store"; icon: "search"; style: "outline"; onClicked: exe.searchStore() }
            Item { Layout.fillWidth: true }
            Btn { text: "Cancelar"; style: "tonal"; onClicked: Qt.quit() }
            Btn { text: exe.hasWine ? "Abrir con Wine" : "Instalar Wine y abrir"; icon: "play_arrow"; onClicked: exe.open(remember.checked) }
        }
    }
}
