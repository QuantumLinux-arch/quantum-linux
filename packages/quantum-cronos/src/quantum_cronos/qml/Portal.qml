import QtQuick
import QtQuick.Shapes

// El portal del tiempo: anillos con los colores de Quantum que giran como un reloj, marcas
// de minutos y el reloj de arena al centro. speed < 0 gira hacia atrás (al viajar).
Item {
    id: root
    property real speed: 0.25          // vueltas por… algo: más es más rápido
    property real time: 0
    FrameAnimation { running: root.visible; onTriggered: root.time += frameTime * root.speed }

    readonly property real rad: Math.min(width, height) / 2

    // halo
    Rectangle {
        anchors.centerIn: parent
        width: root.rad * 1.7; height: width; radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0; color: theme.alpha(theme.indigo, 0.0) }
            GradientStop { position: 0.5; color: theme.alpha(theme.indigo, 0.16) }
            GradientStop { position: 1; color: theme.alpha(theme.violet, 0.0) }
        }
        opacity: 0.8 + 0.2 * Math.sin(root.time * 6)
    }
    // marcas de un reloj
    Repeater {
        model: 60
        Rectangle {
            required property int index
            readonly property bool big: index % 5 === 0
            x: root.width / 2 - width / 2
            y: root.height / 2 - root.rad + 2
            width: big ? 3 : 1.5; height: big ? 12 : 6; radius: 1
            color: theme.alpha(theme.fg, big ? 0.45 : 0.2)
            transform: Rotation { origin.x: width / 2; origin.y: root.rad - 2; angle: index * 6 + root.time * -20 }
        }
    }
    // anillos (arcos) que giran a distinta velocidad y sentido
    Repeater {
        model: [
            { r: 0.86, w: 5, sweep: 250, col: "#4FD8FF", k: 1.0 },
            { r: 0.74, w: 3, sweep: 140, col: "#6A5CFF", k: -1.6 },
            { r: 0.64, w: 7, sweep: 300, col: "#B14DFF", k: 0.7 },
            { r: 0.54, w: 2, sweep: 90, col: "#4FD8FF", k: -2.4 },
        ]
        Shape {
            id: ring
            required property var modelData
            anchors.fill: parent
            rotation: root.time * 360 * modelData.k
            ShapePath {
                strokeColor: ring.modelData.col
                strokeWidth: ring.modelData.w
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: root.width / 2; centerY: root.height / 2
                    radiusX: root.rad * ring.modelData.r; radiusY: radiusX
                    startAngle: 0; sweepAngle: ring.modelData.sweep
                }
            }
        }
    }
    // el reloj de arena
    Image {
        anchors.centerIn: parent
        width: root.rad * 0.62; height: width
        source: assetsDir + "/quantum-cronos.svg"
        sourceSize: Qt.size(width * 2, height * 2)
        smooth: true
    }
}
