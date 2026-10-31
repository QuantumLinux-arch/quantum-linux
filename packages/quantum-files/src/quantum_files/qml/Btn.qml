import QtQuick

// Botón de la barra: ícono, texto o los dos. Se hunde al apretarlo.
Rectangle {
    id: b
    property string icon: ""
    property string label: ""
    property string tip: ""
    property bool primary: false
    property bool on: false
    property bool enabled_: true
    property bool flat: false
    signal clicked()
    implicitHeight: 36
    implicitWidth: label ? row.implicitWidth + (icon ? 28 : 28) : 36
    radius: theme.pillR
    opacity: enabled_ ? 1 : 0.38
    color: primary ? theme.accentStrong : on ? theme.accentSoft : ma.containsMouse && enabled_ ? theme.alpha(theme.fg, 0.07) : "transparent"
    border.width: theme.serp && !primary && !flat ? 1 : 0
    border.color: theme.line
    scale: ma.pressed && enabled_ ? 0.93 : 1
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
    Behavior on color { ColorAnimation { duration: 120 } }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Sym { anchors.verticalCenter: parent.verticalCenter; visible: b.icon !== ""; text: b.icon; size: 19; fill: b.on ? 1 : 0; color: b.primary ? theme.accentFg : b.on ? theme.accent : theme.fg }
        T { anchors.verticalCenter: parent.verticalCenter; visible: b.label !== ""; text: b.label; font.pixelSize: 13; font.weight: Font.DemiBold; color: b.primary ? theme.accentFg : theme.fg }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: b.enabled_ ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (b.enabled_) b.clicked()
    }
    // globito con el nombre (para los botones de solo ícono)
    Rectangle {
        visible: b.tip !== "" && ma.containsMouse && tipTimer.done
        z: 100
        anchors.top: parent.bottom; anchors.topMargin: 8; anchors.horizontalCenter: parent.horizontalCenter
        width: tipT.implicitWidth + 18; height: 28; radius: 8
        color: theme.serp ? "#2A2027" : "#2E2D3A"
        T { id: tipT; anchors.centerIn: parent; text: b.tip; font.pixelSize: 12; color: "white" }
    }
    Timer { id: tipTimer; property bool done: false; interval: 500; running: ma.containsMouse; onRunningChanged: if (!running) done = false; onTriggered: done = true }
}
