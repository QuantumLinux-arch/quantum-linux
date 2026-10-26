import QtQuick
import QtQuick.Layouts

// Ficha de un juego de la tienda.
Overlay {
    id: d
    property string gid: ""
    // el juego se vuelve a leer del catálogo para ver el avance de la instalación en vivo
    readonly property var g: (foton.catalog || []).find(x => x.id === gid) || null
    function show(game) { if (game) { gid = game.id; open(); forceActiveFocus(); } }
    cardHeight: 600

    Item {
        anchors.fill: parent
        Image {
            id: heroImg
            width: parent.width; height: 300
            source: d.g ? window.img(d.g.hero) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Rectangle {
            width: parent.width; height: 300
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.55; color: theme.alpha(theme.low, 0.35) }
                GradientStop { position: 1; color: theme.low }
            }
        }
        // cerrar
        Rectangle {
            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 16
            width: 40; height: 40; radius: 20
            color: closeArea.containsMouse ? Qt.rgba(0, 0, 0, 0.7) : Qt.rgba(0, 0, 0, 0.45)
            Sym { anchors.centerIn: parent; text: "close"; color: "white" }
            MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: d.close() }
        }
        RowLayout {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: 36
            anchors.bottomMargin: 34
            spacing: 30
            Image {
                Layout.preferredWidth: 150; Layout.preferredHeight: 225
                Layout.alignment: Qt.AlignBottom
                source: d.g ? window.img(d.g.cover) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(300, 450)
                layer.enabled: true
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignBottom
                spacing: 10
                T { Layout.fillWidth: true; text: d.g ? d.g.name : ""; font.pixelSize: 34; font.weight: Font.Black; wrapMode: Text.WordWrap; maximumLineCount: 2 }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Fact { icon: "sell"; text: "Gratis" }
                    Fact { icon: "category"; text: d.g ? d.g.genre : "" }
                    Fact { icon: d.g && d.g.kind === "steam" ? "cloud" : "deployed_code"; text: d.g && d.g.kind === "steam" ? "Steam" : "Linux (Flathub)" }
                    Fact { icon: d.g && d.g.spec === "bajo" ? "eco" : "memory"; text: d.g ? window.specName(d.g.spec) : "" }
                }
                T { Layout.fillWidth: true; Layout.topMargin: 4; text: d.g ? d.g.desc : ""; color: theme.muted; font.pixelSize: 15; wrapMode: Text.WordWrap; maximumLineCount: 4 }
                RowLayout {
                    visible: !!d.g && (!!d.g.note || d.g.kind === "steam")
                    spacing: 8
                    Sym { text: "info"; size: 18; color: theme.primary }
                    T {
                        text: !d.g ? "" : d.g.note ? d.g.note
                            : "Se instala desde Steam: te pedirá iniciar sesión (la cuenta es gratis)."
                        color: theme.primary; font.pixelSize: 13; font.weight: Font.DemiBold
                    }
                }
                InstallButton { Layout.topMargin: 10; g: d.g; big: true }
            }
        }
    }

    component Fact: Rectangle {
        property string icon
        property string text
        visible: text !== ""
        implicitWidth: fr.implicitWidth + 24; implicitHeight: 32; radius: 16
        color: theme.card
        Row {
            id: fr
            anchors.centerIn: parent; spacing: 6
            Sym { text: parent.parent.icon; size: 17; color: theme.primary; anchors.verticalCenter: parent.verticalCenter }
            T { text: parent.parent.text; font.pixelSize: 13; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
        }
    }
}
