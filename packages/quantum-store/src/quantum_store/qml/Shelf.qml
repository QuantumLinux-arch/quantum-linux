import QtQuick
import QtQuick.Layouts

// Fila con título y apps que se desplaza de lado.
ColumnLayout {
    id: shelf
    property string title
    property string icon: ""
    property var apps: []
    Layout.fillWidth: true
    spacing: 12
    visible: apps && apps.length > 0

    RowLayout {
        spacing: 10
        Sym { visible: shelf.icon !== ""; text: shelf.icon; size: 24; fill: 1; color: theme.primary }
        T { text: shelf.title; font.pixelSize: 20; font.weight: Font.ExtraBold }
    }
    ListView {
        Layout.fillWidth: true
        Layout.preferredHeight: 132
        orientation: ListView.Horizontal
        spacing: 14
        clip: true
        model: shelf.apps
        boundsBehavior: Flickable.StopAtBounds
        delegate: AppCard { required property var modelData; required property int index; app: modelData }
    }
}
