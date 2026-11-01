import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// Al activar el Modo juego: la pantalla se oscurece un momento, salen anillos con los colores de
// Quantum desde el centro y aparece «MODO JUEGO» con lo que hace. Dura 2 s y no recibe clics.
Scope {
    id: root
    property real t: -1                 // 0..1 mientras se muestra
    readonly property real dur: 2.2

    Connections {
        target: Shell
        function onGameModeChanged() {
            // dentro de un juego a pantalla completa no se interrumpe
            if (Shell.gameMode && !(Wm.active?.fullscreen ?? false)) { root.t = 0; Sounds.play("whoosh"); }
        }
    }
    FrameAnimation {
        running: root.t >= 0
        onTriggered: { root.t += frameTime / root.dur; if (root.t >= 1) root.t = -1; }
    }

    LazyLoader {
        active: root.t >= 0

        PanelWindow {
            id: win
            screen: Wm.screen
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quantum-gamemode"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            mask: Region {}                     // los clics pasan a lo de abajo

            readonly property real t: Math.max(0, root.t)
            // entra rápido (0-15 %), se queda y sale (80-100 %)
            readonly property real show: t < 0.15 ? t / 0.15 : t > 0.8 ? (1 - t) / 0.2 : 1
            function ease(x: real): real { return 1 - Math.pow(1 - Math.min(1, Math.max(0, x)), 3); }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.02, 0.01, 0.06, 0.62 * win.show)
            }
            // anillos que salen del centro
            Repeater {
                model: [[0.0, "#4FD8FF"], [0.08, "#6A5CFF"], [0.16, "#B14DFF"]]
                Rectangle {
                    required property var modelData
                    readonly property real k: win.ease((win.t - modelData[0]) / 0.55)
                    anchors.centerIn: parent
                    width: 120 + k * Math.max(win.width, win.height) * 1.1
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 6 * (1 - k) + 1
                    border.color: modelData[1]
                    opacity: (1 - k) * 0.9
                    visible: win.t >= modelData[0]
                }
            }
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 14
                opacity: win.show
                // el control, con un rebote
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 132; implicitHeight: 132; radius: 66
                    scale: 0.4 + 0.6 * win.ease(win.t / 0.22) + 0.06 * Math.sin(Math.min(1, win.t / 0.3) * Math.PI)
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#4FD8FF" }
                        GradientStop { position: 0.5; color: "#6A5CFF" }
                        GradientStop { position: 1; color: "#B14DFF" }
                    }
                    Icon { anchors.centerIn: parent; text: "sports_esports"; size: 72; fill: 1; color: "white" }
                }
                Txt {
                    Layout.alignment: Qt.AlignHCenter
                    text: "MODO JUEGO"
                    color: "white"
                    font.pixelSize: 54
                    font.weight: Font.Black
                    font.letterSpacing: 4 + 18 * (1 - win.ease(win.t / 0.3))
                }
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10
                    Repeater {
                        model: [["bolt", "Rendimiento al máximo"], ["notifications_off", "Notificaciones en silencio"], ["animation", "Efectos apagados"]]
                        Rectangle {
                            id: chipBox
                            required property var modelData
                            required property int index
                            readonly property real k: win.ease((win.t - 0.18 - index * 0.07) / 0.2)
                            width: chip.implicitWidth + 30; height: 40; radius: 20
                            color: Qt.rgba(1, 1, 1, 0.1)
                            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.16)
                            opacity: k
                            transform: Translate { y: (1 - chipBox.k) * 16 }
                            Row {
                                id: chip
                                anchors.centerIn: parent
                                spacing: 8
                                Icon { anchors.verticalCenter: parent.verticalCenter; text: chipBox.modelData[0]; size: 19; fill: 1; color: "#7FE3FF" }
                                Txt { anchors.verticalCenter: parent.verticalCenter; text: chipBox.modelData[1]; color: "white"; font.weight: Font.DemiBold }
                            }
                        }
                    }
                }
                Txt {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 6
                    text: "Contador de FPS en tus juegos: Mayús derecha + F12"
                    color: Qt.rgba(1, 1, 1, 0.55)
                    font.pixelSize: Theme.textSmall
                }
            }
        }
    }
}
