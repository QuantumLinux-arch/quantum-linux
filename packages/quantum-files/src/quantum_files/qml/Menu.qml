import QtQuick

// Menú de clic derecho al estilo de Windows 11: una fila de acciones rápidas arriba
// (cortar, copiar, renombrar, eliminar…) y la lista debajo. Los submenús (Abrir con…,
// Nuevo, Ordenar) reemplazan la lista, con «Volver» arriba.
// items: [{ icon, text, keys, run: function, sep: bool, sub: [...] , danger }]
Item {
    id: m
    anchors.fill: parent
    visible: open || box.opacity > 0.01
    z: 1000

    property bool open: false
    property var items: []
    property var quick: []
    property var stack: []
    property real px: 0
    property real py: 0

    function popup(x, y, list, quickList) {
        stack = [];
        items = list;
        quick = quickList || [];
        px = x; py = y;
        open = true;
    }
    function close() { open = false; }
    function run(it) {
        if (it.sub) { stack = stack.concat([items]); items = [{ icon: "arrow_back", text: "Volver", back: true }, { sep: true }].concat(it.sub); return; }
        if (it.back) { items = stack[stack.length - 1]; stack = stack.slice(0, -1); return; }
        open = false;
        if (it.run) it.run();
    }

    MouseArea {
        anchors.fill: parent
        enabled: m.open
        acceptedButtons: Qt.AllButtons
        onPressed: m.open = false
        onWheel: m.open = false
    }

    Rectangle {
        id: box
        width: 300
        height: col.implicitHeight + 16
        x: Math.max(8, Math.min(m.px, m.width - width - 8))
        y: m.py + height > m.height - 8 ? Math.max(8, m.py - height) : m.py
        radius: theme.r
        color: theme.serp ? "#1A1318" : Qt.lighter(theme.card, 1.08)
        border.width: 1
        border.color: theme.serp ? theme.alpha(theme.accent, 0.3) : theme.alpha(theme.fg, 0.12)
        opacity: m.open ? 1 : 0
        scale: m.open ? 1 : 0.94
        transformOrigin: m.py + height > m.height - 8 ? Item.Bottom : Item.Top
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        // sombra
        Rectangle { z: -1; anchors.fill: parent; anchors.margins: -1; anchors.topMargin: 6; anchors.bottomMargin: -10; radius: parent.radius + 4; color: "black"; opacity: 0.28 }
        MouseArea { anchors.fill: parent }

        Column {
            id: col
            x: 8; y: 8; width: parent.width - 16
            Row {
                visible: m.quick.length > 0 && m.stack.length === 0
                spacing: 2; height: 48
                Repeater {
                    model: m.quick
                    Btn {
                        required property var modelData
                        anchors.verticalCenter: parent.verticalCenter
                        width: 54; height: 42; flat: true
                        icon: modelData.icon; tip: modelData.text
                        enabled_: modelData.enabled !== false
                        onClicked: m.run(modelData)
                    }
                }
            }
            Rectangle { visible: m.quick.length > 0 && m.stack.length === 0; width: parent.width; height: 1; color: theme.line }
            Repeater {
                model: m.items
                Item {
                    id: row
                    required property var modelData
                    width: col.width
                    height: modelData.sep ? 9 : 40
                    visible: modelData.visible !== false
                    Rectangle { visible: row.modelData.sep === true; anchors.centerIn: parent; width: parent.width - 8; height: 1; color: theme.line }
                    Rectangle {
                        visible: !row.modelData.sep
                        anchors.fill: parent; radius: 8
                        color: ma.containsMouse ? (row.modelData.danger ? theme.alpha(theme.danger, 0.16) : theme.accentSoft) : "transparent"
                        Image {
                            visible: (row.modelData.img || "") !== ""
                            x: 12; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22
                            source: row.modelData.img || ""; sourceSize: Qt.size(44, 44)
                        }
                        Sym {
                            visible: !row.modelData.img
                            x: 12; anchors.verticalCenter: parent.verticalCenter; width: 22
                            text: row.modelData.icon || ""; size: 19
                            fill: row.modelData.checked ? 1 : 0
                            color: row.modelData.danger ? theme.danger : ma.containsMouse || row.modelData.checked ? theme.accent : theme.fg
                        }
                        T {
                            x: 46; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 120
                            text: row.modelData.text || ""; font.pixelSize: 13
                            color: row.modelData.danger ? theme.danger : theme.fg
                            font.weight: row.modelData.bold ? Font.DemiBold : Font.Normal
                        }
                        T {
                            anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.sub ? "" : (row.modelData.keys || ""); font.pixelSize: 11; color: theme.muted
                        }
                        Sym { visible: !!row.modelData.sub; anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: "chevron_right"; size: 18; color: theme.muted }
                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: m.run(row.modelData)
                        }
                    }
                }
            }
        }
    }
}
