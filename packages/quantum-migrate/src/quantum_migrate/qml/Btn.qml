import QtQuick
import QtQuick.Layouts

// Botón con ícono opcional. style: "filled" | "tonal" | "outline" | "danger"
Rectangle {
    id: b
    property string text: ""
    property string icon: ""
    property string style: "filled"
    property bool small: false
    signal clicked

    implicitWidth: row.implicitWidth + (small ? 28 : 40)
    implicitHeight: small ? 36 : 46
    radius: height / 2
    color: style === "filled" ? theme.primary
         : style === "danger" ? theme.alpha(theme.error, area.containsMouse ? 0.28 : 0.18)
         : style === "tonal" ? (area.containsMouse ? theme.highest : theme.high)
         : (area.containsMouse ? theme.alpha(theme.fg, 0.08) : "transparent")
    border.width: style === "outline" ? 1 : 0
    border.color: theme.outline
    scale: area.pressed ? 0.96 : 1
    Behavior on scale { NumberAnimation { duration: 120 } }
    Behavior on color { ColorAnimation { duration: 150 } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Sym {
            visible: b.icon !== ""
            text: b.icon
            size: b.small ? 18 : 20
            fill: 1
            color: b.style === "filled" ? theme.onPrimary : b.style === "danger" ? theme.error : theme.fg
        }
        T {
            visible: b.text !== ""
            text: b.text
            font.pixelSize: b.small ? 13 : 14
            font.weight: Font.DemiBold
            color: b.style === "filled" ? theme.onPrimary : b.style === "danger" ? theme.error : theme.fg
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}
