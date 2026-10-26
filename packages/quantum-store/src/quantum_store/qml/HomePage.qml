import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Portada: destacados grandes + filas de apps de Flathub.
Flickable {
    id: pg
    objectName: "flick-inicio"
    contentHeight: col.implicitHeight + 40
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}

    readonly property var h: store.home || ({})
    property int heroIdx: 0

    Timer {
        interval: 5000; repeat: true
        running: window.page === "inicio" && (pg.h.hero || []).length > 1
        onTriggered: pg.heroIdx = (pg.heroIdx + 1) % pg.h.hero.length
    }

    ColumnLayout {
        id: col
        x: 20; y: 10
        width: pg.width - 40
        spacing: 28

        // ----------------------------------------------------------- destacado
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 300
            visible: (pg.h.hero || []).length > 0
            Repeater {
                model: pg.h.hero || []
                Rectangle {
                    id: hero
                    required property var modelData
                    required property int index
                    anchors.fill: parent
                    radius: 30
                    clip: true
                    opacity: pg.heroIdx === index ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: hero.modelData.a }
                        GradientStop { position: 1; color: hero.modelData.b }
                    }
                    // captura a la derecha, inclinada
                    Image {
                        anchors.right: parent.right
                        anchors.rightMargin: -40
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.55
                        height: parent.height * 1.1
                        source: theme.web(hero.modelData.shot)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        opacity: 0.9
                        rotation: -4
                        scale: pg.heroIdx === hero.index ? 1 : 0.92
                        Behavior on scale { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
                    }
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.35; color: Qt.rgba(0, 0, 0, 0.35) }
                            GradientStop { position: 0.8; color: "transparent" }
                        }
                    }
                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.leftMargin: 44
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.45
                        spacing: 12
                        Image { source: theme.web(hero.modelData.icon); sourceSize: Qt.size(160, 160); Layout.preferredWidth: 72; Layout.preferredHeight: 72; asynchronous: true }
                        T { text: hero.modelData.title; color: "white"; font.pixelSize: 40; font.weight: Font.ExtraBold }
                        T { Layout.fillWidth: true; text: hero.modelData.text; color: Qt.rgba(1, 1, 1, 0.85); font.pixelSize: 17; wrapMode: Text.WordWrap }
                        RowLayout {
                            Layout.topMargin: 6
                            spacing: 10
                            Rectangle {
                                implicitWidth: heroBtn.implicitWidth + 44; implicitHeight: 46; radius: 23
                                color: heroArea.containsMouse ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.92)
                                T { id: heroBtn; anchors.centerIn: parent; text: hero.modelData.installed ? "Abrir" : "Ver más"; color: "#111"; font.weight: Font.Bold }
                                MouseArea { id: heroArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: window.openApp(hero.modelData.key) }
                            }
                        }
                    }
                }
            }
            // puntos
            Row {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 18
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                Repeater {
                    model: (pg.h.hero || []).length
                    Rectangle {
                        required property int index
                        width: pg.heroIdx === index ? 26 : 8; height: 8; radius: 4
                        color: Qt.rgba(1, 1, 1, pg.heroIdx === index ? 0.95 : 0.45)
                        Behavior on width { NumberAnimation { duration: 260 } }
                        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: pg.heroIdx = parent.index }
                    }
                }
            }
        }

        // carga inicial
        ColumnLayout {
            visible: (store.busy || []).indexOf("home") >= 0 && !(pg.h.popular || []).length
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 120
            BusyIndicator { Layout.alignment: Qt.AlignHCenter; running: true }
            T { text: "Cargando la tienda…"; color: theme.muted }
        }

        Shelf { title: "Lo más popular"; icon: "local_fire_department"; apps: pg.h.popular || [] }
        Shelf { title: "Juegos"; icon: "sports_esports"; apps: pg.h.games || [] }
        Shelf { title: "Para crear"; icon: "movie"; apps: pg.h.create || [] }
        Shelf { title: "Oficina y estudio"; icon: "description"; apps: pg.h.office || [] }
        Shelf { title: "En tendencia"; icon: "trending_up"; apps: pg.h.trending || [] }
    }
}
