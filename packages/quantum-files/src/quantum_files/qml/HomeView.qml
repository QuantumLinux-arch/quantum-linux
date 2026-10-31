import QtQuick

// Inicio: saludo, accesos rápidos, discos y dispositivos, y archivos recientes.
Flickable {
    id: home
    signal go(string path)
    signal openFile(string path)
    signal openDrive(var drive)
    signal menuFor(var entry, real x, real y)
    contentHeight: col.implicitHeight + 50
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    property var recent: []
    function refresh() { recent = fm.recent(); }
    Component.onCompleted: refresh()

    readonly property string greeting: {
        const h = new Date().getHours();
        return (h < 6 ? "Buenas noches" : h < 12 ? "Buenos días" : h < 20 ? "Buenas tardes" : "Buenas noches");
    }

    Column {
        id: col
        x: 32; y: 26; width: home.width - 64; spacing: 16
        T { text: home.greeting + ", " + fm.userName.charAt(0).toUpperCase() + fm.userName.slice(1); font.pixelSize: 28; font.weight: Font.Bold }
        T { text: "Accesos rápidos"; font.pixelSize: 15; font.weight: Font.DemiBold; color: theme.muted }
        Flow {
            width: parent.width; spacing: 14
            Repeater {
                model: fm.places
                Rectangle {
                    id: pc
                    required property var modelData
                    // 6 por fila si caben; si no, 3 (nunca 5 + 1)
                    readonly property int per: col.width >= 6 * 150 + 70 ? 6 : 3
                    width: (col.width - (per - 1) * 14) / per; height: 132; radius: theme.r
                    color: pma.containsMouse ? theme.cardHi : theme.card
                    border.width: 1; border.color: theme.line
                    scale: pma.pressed ? 0.97 : 1
                    Behavior on scale { NumberAnimation { duration: 140 } }
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Image { x: 16; y: 16; width: 52; height: 52; source: theme.folderIcon(pc.modelData.key); sourceSize: Qt.size(104, 104) }
                    T { x: 16; y: 80; width: parent.width - 32; text: pc.modelData.name; font.pixelSize: 15; font.weight: Font.DemiBold }
                    T { x: 16; y: 102; text: pc.modelData.count === 1 ? "1 elemento" : pc.modelData.count + " elementos"; font.pixelSize: 12; color: theme.muted }
                    MouseArea {
                        id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: e => {
                            if (e.button === Qt.RightButton) { const p = mapToItem(null, e.x, e.y); home.menuFor(fm.info(pc.modelData.path), p.x, p.y); }
                            else home.go(pc.modelData.path);
                        }
                    }
                }
            }
        }
        Item { width: 1; height: 4 }
        T { text: "Discos y dispositivos"; font.pixelSize: 15; font.weight: Font.DemiBold; color: theme.muted }
        Flow {
            width: parent.width; spacing: 14
            Repeater {
                model: fm.drives
                Rectangle {
                    id: dc
                    required property var modelData
                    width: Math.max(300, (col.width - 2 * 14) / 3); height: 96; radius: theme.r
                    color: dma.containsMouse ? theme.cardHi : theme.card
                    border.width: 1; border.color: theme.line
                    scale: dma.pressed ? 0.97 : 1
                    Behavior on scale { NumberAnimation { duration: 140 } }
                    Image { x: 16; anchors.verticalCenter: parent.verticalCenter; width: 52; height: 52; source: theme.icon(dc.modelData.icon + ",drive-harddisk"); sourceSize: Qt.size(104, 104) }
                    Column {
                        x: 82; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 82 - (dc.modelData.removable ? 60 : 20); spacing: 8
                        T { width: parent.width; text: dc.modelData.name; font.pixelSize: 15; font.weight: Font.DemiBold }
                        Rectangle {
                            visible: dc.modelData.mount !== ""
                            width: parent.width; height: 8; radius: 4; color: theme.cardHi
                            Rectangle { width: Math.max(8, parent.width * dc.modelData.used); height: 8; radius: 4; color: dc.modelData.used > 0.9 ? theme.danger : dc.modelData.used > 0.75 ? theme.warn : theme.accentStrong }
                        }
                        T { text: dc.modelData.text; font.pixelSize: 12; color: theme.muted }
                    }
                    MouseArea {
                        id: dma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: home.openDrive(dc.modelData)
                    }
                    Btn {
                        visible: dc.modelData.removable && dc.modelData.mount !== ""
                        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                        icon: "eject"; tip: "Expulsar"; flat: true
                        onClicked: fm.eject(dc.modelData.dev)
                    }
                }
            }
        }
        Item { width: 1; height: 4; visible: home.recent.length > 0 }
        T { visible: home.recent.length > 0; text: "Recientes"; font.pixelSize: 15; font.weight: Font.DemiBold; color: theme.muted }
        Rectangle {
            visible: home.recent.length > 0
            width: parent.width; height: rl.implicitHeight + 44; radius: theme.r; color: theme.card
            border.width: 1; border.color: theme.line
            readonly property var cols: [0.45, 0.27, 0.17, 0.11]
            Row {
                x: 18; y: 12
                Repeater {
                    model: ["Nombre", "Ubicación", "Modificado", "Tamaño"]
                    T { required property string modelData; required property int index; width: (col.width - 36) * parent.parent.cols[index]; text: modelData; font.pixelSize: 12; font.weight: Font.Bold; color: theme.muted }
                }
            }
            Column {
                id: rl
                x: 8; y: 36; width: parent.width - 16
                Repeater {
                    model: home.recent
                    Rectangle {
                        id: rr
                        required property var modelData
                        width: rl.width; height: 46; radius: 8
                        color: rma.containsMouse ? theme.accentSoft : "transparent"
                        readonly property var cols: parent.parent.cols
                        readonly property real w: col.width - 36
                        Image { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; source: theme.icon(rr.modelData.icon); sourceSize: Qt.size(56, 56) }
                        T { x: 50; width: rr.w * rr.cols[0] - 42; anchors.verticalCenter: parent.verticalCenter; text: rr.modelData.name; font.weight: Font.DemiBold }
                        T { x: 10 + rr.w * rr.cols[0]; width: rr.w * rr.cols[1] - 10; anchors.verticalCenter: parent.verticalCenter; color: theme.muted
                            text: { const d = fm.parentOf(rr.modelData.path); return d.indexOf(fm.home) === 0 ? d.slice(fm.home.length + 1).split("/").join(" › ") || fm.userName : d; } }
                        T { x: 10 + rr.w * (rr.cols[0] + rr.cols[1]); width: rr.w * rr.cols[2]; anchors.verticalCenter: parent.verticalCenter; text: fm.dateText(rr.modelData.mtime); color: theme.muted }
                        T { x: 10 + rr.w * (rr.cols[0] + rr.cols[1] + rr.cols[2]); width: rr.w * rr.cols[3]; anchors.verticalCenter: parent.verticalCenter; text: fm.sizeText(rr.modelData.size); color: theme.muted }
                        MouseArea {
                            id: rma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: e => { if (e.button === Qt.RightButton) { const p = mapToItem(null, e.x, e.y); home.menuFor(rr.modelData, p.x, p.y); } }
                            onDoubleClicked: home.openFile(rr.modelData.path)
                        }
                    }
                }
            }
        }
    }
}
