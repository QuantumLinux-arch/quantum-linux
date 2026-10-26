/*
    Diapositivas de Quantum Linux mientras se instala: capturas reales del
    sistema, con texto a la izquierda y la pantalla a la derecha.
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick 2.15
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Timer {
        interval: 8000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    // Fondo: oscuro con resplandores de color que se mueven lento
    Rectangle {
        anchors.fill: parent
        z: -2
        color: "#0B0A12"
    }
    Rectangle {
        z: -1
        width: parent.width * 0.9; height: width; radius: width / 2
        x: parent.width * 0.45 + Math.sin(glow.t) * 30; y: -height * 0.35
        opacity: 0.35
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#6A5CFF" }
            GradientStop { position: 1.0; color: "#0B0A12" }
        }
    }
    Rectangle {
        z: -1
        width: parent.width * 0.7; height: width; radius: width / 2
        x: -width * 0.35; y: parent.height * 0.4 + Math.cos(glow.t) * 20
        opacity: 0.25
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#2FC4F0" }
            GradientStop { position: 1.0; color: "#0B0A12" }
        }
    }
    QtObject {
        id: glow
        property real t: 0
        property var timer: Timer { interval: 50; running: presentation.activatedInCalamares; repeat: true; onTriggered: glow.t += 0.02 }
    }

    component QuantumSlide: Slide {
        id: s
        property string icon
        property string heading
        property string body
        property string image: ""

        // entrada: el texto sube y la captura se desliza
        property real enter: 0
        onVisibleChanged: if (visible) { enter = 0; anim.restart(); }
        NumberAnimation { id: anim; target: s; property: "enter"; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }

        Row {
            anchors.centerIn: parent
            spacing: 40
            width: Math.min(parent.width - 60, 900)

            Column {
                width: s.image ? parent.width * 0.4 : parent.width
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16
                opacity: s.enter
                transform: Translate { y: (1 - s.enter) * 24 }

                Rectangle {
                    width: 64; height: 64; radius: 20
                    anchors.horizontalCenter: s.image ? undefined : parent.horizontalCenter
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#4FD8FF" }
                        GradientStop { position: 0.5; color: "#6A5CFF" }
                        GradientStop { position: 1.0; color: "#B14DFF" }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: s.icon
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 36
                        color: "#FFFFFF"
                    }
                }
                Text {
                    text: s.heading
                    width: parent.width
                    horizontalAlignment: s.image ? Text.AlignLeft : Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: "#F2EFFC"
                    font.family: "Inter"
                    font.pixelSize: 30
                    font.weight: Font.ExtraBold
                }
                Text {
                    text: s.body
                    width: parent.width
                    horizontalAlignment: s.image ? Text.AlignLeft : Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: "#A9A3C4"
                    font.family: "Inter"
                    font.pixelSize: 16
                    lineHeight: 1.3
                }
            }

            // captura en un marco de monitor
            Rectangle {
                visible: s.image !== ""
                width: parent.width * 0.6 - 40
                height: width * 9 / 16 + 16
                anchors.verticalCenter: parent.verticalCenter
                radius: 16
                color: "#05040A"
                border.width: 1
                border.color: "#2A2640"
                opacity: s.enter
                transform: Translate { x: (1 - s.enter) * 60 }
                Image {
                    anchors.fill: parent
                    anchors.margins: 8
                    source: s.image ? "slides/" + s.image : ""
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    mipmap: true
                }
            }
        }
    }

    QuantumSlide {
        icon: "rocket_launch"
        heading: "Bienvenido a Quantum"
        body: "En unos minutos tendrás un sistema rápido, bonito y listo para jugar. Como Windows, pero mejor. Hecho con la comunidad."
    }
    QuantumSlide {
        icon: "stadia_controller"
        heading: "Fotón: todos tus juegos"
        body: "Steam, Epic, GOG y Amazon juntos en una biblioteca, con modo juego, FPS en pantalla y Proton-GE con un clic."
        image: "foton.jpg"
    }
    QuantumSlide {
        icon: "storefront"
        heading: "Quantum Store"
        body: "Miles de apps de Arch, Flathub y la comunidad. Buscas, haces clic y listo: sin terminal."
        image: "store.jpg"
    }
    QuantumSlide {
        icon: "palette"
        heading: "Tu estilo, al instante"
        body: "Modo claro u oscuro, fondos y colores que se adaptan a tu fondo de pantalla en todo el sistema."
        image: "colores.jpg"
    }
    QuantumSlide {
        icon: "grid_view"
        heading: "Fácil si vienes de Windows"
        body: "Menú Inicio, barra de tareas, Alt+Tab, Win+E y ventanas en mosaico. Y los .exe se abren con doble clic."
        image: "inicio.jpg"
    }
    QuantumSlide {
        icon: "history"
        heading: "Seguro ante errores"
        body: "Antes de cada actualización se guarda una copia del sistema. Si algo falla, eliges la anterior al arrancar."
        image: "mosaico.jpg"
    }
    QuantumSlide {
        icon: "favorite"
        heading: "Hecho con la comunidad"
        body: "Sigue el proyecto y propone ideas en TikTok (@quantum.os) y en quantumlinux-arch.github.io"
    }
}
