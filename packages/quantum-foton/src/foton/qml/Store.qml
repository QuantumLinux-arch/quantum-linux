import QtQuick
import QtQuick.Layouts

// Tienda de Fotón: juegos gratis y legales del catálogo de Quantum, en carrusel y por secciones.
ColumnLayout {
    id: store
    spacing: 26

    readonly property var all: foton.catalog || []
    readonly property var featured: all.filter(g => g.featured)
    readonly property var pending: all.filter(g => g.pending)
    property string filter: "all"
    readonly property var filters: [
        { id: "all", t: "Todos", i: "apps" },
        { id: "low", t: "Para PCs modestas", i: "eco" },
        { id: "steam", t: "Gratis en Steam", i: "cloud" },
        { id: "linux", t: "Hechos para Linux", i: "deployed_code" },
    ]
    function match(g) {
        if (window.query && (g.name + " " + g.genre).toLowerCase().indexOf(window.query) < 0) return false;
        return filter === "all" || (filter === "low" && g.spec === "bajo")
            || (filter === "steam" && g.kind === "steam") || (filter === "linux" && g.kind === "flathub");
    }
    readonly property var shown: all.filter(g => match(g))
    readonly property bool sectioned: filter === "all" && !window.query

    // ------------------------------------------------------- carrusel
    Rectangle {
        id: hero
        visible: store.sectioned && store.featured.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: 380
        radius: 30
        clip: true
        color: "#0D0B14"
        property int idx: 0
        readonly property var g: store.featured.length ? store.featured[idx % store.featured.length] : null
        Timer { interval: 7000; repeat: true; running: hero.visible && !heroArea.containsMouse && !detail.shown; onTriggered: hero.idx++ }

        // dos imágenes que se cruzan al cambiar
        Repeater {
            model: 2
            Image {
                required property int index
                anchors.fill: parent
                readonly property bool mine: hero.idx % 2 === index
                property var game: null
                source: game ? window.img(game.hero) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: mine && status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }
                scale: mine ? 1.0 : 1.06
                Behavior on scale { NumberAnimation { duration: 7000 } }
                Component.onCompleted: if (mine) game = hero.g
                onMineChanged: if (mine) game = hero.g
            }
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(0.05, 0.04, 0.1, 0.94) }
                GradientStop { position: 0.6; color: Qt.rgba(0.05, 0.04, 0.1, 0.3) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        MouseArea { id: heroArea; anchors.fill: parent; hoverEnabled: true; onClicked: detail.show(hero.g) }
        ColumnLayout {
            id: heroInfo
            anchors.left: parent.left; anchors.leftMargin: 44
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.48
            spacing: 12
            Row {
                spacing: 8
                Pill { text: "Gratis"; strong: true }
                Pill { text: hero.g ? hero.g.genre : "" }
                Pill { visible: !!hero.g && hero.g.spec === "bajo"; text: "PC modesta" }
            }
            T { Layout.fillWidth: true; text: hero.g ? hero.g.name : ""; color: "white"; font.pixelSize: 44; font.weight: Font.Black; wrapMode: Text.WordWrap; maximumLineCount: 2 }
            T { Layout.fillWidth: true; text: hero.g ? hero.g.desc : ""; color: Qt.rgba(1, 1, 1, 0.8); font.pixelSize: 15; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight }
            InstallButton { Layout.topMargin: 8; g: hero.g; big: true }
        }
        // puntos
        Row {
            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 22
            spacing: 8
            Repeater {
                model: store.featured.length
                Rectangle {
                    required property int index
                    readonly property bool on: hero.idx % store.featured.length === index
                    width: on ? 26 : 9; height: 9; radius: 4.5
                    color: on ? "white" : Qt.rgba(1, 1, 1, 0.4)
                    Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: hero.idx = index }
                }
            }
        }
    }

    // -------------------------------------------- elegidos al instalar
    Section {
        visible: store.sectioned && store.pending.length > 0
        title: "Los elegiste al instalar Quantum"
        hint: "Están listos para instalar: Steam te pedirá iniciar sesión (es gratis)."
        games: store.pending
    }

    // ------------------------------------------------------- filtros
    RowLayout {
        spacing: 10
        T { text: "Juegos gratis"; font.pixelSize: 24; font.weight: Font.ExtraBold; Layout.rightMargin: 14 }
        Repeater {
            model: store.filters
            Rectangle {
                id: chip
                required property var modelData
                readonly property bool on: store.filter === modelData.id
                implicitWidth: chipRow.implicitWidth + 30; implicitHeight: 38; radius: 19
                color: on ? theme.primaryContainer : chipArea.containsMouse ? theme.high : theme.card
                Behavior on color { ColorAnimation { duration: 150 } }
                Row {
                    id: chipRow
                    anchors.centerIn: parent; spacing: 6
                    Sym { text: chip.modelData.i; size: 17; fill: chip.on ? 1 : 0; color: chip.on ? theme.onPrimaryContainer : theme.fg; anchors.verticalCenter: parent.verticalCenter }
                    T { text: chip.modelData.t; font.weight: Font.DemiBold; color: chip.on ? theme.onPrimaryContainer : theme.fg; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { id: chipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: store.filter = chip.modelData.id }
            }
        }
    }

    // --------------------------------------------------- secciones
    Section {
        visible: store.sectioned
        title: "Gratis en Steam"
        hint: "Los más jugados del mundo. Los de Windows funcionan con Proton, que Steam configura solo."
        games: store.all.filter(g => g.kind === "steam")
    }
    Section {
        visible: store.sectioned
        title: "Hechos para Linux"
        hint: "Se instalan con un clic, sin cuentas, y la mayoría corre en cualquier PC."
        games: store.all.filter(g => g.kind === "flathub")
    }
    Section {
        visible: !store.sectioned
        title: store.shown.length ? store.shown.length + (store.shown.length === 1 ? " juego" : " juegos") : "No encontré juegos con ese nombre"
        hint: ""
        games: store.shown
    }

    T {
        Layout.fillWidth: true
        Layout.topMargin: 10
        text: "Todos los juegos de la tienda son gratis y legales: vienen de Steam y Flathub, directo de sus creadores."
        color: theme.muted; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter
    }

    component Section: ColumnLayout {
        property string title
        property string hint
        property var games: []
        Layout.fillWidth: true
        spacing: 14
        ColumnLayout {
            spacing: 2
            T { text: title; font.pixelSize: 20; font.weight: Font.Bold }
            T { visible: hint !== ""; text: hint; color: theme.muted; font.pixelSize: 13 }
        }
        Flow {
            Layout.fillWidth: true
            spacing: 20
            Repeater {
                model: games
                StoreCard { required property var modelData; required property int index; g: modelData; order: index }
            }
        }
    }

    component Pill: Rectangle {
        property string text
        property bool strong: false
        implicitWidth: pt.implicitWidth + 24; implicitHeight: 30; radius: 15
        color: strong ? Qt.rgba(0.13, 0.71, 0.45, 0.9) : Qt.rgba(1, 1, 1, 0.14)
        T { id: pt; anchors.centerIn: parent; text: parent.text; color: "white"; font.pixelSize: 13; font.weight: Font.DemiBold }
    }
}
