import QtQuick
import Quickshell

// Personaje que gira como una peonza (menú de apagado y bloqueo). Si existe una imagen propia en
// ~/.config/quantum/gira.gif, .png o .webp, gira esa; si no, Quarki.
Item {
    id: root

    property bool running: visible
    implicitWidth: 120
    implicitHeight: 120

    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/quantum/"
    readonly property var names: ["gira.gif", "gira.png", "gira.webp"]
    property int tryIndex: 0
    readonly property bool own: custom.status === AnimatedImage.Ready

    property real turn: 0
    property real bob: 0
    FrameAnimation {
        running: root.running
        onTriggered: {
            root.turn = (root.turn + frameTime * 150) % 360;     // una vuelta cada 2,4 s
            root.bob += frameTime * 4.2;
        }
    }

    Item {
        id: figure
        anchors.fill: parent
        y: -Math.abs(Math.sin(root.bob)) * root.height * 0.05
        transform: Rotation {
            origin.x: figure.width / 2
            origin.y: figure.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: root.turn
        }

        AnimatedImage {
            id: custom
            anchors.fill: parent
            visible: root.own
            source: root.tryIndex < root.names.length ? "file://" + root.dir + root.names[root.tryIndex] : ""
            fillMode: Image.PreserveAspectFit
            cache: false
            playing: root.running
            // la siguiente extensión si esta no existe
            onStatusChanged: if (status === AnimatedImage.Error && root.tryIndex < root.names.length) Qt.callLater(() => root.tryIndex++)
        }
        Mascot {
            anchors.fill: parent
            visible: !root.own
            mood: "awake"
            showZ: false
        }
    }
    // sombra en el piso
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: -4
        width: root.width * (0.5 - 0.08 * Math.abs(Math.sin(root.bob)))
        height: width * 0.16
        radius: height / 2
        color: Qt.rgba(0, 0, 0, 0.3)
    }
}
