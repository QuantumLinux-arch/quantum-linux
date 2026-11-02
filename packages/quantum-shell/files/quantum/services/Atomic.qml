pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Atomic: el tercer shell de Quantum. La forma de Caelestial (barra, dock, isla, paneles) hecha de
// Cristal Cuántico: cada panel refracta el fondo de pantalla en sus bordes (components/Glass.qml).
// Aquí se preparan las texturas del fondo para el cristal: una chica nítida y otra desenfocada.
Singleton {
    id: root
    readonly property bool on: Settings.ui.shell === "atomic"
    readonly property string wall: Settings.appearance.wallpaper
    readonly property bool hasTex: on && wall !== "" && wall !== "quantum:live"
    property int rev: 0
    // La luz del reflejo: viene de donde está el mouse (siempre un poco desde arriba), y cambia de a
    // poco. Solo se escucha el mouse mientras Atomic está activo y no hay un juego a pantalla completa.
    property point light: Qt.point(-0.6, -0.8)
    property point target: Qt.point(-0.6, -0.8)
    readonly property bool follow: on && !weak && !Shell.gameMode && !(Wm.active?.fullscreen ?? false)
    Process {
        running: root.follow
        command: [Quickshell.env("QUANTUM_WF") || "quantum-wf", "cursor"]
        stdout: SplitParser {
            onRead: line => {
                const p = line.split(" ");
                if (p.length < 2) return;
                const sw = Wm.screen?.width ?? 1920, sh = Wm.screen?.height ?? 1080;
                const x = (+p[0] / sw - 0.5) * 2, y = (+p[1] / sh - 0.5) * 2 - 0.9;
                const l = Math.hypot(x, y) || 1;
                root.target = Qt.point(x / l, y / l);
            }
        }
    }
    // acercarse al objetivo ~15 veces por segundo (no en cada movimiento: así no se redibuja de más)
    Timer {
        running: root.follow
        interval: 66
        repeat: true
        onTriggered: {
            const dx = root.target.x - root.light.x, dy = root.target.y - root.light.y;
            if (Math.abs(dx) + Math.abs(dy) < 0.01) return;
            root.light = Qt.point(root.light.x + dx * 0.35, root.light.y + dy * 0.35);
        }
    }

    // ---- ¿el PC puede con el cristal? (sin aceleración gráfica o con poca memoria, va lento)
    property bool weak: false
    property string weakWhy: ""
    Process {
        id: probe
        running: root.on
        command: ["sh", "-c",
            "ls /dev/dri/renderD* >/dev/null 2>&1 || echo sin-grafica; " +
            "glxinfo -B 2>/dev/null | grep -qiE 'llvmpipe|softpipe|swrast' && echo sin-grafica; " +
            "awk '/^MemTotal:/ { if ($2 < 3800000) print \"poca-memoria\" }' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = (text.trim() + " " + (Quickshell.env("QUANTUM_ATOMIC_WEAK") ? "sin-grafica" : "")).trim();   // QUANTUM_ATOMIC_WEAK=1: simular un PC débil
                root.weak = t !== "" && !Quickshell.env("QUANTUM_ATOMIC_FORCE");
                root.weakWhy = /sin-grafica/.test(t) ? "Este PC no tiene aceleración gráfica" : /poca-memoria/.test(t) ? "Este PC tiene poca memoria" : "";
                if (root.weak) avisoProc.running = true;
            }
        }
    }
    // el aviso sale una sola vez por PC
    Process {
        id: avisoProc
        command: ["sh", "-c",
            "f=\"${XDG_STATE_HOME:-$HOME/.local/state}/quantum/atomic-aviso\"; [ -e \"$f\" ] && exit 0; mkdir -p \"$(dirname \"$f\")\"; : > \"$f\"; sleep 8; " +
            "r=$(notify-send -a Quantum -i dialog-information -A caelestial='Usar Caelestial' \"Atomic puede ir lento en este PC\" \"$1. El cristal se simplificó, pero Caelestial se verá más fluido.\"); " +
            "[ \"$r\" = caelestial ] && qs -c quantum ipc call atomic caelestial",
            "sh", root.weakWhy]
    }
    IpcHandler {
        target: "atomic"
        function caelestial(): void { Serp.choose("caelestial", false, false); }
    }

    function base(p: string): string { return Settings.stillsDir + "/" + Qt.md5(p) + "-glass"; }
    readonly property string blurUrl: hasTex ? "file://" + base(wall) + "-b.jpg?r=" + rev : ""
    readonly property string sharpUrl: hasTex ? "file://" + base(wall) + "-s.jpg?r=" + rev : ""

    function make(): void {
        if (!hasTex) return;
        const src = Settings.stillFor(wall);
        proc.command = ["sh", "-c",
            "mkdir -p \"$(dirname \"$2\")\"; i=0; while [ ! -s \"$1\" ] && [ $i -lt 40 ]; do sleep 0.5; i=$((i+1)); done; " +
            "[ -s \"$2-s.jpg\" ] || ffmpeg -v error -y -i \"$1\" -vf scale=960:-2 -q:v 3 \"$2-s.jpg\" </dev/null; " +
            "[ -s \"$2-b.jpg\" ] || ffmpeg -v error -y -i \"$1\" -vf 'scale=960:-2,gblur=sigma=12' -q:v 3 \"$2-b.jpg\" </dev/null",
            "sh", src, base(wall)];
        proc.running = true;
    }
    Process { id: proc; onExited: root.rev++ }
    // se espera a que el fondo y el shell ya estén cargados (al arrancar cambian casi juntos)
    onWallChanged: Qt.callLater(make)
    onHasTexChanged: Qt.callLater(make)
    Component.onCompleted: Qt.callLater(make)
}
