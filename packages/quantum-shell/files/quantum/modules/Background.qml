import QtQuick
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs.services
import qs.components

// Fondo de pantalla en cada monitor. Al cambiarlo, el nuevo se revela con un
// círculo que crece desde el centro, con un anillo de luz en el borde.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData
        // «quantum:live» = fondo vivo (el átomo de Quantum animado); si no, una imagen
        readonly property bool live: Settings.appearance.wallpaper === "quantum:live"
        // la imagen que revela el círculo (en los fondos animados, un cuadro fijo del video)
        readonly property string source: !live && Settings.appearance.wallpaper ? Settings.stillUrl(Settings.appearance.wallpaper) : ""
        // Fondos animados (video o GIF): se pausan con juegos o videos a pantalla completa,
        // el Modo juego, la batería baja o la pantalla bloqueada
        readonly property string wall: Settings.appearance.wallpaper
        readonly property bool anim: Settings.isAnimated(wall)
        readonly property var battery: UPower.displayDevice
        readonly property bool lowBattery: (battery?.isLaptopBattery ?? false) && (battery?.percentage ?? 1) < 0.2
                                           && battery?.state !== UPowerDeviceState.Charging
        readonly property bool paused: Shell.gameMode || (Wm.active?.fullscreen ?? false) || lowBattery || Shell.locked
        // radio del círculo que revela el fondo nuevo
        property real radius: 0
        readonly property real maxRadius: Math.hypot(width, height) / 2 + 40
        property bool revealing: false

        screen: modelData
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "quantum-background"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: Theme.surface

        Component.onCompleted: under.source = source
        onSourceChanged: {
            if (!under.source.toString() || Theme.animMult === 0)
                under.source = source;
            else
                over.source = source;
        }

        component Wall: Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize: Qt.size(win.width, win.height)
        }

        // el fondo actual
        Wall { id: under; visible: !win.live }

        // el fondo animado, encima del cuadro fijo (aparece con un fundido cuando ya corre)
        Loader {
            id: animLayer
            anchors.fill: parent
            active: win.anim && !win.live
            sourceComponent: !win.anim ? null : Settings.isVideo(win.wall) ? videoC : gifC
            property bool ready: false
            opacity: ready && !win.revealing ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 450 } }
            onSourceComponentChanged: ready = false
            onActiveChanged: ready = false
        }
        Component {
            id: videoC
            Video {
                source: "file://" + win.wall
                fillMode: VideoOutput.PreserveAspectCrop
                loops: MediaPlayer.Infinite
                muted: true
                autoPlay: true
                readonly property bool hold: win.paused
                onHoldChanged: hold ? pause() : play()
                onPlaybackStateChanged: if (playbackState === MediaPlayer.PlayingState) animLayer.ready = true
                onSourceChanged: animLayer.ready = false
            }
        }
        Component {
            id: gifC
            AnimatedImage {
                source: /\.gif$/i.test(win.wall) ? "file://" + win.wall : ""
                fillMode: Image.PreserveAspectCrop
                cache: false
                playing: !win.paused
                onStatusChanged: animLayer.ready = status === Image.Ready
            }
        }

        // el fondo nuevo: se carga escondido y se muestra a través del círculo
        Wall {
            id: over
            visible: false
            onStatusChanged: {
                if (status === Image.Ready && source.toString() === win.source) {
                    win.radius = 0;
                    win.revealing = true;
                    reveal.restart();
                }
            }
        }
        NumberAnimation {
            id: reveal
            target: win
            property: "radius"
            to: win.maxRadius
            duration: Math.round(1100 * Math.max(0.5, Theme.animMult))
            easing.type: Easing.InOutCubic
            // al terminar, el nuevo pasa a ser el de abajo
            onFinished: under.source = over.source
        }
        Connections {
            target: under
            function onStatusChanged() {
                if (under.status === Image.Ready && under.source === over.source) {
                    win.revealing = false;
                    over.source = "";
                }
            }
        }

        Item {
            id: mask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            Rectangle {
                x: parent.width / 2 - win.radius
                y: parent.height / 2 - win.radius
                width: win.radius * 2
                height: width
                radius: win.radius
                color: "white"
            }
        }
        MultiEffect {
            anchors.fill: parent
            visible: win.revealing && !win.live
            source: over
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.2
        }
        // anillo de luz con los colores de Quantum en el borde del círculo
        Rectangle {
            visible: win.revealing && !win.live && win.radius < win.maxRadius - 1
            x: win.width / 2 - win.radius
            y: win.height / 2 - win.radius
            width: win.radius * 2
            height: width
            radius: win.radius
            color: "transparent"
            border.width: 3
            border.color: Theme.alpha(Theme.brandCyan, 0.7 * (1 - win.radius / win.maxRadius))
        }

        // Fondo vivo: se pausa con juegos, ventanas a pantalla completa o maximizadas,
        // el modo juego o la pantalla bloqueada, para no gastar batería ni gráfica.
        LazyLoader {
            active: win.live
            LiveWallpaper {
                parent: win.contentItem
                anchors.fill: parent
                running: !Shell.gameMode && !(Wm.active?.fullscreen ?? false) && !(Wm.active?.maximized ?? false)
                         && Settings.windows.animations !== "none"
            }
        }
    }
}
