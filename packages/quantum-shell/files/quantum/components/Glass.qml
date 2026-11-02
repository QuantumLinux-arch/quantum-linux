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
    property bool liquid: !Atomic.weak        // la forma líquida (se apaga en PCs sin buena gráfica)

    // ---- forma líquida: al aparecer se asienta como una gota, y al cambiar de tamaño se aplasta
    property real popX: 1
    property real popY: 1
    property real popGlow: 0
    property real lastW: width
    property real lastH: height
    property real squash: 0
    property bool morphing: false
    SequentialAnimation {
        id: pop
        ParallelAnimation {
            NumberAnimation { target: root; property: "popX"; from: 0.9; to: 1.035; duration: 190; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popY"; from: 1.1; to: 0.97; duration: 190; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "popGlow"; from: 0.9; to: 0.5; duration: 190 }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "popX"; to: 1; duration: 520; easing.type: Easing.OutElastic; easing.amplitude: 1.1; easing.period: 0.5 }
            NumberAnimation { target: root; property: "popY"; to: 1; duration: 520; easing.type: Easing.OutElastic; easing.amplitude: 1.1; easing.period: 0.5 }
            NumberAnimation { target: root; property: "popGlow"; to: 0; duration: 600; easing.type: Easing.OutCubic }
        }
    }
    function startPop(): void { if (liquid && width > 0) pop.restart(); }
    FrameAnimation {
        running: root.liquid && root.morphing
        onTriggered: {
            const dt = Math.max(0.008, frameTime);
            const vw = (root.width - root.lastW) / dt, vh = (root.height - root.lastH) / dt;
            root.lastW = root.width; root.lastH = root.height;
            const t = Math.max(-0.12, Math.min(0.12, (vw - vh * 1.6) / 4000));
            root.squash += (t - root.squash) * Math.min(1, dt * 12);
            if (Math.abs(vw) < 2 && Math.abs(vh) < 2 && Math.abs(root.squash) < 0.002) { root.squash = 0; root.morphing = false; }
        }
    }
    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: root.popX * (1 + root.squash * 0.35)
        yScale: root.popY * (1 - root.squash)
    }

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
    onWidthChanged: { update(); morphing = true; }
    onHeightChanged: { update(); morphing = true; }
    onVisibleChanged: if (visible) { update(); startPop(); }
    Component.onCompleted: { update(); startPop(); }
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
        readonly property real glow: Math.min(1.2, root.glow + root.popGlow)
        readonly property var blurred: blurTex
        readonly property var sharp: sharpTex
        fragmentShader: Quickshell.shellDir + "/shaders/glass.frag.qsb"
    }
}
