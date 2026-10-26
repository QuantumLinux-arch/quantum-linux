import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs

// Agregar un juego de Windows: un instalador (se instala con Proton en su propio espacio)
// o el .exe de un juego que ya tienes. También explica la carpeta Juegos.
Overlay {
    id: a
    cardWidth: 720
    cardHeight: picking ? 560 : 520
    property bool picking: false          // eligiendo el .exe tras instalar
    property string pName: ""
    property string pPrefix: ""
    property var candidates: []

    onShownChanged: if (shown) { picking = false; nameField.text = ""; forceActiveFocus(); }

    Connections {
        target: foton
        function onExePicker(name, prefix, found) {
            a.pName = name; a.pPrefix = prefix; a.candidates = found;
            a.picking = true; a.open();
        }
    }

    FileDialog {
        id: fileDlg
        title: "Elige el instalador o el juego (.exe)"
        nameFilters: ["Programas de Windows (*.exe *.msi *.EXE *.MSI)"]
        onAccepted: { foton.addWindowsGame(selectedFile.toString(), nameField.text); a.close(); }
    }

    ColumnLayout {
        visible: !a.picking
        anchors.fill: parent
        anchors.margins: 36
        spacing: 16
        RowLayout {
            spacing: 14
            Rectangle {
                implicitWidth: 52; implicitHeight: 52; radius: 26; color: theme.primaryContainer
                Sym { anchors.centerIn: parent; text: "add"; size: 30; color: theme.onPrimaryContainer }
            }
            ColumnLayout {
                spacing: 0
                T { text: "Agregar un juego de Windows"; font.pixelSize: 24; font.weight: Font.ExtraBold }
                T { text: "Funciona con Proton, lo mismo que usa Steam para correr juegos de Windows."; color: theme.muted }
            }
        }
        T { Layout.topMargin: 6; text: "Nombre del juego (opcional)"; font.weight: Font.DemiBold }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 48; radius: 14
            color: theme.card
            border.width: nameField.activeFocus ? 2 : 1
            border.color: nameField.activeFocus ? theme.primary : theme.alpha(theme.fg, 0.08)
            TextInput {
                id: nameField
                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                verticalAlignment: TextInput.AlignVCenter
                font.family: theme.font; font.pixelSize: 15; color: theme.fg; clip: true
                T { anchors.verticalCenter: parent.verticalCenter; visible: !nameField.text; text: "Por ejemplo: Hollow Knight"; color: theme.muted; font.pixelSize: 15 }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Choice {
                icon: "install_desktop"; title: "Tengo el instalador"
                text: "Un archivo setup.exe o .msi. Lo instalamos y lo sumamos a tu biblioteca."
                onClicked: fileDlg.open()
            }
            Choice {
                icon: "sports_esports"; title: "Ya está instalado"
                text: "Elige el .exe del juego (por ejemplo, de un disco o una carpeta)."
                onClicked: fileDlg.open()
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: tipRow.implicitHeight + 28; radius: 16
            color: theme.alpha(theme.primary, 0.1)
            RowLayout {
                id: tipRow
                anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 16
                spacing: 12
                Sym { text: "folder_special"; color: theme.primary; size: 26 }
                T {
                    Layout.fillWidth: true
                    text: "Atajo: copia la carpeta de un juego dentro de «Juegos», en tu carpeta personal, y aparece sola en Fotón."
                    wrapMode: Text.WordWrap; font.pixelSize: 13
                }
                Btn { text: "Abrir Juegos"; small: true; style: "tonal"; onClicked: foton.openGamesFolder() }
            }
        }
        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true
            T { Layout.fillWidth: true; text: "Usa solo juegos que compraste o que son gratis."; color: theme.muted; font.pixelSize: 12 }
            Btn { text: "Cancelar"; style: "outline"; onClicked: a.close() }
        }
    }

    // tras instalar: elegir cuál es el juego
    ColumnLayout {
        visible: a.picking
        anchors.fill: parent
        anchors.margins: 36
        spacing: 14
        T { text: a.pName + " se instaló"; font.pixelSize: 24; font.weight: Font.ExtraBold }
        T { Layout.fillWidth: true; text: "¿Cuál de estos archivos abre el juego? Normalmente es el primero."; color: theme.muted; wrapMode: Text.WordWrap }
        Repeater {
            model: a.candidates
            Rectangle {
                id: cand
                required property string modelData
                required property int index
                Layout.fillWidth: true
                implicitHeight: 58; radius: 16
                color: candArea.containsMouse ? theme.high : theme.card
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                    spacing: 12
                    Sym { text: cand.index === 0 ? "star" : "description"; fill: 1; color: cand.index === 0 ? theme.primary : theme.muted }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 0
                        T { Layout.fillWidth: true; text: cand.modelData.split("/").pop(); font.weight: Font.Bold }
                        T { Layout.fillWidth: true; text: cand.modelData.replace(/.*drive_c\//, "C:/"); color: theme.muted; font.pixelSize: 11; elide: Text.ElideMiddle }
                    }
                }
                MouseArea { id: candArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { foton.chooseExe(a.pName, a.pPrefix, cand.modelData); a.close(); } }
            }
        }
        Item { Layout.fillHeight: true }
        Btn { Layout.alignment: Qt.AlignRight; text: "Cancelar"; style: "outline"; onClicked: a.close() }
    }

    component Choice: Rectangle {
        id: ch
        property string icon
        property string title
        property string text
        signal clicked
        Layout.fillWidth: true
        implicitHeight: 150; radius: 20
        color: chArea.containsMouse ? theme.high : theme.card
        border.width: chArea.containsMouse ? 2 : 1
        border.color: chArea.containsMouse ? theme.primary : theme.alpha(theme.fg, 0.06)
        Behavior on color { ColorAnimation { duration: 150 } }
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 20
            spacing: 6
            Sym { text: ch.icon; size: 32; fill: 1; color: theme.primary }
            T { text: ch.title; font.pixelSize: 17; font.weight: Font.Bold }
            T { Layout.fillWidth: true; text: ch.text; color: theme.muted; font.pixelSize: 13; wrapMode: Text.WordWrap; maximumLineCount: 3 }
        }
        MouseArea { id: chArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ch.clicked() }
    }
}
