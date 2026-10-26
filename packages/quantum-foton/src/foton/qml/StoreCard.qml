import QtQuick
import QtQuick.Layouts

// Portada de un juego de la tienda: origen, si corre en PCs modestas y su estado.
Item {
    id: card
    property var g
    property int order: 0
    width: 196
    height: 346

    opacity: 0
    transform: Translate { id: tr; y: 18 }
    Component.onCompleted: appear.start()
    SequentialAnimation {
        id: appear
        PauseAnimation { duration: Math.min(card.order, 14) * 30 }
        ParallelAnimation {
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: tr; property: "y"; to: 0; duration: 380; easing.type: Easing.OutCubic }
        }
    }

    Rectangle {
        anchors.fill: cover
        anchors.margins: -4
        radius: 24
        opacity: area.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        gradient: Gradient {
            GradientStop { position: 0; color: theme.cyan }
            GradientStop { position: 0.5; color: theme.indigo }
            GradientStop { position: 1; color: theme.violet }
        }
        scale: cover.scale
    }

    Rectangle {
        id: cover
        width: parent.width
        height: 294
        radius: 20
        clip: true
        color: theme.card
        scale: area.pressed ? 0.97 : area.containsMouse ? 1.04 : 1
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Image {
            anchors.fill: parent
            source: window.img(card.g.cover)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(400, 600)
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }
        // origen
        Rectangle {
            anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 10
            implicitWidth: srcRow.implicitWidth + 16; implicitHeight: 24; radius: 12
            color: Qt.rgba(0, 0, 0, 0.6)
            Row {
                id: srcRow
                anchors.centerIn: parent
                spacing: 4
                Sym { text: card.g.kind === "steam" ? "cloud" : "deployed_code"; size: 13; fill: 1; color: "white"; anchors.verticalCenter: parent.verticalCenter }
                T { text: card.g.kind === "steam" ? "Steam" : "Linux"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        // PC modesta
        Rectangle {
            visible: card.g.spec === "bajo"
            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10
            width: 24; height: 24; radius: 12
            color: Qt.rgba(0.13, 0.71, 0.45, 0.9)
            Sym { anchors.centerIn: parent; text: "eco"; size: 15; fill: 1; color: "white" }
        }
        // estado
        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            height: 34
            visible: card.g.installed || card.g.progress >= 0
            color: Qt.rgba(0.04, 0.03, 0.09, 0.82)
            Rectangle {
                visible: card.g.progress >= 0
                height: parent.height; width: parent.width * Math.max(0.03, card.g.progress)
                color: theme.alpha(theme.indigo, 0.75)
                Behavior on width { NumberAnimation { duration: 300 } }
            }
            Row {
                anchors.centerIn: parent
                spacing: 6
                Sym { text: card.g.installed ? "check_circle" : "downloading"; size: 17; fill: 1; color: card.g.installed ? "#4ADE80" : "white"; anchors.verticalCenter: parent.verticalCenter }
                T {
                    text: card.g.installed ? "Instalado" : "Instalando " + Math.round(card.g.progress * 100) + " %"
                    color: "white"; font.pixelSize: 12; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
    Column {
        anchors.top: cover.bottom; anchors.topMargin: 10
        width: parent.width
        spacing: 2
        T { width: parent.width; text: card.g.name; font.pixelSize: 14; font.weight: Font.DemiBold }
        T { width: parent.width; text: card.g.genre + " · Gratis"; font.pixelSize: 12; color: theme.muted }
    }

    MouseArea {
        id: area
        anchors.fill: cover
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: detail.show(card.g)
    }
}
