import QtQuick
import Quickshell

// Quarki, la mascota de Quantum: estrella de luz con núcleo oscuro, ojos de chispa y un aro
// que gira (capas en assets/quarki, generadas por branding/assistant/quarki.py).
//   mood: sleep (en la barra, respira) · peek (se asoma al pasar el mouse) · awake ·
//         think (mira hacia arriba) · work (el aro gira rápido) · done (salta y brilla)
Item {
    id: root

    property string mood: "awake"
    property bool showZ: true                 // las «z» al dormir
    property point look: Qt.point(0, 0)       // hacia dónde mira (-1..1)
    readonly property real u: width / 200     // unidad: el dibujo mide 200x200
    readonly property string dir: Quickshell.shellDir + "/assets/quarki/"
    readonly property bool asleep: mood === "sleep"

    implicitWidth: 64
    implicitHeight: 64

    // ---------------------------------------------------------------- movimiento
    // aro: velocidad de la partícula y cuánto se bambolea según el ánimo
    readonly property real spin: ({ sleep: 0, peek: 0.6, awake: 1.3, think: 2.6, work: 6.5, done: 4 })[mood] ?? 1.3
    readonly property real wobble: ({ sleep: 0, peek: 3, awake: 7, think: 10, work: 24, done: 14 })[mood] ?? 7
    property real particle: 0.6
    property real phase: 0
    property real breath: 0
    readonly property real tilt: -14 + wobble * Math.sin(phase)

    FrameAnimation {
        running: root.visible
        onTriggered: {
            const dt = Math.min(frameTime, 0.05);
            root.particle += dt * root.spin;
            root.phase += dt * (root.mood === "work" ? 1.7 : 0.7);
            root.breath += dt * (root.asleep ? 1.6 : 2.2);
        }
    }

    // ¿la partícula pasa por delante (mitad de abajo del aro)?
    readonly property real px: 92 * Math.cos(particle)
    readonly property real py: 24 * Math.sin(particle)
    readonly property bool particleFront: Math.sin(particle) > 0
    readonly property real tr: tilt * Math.PI / 180
    readonly property real partX: (100 + px * Math.cos(tr) - py * Math.sin(tr)) * u
    readonly property real partY: (100 + px * Math.sin(tr) + py * Math.cos(tr)) * u

    // al despertar se estira; al terminar algo, salta
    property real stretch: 1
    property real hop: 0
    onMoodChanged: {
        if (mood === "awake" || mood === "think") wake.restart();
        if (mood === "done") jump.restart();
    }
    SequentialAnimation {
        id: wake
        NumberAnimation { target: root; property: "stretch"; to: 1.12; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "stretch"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
    }
    SequentialAnimation {
        id: jump
        NumberAnimation { target: root; property: "hop"; to: -0.16; duration: 200; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "hop"; to: 0; duration: 520; easing.type: Easing.OutBounce }
    }

    // parpadeo de vez en cuando
    property real blink: 1
    Timer {
        running: root.visible && !root.asleep
        interval: 2600 + Math.random() * 2600
        repeat: true
        onTriggered: { interval = 2400 + Math.random() * 3200; blinkAnim.restart(); }
    }
    SequentialAnimation {
        id: blinkAnim
        NumberAnimation { target: root; property: "blink"; to: 0.1; duration: 70 }
        NumberAnimation { target: root; property: "blink"; to: 1; duration: 110 }
    }

    // ------------------------------------------------------------------- dibujo
    component Layer: Image {
        anchors.fill: parent
        sourceSize: Qt.size(Math.max(64, root.width * 2), Math.max(64, root.height * 2))
        smooth: true
        mipmap: true
    }
    component Dot: Item {
        x: root.partX - width / 2
        y: root.partY - height / 2
        width: 18 * root.u; height: width
        Rectangle { anchors.fill: parent; radius: width / 2; color: "#7FE3FF"; opacity: 0.35 }
        Rectangle { anchors.centerIn: parent; width: parent.width / 2; height: width; radius: width / 2; color: "white" }
    }

    Item {
        id: figure
        width: root.width
        height: root.height
        y: root.hop * root.height + (root.asleep ? 0 : Math.sin(root.breath) * 2 * root.u)
        scale: root.stretch * (root.asleep ? 0.84 + 0.025 * Math.sin(root.breath) : 1)
        Behavior on scale { enabled: !root.asleep; NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

        Layer {
            source: root.dir + "glow.svg"
            opacity: root.asleep ? 0.55 : root.mood === "work" ? 0.85 + 0.15 * Math.sin(root.breath * 3) : 1
            scale: root.mood === "done" ? 1.15 : 1
            Behavior on scale { NumberAnimation { duration: 300 } }
        }
        Layer {
            source: root.dir + "rays.svg"
            opacity: root.asleep ? 0.35 : 0.8 + 0.2 * Math.sin(root.breath * 1.3)
            Behavior on opacity { NumberAnimation { duration: 400 } }
        }
        // mitad de atrás del aro (y la partícula cuando va por detrás)
        Item {
            anchors.fill: parent
            rotation: root.tilt
            opacity: root.asleep ? 0.35 : root.mood === "peek" ? 0.65 : 1
            Behavior on opacity { NumberAnimation { duration: 400 } }
            Layer { source: root.dir + "ring-back.svg" }
        }
        Dot { visible: !root.asleep && !root.particleFront }
        Layer { source: root.dir + "body.svg" }
        // ojos
        Layer {
            source: root.dir + (root.asleep ? "eyes-closed.svg" : root.mood === "think" ? "eyes-think.svg"
                                : root.mood === "done" ? "eyes-happy.svg" : "eyes-open.svg")
            transform: [
                Scale { origin.x: root.width / 2; origin.y: root.height / 2; yScale: root.mood === "peek" ? 0.55 * root.blink : root.blink }
            ]
            x: root.look.x * 6 * root.u
            y: root.look.y * 5 * root.u
            Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        }
        // mitad de adelante del aro
        Item {
            anchors.fill: parent
            rotation: root.tilt
            opacity: root.asleep ? 0.35 : root.mood === "peek" ? 0.65 : 1
            Behavior on opacity { NumberAnimation { duration: 400 } }
            Layer { source: root.dir + "ring-front.svg" }
        }
        Dot { visible: !root.asleep && root.particleFront }
    }

    // chispas al terminar algo
    Repeater {
        model: [[0.12, 0.2, 0], [0.86, 0.26, 120], [0.8, 0.84, 240]]
        Text {
            required property var modelData
            x: modelData[0] * root.width - width / 2
            y: modelData[1] * root.height - height / 2
            text: "✦"
            color: "white"
            font.pixelSize: Math.max(8, 22 * root.u)
            opacity: 0
            scale: 0.4
            states: State {
                when: root.mood === "done"
                PropertyChanges { opacity: 1; scale: 1 }
            }
            transitions: Transition {
                SequentialAnimation {
                    PauseAnimation { duration: modelData[2] }
                    NumberAnimation { properties: "opacity,scale"; duration: 280; easing.type: Easing.OutBack }
                }
            }
        }
    }

    // «z» que suben mientras duerme
    Repeater {
        model: 2
        Text {
            required property int index
            visible: root.asleep && root.showZ
            readonly property real t: ((root.breath * 0.16 + index * 0.5) % 1)
            x: root.width * (0.7 + 0.12 * t) + index * 2
            y: root.height * (0.32 - 0.3 * t)
            text: "z"
            color: "#C5C0FF"
            font.family: "Inter"
            font.weight: Font.ExtraBold
            font.pixelSize: Math.max(7, root.width * (0.14 + 0.06 * t))
            opacity: Math.sin(t * Math.PI) * 0.9
        }
    }
}
