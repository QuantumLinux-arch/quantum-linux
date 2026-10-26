import QtQuick
import QtQuick.Layouts

// Tarjeta de app en las grillas: ícono, nombre, resumen y origen.
Rectangle {
    id: card
    required property var app
    objectName: "card-" + app.key
    property int index: 0
    width: 236
    height: 128
    radius: 22
    color: area.containsMouse ? theme.high : theme.card
    border.width: 1
    border.color: theme.alpha(theme.fg, area.containsMouse ? 0.10 : 0.05)
    scale: area.pressed ? 0.97 : 1
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 120 } }

    // entrada escalonada
    opacity: 0
    transform: Translate { id: tr; y: 16 }
    Component.onCompleted: { appear.start(); }
    ParallelAnimation {
        id: appear
        NumberAnimation { target: card; property: "opacity"; to: 1; duration: 280; easing.type: Easing.OutCubic }
        NumberAnimation { target: tr; property: "y"; to: 0; duration: 340; easing.type: Easing.OutCubic }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14
        Rectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 64
            implicitHeight: 64
            radius: 18
            color: theme.alpha(theme.fg, 0.04)
            Image {
                anchors.centerIn: parent
                width: 52; height: 52
                source: theme.iconSource(card.app.icon)
                sourceSize: Qt.size(104, 104)
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4
            T { Layout.fillWidth: true; text: card.app.name; font.pixelSize: 15; font.weight: Font.Bold }
            T {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: card.app.summary
                color: theme.muted
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                verticalAlignment: Text.AlignTop
            }
            RowLayout {
                spacing: 6
                SourceChip { source: card.app.source }
                Sym { visible: card.app.installed; text: "check_circle"; size: 16; fill: 1; color: theme.primary }
            }
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: window.openApp(card.app.key)
    }
}
