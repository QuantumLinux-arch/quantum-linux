import QtQuick

// Etiqueta de origen: Arch, Flathub, Comunidad (AUR) o Android
Rectangle {
    property string source: "arch"
    implicitWidth: lbl.implicitWidth + 16
    implicitHeight: 22
    radius: 11
    color: theme.alpha(theme.sourceColor(source), 0.18)
    T {
        id: lbl
        anchors.centerIn: parent
        text: theme.sourceName(parent.source)
        font.pixelSize: 11
        font.weight: Font.Bold
        color: theme.sourceColor(parent.source)
    }
}
