import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs.services
import qs.components

// Isla dinámica (Caelestial): una píldora arriba al centro que cambia de forma según lo que pasa.
// Prioridad: volumen o brillo > modo juego > lo que instala Quarki > la música que suena.
// Con la música, al pasar el mouse se agranda con el título y los controles.
Scope {
    id: island
    // para videos: qs -c quantum ipc call island demo volume 0.6 (no toca el volumen real)
    property real demoLevel: -1
    signal demoFlash(string kind)
    // Colores de la carátula: los 3 más vivos, un poco más brillantes para que luzcan
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? null
    ColorQuantizer {
        id: quant
        source: island.player?.trackArtUrl ?? ""
        depth: 3
        rescaleSize: 64
    }
    readonly property var picked: {
        const cs = (quant.colors ?? []).slice();
        if (!island.player || !cs.length) return [];
        cs.sort((a, b) => (b.hsvSaturation * b.hsvValue) - (a.hsvSaturation * a.hsvValue));
        return cs.slice(0, 3).map(c => Qt.hsva(c.hsvHue < 0 ? 0.75 : c.hsvHue, Math.min(1, Math.max(0.45, c.hsvSaturation * 1.2)),
                                               Math.min(1, Math.max(0.75, c.hsvValue * 1.25)), 1));
    }
    onPickedChanged: Shell.musicColors = picked

    IpcHandler {
        target: "island"
        function demo(kind: string, level: real): void { island.demoLevel = level; island.demoFlash(kind); }
    }

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
        implicitWidth: 640
        implicitHeight: 190
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
        Connections { target: island; function onDemoFlash(kind) { win.show(kind); } }
        readonly property real level: island.demoLevel >= 0 ? island.demoLevel
            : mode === "brightness" ? Brightness.value : (Audio.muted ? 0 : Audio.volume)

        // la notificación que se muestra (la más nueva); se va sola a los 5 s o al tocarla
        readonly property var notif: enabled_ && !Shell.controlCenterOpen ? (Notifs.popups[0] ?? null) : null
        Timer {
            running: !!win.notif && !win.hovered
            interval: 5000
            onTriggered: if (win.notif) Notifs.dismissPopup(win.notif)
        }

        readonly property string mode: flash !== "" ? flash
            : notif ? "notif"
            : Quarki.working ? "job"
            : player ? (hovered ? "musicBig" : "music")
            : "idle"
        // tamaño de cada forma
        readonly property size target: ({
            idle: Qt.size(118, 34), music: Qt.size(250, 38), musicBig: Qt.size(430, 112),
            volume: Qt.size(320, 46), brightness: Qt.size(320, 46), game: Qt.size(300, 46), job: Qt.size(340, 46),
            notif: Qt.size(440, (notif?.actions ?? []).filter(a => a.identifier !== "default").length ? 118 : 78)
        })[mode] ?? Qt.size(118, 34)

        // ------------------------------------------------ cómo se deforma
        // El tamaño sigue a un resorte; la velocidad del cambio aplasta la píldora (se estira a lo
        // ancho y se afina de alto, y rebota), como una gota de gelatina.
        property real lastW: pill.width
        property real lastH: pill.height
        property real squash: 0                 // + se estira a lo ancho, - a lo alto
        property real energy: 0                 // 0..1: qué tan fuerte se está transformando
        FrameAnimation {
            running: win.visible
            onTriggered: {
                const dt = Math.max(0.008, frameTime);
                const vw = (pill.width - win.lastW) / dt, vh = (pill.height - win.lastH) / dt;
                win.lastW = pill.width; win.lastH = pill.height;
                const target = Math.max(-0.16, Math.min(0.16, (vw - vh * 1.6) / 3200));
                win.squash += (target - win.squash) * Math.min(1, dt * 14);
                const e = Math.min(1, (Math.abs(vw) + Math.abs(vh)) / 1400);
                win.energy = Math.max(e, win.energy - dt * 1.6);
            }
        }
        readonly property bool rich: mode === "musicBig" || mode === "game"

        // resplandor con los colores de Quantum, detrás de la píldora
        Item {
            id: glowSrc
            anchors.centerIn: pill
            width: pill.width + 10; height: pill.height + 10
            visible: false
            layer.enabled: true
            Rectangle {
                anchors.fill: parent
                radius: Math.min(height / 2, 34)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Shell.tint(0, Theme.brandCyan); Behavior on color { ColorAnimation { duration: 900 } } }
                    GradientStop { position: 0.5; color: Shell.tint(1, Theme.brandIndigo); Behavior on color { ColorAnimation { duration: 900 } } }
                    GradientStop { position: 1; color: Shell.tint(2, Theme.brandViolet); Behavior on color { ColorAnimation { duration: 900 } } }
                }
            }
        }
        MultiEffect {
            anchors.fill: glowSrc
            source: glowSrc
            blurEnabled: true
            blurMax: 48
            blur: 1
            transform: Scale { origin.x: glowSrc.width / 2; origin.y: 0; xScale: 1 + win.squash * 0.35; yScale: 1 - win.squash }
            opacity: Math.min(0.9, (win.rich ? 0.42 : win.mode === "idle" ? 0 : win.mode === "music" ? 0.26 : 0.16) + win.energy * 0.75)
            Behavior on opacity { NumberAnimation { duration: 260 } }
        }

        Rectangle {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            width: win.target.width
            height: win.target.height
            radius: Math.min(height / 2, 30)
            color: "#0B0A12"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08 + 0.25 * win.energy)
            clip: true
            antialiasing: true
            Behavior on width { SpringAnimation { spring: 3.4; damping: 0.24; epsilon: 0.25 } }
            Behavior on height { SpringAnimation { spring: 3.8; damping: 0.28; epsilon: 0.25 } }
            transform: Scale {
                origin.x: pill.width / 2
                origin.y: 0
                xScale: 1 + win.squash * 0.35
                yScale: 1 - win.squash
            }
            // brillo superior con los colores de Quantum, que se enciende al transformarse
            Rectangle {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 2 * Math.min(parent.radius, 24)
                height: 1.5
                opacity: 0.25 + 0.75 * win.energy + (win.rich ? 0.3 : 0)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.3; color: Shell.tint(0, Theme.brandCyan) }
                    GradientStop { position: 0.7; color: Shell.tint(2, Theme.brandViolet) }
                    GradientStop { position: 1; color: "transparent" }
                }
            }

            // debajo de los controles: detecta el mouse y abre el panel al tocarla en reposo
            MouseArea {
                anchors.fill: parent
                z: -1
                hoverEnabled: true
                onContainsMouseChanged: win.hovered = containsMouse
                onClicked: if (win.mode === "idle") Shell.toggleDashboard()
            }

            // Cada contenido: lo anterior se va rápido y lo nuevo entra cuando la forma ya cambió,
            // subiendo un poco y con un fundido (nunca se ven dos encimados).
            component Face: Item {
                id: face
                property string when: ""
                readonly property bool on: win.mode === when
                anchors.fill: parent
                opacity: 0
                scale: 0.94
                visible: opacity > 0.01
                transform: Translate { id: lift; y: 6 }
                states: State {
                    when: face.on
                    PropertyChanges { face.opacity: 1; face.scale: 1; lift.y: 0 }
                }
                transitions: [
                    Transition {
                        to: ""
                        NumberAnimation { properties: "opacity,scale,y"; duration: 110; easing.type: Easing.InCubic }
                    },
                    Transition {
                        from: ""
                        SequentialAnimation {
                            PauseAnimation { duration: 150 }
                            ParallelAnimation {
                                NumberAnimation { property: "opacity"; duration: 260; easing.type: Easing.OutCubic }
                                NumberAnimation { property: "scale"; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                                NumberAnimation { target: lift; property: "y"; duration: 380; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                ]
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
                            width: parent.width * win.level
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
                        text: Math.round(100 * win.level)
                        color: "white"; font.weight: Font.Bold; font.pixelSize: 13
                    }
                }
            }

            // ------------------------------------------------------ notificación
            Face {
                when: "notif"
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const n = win.notif;
                        if (!n) return;
                        const def = n.actions.find(a => a.identifier === "default");
                        if (def) def.invoke();
                        Notifs.dismissPopup(n);
                    }
                }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Rectangle {
                            Layout.preferredWidth: 46; Layout.preferredHeight: 46; radius: 14
                            color: Qt.rgba(1, 1, 1, 0.08)
                            Image {
                                anchors.fill: parent; anchors.margins: 6
                                source: win.notif ? (win.notif.appIcon ? Quickshell.iconPath(win.notif.appIcon, true) : win.notif.image) : ""
                                sourceSize: Qt.size(68, 68)
                                fillMode: Image.PreserveAspectFit
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Txt {
                                Layout.fillWidth: true
                                text: win.notif ? (win.notif.summary || win.notif.appName) : ""
                                color: "white"; font.weight: Font.Bold; elide: Text.ElideRight
                            }
                            Txt {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: win.notif ? win.notif.body.replace(/<[^>]+>/g, "").replace(/\s+/g, " ") : ""
                                color: Qt.rgba(1, 1, 1, 0.65); font.pixelSize: 12; elide: Text.ElideRight
                            }
                        }
                        Txt { text: win.notif?.appName ?? ""; color: Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 11 }
                    }
                    Row {
                        spacing: 8
                        visible: actRep.count > 0
                        Repeater {
                            id: actRep
                            model: (win.notif?.actions ?? []).filter(a => a.identifier !== "default").slice(0, 3)
                            Rectangle {
                                required property var modelData
                                width: actT.implicitWidth + 26; height: 30; radius: 15
                                color: actArea.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.1)
                                Txt { id: actT; anchors.centerIn: parent; text: parent.modelData.text; color: "white"; font.pixelSize: 12; font.weight: Font.DemiBold }
                                MouseArea {
                                    id: actArea
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { const n = win.notif; parent.modelData.invoke(); if (n) Notifs.dismissPopup(n); }
                                }
                            }
                        }
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
            // carátula con las esquinas redondeadas de verdad (clip solo recorta en rectángulo)
            component Art: Item {
                id: art
                property real radius: 9
                Rectangle { anchors.fill: parent; radius: art.radius; color: Qt.rgba(1, 1, 1, 0.08) }
                Image {
                    id: artImg
                    anchors.fill: parent
                    source: win.player?.trackArtUrl ?? ""
                    sourceSize: Qt.size(art.width * 2, art.height * 2)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                    layer.enabled: true
                }
                Rectangle { id: artMask; anchors.fill: parent; radius: art.radius; visible: false; layer.enabled: true; layer.smooth: true }
                MultiEffect {
                    anchors.fill: parent
                    source: artImg
                    maskEnabled: true
                    maskSource: artMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }
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
                        color: Shell.tint(index, ["#4FD8FF", "#6A5CFF", "#B14DFF", "#4FD8FF"][index])
                        Behavior on color { ColorAnimation { duration: 900 } }
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
                    Art { Layout.preferredWidth: 82; Layout.preferredHeight: 82; radius: 18 }
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
}
