import QtQuick
import Quickshell
import qs.services

// Cristal Cuántico (shell Atomic): refracta el fondo de pantalla en los bordes, lo desenfoca,
// separa los colores en el borde y tiene reflejo de luz (shaders/glass.frag).
// Para saber qué parte del fondo hay detrás, calcula dónde está en la pantalla: la posición de su
// ventana (por sus anclas y márgenes) más su posición dentro de la ventana.
Item {
    id: root
    property real radius: 20
    property real bevel: Math.max(12, Math.min(32, Math.min(width, height) * 0.3))
    property real refr: bevel * 1.25
    property real dim: 0.66
    property real tint: 0.10
    property real glow: 0

    property point local: Qt.point(0, 0)
    readonly property var win: QsWindow.window
    readonly property size scr: win?.screen ? Qt.size(win.screen.width, win.screen.height) : Qt.size(1920, 1080)
    readonly property point winPos: {
        const w = win;
        if (!w) return Qt.point(0, 0);
        const a = w.anchors ?? {}, m = w.margins ?? {};
        const x = a.left ? (m.left ?? 0) : a.right ? scr.width - w.width - (m.right ?? 0) : (scr.width - w.width) / 2;
        const y = a.top ? (m.top ?? 0) : a.bottom ? scr.height - w.height - (m.bottom ?? 0) : (scr.height - w.height) / 2;
        return Qt.point(x, y);
    }
    function update(): void {
        const p = root.mapToItem(null, 0, 0);
        if (p.x !== local.x || p.y !== local.y) local = p;
    }
    onWidthChanged: update()
    onHeightChanged: update()
    onVisibleChanged: if (visible) update()
    Component.onCompleted: update()
    // por si se mueve dentro de la ventana (animaciones de abrir y cerrar)
    Timer { running: root.visible; interval: 250; repeat: true; onTriggered: root.update() }

    Image { id: blurTex; visible: false; source: Atomic.blurUrl; asynchronous: true; cache: true }
    Image { id: sharpTex; visible: false; source: Atomic.sharpUrl; asynchronous: true; cache: true }

    ShaderEffect {
        anchors.fill: parent
        readonly property size boxSize: Qt.size(width, height)
        readonly property point orig: Qt.point(root.winPos.x + root.local.x, root.winPos.y + root.local.y)
        readonly property size scr: root.scr
        readonly property point light: Atomic.light
        readonly property real radius: root.radius
        readonly property real bevel: root.bevel
        readonly property real refr: root.refr
        readonly property real dim: root.dim
        readonly property real tint: root.tint
        readonly property real hasTex: blurTex.status === Image.Ready && sharpTex.status === Image.Ready ? 1 : 0
        readonly property real glow: root.glow
        readonly property var blurred: blurTex
        readonly property var sharp: sharpTex
        fragmentShader: Quickshell.shellDir + "/shaders/glass.frag.qsb"
    }
}
