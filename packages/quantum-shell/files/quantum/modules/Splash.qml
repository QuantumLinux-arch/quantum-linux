import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services

// Pantalla de carga al iniciar sesión: continúa la animación de arranque (el logo de
// Quantum con su órbita y el cometa) mientras el escritorio carga de fondo, y luego se desvanece para que
// aparezca todo de golpe. Es liviana a propósito (sin desenfoques, solo formas simples) para
// mostrarse enseguida aunque sea la primera vez o no haya tarjeta gráfica.
// No aparece al recargar el shell (por ejemplo, tras una actualización).
Scope {
    id: root

    required property bool desktopReady       // el resto del shell ya cargó
    signal sessionStarted                     // la pantalla se fue: es el inicio de la sesión

    readonly property string marker: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quantum-session-ready"
    property bool needed: false
    property bool checked: false
    property bool leaving: false
    property bool minTimePassed: false

    // ¿Es el inicio de la sesión? (si el marcador no existe)
    Process {
        running: true
        command: ["sh", "-c", "[ -e \"$1\" ]", "sh", root.marker]
        onExited: code => {
            root.needed = code !== 0 && !Quickshell.env("QUANTUM_NO_SPLASH");
            root.checked = true;
        }
    }
    Process { id: mark; command: ["sh", "-c", ": > \"$1\"", "sh", root.marker] }

    Timer { running: root.needed; interval: 1400; onTriggered: root.minTimePassed = true }
    // espera a que el escritorio esté listo (y un respiro para que pinte su primer cuadro)
    Timer {
        running: root.needed && root.desktopReady && root.minTimePassed && !root.leaving
        interval: 350
        onTriggered: { root.leaving = true; mark.running = true; root.sessionStarted(); }
    }

    LazyLoader {
        active: root.needed && !root.gone
        PanelWindow {
            id: win
            screen: Quickshell.screens[0]
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quantum-splash"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            property real time: 0
            FrameAnimation { running: true; onTriggered: win.time += frameTime }

            property real fade: root.leaving ? 0 : 1
            Behavior on fade { NumberAnimation { duration: 650; easing.type: Easing.InOutCubic } }
            onFadeChanged: if (fade === 0) root.gone = true

            Item {
                anchors.fill: parent
                opacity: win.fade
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#05040C" }
                        GradientStop { position: 1; color: "#120B2E" }
                    }
                }
                // estrellas
                Repeater {
                    model: 60
                    Rectangle {
                        required property int index
                        function rnd(k: real): real { const s = Math.sin(index * 12.9898 + k * 78.233) * 43758.5453; return s - Math.floor(s); }
                        x: rnd(1) * win.width; y: rnd(2) * win.height
                        width: 2 + rnd(3) * 2; height: width; radius: width / 2
                        color: "white"
                        opacity: (0.15 + 0.45 * rnd(4)) * (0.55 + 0.45 * Math.sin(win.time * (1 + rnd(6) * 2) + index))
                    }
                }
                // el logo con una órbita grande e inclinada y un cometa que la recorre (como el
                // cierre de los videos); crece un poco al irse, como si el escritorio saliera de él
                Item {
                    id: atom
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -30
                    width: 600; height: 600
                    scale: (1 + 0.02 * Math.sin(win.time * 1.6)) * (1 + 0.5 * (1 - win.fade))
                    readonly property real tilt: -24 + 10 * Math.sin(win.time * 0.6)
                    readonly property real u: win.time * 2.6
                    readonly property var cols: ["#4FD8FF", "#6A5CFF", "#B14DFF"]

                    // halo que respira
                    Shape {
                        anchors.fill: parent
                        opacity: 0.45 + 0.15 * Math.sin(win.time * 2.2)
                        ShapePath {
                            strokeWidth: 0
                            fillGradient: RadialGradient {
                                centerX: 300; centerY: 300; centerRadius: 210; focalX: 300; focalY: 300
                                GradientStop { position: 0; color: "#996A5CFF" }
                                GradientStop { position: 0.55; color: "#336A5CFF" }
                                GradientStop { position: 1; color: "#006A5CFF" }
                            }
                            PathAngleArc { centerX: 300; centerY: 300; radiusX: 210; radiusY: 210; startAngle: 0; sweepAngle: 360 }
                        }
                    }
                    // mitad de atrás de la órbita y el cometa cuando pasa por detrás
                    component Half: Item {
                        id: half
                        property bool front: false
                        anchors.fill: parent
                        rotation: atom.tilt
                        Shape {
                            anchors.fill: parent
                            ShapePath {
                                strokeColor: Qt.rgba(0.77, 0.75, 1, 0.3)
                                strokeWidth: 2
                                fillColor: "transparent"
                                startX: 35; startY: 300
                                PathArc {
                                    x: 565; y: 300; radiusX: 265; radiusY: 82
                                    direction: half.front ? PathArc.Counterclockwise : PathArc.Clockwise
                                }
                            }
                        }
                        Repeater {
                            model: 45
                            Rectangle {
                                required property int index
                                readonly property real b: atom.u - index * 0.018
                                readonly property real r: 6.5 - index * 0.12
                                visible: (Math.sin(b) > 0) === half.front
                                x: 300 + 265 * Math.cos(b) - r
                                y: 300 + 82 * Math.sin(b) - r
                                width: 2 * r; height: width; radius: r
                                color: index === 0 ? "white" : atom.cols[Math.min(2, Math.floor(index / 15))]
                                opacity: 0.86 * Math.pow(1 - index / 45, 1.8)
                            }
                        }
                    }
                    Half { front: false }
                    Image {
                        anchors.centerIn: parent
                        width: 230; height: 230
                        source: Quickshell.shellDir + "/assets/quantum-mark.svg"
                        sourceSize: Qt.size(460, 460)
                    }
                    Half { front: true }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: atom.verticalCenter
                    anchors.topMargin: 190
                    text: "Preparando tu escritorio"
                    font.family: "Inter"
                    font.pixelSize: 17
                    color: "#9C95B8"
                    opacity: Math.min(1, Math.max(0, (win.time - 1.2) / 0.6)) * (0.7 + 0.3 * Math.sin(win.time * 2))
                }
            }
        }
    }
    property bool gone: false
}
