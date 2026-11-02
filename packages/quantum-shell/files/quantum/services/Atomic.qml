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
    // la luz del reflejo: arriba a la izquierda, y se mueve un poco con el mouse
    property point light: Qt.point(-0.6, -0.8)

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
