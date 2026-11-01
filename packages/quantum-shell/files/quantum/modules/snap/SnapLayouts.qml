import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.components

// Diseños de ventanas, como en Windows 11. Se abren con el mouse medio segundo sobre el botón
// de maximizar (lo pide el plugin de decoraciones) o con Super + Z. Al elegir una zona la ventana
// va ahí, y si el diseño tiene más zonas se ofrecen las otras ventanas para completarlo.
Scope {
    id: root

    // [fx, fy, fw, fh] en fracciones del área útil de la pantalla
    readonly property var layouts: [
        [[0, 0, 0.5, 1], [0.5, 0, 0.5, 1]],
        [[0, 0, 0.66, 1], [0.66, 0, 0.34, 1]],
        [[0, 0, 0.333, 1], [0.333, 0, 0.334, 1], [0.667, 0, 0.333, 1]],
        [[0, 0, 0.5, 1], [0.5, 0, 0.5, 0.5], [0.5, 0.5, 0.5, 0.5]],
        [[0, 0, 0.5, 0.5], [0.5, 0, 0.5, 0.5], [0, 0.5, 0.5, 0.5], [0.5, 0.5, 0.5, 0.5]],
        [[0.25, 0, 0.5, 1], [0, 0, 0.25, 1], [0.75, 0, 0.25, 1]],
    ]

    property string phase: ""              // "" | pick (eligiendo diseño) | fill (completando)
    property var target: null              // { view, cursor, workarea, screen }
    property var hoverZone: null           // [fx, fy, fw, fh] bajo el mouse
    property var pending: []               // zonas que faltan por completar
    property var others: []                // otras ventanas para completarlas
    readonly property string wf: Quickshell.env("QUANTUM_WF") || "quantum-wf"

    function open(): void {
        if (phase !== "" || targetProc.running) return;
        targetProc.running = true;
    }
    function close(): void { phase = ""; hoverZone = null; pending = []; }

    function choose(layout: var, zone: int): void {
        const z = layout[zone];
        Quickshell.execDetached([wf, "place", String(target.view.id)].concat(z.map(String)));
        Sounds.play("click");
        const rest = layout.filter((_, i) => i !== zone);
        hoverZone = null;
        if (!rest.length) { close(); return; }
        pending = rest;
        othersProc.command = [wf, "others", String(target.view.id)];
        othersProc.running = true;
    }
    function fill(win: var): void {
        const z = pending[0];
        Quickshell.execDetached([wf, "place", String(win.id)].concat(z.map(String)));
        others = others.filter(o => o.id !== win.id);
        pending = pending.slice(1);
        if (!pending.length || !others.length) close();
    }

    Process {
        id: targetProc
        command: [root.wf, "target"]
        stdout: StdioCollector {
            onStreamFinished: {
                let t = null;
                try { t = JSON.parse(text); } catch (e) {}
                if (!t?.view) return;
                root.target = t;
                root.phase = "pick";
            }
        }
    }
    Process {
        id: othersProc
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.others = JSON.parse(text); } catch (e) { root.others = []; }
                if (root.others.length) root.phase = "fill";
                else root.close();
            }
        }
    }

    IpcHandler {
        target: "snap"
        function open(): void { root.open(); }
        function close(): void { root.close(); }
    }
    Connections {
        target: Shell
        function onSnapRequested() { root.open(); }
    }

    LazyLoader {
        active: root.phase !== ""

        PanelWindow {
            id: win
            screen: Wm.screen
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quantum-snap"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            readonly property var wa: root.target?.workarea ?? ({ x: 0, y: 0, width: width, height: height })
            readonly property var sc: root.target?.screen ?? ({ x: 0, y: 0 })
            // una zona del área útil → rectángulo en esta ventana
            function rectOf(z: var): rect {
                const g = 8;
                return Qt.rect(wa.x - sc.x + g + z[0] * (wa.width - g), wa.y - sc.y + g + z[1] * (wa.height - g),
                               z[2] * (wa.width - g) - g, z[3] * (wa.height - g) - g);
            }

            property real progress: 0
            NumberAnimation on progress { from: 0; to: 1; duration: 260; easing.type: Easing.OutBack }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.close()

                // fuera del panel: un clic, o alejar mucho el mouse, lo cierra
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: root.phase === "pick"
                    onClicked: root.close()
                    onPositionChanged: m => {
                        if (root.phase !== "pick") return;
                        const dx = Math.max(card.x - m.x, 0, m.x - card.x - card.width);
                        const dy = Math.max(card.y - m.y, 0, m.y - card.y - card.height);
                        if (Math.hypot(dx, dy) > 140) root.close();
                    }
                }

                // la zona que se está apuntando, dibujada en la pantalla
                Rectangle {
                    readonly property rect r: root.hoverZone ? win.rectOf(root.hoverZone) : Qt.rect(0, 0, 0, 0)
                    visible: root.phase === "pick" && !!root.hoverZone
                    x: r.x; y: r.y; width: r.width; height: r.height
                    radius: 18
                    color: Theme.alpha(Theme.primary, 0.16)
                    border.width: 2
                    border.color: Theme.alpha(Theme.primary, 0.75)
                    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }

                // ------------------------------------------------------ elegir diseño
                Card {
                    id: card
                    visible: root.phase === "pick"
                    readonly property real cx: (root.target?.cursor?.x ?? 0) - win.sc.x
                    readonly property real cy: (root.target?.cursor?.y ?? 0) - win.sc.y
                    width: grid.implicitWidth + 28
                    height: grid.implicitHeight + 52
                    x: Math.max(10, Math.min(win.width - width - 10, cx - width / 2))
                    y: Math.max(10, Math.min(win.height - height - 10, cy + 18))
                    opacity: Math.min(1, win.progress * 1.5)
                    scale: 0.9 + 0.1 * win.progress
                    transformOrigin: Item.Top
                    // el mouse sobre el panel no cuenta como «fuera»
                    MouseArea { anchors.fill: parent; hoverEnabled: true; onExited: root.hoverZone = null }

                    Txt {
                        x: 16; y: 12
                        text: "Diseños de ventanas"
                        font.weight: Font.Bold
                        font.pixelSize: Theme.textSmall + 1
                        color: Theme.fgMuted
                    }
                    GridLayout {
                        id: grid
                        x: 14; y: 38
                        columns: 3
                        columnSpacing: 10; rowSpacing: 10
                        Repeater {
                            model: root.layouts
                            Rectangle {
                                id: lay
                                required property var modelData
                                implicitWidth: 112; implicitHeight: 70
                                radius: 12
                                color: Theme.alpha(Theme.fg, 0.05)
                                border.width: 1
                                border.color: Theme.alpha(Theme.fg, 0.08)
                                Repeater {
                                    model: lay.modelData
                                    Rectangle {
                                        id: zone
                                        required property var modelData
                                        required property int index
                                        readonly property bool on: root.hoverZone === modelData
                                        x: 5 + modelData[0] * (lay.width - 10) + 2
                                        y: 5 + modelData[1] * (lay.height - 10) + 2
                                        width: modelData[2] * (lay.width - 10) - 4
                                        height: modelData[3] * (lay.height - 10) - 4
                                        radius: 6
                                        color: on ? Theme.primary : Theme.alpha(Theme.fg, 0.16)
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: root.hoverZone = zone.modelData
                                            onClicked: root.choose(lay.modelData, zone.index)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // --------------------------------------------- completar el diseño
                Repeater {
                    model: root.phase === "fill" ? root.pending.slice(0, 1) : []
                    Rectangle {
                        id: slot
                        required property var modelData
                        readonly property rect r: win.rectOf(modelData)
                        x: r.x; y: r.y; width: r.width; height: r.height
                        radius: 20
                        color: Theme.alpha(Theme.surface, 0.94)
                        border.width: 2
                        border.color: Theme.alpha(Theme.primary, 0.6)
                        opacity: win.progress
                        MouseArea { anchors.fill: parent }        // un clic en el espacio vacío no cierra
                        ColumnLayout {
                            anchors.centerIn: parent
                            width: Math.min(parent.width - 40, 420)
                            spacing: 10
                            Txt {
                                Layout.alignment: Qt.AlignHCenter
                                text: "¿Qué va aquí?"
                                font.pixelSize: Theme.textTitle
                                font.weight: Font.Bold
                            }
                            Txt {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Elige una ventana para completar el diseño · Esc para terminar"
                                color: Theme.fgMuted
                                font.pixelSize: Theme.textSmall
                            }
                            Item { implicitHeight: 4 }
                            Repeater {
                                model: root.others.slice(0, 6)
                                Rectangle {
                                    id: opt
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 52
                                    radius: 16
                                    color: optArea.containsMouse ? Theme.alpha(Theme.primary, 0.2) : Theme.alpha(Theme.fg, 0.06)
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14; anchors.rightMargin: 14
                                        spacing: 12
                                        AppIcon { size: 28; name: Wm.iconFor(opt.modelData["app-id"]) }
                                        Txt {
                                            Layout.fillWidth: true
                                            text: opt.modelData.title || Wm.nameFor(opt.modelData["app-id"])
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }
                                    }
                                    MouseArea { id: optArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.fill(opt.modelData) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
