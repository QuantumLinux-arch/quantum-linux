/* Instalador de Quantum Linux: paso «Tus apps».
   Tarjetas para elegir navegador, oficina, emuladores y juegos/chat (todo de Flathub)
   y si se instalan ahora (durante la instalación) o al primer inicio.
   Lo elegido se guarda en Global Storage: quantumApps (ids separados por espacio),
   quantumAppNames (nombres separados por «;») y quantumAppsWhen (now | later).
   Juegos gratis (sección aparte): siempre se instalan después, al primer inicio:
   quantumGames (Flathub: ids;nombres) y quantumSteamGames (id del catálogo de Fotón;nombre).
   Lo lee el job quantumapps.
   SPDX-License-Identifier: GPL-3.0-or-later
*/
import io.calamares.core 1.0

import QtQuick 2.15

Rectangle {
    id: page
    color: "#13121C"

    // ----------------------------------------------------------- catálogo
    // single: solo se puede elegir una (o ninguna) en la sección
    readonly property var sections: [
        { t: "Navegador", h: "Firefox ya viene incluido. Agrega otro si lo prefieres.", single: false, apps: [
            { id: "org.mozilla.firefox", n: "Firefox", d: "Ya incluido", fixed: true },
            { id: "com.google.Chrome", n: "Google Chrome", d: "El de Google" },
            { id: "com.brave.Browser", n: "Brave", d: "Bloquea anuncios" },
            { id: "com.opera.Opera", n: "Opera", d: "Con VPN gratis" },
            { id: "com.vivaldi.Vivaldi", n: "Vivaldi", d: "Muy personalizable" },
            { id: "app.zen_browser.zen", n: "Zen", d: "Moderno y minimal" },
            { id: "org.chromium.Chromium", n: "Chromium", d: "Chrome sin Google" },
            { id: "io.gitlab.librewolf-community", n: "LibreWolf", d: "Máxima privacidad" } ] },
        { t: "Oficina", h: "Para documentos, hojas de cálculo y presentaciones (abren archivos de Office).", single: true, apps: [
            { id: "org.libreoffice.LibreOffice", n: "LibreOffice", d: "La suite libre más completa" },
            { id: "org.onlyoffice.desktopeditors", n: "OnlyOffice", d: "Se ve como Microsoft Office" } ] },
        { t: "Asistente con IA", h: "Una IA que funciona en tu PC (sin internet ni cuentas). Ábrela con Super + H. Elige según tu equipo.", single: true, apps: [
            { id: "ai:gemma3:1b", ic: "quantum-assistant", n: "Ligero", d: "0,8 GB · 4 GB de RAM", ai: "gemma3:1b" },
            { id: "ai:gemma3:4b", ic: "quantum-assistant", n: "Equilibrado", d: "3,4 GB · 8 GB de RAM", ai: "gemma3:4b" },
            { id: "ai:qwen3:8b", ic: "quantum-assistant", n: "Avanzado", d: "5,2 GB · 16 GB de RAM", ai: "qwen3:8b" } ] },
        { t: "Emuladores", h: "Juega tus juegos de consola. Los juegos (ROMs) y BIOS no vienen incluidos.", single: false, apps: [
            { id: "org.DolphinEmu.dolphin-emu", n: "Dolphin", d: "Wii y GameCube" },
            { id: "io.github.ryubing.Ryujinx", n: "Ryujinx", d: "Nintendo Switch" },
            { id: "info.cemu.Cemu", n: "Cemu", d: "Wii U" },
            { id: "org.azahar_emu.Azahar", n: "Azahar", d: "Nintendo 3DS" },
            { id: "net.kuribo64.melonDS", n: "melonDS", d: "Nintendo DS" },
            { id: "io.mgba.mGBA", n: "mGBA", d: "Game Boy Advance" },
            { id: "net.pcsx2.PCSX2", n: "PCSX2", d: "PlayStation 2" },
            { id: "net.rpcs3.RPCS3", n: "RPCS3", d: "PlayStation 3" },
            { id: "org.duckstation.DuckStation", n: "DuckStation", d: "PlayStation 1" },
            { id: "org.ppsspp.PPSSPP", n: "PPSSPP", d: "PSP" },
            { id: "app.xemu.xemu", n: "xemu", d: "Xbox clásica" },
            { id: "org.libretro.RetroArch", n: "RetroArch", d: "Todas las retro" } ] },
        { t: "Juegos y chat", h: "Steam ya viene incluido. Suma tiendas, chat y más.", single: false, apps: [
            { id: "com.heroicgameslauncher.hgl", n: "Heroic", d: "Epic, GOG y Amazon" },
            { id: "net.lutris.Lutris", n: "Lutris", d: "Battle.net, EA y más" },
            { id: "net.davidotek.pupgui2", n: "ProtonUp-Qt", d: "Más versiones de Proton" },
            { id: "com.discordapp.Discord", n: "Discord", d: "Chat con tus amigos" },
            { id: "org.telegram.desktop", n: "Telegram", d: "Mensajería" },
            { id: "com.spotify.Client", n: "Spotify", d: "Música" },
            { id: "com.obsproject.Studio", n: "OBS Studio", d: "Graba y transmite" },
            { id: "org.videolan.VLC", n: "VLC", d: "Reproduce cualquier video" } ] }
    ]

    // Juegos gratis y legales del catálogo de Fotón (mismos ids). Se instalan al primer
    // inicio para no alargar la instalación: los de Flathub solos, los de Steam desde Fotón.
    readonly property var games: [
        { id: "roblox", ref: "org.vinegarhq.Sober", n: "Roblox", k: "flathub" },
        { id: "minecraft", ref: "org.prismlauncher.PrismLauncher", n: "Minecraft (Java)", k: "flathub" },
        { id: "cs2", ref: "730", n: "Counter-Strike 2", k: "steam" },
        { id: "marvel-rivals", ref: "2767030", n: "Marvel Rivals", k: "steam" },
        { id: "efootball", ref: "1665460", n: "eFootball", k: "steam" },
        { id: "warframe", ref: "230410", n: "Warframe", k: "steam" },
        { id: "dota2", ref: "570", n: "Dota 2", k: "steam" },
        { id: "overwatch", ref: "2357570", n: "Overwatch 2", k: "steam" },
        { id: "supertuxkart", ref: "net.supertuxkart.SuperTuxKart", n: "SuperTuxKart", k: "flathub", low: true },
        { id: "brawlhalla", ref: "291550", n: "Brawlhalla", k: "steam", low: true },
        { id: "stumble-guys", ref: "1677740", n: "Stumble Guys", k: "steam", low: true },
        { id: "osu", ref: "sh.ppy.osu", n: "osu!", k: "flathub", low: true },
        { id: "tf2", ref: "440", n: "Team Fortress 2", k: "steam", low: true },
        { id: "srb2kart", ref: "org.srb2.SRB2Kart", n: "Sonic Robo Blast 2 Kart", k: "flathub", low: true },
        { id: "master-duel", ref: "1449850", n: "Yu-Gi-Oh! Master Duel", k: "steam", low: true },
        { id: "luanti", ref: "org.luanti.luanti", n: "Luanti", k: "flathub", low: true },
        { id: "zeroad", ref: "com.play0ad.zeroad", n: "0 A.D.", k: "flathub" },
        { id: "mindustry", ref: "com.github.Anuken.Mindustry", n: "Mindustry", k: "flathub", low: true }
    ]
    property var chosenGames: ({})     // id -> true
    readonly property var pickedGames: games.filter(g => chosenGames[g.id])
    function toggleGame(g) {
        const c = Object.assign({}, chosenGames);
        if (c[g.id]) delete c[g.id]; else c[g.id] = true;
        chosenGames = c;
    }

    property var chosen: ({})          // id -> true
    // internet: se vuelve a comprobar cada pocos segundos por si se conectan ahora.
    // La prueba es asíncrona y con tiempo máximo: Network.checkHasInternet() bloqueaba
    // la ventana entera mientras esperaba la red (con internet lento parecía colgado).
    property bool online: Network.hasInternet
    property string when: online ? "now" : "later"
    onOnlineChanged: if (!online && when === "now") when = "later"
    property var probeXhr: null
    function probe() {
        if (probeXhr) return;                       // ya hay una prueba en curso
        const x = new XMLHttpRequest();
        probeXhr = x;
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE || page.probeXhr !== x) return;
            page.probeXhr = null;
            probeLimit.stop();
            page.online = x.status > 0 && x.status < 500;
        };
        x.open("HEAD", "https://archlinux.org/");
        x.send();
        probeLimit.restart();
    }
    Timer {
        id: probeLimit
        interval: 5000
        onTriggered: {
            const x = page.probeXhr;
            page.probeXhr = null;
            page.online = false;
            if (x) x.abort();
        }
    }
    Timer {
        interval: 6000; repeat: true; triggeredOnStart: true; running: page.visible
        onTriggered: page.probe()
    }
    readonly property var picked: {
        const out = [];
        for (const s of sections) for (const a of s.apps) if (!a.fixed && chosen[a.id]) out.push(a);
        return out;
    }
    readonly property var apps: picked.filter(a => !a.ai)          // de Flathub
    readonly property string aiModel: (picked.find(a => a.ai) ?? {}).ai ?? ""

    function toggle(sec, app) {
        if (app.fixed) return;
        const c = Object.assign({}, chosen);
        if (sec.single && !c[app.id]) for (const a of sec.apps) delete c[a.id];
        if (c[app.id]) delete c[app.id]; else c[app.id] = true;
        chosen = c;
    }
    function save() {
        Global.insert("quantumApps", apps.map(a => a.id).join(" "));
        Global.insert("quantumAppNames", apps.map(a => a.n).join(";"));
        Global.insert("quantumAI", aiModel);
        Global.insert("quantumAppsWhen", picked.length ? when : "none");
        const fh = pickedGames.filter(g => g.k === "flathub"), st = pickedGames.filter(g => g.k === "steam");
        Global.insert("quantumGames", fh.map(g => g.ref + "\t" + g.n).join(";"));
        Global.insert("quantumSteamGames", st.map(g => g.id + "\t" + g.n).join(";"));
    }
    onPickedChanged: save()
    onPickedGamesChanged: save()
    onWhenChanged: save()
    Component.onCompleted: save()

    // --------------------------------------------------------------- vista
    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 0
        contentHeight: col.height + 120
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            x: 36; y: 28
            width: flick.width - 72
            spacing: 22

            // encabezado
            Column {
                spacing: 6
                Text { text: "Tus apps"; color: "#FFFFFF"; font.family: "Inter"; font.pixelSize: 30; font.weight: Font.ExtraBold }
                Text {
                    width: col.width
                    text: "Elige lo que quieres tener listo desde el primer día. Todo es gratis y puedes cambiarlo después en Quantum Store."
                    color: "#B9B3D6"; font.family: "Inter"; font.pixelSize: 14; wrapMode: Text.WordWrap
                }
            }

            // ¿cuándo?
            Row {
                spacing: 14
                Repeater {
                    model: [
                        { v: "now", t: "Durante la instalación", h: page.online ? "Todo queda listo al terminar. Puede tardar varios minutos según tu internet." : "Necesita internet: conéctate para activarlo.", i: "download" },
                        { v: "later", t: "Al primer inicio", h: "La instalación es más rápida y se descargan al entrar.", i: "schedule" }
                    ]
                    Rectangle {
                        id: wc
                        required property var modelData
                        readonly property bool on: page.when === modelData.v
                        readonly property bool ok: modelData.v !== "now" || page.online
                        width: (col.width - 14) / 2; height: 78; radius: 18
                        color: on ? "#2A2550" : wArea.containsMouse && ok ? "#24232E" : "#1B1A24"
                        border.width: on ? 2 : 1
                        border.color: on ? "#8F7BFF" : "#2E2C3A"
                        opacity: ok ? 1 : 0.45
                        Rectangle {
                            x: 16; anchors.verticalCenter: parent.verticalCenter
                            width: 22; height: 22; radius: 11
                            color: "transparent"; border.width: 2; border.color: wc.on ? "#8F7BFF" : "#5A5770"
                            Rectangle { anchors.centerIn: parent; width: 10; height: 10; radius: 5; color: "#8F7BFF"; visible: wc.on }
                        }
                        Column {
                            x: 52; anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 68; spacing: 3
                            Text { text: wc.modelData.t; color: "#FFFFFF"; font.family: "Inter"; font.pixelSize: 15; font.weight: Font.Bold }
                            Text { width: parent.width; text: wc.modelData.h; color: "#9C95B8"; font.family: "Inter"; font.pixelSize: 12; wrapMode: Text.WordWrap }
                        }
                        MouseArea { id: wArea; anchors.fill: parent; hoverEnabled: true; enabled: wc.ok; cursorShape: Qt.PointingHandCursor; onClicked: page.when = wc.modelData.v }
                    }
                }
            }

            // secciones
            Repeater {
                model: page.sections
                Column {
                    id: sec
                    required property var modelData
                    width: col.width
                    spacing: 12
                    Column {
                        spacing: 2
                        Row {
                            spacing: 10
                            Text { text: sec.modelData.t; color: "#FFFFFF"; font.family: "Inter"; font.pixelSize: 18; font.weight: Font.Bold }
                            Rectangle {
                                visible: sec.modelData.single
                                anchors.verticalCenter: parent.verticalCenter
                                width: oneT.implicitWidth + 16; height: 20; radius: 10; color: "#2A2550"
                                Text { id: oneT; anchors.centerIn: parent; text: "elige una"; color: "#C5C0FF"; font.family: "Inter"; font.pixelSize: 11; font.weight: Font.DemiBold }
                            }
                        }
                        Text { width: col.width; text: sec.modelData.h; color: "#9C95B8"; font.family: "Inter"; font.pixelSize: 12; wrapMode: Text.WordWrap }
                    }
                    Grid {
                        columns: Math.max(2, Math.floor((col.width + 12) / 250))
                        spacing: 12
                        Repeater {
                            model: sec.modelData.apps
                            Rectangle {
                                id: card
                                required property var modelData
                                readonly property bool on: modelData.fixed || !!page.chosen[modelData.id]
                                width: (col.width - 12 * (parent.columns - 1)) / parent.columns
                                height: 76; radius: 16
                                color: on ? "#262145" : cArea.containsMouse ? "#22212C" : "#1B1A24"
                                border.width: on ? 2 : 1
                                border.color: on ? (modelData.fixed ? "#4A4570" : "#8F7BFF") : "#2A2836"
                                scale: cArea.pressed ? 0.97 : 1
                                Behavior on scale { NumberAnimation { duration: 90 } }
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Image {
                                    x: 12; anchors.verticalCenter: parent.verticalCenter
                                    width: 44; height: 44
                                    source: Qt.resolvedUrl("apps/" + (card.modelData.ic ?? card.modelData.id) + ".png")
                                    sourceSize: Qt.size(88, 88)
                                    smooth: true; mipmap: true
                                }
                                Column {
                                    x: 66; anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 66 - 34
                                    spacing: 2
                                    Text { width: parent.width; text: card.modelData.n; color: "#FFFFFF"; font.family: "Inter"; font.pixelSize: 14; font.weight: Font.Bold; elide: Text.ElideRight }
                                    Text { width: parent.width; text: card.modelData.d; color: "#9C95B8"; font.family: "Inter"; font.pixelSize: 11; elide: Text.ElideRight }
                                }
                                // marca
                                Rectangle {
                                    anchors.right: parent.right; anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 22; height: 22; radius: 11
                                    color: card.on ? (card.modelData.fixed ? "#4A4570" : "#6A5CFF") : "transparent"
                                    border.width: card.on ? 0 : 2; border.color: "#4A4766"
                                    Text { anchors.centerIn: parent; visible: card.on; text: "✓"; color: "white"; font.pixelSize: 13; font.weight: Font.Black }
                                }
                                MouseArea {
                                    id: cArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: card.modelData.fixed ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: page.toggle(sec.modelData, card.modelData)
                                }
                            }
                        }
                    }
                }
            }
            // juegos gratis
            Column {
                width: col.width
                spacing: 12
                Column {
                    spacing: 2
                    Row {
                        spacing: 10
                        Text { text: "Juegos gratis"; color: "#FFFFFF"; font.family: "Inter"; font.pixelSize: 18; font.weight: Font.Bold }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: laterT.implicitWidth + 16; height: 20; radius: 10; color: "#2A2550"
                            Text { id: laterT; anchors.centerIn: parent; text: "se instalan al primer inicio"; color: "#C5C0FF"; font.family: "Inter"; font.pixelSize: 11; font.weight: Font.DemiBold }
                        }
                    }
                    Text {
                        width: col.width
                        text: "Gratis y legales. Los encuentras en Fotón, la app de juegos de Quantum. Los de Steam te pedirán iniciar sesión (la cuenta es gratis). La hoja verde indica que corren en PCs modestas."
                        color: "#9C95B8"; font.family: "Inter"; font.pixelSize: 12; wrapMode: Text.WordWrap
                    }
                }
                Grid {
                    id: gameGrid
                    columns: Math.max(2, Math.floor((col.width + 12) / 230))
                    spacing: 12
                    Repeater {
                        model: page.games
                        Rectangle {
                            id: gcard
                            required property var modelData
                            readonly property bool on: !!page.chosenGames[modelData.id]
                            width: (col.width - 12 * (gameGrid.columns - 1)) / gameGrid.columns
                            height: width * 215 / 460 + 34
                            radius: 14
                            color: on ? "#262145" : gArea.containsMouse ? "#22212C" : "#1B1A24"
                            border.width: on ? 2 : 1
                            border.color: on ? "#8F7BFF" : "#2A2836"
                            scale: gArea.pressed ? 0.97 : gArea.containsMouse ? 1.02 : 1
                            Behavior on scale { NumberAnimation { duration: 120 } }
                            Rectangle {
                                id: imgBox
                                x: 4; y: 4
                                width: parent.width - 8; height: (parent.width - 8) * 215 / 460
                                radius: 11
                                clip: true
                                color: "#0D0B14"
                                Image {
                                    anchors.fill: parent
                                    source: Qt.resolvedUrl("games/" + gcard.modelData.id + ".jpg")
                                    sourceSize: Qt.size(460, 215)
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true; mipmap: true
                                }
                                Rectangle {
                                    anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 6
                                    width: srcT.implicitWidth + 12; height: 18; radius: 9
                                    color: Qt.rgba(0, 0, 0, 0.6)
                                    Text { id: srcT; anchors.centerIn: parent; text: gcard.modelData.k === "steam" ? "Steam" : "Linux"; color: "white"; font.family: "Inter"; font.pixelSize: 10; font.weight: Font.Bold }
                                }
                                Rectangle {
                                    visible: !!gcard.modelData.low
                                    anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 6
                                    width: 18; height: 18; radius: 9
                                    color: "#22B573"
                                    // hoja: PC modesta
                                    Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; rotation: 45; color: "white"; antialiasing: true }
                                }
                            }
                            Text {
                                x: 10; anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                                width: parent.width - 44
                                text: gcard.modelData.n; color: "#FFFFFF"; font.family: "Inter"; font.pixelSize: 13; font.weight: Font.Bold; elide: Text.ElideRight
                            }
                            Rectangle {
                                anchors.right: parent.right; anchors.rightMargin: 9
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 7
                                width: 20; height: 20; radius: 10
                                color: gcard.on ? "#6A5CFF" : "transparent"
                                border.width: gcard.on ? 0 : 2; border.color: "#4A4766"
                                Text { anchors.centerIn: parent; visible: gcard.on; text: "✓"; color: "white"; font.pixelSize: 12; font.weight: Font.Black }
                            }
                            MouseArea { id: gArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.toggleGame(gcard.modelData) }
                        }
                    }
                }
            }
        }
    }

    // resumen fijo abajo
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 62
        color: "#16151F"
        Rectangle { width: parent.width; height: 1; color: "#2A2836" }
        Row {
            x: 36; anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 34; height: 34; radius: 17
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#4FD8FF" }
                    GradientStop { position: 0.5; color: "#6A5CFF" }
                    GradientStop { position: 1; color: "#B14DFF" }
                }
                Text { anchors.centerIn: parent; text: page.picked.length + page.pickedGames.length; color: "white"; font.family: "Inter"; font.pixelSize: 15; font.weight: Font.Black }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: page.width - 140
                text: (page.picked.length === 0 ? "Sin apps extra"
                    : (page.picked.length === 1 ? "1 app" : page.picked.length + " apps") + " " +
                      (page.when === "now" ? "durante la instalación" : "al primer inicio"))
                    + (page.pickedGames.length ? " · " + (page.pickedGames.length === 1 ? "1 juego" : page.pickedGames.length + " juegos") + " al primer inicio" : "")
                    + (page.picked.length + page.pickedGames.length === 0 ? ": puedes instalarlas después desde Quantum Store y Fotón." : "")
                color: "#E4E0EE"; font.family: "Inter"; font.pixelSize: 13; font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }
    }
}
