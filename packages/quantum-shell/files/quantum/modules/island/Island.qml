import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs.services
import qs.components

// Isla dinámica (Caelestial): una píldora arriba al centro que cambia de forma según lo que pasa.
// Prioridad: volumen o brillo > modo juego > lo que instala Quarki > la música que suena.
// Con la música, al pasar el mouse se agranda con el título y los controles.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property ShellScreen modelData
        screen: modelData

        readonly property bool enabled_: !Serp.on && Settings.layout.topBar.island
        visible: enabled_ && !(Wm.active?.fullscreen ?? false)
        // sobre la barra de arriba (si no, la barra se queda con el mouse)
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quantum-island"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true }
        margins.top: Settings.layout.style === "single" ? 8 : (Settings.layout.topBar.floating ? 9 : 5)
        implicitWidth: 560
        implicitHeight: 140
        color: "transparent"
        // solo la píldora recibe el mouse (lo transparente deja pasar los clics)
        mask: Region { item: pill }

        // ------------------------------------------------------------ estado
        readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? null
        property string flash: ""                  // volume | brightness | game
        property bool hovered: false
        Timer { id: flashTimer; interval: 1800; onTriggered: win.flash = "" }
        function show(k: string): void { flash = k; flashTimer.restart(); }
        Connections { target: Audio; function onChanged() { if (win.enabled_) win.show("volume"); } }
        Connections { target: Brightness; function onChanged() { if (win.enabled_) win.show("brightness"); } }
        Connections { target: Shell; function onGameModeChanged() { if (win.enabled_) win.show("game"); } }

        readonly property string mode: flash !== "" ? flash
            : Quarki.working ? "job"
            : player ? (hovered ? "musicBig" : "music")
            : "idle"
        // tamaño de cada forma
        readonly property size target: ({
            idle: Qt.size(118, 34), music: Qt.size(250, 38), musicBig: Qt.size(430, 112),
            volume: Qt.size(320, 46), brightness: Qt.size(320, 46), game: Qt.size(300, 46), job: Qt.size(340, 46)
        })[mode] ?? Qt.size(118, 34)

        Rectangle {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            width: win.target.width
            height: win.target.height
            radius: Math.min(height / 2, 30)
            color: "#0B0A12"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)
            clip: true
            Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
            Behavior on height { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

            // debajo de los controles: detecta el mouse y abre el panel al tocarla en reposo
            MouseArea {
                anchors.fill: parent
                z: -1
                hoverEnabled: true
                onContainsMouseChanged: win.hovered = containsMouse
                onClicked: if (win.mode === "idle") Shell.toggleDashboard()
            }

            // cada contenido aparece con un fundido cuando su forma está lista
            component Face: Item {
                property string when: ""
                anchors.fill: parent
                opacity: win.mode === when ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 220 } }
            }

            // ------------------------------------------------------- en reposo
            Face {
                when: "idle"
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18; height: 18
                        source: Quickshell.shellDir + "/assets/quantum-mark.svg"
                        sourceSize: Qt.size(36, 36)
                    }
                    Txt { anchors.verticalCenter: parent.verticalCenter; text: Qt.formatTime(clock.date, "HH:mm"); color: "white"; font.weight: Font.Bold; font.pixelSize: 13 }
                }
            }

            // --------------------------------------------- volumen y brillo
            Face {
                when: win.mode === "volume" || win.mode === "brightness" ? win.mode : "-"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18; anchors.rightMargin: 20
                    spacing: 12
                    Icon {
                        text: win.mode === "brightness" ? "light_mode" : Audio.icon
                        size: 20; fill: 1; color: "white"
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6; radius: 3
                        color: Qt.rgba(1, 1, 1, 0.14)
                        Rectangle {
                            width: parent.width * (win.mode === "brightness" ? Brightness.value : (Audio.muted ? 0 : Audio.volume))
                            height: parent.height; radius: 3
                            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Theme.brandCyan }
                                GradientStop { position: 0.5; color: Theme.brandIndigo }
                                GradientStop { position: 1; color: Theme.brandViolet }
                            }
                        }
                    }
                    Txt {
                        Layout.preferredWidth: 34
                        horizontalAlignment: Text.AlignRight
                        text: Math.round(100 * (win.mode === "brightness" ? Brightness.value : (Audio.muted ? 0 : Audio.volume)))
                        color: "white"; font.weight: Font.Bold; font.pixelSize: 13
                    }
                }
            }

            // ------------------------------------------------------ modo juego
            Face {
                when: "game"
                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    Icon { anchors.verticalCenter: parent.verticalCenter; text: "sports_esports"; size: 22; fill: 1; color: Shell.gameMode ? "#7FE3FF" : "white" }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Shell.gameMode ? "Modo juego activado" : "Modo juego desactivado"
                        color: "white"; font.weight: Font.Bold
                    }
                }
            }

            // -------------------------------------------- Quarki instalando algo
            Face {
                when: "job"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8; anchors.rightMargin: 18
                    spacing: 8
                    Mascot { Layout.preferredWidth: 38; Layout.preferredHeight: 38; mood: "work"; showZ: false }
                    Txt {
                        Layout.fillWidth: true
                        text: (Quarki.jobKind === "remove" ? "Desinstalando " : "Instalando ") + Quarki.jobName
                        color: "white"; font.weight: Font.DemiBold; elide: Text.ElideRight
                    }
                    // puntitos que avanzan
                    Row {
                        spacing: 4
                        Repeater {
                            model: 3
                            Rectangle {
                                required property int index
                                width: 6; height: 6; radius: 3; color: "#7FE3FF"
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    PauseAnimation { duration: index * 160 }
                                    NumberAnimation { from: 0.25; to: 1; duration: 320 }
                                    NumberAnimation { from: 1; to: 0.25; duration: 320 }
                                    PauseAnimation { duration: (2 - index) * 160 }
                                }
                            }
                        }
                    }
                }
            }

            // ---------------------------------------------- música (pequeña)
            component Art: Rectangle {
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.08)
                clip: true
                Image { anchors.fill: parent; source: win.player?.trackArtUrl ?? ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                Icon { anchors.centerIn: parent; visible: !(win.player?.trackArtUrl); text: "music_note"; size: 16; color: "white" }
            }
            component Bars: Row {
                spacing: 3
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3; radius: 1.5
                        color: ["#4FD8FF", "#6A5CFF", "#B14DFF", "#4FD8FF"][index]
                        height: 6 + 10 * Math.abs(Math.sin(waves.t * (3 + index * 1.3) + index))
                    }
                }
            }
            QtObject { id: waves; property real t: 0 }
            FrameAnimation { running: win.visible && !!win.player; onTriggered: waves.t += frameTime }

            Face {
                when: "music"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 5; anchors.rightMargin: 14
                    spacing: 10
                    Art { Layout.preferredWidth: 28; Layout.preferredHeight: 28 }
                    Txt {
                        Layout.fillWidth: true
                        text: win.player?.trackTitle || win.player?.identity || ""
                        color: "white"; font.weight: Font.DemiBold; font.pixelSize: 13; elide: Text.ElideRight
                    }
                    Bars {}
                }
            }

            // ------------------------------------------------- música (grande)
            Face {
                when: "musicBig"
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 14
                    Art { Layout.preferredWidth: 82; Layout.preferredHeight: 82; radius: 14 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Txt { Layout.fillWidth: true; text: win.player?.trackTitle || "Sin título"; color: "white"; font.weight: Font.Bold; font.pixelSize: 15; elide: Text.ElideRight }
                        Txt { Layout.fillWidth: true; text: win.player?.trackArtist || win.player?.identity || ""; color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 12; elide: Text.ElideRight }
                        Item { Layout.fillHeight: true }
                        RowLayout {
                            spacing: 6
                            Repeater {
                                model: [
                                    { i: "skip_previous", f: () => win.player?.previous() },
                                    { i: win.player?.isPlaying ? "pause" : "play_arrow", f: () => win.player?.togglePlaying(), big: true },
                                    { i: "skip_next", f: () => win.player?.next() },
                                ]
                                Rectangle {
                                    id: ctl
                                    required property var modelData
                                    implicitWidth: modelData.big ? 40 : 32; implicitHeight: implicitWidth; radius: implicitWidth / 2
                                    color: modelData.big ? "white" : ctlArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                                    Icon { anchors.centerIn: parent; text: ctl.modelData.i; size: ctl.modelData.big ? 24 : 22; fill: 1; color: ctl.modelData.big ? "#0B0A12" : "white" }
                                    MouseArea { id: ctlArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ctl.modelData.f() }
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Bars {}
                        }
                    }
                }
            }
        }
        SystemClock { id: clock; precision: SystemClock.Minutes }
    }
}
