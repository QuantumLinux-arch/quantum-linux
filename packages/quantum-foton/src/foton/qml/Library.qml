import QtQuick
import QtQuick.Layouts

// Biblioteca: el juego destacado (el último que jugaste), filtros y portadas.
ColumnLayout {
    id: libroot
    spacing: 24
    // ------------------------------------------------- juego destacado
    Rectangle {
        id: hero
        visible: !!window.featured
        Layout.fillWidth: true
        Layout.preferredHeight: 330
        radius: 30
        clip: true
        color: "#0D0B14"
        Image {
            anchors.fill: parent
            source: window.featured ? window.img(window.featured.hero || window.featured.cover) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 400 } }
            scale: heroArea.containsMouse ? 1.03 : 1
            Behavior on scale { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(0.05, 0.04, 0.1, 0.92) }
                GradientStop { position: 0.55; color: Qt.rgba(0.05, 0.04, 0.1, 0.35) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        MouseArea { id: heroArea; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
        ColumnLayout {
            anchors.left: parent.left; anchors.leftMargin: 44
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.5
            spacing: 12
            Rectangle {
                implicitWidth: lastTxt.implicitWidth + 24; implicitHeight: 30; radius: 15
                color: Qt.rgba(1, 1, 1, 0.14)
                T { id: lastTxt; anchors.centerIn: parent; text: window.featured && window.featured.lastPlayed ? window.ago(window.featured.lastPlayed) : "Destacado"; color: "white"; font.pixelSize: 13; font.weight: Font.DemiBold }
            }
            T { Layout.fillWidth: true; text: window.featured ? window.featured.name : ""; color: "white"; font.pixelSize: 46; font.weight: Font.Black; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
            T { text: window.featured ? window.srcName(window.featured.source) : ""; color: Qt.rgba(1, 1, 1, 0.75); font.pixelSize: 16 }
            PlayButton { Layout.topMargin: 8; big: true; onClicked: foton.play(window.featured.key) }
        }
    }

    // ------------------------------------------------- filtros
    RowLayout {
        visible: window.all.length > 0
        spacing: 10
        T { text: "Tu biblioteca"; font.pixelSize: 24; font.weight: Font.ExtraBold; Layout.rightMargin: 14 }
        Repeater {
            model: window.sources.filter(s => s.id === "all" || window.all.some(g => g.source === s.id))
            Rectangle {
                id: chip
                required property var modelData
                readonly property bool on: window.filter === modelData.id
                implicitWidth: chipTxt.implicitWidth + 32; implicitHeight: 38; radius: 19
                color: on ? theme.primaryContainer : chipArea.containsMouse ? theme.high : theme.card
                Behavior on color { ColorAnimation { duration: 150 } }
                T { id: chipTxt; anchors.centerIn: parent; text: chip.modelData.text; font.weight: Font.DemiBold; color: chip.on ? theme.onPrimaryContainer : theme.fg }
                MouseArea { id: chipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: window.filter = chip.modelData.id }
            }
        }
        T { text: window.shown.length + (window.shown.length === 1 ? " juego" : " juegos"); color: theme.muted; Layout.leftMargin: 8 }
    }

    // ---------------------------------------------- portadas
    Flow {
        Layout.fillWidth: true
        spacing: 20
        Repeater {
            model: window.shown
            GameCard { required property var modelData; required property int index; g: modelData; order: index }
        }
    }

    // ------------------------------------------------- vacío
    ColumnLayout {
        visible: window.all.length === 0
        Layout.fillWidth: true
        Layout.topMargin: 60
        spacing: 16
        Mark { Layout.alignment: Qt.AlignHCenter; implicitWidth: 110; implicitHeight: 110; color: theme.primary }
        T { Layout.alignment: Qt.AlignHCenter; text: "Todavía no tienes juegos instalados"; font.pixelSize: 26; font.weight: Font.ExtraBold }
        T { Layout.alignment: Qt.AlignHCenter; text: "Fotón junta aquí tus juegos de Steam, Epic, GOG, Amazon, Windows y los de la Tienda."; color: theme.muted; font.pixelSize: 15 }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            spacing: 12
            Btn { text: "Explorar la Tienda"; icon: "storefront"; onClicked: window.tab = "store" }
            Btn { text: "Agregar juego de Windows"; icon: "add"; style: "tonal"; onClicked: addGame.open() }
            Btn { text: "Epic y GOG (Heroic)"; icon: "sports_esports"; style: "outline"; onClicked: foton.open("heroic") }
        }
    }
}
