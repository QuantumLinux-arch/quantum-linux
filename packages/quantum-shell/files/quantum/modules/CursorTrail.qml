import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services

// Estela de luz que sigue al mouse (Personalizar → Ventanas → Estela del cursor; viene apagada).
// La posición la da `quantum-wf cursor`. No recibe clics, y se apaga con el Modo juego o una
// ventana a pantalla completa.
Scope {
    id: root
    readonly property bool on: Settings.appearance.cursorTrail && !Shell.gameMode && !(Wm.active?.fullscreen ?? false)
    readonly property int count: 28
    property var pts: []                   // [{x, y, t}] lo último que recorrió el mouse
    property real now: 0

    Process {
        running: root.on
        command: [Quickshell.env("QUANTUM_WF") || "quantum-wf", "cursor"]
        stdout: SplitParser {
            onRead: line => {
                const p = line.split(" ");
                if (p.length < 2) return;
                const pts = root.pts.concat([{ x: +p[0], y: +p[1], t: Date.now() }]);
                root.pts = pts.slice(-root.count);
            }
        }
    }

    LazyLoader {
        active: root.on

        PanelWindow {
            id: win
            screen: Wm.screen
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quantum-trail"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            mask: Region {}

            // una línea continua que se afina y se apaga (cian → índigo → violeta), con brillo
            readonly property int life: 480
            property bool alive: false
            FrameAnimation {
                running: true
                onTriggered: {
                    root.now = Date.now();
                    const live = root.pts.length > 1 && root.now - root.pts[root.pts.length - 1].t < win.life;
                    if (live || win.alive) trail.requestPaint();
                    win.alive = live;
                }
            }
            Canvas {
                id: trail
                anchors.fill: parent
                renderStrategy: Canvas.Threaded
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const ox = win.screen?.x ?? 0, oy = win.screen?.y ?? 0;
                    const pts = root.pts.filter(p => root.now - p.t < win.life);
                    if (pts.length < 2) return;
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    ctx.shadowColor = "#7F6CFF";
                    ctx.shadowBlur = 14;
                    const cols = ["#C77DFF", "#8A7DFF", "#7FE3FF"];
                    for (let i = 1; i < pts.length; i++) {
                        const k = i / (pts.length - 1);                         // 0 = cola, 1 = punta
                        const fade = 1 - (root.now - pts[i].t) / win.life;
                        ctx.globalAlpha = Math.max(0, 0.85 * fade * k);
                        ctx.strokeStyle = cols[Math.min(2, Math.floor(k * 3))];
                        ctx.lineWidth = 1.5 + 7 * k * fade;
                        ctx.beginPath();
                        ctx.moveTo(pts[i - 1].x - ox, pts[i - 1].y - oy);
                        ctx.lineTo(pts[i].x - ox, pts[i].y - oy);
                        ctx.stroke();
                    }
                }
            }
        }
    }
}
