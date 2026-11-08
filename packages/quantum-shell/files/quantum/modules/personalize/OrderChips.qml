import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// Elementos de la barra de tareas: toca uno para mostrarlo u ocultarlo y arrástralo para cambiar el orden.
// Lo que queda después de «Apps» va a la derecha de la barra.
Item {
    id: oc

    Layout.fillWidth: true
    readonly property var info: ({
        start: { t: "Inicio", i: "grid_view", f: "showStart" },
        search: { t: "Buscar", i: "search", f: "showSearch" },
        quarki: { t: "Quarki", i: "smart_toy", f: "showQuarki" },
        apps: { t: "Tus apps", i: "apps", f: "" },
        weather: { t: "Clima", i: "partly_cloudy_day", f: "showWeather" },
        sysmon: { t: "Uso del PC", i: "memory", f: "showSysmon" },
        tray: { t: "Bandeja y estado", i: "wifi", f: "showTray", single: true },
        clock: { t: "Reloj", i: "schedule", f: "showClock", single: true },
        desktop: { t: "Ver escritorio", i: "select_window_2", f: "showDesktop" }
    })
    readonly property var allIds: ["start", "search", "quarki", "apps", "weather", "sysmon", "tray", "clock", "desktop"]
    readonly property var order: {
        const o = (Settings.dock.order ?? []).filter(id => allIds.includes(id));
        for (const id of allIds) if (!o.includes(id)) o.push(id);
        return o;
    }
    readonly property bool single: Settings.layout.style === "single" || Settings.dock.position === "top"
    function isOn(id: string): bool { return id === "apps" || (Settings.dock[info[id].f] ?? false); }

    readonly property int cw: 214
    readonly property int ch: 48
    readonly property int gap: 8
    readonly property int cols: Math.max(1, Math.floor((width + gap) / (cw + gap)))
    implicitHeight: Math.ceil(order.length / cols) * (ch + gap) - gap

    // arrastre
    property int dragFrom: -1
    property point dragPos: Qt.point(0, 0)
    readonly property int dragTo: {
        if (dragFrom < 0) return -1;
        const c = Math.max(0, Math.min(cols - 1, Math.round(dragPos.x / (cw + gap))));
        const r = Math.max(0, Math.round(dragPos.y / (ch + gap)));
        return Math.max(0, Math.min(order.length - 1, r * cols + c));
    }
    readonly property var shown: {
        if (dragFrom < 0 || dragTo < 0) return order;
        const o = order.slice();
        const [m] = o.splice(dragFrom, 1);
        o.splice(dragTo, 0, m);
        return o;
    }
    function slot(i: int): point { return Qt.point((i % cols) * (cw + gap), Math.floor(i / cols) * (ch + gap)); }

    Repeater {
        model: oc.order
        Rectangle {
            id: chip
            required property string modelData
            required property int index
            readonly property var it: oc.info[modelData]
            readonly property bool on: oc.isOn(modelData)
            readonly property bool dragging: oc.dragFrom === index
            // en el modo de dos barras, la bandeja y el reloj están en la barra de arriba
            readonly property bool elsewhere: (it.single ?? false) && !oc.single
            readonly property point home: oc.slot(oc.shown.indexOf(modelData))
            x: dragging ? oc.dragPos.x : home.x
            y: dragging ? oc.dragPos.y : home.y
            z: dragging ? 10 : 0
            Behavior on x { enabled: !chip.dragging; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on y { enabled: !chip.dragging; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            width: oc.cw; height: oc.ch
            radius: Theme.radius
            color: on ? (dragging ? Theme.surfaceHighest : Theme.surfaceHigh) : "transparent"
            border.width: 1
            border.color: on ? Theme.alpha(Theme.primary, chip.modelData === "apps" ? 0.6 : 0.25) : Theme.alpha(Theme.fg, 0.16)
            opacity: elsewhere ? 0.5 : 1
            scale: dragging ? 1.04 : 1
            Behavior on scale { NumberAnimation { duration: 120 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8; anchors.rightMargin: 10
                spacing: 8
                Icon { text: "drag_indicator"; size: 18; color: Theme.fgMuted; opacity: 0.6 }
                Icon { text: chip.it.i; size: 19; fill: chip.on ? 1 : 0; color: chip.on ? Theme.primary : Theme.fgMuted }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Txt { Layout.fillWidth: true; text: chip.it.t; font.weight: Font.DemiBold; elide: Text.ElideRight
                          color: chip.on ? Theme.fg : Theme.fgMuted }
                    Txt { visible: chip.elsewhere; text: "En la barra de arriba"; font.pixelSize: Theme.textSmall - 1; color: Theme.fgMuted }
                }
                Icon {
                    visible: chip.modelData !== "apps"
                    text: chip.on ? "check_circle" : "add_circle"
                    size: 19; fill: chip.on ? 1 : 0
                    color: chip.on ? Theme.primary : Theme.fgMuted
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: chip.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                preventStealing: true
                property point start
                property point base
                property bool moved: false
                onPressed: e => { start = mapToItem(oc, e.x, e.y); base = Qt.point(chip.x, chip.y); moved = false; }
                onPositionChanged: e => {
                    const p = mapToItem(oc, e.x, e.y), dx = p.x - start.x, dy = p.y - start.y;
                    if (!moved && Math.abs(dx) + Math.abs(dy) > 8) { moved = true; oc.dragFrom = chip.index; }
                    if (moved) oc.dragPos = Qt.point(base.x + dx, base.y + dy);
                }
                onReleased: {
                    if (moved) {
                        const o = oc.shown.slice();
                        oc.dragFrom = -1;
                        Settings.set("dock", "order", o);
                    } else if (chip.modelData !== "apps") {
                        Settings.set("dock", chip.it.f, !chip.on);
                    }
                }
            }
        }
    }
}
