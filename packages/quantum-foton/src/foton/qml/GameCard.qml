import QtQuick
import QtQuick.Layouts

// Portada de un juego (2:3) con brillo al pasar el mouse y botón Jugar.
Item {
    id: card
    property var g
    property int order: 0
    width: 196
    height: 330

    opacity: 0
    transform: Translate { id: tr; y: 18 }
    Component.onCompleted: appear.start()
    SequentialAnimation {
        id: appear
        PauseAnimation { duration: Math.min(card.order, 14) * 35 }
        ParallelAnimation {
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: tr; property: "y"; to: 0; duration: 380; easing.type: Easing.OutCubic }
        }
    }

    // brillo de color detrás de la portada
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
            id: art
            anchors.fill: parent
            source: window.img(card.g.cover)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(400, 600)
            visible: status === Image.Ready
        }
        // sin portada: degradado con el ícono y el nombre
        Rectangle {
            anchors.fill: parent
            visible: !art.visible
            gradient: Gradient {
                GradientStop { position: 0; color: theme.high }
                GradientStop { position: 1; color: theme.alpha(theme.indigo, 0.55) }
            }
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 30
                spacing: 14
                Image {
                    Layout.alignment: Qt.AlignHCenter
                    source: "image://icon/" + (card.g.icon || "applications-games")
                    sourceSize: Qt.size(192, 192)
                    Layout.preferredWidth: 96; Layout.preferredHeight: 96
                }
                T { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: card.g.name; font.pixelSize: 17; font.weight: Font.Bold; wrapMode: Text.WordWrap; maximumLineCount: 3 }
            }
        }
        // Jugar al pasar el mouse
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.35)
            opacity: area.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Rectangle {
                anchors.centerIn: parent
                width: 72; height: 72; radius: 36
                color: "white"
                scale: area.containsMouse ? 1 : 0.6
                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                Sym { anchors.centerIn: parent; anchors.horizontalCenterOffset: 3; text: "play_arrow"; size: 44; fill: 1; color: theme.indigo }
            }
        }
        // origen
        Rectangle {
            anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 10
            implicitWidth: srcTxt.implicitWidth + 16; implicitHeight: 24; radius: 12
            color: Qt.rgba(0, 0, 0, 0.55)
            T { id: srcTxt; anchors.centerIn: parent; text: window.srcName(card.g.source); color: "white"; font.pixelSize: 11; font.weight: Font.Bold }
        }
    }
    T {
        anchors.top: cover.bottom; anchors.topMargin: 10
        width: parent.width
        text: card.g.name
        font.pixelSize: 14; font.weight: Font.DemiBold
    }

    MouseArea {
        id: area
        anchors.fill: cover
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: foton.play(card.g.key)
    }
}
