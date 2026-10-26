import QtQuick
import QtQuick.Window

// Instalación automática de Quantum: pantalla completa, el átomo que gira, los pasos y el avance.
Window {
    id: win
    visible: true
    visibility: Window.FullScreen
    width: 1920; height: 1080
    color: "#07060D"
    title: "Instalando Quantum Linux"

    readonly property color cyan: "#4FD8FF"
    readonly property color indigo: "#6A5CFF"
    readonly property color violet: "#B14DFF"
    readonly property bool done: install.state === "done"
    readonly property bool failed: install.state === "error"
    property real time: 0
    FrameAnimation { running: true; onTriggered: win.time += frameTime }

    // fondo: degradado y estrellas
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#05040C" }
            GradientStop { position: 1; color: "#140C34" }
        }
    }
    Repeater {
        model: 70
        Rectangle {
            required property int index
            function rnd(k) { const s = Math.sin(index * 12.9898 + k * 78.233) * 43758.5453; return s - Math.floor(s); }
            x: rnd(1) * win.width; y: rnd(2) * win.height
            width: 2 + rnd(3) * 2; height: width; radius: width / 2; color: "white"
            opacity: (0.15 + 0.45 * rnd(4)) * (0.55 + 0.45 * Math.sin(win.time * (1 + rnd(6) * 2) + index))
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 110

        // ---- el átomo con el anillo de avance
        Item {
            width: 440; height: 440
            anchors.verticalCenter: parent.verticalCenter
            Canvas {
                id: ring
                anchors.fill: parent
                property real k: install.percent / 100
                onKChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d"); c.reset();
                    const r = width / 2 - 14;
                    c.lineWidth = 12; c.lineCap = "round";
                    c.strokeStyle = "rgba(255,255,255,0.08)"; c.beginPath(); c.arc(width / 2, height / 2, r, 0, Math.PI * 2); c.stroke();
                    const g = c.createLinearGradient(0, 0, width, height);
                    g.addColorStop(0, "#4FD8FF"); g.addColorStop(0.5, "#6A5CFF"); g.addColorStop(1, "#B14DFF");
                    c.strokeStyle = win.failed ? "#FF6B7A" : g; c.beginPath();
                    c.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0.005, k)); c.stroke();
                }
            }
            Item {
                id: atom
                anchors.centerIn: parent
                width: 300; height: 300
                readonly property real k: width / 256
                scale: 1 + 0.03 * Math.sin(win.time * 1.6)
                Image { anchors.fill: parent; source: "quantum-atom.svg"; sourceSize: Qt.size(600, 600) }
                Repeater {
                    model: [90, -30, 30]
                    Item {
                        id: orb
                        required property real modelData
                        required property int index
                        anchors.fill: parent
                        rotation: modelData
                        readonly property real a: win.time * [2.4, 1.9, 2.1][index] + index * 2.09
                        Repeater {
                            model: 6
                            Rectangle {
                                required property int index
                                readonly property real b: orb.a - index * 0.08
                                readonly property real sz: (20 - index * 2.4)
                                x: atom.width / 2 + 104 * atom.k * Math.cos(b) - sz / 2
                                y: atom.height / 2 + 38 * atom.k * Math.sin(b) - sz / 2
                                width: sz; height: sz; radius: sz / 2
                                color: index === 0 ? "white" : [win.cyan, win.indigo, win.violet][orb.index]
                                opacity: index === 0 ? 1 : 0.55 * (1 - index / 6)
                                border.width: index === 0 ? 3 : 0
                                border.color: [win.cyan, win.indigo, win.violet][orb.index]
                            }
                        }
                    }
                }
            }
        }

        // ---- textos y pasos
        Column {
            width: 720
            anchors.verticalCenter: parent.verticalCenter
            spacing: 18
            Text {
                text: win.failed ? "La instalación se detuvo" : win.done ? (install.name ? "¡Listo, " + install.name + "!" : "¡Listo!") : "Instalando Quantum Linux"
                color: "white"; font.family: "Inter"; font.pixelSize: 54; font.weight: Font.Black
            }
            Text {
                width: parent.width; wrapMode: Text.WordWrap
                text: win.failed ? install.error
                    : win.done ? "Quantum ya está instalado. Al reiniciar, saca el pendrive cuando veas el logo."
                    : Math.round(install.percent) + " % · No apagues el PC. Puedes ir por un café: esto es automático."
                color: win.failed ? "#FFB4BC" : "#B9B3D6"; font.family: "Inter"; font.pixelSize: 20
            }
            Item { width: 1; height: 10 }
            Repeater {
                model: install.steps
                Row {
                    id: st
                    required property var modelData
                    spacing: 18
                    opacity: modelData.state === "waiting" ? 0.45 : 1
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                    Rectangle {
                        width: 34; height: 34; radius: 17
                        anchors.verticalCenter: parent.verticalCenter
                        color: st.modelData.state === "ok" ? "#34D399" : st.modelData.state === "error" ? "#FF6B7A"
                             : st.modelData.state === "running" ? win.indigo : "transparent"
                        border.width: st.modelData.state === "waiting" ? 2 : 0
                        border.color: Qt.rgba(1, 1, 1, 0.3)
                        Text {
                            anchors.centerIn: parent
                            text: st.modelData.state === "ok" ? "✓" : st.modelData.state === "error" ? "!" : ""
                            color: "white"; font.pixelSize: 18; font.weight: Font.Black
                        }
                        // punto que late en el paso actual
                        Rectangle {
                            anchors.centerIn: parent
                            visible: st.modelData.state === "running"
                            width: 12 + 4 * Math.sin(win.time * 5); height: width; radius: width / 2; color: "white"
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: st.modelData.title; color: "white"; font.family: "Inter"; font.pixelSize: 22; font.weight: Font.Bold }
                        Text {
                            visible: st.modelData.state === "running" && install.detail !== ""
                            text: install.detail; color: "#9C95B8"; font.family: "Inter"; font.pixelSize: 15
                        }
                    }
                }
            }
            Item { width: 1; height: 16 }
            Rectangle {
                visible: win.done || win.failed
                width: btnText.implicitWidth + 80; height: 60; radius: 30
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: win.cyan }
                    GradientStop { position: 0.5; color: win.indigo }
                    GradientStop { position: 1; color: win.violet }
                }
                Text { id: btnText; anchors.centerIn: parent; text: win.done ? "Reiniciar ahora" : "Reiniciar"; color: "white"; font.family: "Inter"; font.pixelSize: 20; font.weight: Font.Bold }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: install.reboot() }
            }
            Text {
                visible: win.done
                text: "Se reinicia sola en " + Math.max(0, 30 - Math.floor(win.time - doneAt.t)) + " s"
                color: "#9C95B8"; font.family: "Inter"; font.pixelSize: 15
            }
        }
    }
    QtObject { id: doneAt; property real t: 0 }
    onDoneChanged: if (done) { doneAt.t = time; autoReboot.start(); }
    Timer { id: autoReboot; interval: 30000; onTriggered: install.reboot() }
}
