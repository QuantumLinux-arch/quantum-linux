import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// Quarki (Super + H o clic en él en la barra): sale de la barra de tareas, te pregunta qué
// necesitas y lo hace. Las acciones delicadas (instalar, desinstalar, apagar) muestran una
// tarjeta para confirmar. Para conversar de cualquier tema usa la IA local (Ollama).
Scope {
    LazyLoader {
        active: Shell.aiOpen

        PanelWindow {
            id: win

            screen: Wm.screen
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quantum-panel"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            // centrado sobre la barra de tareas (o debajo de la barra de Serpantium)
            anchors { bottom: !Serp.on; top: Serp.on }
            margins { bottom: Math.round(56 * Theme.dockScale) + 22; top: 62 }
            implicitWidth: 470
            implicitHeight: Math.min(680, (screen?.height ?? 1080) - 170)
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            property real progress: 0
            NumberAnimation on progress { from: 0; to: 1; duration: Theme.animSlow + 80; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            property bool setup: false          // eligiendo el tamaño de la IA para instalar
            readonly property bool empty: Quarki.messages.length === 0

            // modelos para instalar la IA
            readonly property var tiers: [
                { m: "gemma3:1b", t: "Ligero", h: "0,8 GB · PCs con 4 GB de RAM" },
                { m: "gemma3:4b", t: "Equilibrado", h: "3,4 GB · 8 GB de RAM" },
                { m: "qwen3:8b", t: "Avanzado", h: "5,2 GB · 16 GB de RAM o buena gráfica" },
            ]
            property string tier: "gemma3:4b"

            Card {
                id: card
                anchors.fill: parent
                opacity: Math.min(1, win.progress * 1.4)
                transform: [
                    Scale {
                        origin.x: card.width / 2; origin.y: Serp.on ? 0 : card.height
                        xScale: 0.88 + 0.12 * win.progress; yScale: xScale
                    },
                    Translate { y: (1 - win.progress) * (Serp.on ? -30 : 30) }
                ]
                focus: true
                Keys.onEscapePressed: Shell.aiOpen = false

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    // ---------------------------------------------- encabezado
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Mascot {
                            visible: !win.empty || win.setup
                            Layout.preferredWidth: 54; Layout.preferredHeight: 54
                            mood: Quarki.mood
                            look: Qt.point(0.3, 0.4)
                        }
                        ColumnLayout {
                            visible: !win.empty || win.setup
                            Layout.fillWidth: true
                            spacing: 0
                            Txt { text: "Quarki"; font.pixelSize: Theme.textLarge + 1; font.weight: Font.Bold }
                            Txt { Layout.fillWidth: true; text: Quarki.statusText; color: Theme.fgMuted; font.pixelSize: Theme.textSmall }
                        }
                        Item { visible: win.empty && !win.setup; Layout.fillWidth: true }
                        IconButton { visible: win.setup; icon: "arrow_back"; onClicked: win.setup = false }
                        IconButton { visible: !win.empty && !win.setup; icon: "edit_square"; onClicked: Quarki.clear() }
                        IconButton { icon: "close"; onClicked: Shell.aiOpen = false }
                    }

                    // ------------------------------------------ inicio: saludo
                    ColumnLayout {
                        visible: win.empty && !win.setup
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6
                        Item { Layout.fillHeight: true; Layout.maximumHeight: 10 }
                        Mascot {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 150; Layout.preferredHeight: 150
                            mood: Quarki.mood
                            look: Qt.point(0, 0.5)
                        }
                        Txt {
                            Layout.alignment: Qt.AlignHCenter
                            text: Quarki.hello()
                            font.pixelSize: Theme.textTitle + 4; font.weight: Font.Bold
                        }
                        Txt {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Soy Quarki. ¿En qué te ayudo?"
                            color: Theme.fgMuted
                        }
                        Item { implicitHeight: 10 }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 8; rowSpacing: 8
                            Repeater {
                                model: [
                                    { i: "public", t: "Abre Firefox" },
                                    { i: "download", t: "Instala Minecraft" },
                                    { i: "sports_esports", t: "Activa el modo juego" },
                                    { i: "wallpaper", t: "Cambia el fondo" },
                                    { i: "volume_up", t: "Sube el volumen" },
                                    { i: "system_update_alt", t: "Busca actualizaciones" },
                                ]
                                Rectangle {
                                    id: chip
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 46; radius: 23
                                    color: chipArea.containsMouse ? Theme.surfaceHighest : Theme.surfaceHigh
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 10
                                        spacing: 8
                                        Icon { text: chip.modelData.i; size: 19; color: Theme.primary }
                                        Txt { Layout.fillWidth: true; text: chip.modelData.t; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                    }
                                    MouseArea { id: chipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quarki.ask(chip.modelData.t) }
                                }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }

                    // ------------------------------------------ conversación
                    ListView {
                        id: chat
                        visible: !win.empty && !win.setup
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 10
                        model: Quarki.messages
                        onCountChanged: Qt.callLater(positionViewAtEnd)
                        onContentHeightChanged: Qt.callLater(positionViewAtEnd)
                        add: Transition { NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: 220 } }

                        delegate: Item {
                            id: msg
                            required property var modelData
                            readonly property bool mine: modelData.from === "me"
                            readonly property var c: modelData.card
                            width: chat.width
                            height: col.implicitHeight
                            ColumnLayout {
                                id: col
                                width: parent.width
                                spacing: 8
                                Rectangle {
                                    visible: msg.modelData.text !== ""
                                    Layout.alignment: msg.mine ? Qt.AlignRight : Qt.AlignLeft
                                    Layout.preferredWidth: Math.min(chat.width * (msg.mine ? 0.82 : 0.94), body.implicitWidth + 28)
                                    implicitHeight: body.implicitHeight + 22
                                    radius: 18
                                    color: msg.mine ? Theme.primaryContainer : Theme.surfaceHigh
                                    Text {
                                        id: body
                                        x: 14; y: 11
                                        width: Math.min(chat.width * (msg.mine ? 0.82 : 0.94) - 28, implicitWidth)
                                        text: msg.modelData.text
                                        textFormat: msg.mine ? Text.PlainText : Text.MarkdownText
                                        wrapMode: Text.Wrap
                                        color: msg.mine ? Theme.primaryContainerFg : Theme.fg
                                        font.family: Theme.font
                                        font.pixelSize: Theme.textNormal
                                        onLinkActivated: link => Qt.openUrlExternally(link)
                                    }
                                }
                                Loader {
                                    active: !!msg.c
                                    visible: active
                                    Layout.fillWidth: true
                                    sourceComponent: !msg.c ? null : msg.c.type === "loading" ? loadingC
                                        : msg.c.type === "install" || msg.c.type === "remove" || msg.c.type === "installed" ? appC
                                        : msg.c.type === "choices" ? choicesC : actionC
                                    property var card: msg.c
                                    property int msgId: msg.modelData.id
                                }
                            }
                        }
                    }

                    // ------------------------------------------ instalar la IA
                    ColumnLayout {
                        visible: win.setup
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12
                        Item { Layout.fillHeight: true }
                        Txt { Layout.alignment: Qt.AlignHCenter; text: "Dale un cerebro a Quarki"; font.pixelSize: Theme.textTitle; font.weight: Font.Bold }
                        Txt {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: "Con la IA puedes conversar conmigo de cualquier tema. Funciona en tu PC: no necesita cuentas ni envía tus datos a nadie. Elige un tamaño según tu equipo."
                            color: Theme.fgMuted; wrapMode: Text.WordWrap; elide: Text.ElideNone
                        }
                        Repeater {
                            model: win.tiers
                            Rectangle {
                                id: tc
                                required property var modelData
                                readonly property bool on: win.tier === modelData.m
                                Layout.fillWidth: true
                                implicitHeight: 62; radius: Theme.radius
                                color: on ? Theme.alpha(Theme.primary, 0.14) : Theme.surfaceHigh
                                border.width: on ? 2 : 0; border.color: Theme.primary
                                ColumnLayout {
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 16
                                    spacing: 0
                                    Txt { text: tc.modelData.t + (tc.modelData.m === "gemma3:4b" ? "  (recomendado)" : ""); font.weight: Font.Bold }
                                    Txt { text: tc.modelData.h; color: Theme.fgMuted; font.pixelSize: Theme.textSmall }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.tier = tc.modelData.m }
                            }
                        }
                        PillButton {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Instalar la IA"
                            icon: "download"
                            primary: true
                            onClicked: {
                                // instala Ollama (si falta), lo activa y descarga el modelo, en una terminal visible
                                Quickshell.execDetached(["kitty", "--class", "quantum-update", "--title", "Instalando la IA de Quarki", "bash", "-c",
                                    "echo -e '\\e[1;38;2;143;123;255mQuarki: instalando la IA\\e[0m\\n'; " +
                                    "command -v ollama >/dev/null || sudo pacman -S --needed --noconfirm ollama; " +
                                    "sudo systemctl enable --now ollama && sleep 2 && ollama pull " + win.tier +
                                    " && echo -e '\\n\\e[1;32mListo. Ya puedes cerrar esta ventana y conversar con Quarki.\\e[0m'; " +
                                    "read -rp 'Presiona Enter para cerrar…'"]);
                                Settings.ai.model = win.tier;
                                win.setup = false;
                            }
                        }
                        PillButton { Layout.alignment: Qt.AlignHCenter; text: "Ya la instalé, revisar otra vez"; onClicked: { Ai.check(); win.setup = false; } }
                        Item { Layout.fillHeight: true }
                    }

                    // ---------------------------------------------- escribir
                    Rectangle {
                        visible: !win.setup
                        Layout.fillWidth: true
                        implicitHeight: Math.min(120, Math.max(54, input.contentHeight + 30))
                        radius: 27
                        color: Theme.surfaceHigh
                        border.width: input.activeFocus ? 2 : 1
                        border.color: input.activeFocus ? Theme.primary : Theme.alpha(Theme.fg, 0.08)
                        TextEdit {
                            id: input
                            anchors.left: parent.left; anchors.right: sendBtn.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 20; anchors.rightMargin: 10
                            wrapMode: TextEdit.Wrap
                            font.family: Theme.font; font.pixelSize: Theme.textNormal
                            color: Theme.fg
                            selectionColor: Theme.primary
                            focus: true
                            Keys.onReturnPressed: e => {
                                if (e.modifiers & Qt.ShiftModifier) { e.accepted = false; return; }
                                Quarki.ask(text); text = "";
                            }
                            Keys.onEscapePressed: Shell.aiOpen = false
                            Txt { visible: !input.text; text: "Pídeme algo, como «abre Firefox»…"; color: Theme.fgMuted }
                        }
                        Rectangle {
                            id: sendBtn
                            anchors.right: parent.right; anchors.rightMargin: 7
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40; height: 40; radius: 20
                            color: Ai.busy || input.text ? Theme.primary : Theme.surfaceHighest
                            Icon { anchors.centerIn: parent; text: Ai.busy ? "stop" : "arrow_upward"; fill: 1; color: Ai.busy || input.text ? Theme.primaryFg : Theme.fgMuted }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { if (Ai.busy) Ai.stop(); else { Quarki.ask(input.text); input.text = ""; } }
                            }
                        }
                    }
                    RowLayout {
                        visible: !win.setup
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6
                        Txt {
                            text: Ai.status === "ready" ? "IA local · " + Ai.model + " · puede equivocarse" : "Entiendo órdenes como «instala Minecraft»."
                            color: Theme.fgMuted; font.pixelSize: Theme.textSmall - 1
                        }
                        Txt {
                            visible: Ai.status === "missing" || Ai.status === "nomodel"
                            text: "<a href='#'>Instalar IA</a>"
                            textFormat: Text.StyledText
                            linkColor: Theme.primary
                            font.pixelSize: Theme.textSmall - 1
                            onLinkActivated: win.setup = true
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }

            // =========================================================== tarjetas
            // «Pensando…»: tres puntitos
            Component {
                id: loadingC
                Row {
                    spacing: 6
                    leftPadding: 16
                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            width: 8; height: 8; radius: 4
                            color: Theme.primary
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

            // ícono de una app: URL (Flathub) o del tema
            component ItemIcon: Item {
                property string src: ""
                implicitWidth: 48; implicitHeight: 48
                Image {
                    anchors.fill: parent
                    visible: parent.src.startsWith("http")
                    source: visible ? parent.src : ""
                    sourceSize: Qt.size(96, 96)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
                AppIcon {
                    anchors.fill: parent
                    visible: !parent.src.startsWith("http")
                    size: 48
                    name: parent.src.replace(/^theme:/, "")
                }
            }
            component Badge: Rectangle {
                property string text: ""
                visible: text !== ""
                implicitWidth: bt.implicitWidth + 14; implicitHeight: 22; radius: 11
                color: Theme.alpha(Theme.primary, 0.14)
                Txt { id: bt; anchors.centerIn: parent; text: parent.text; color: Theme.primary; font.pixelSize: Theme.textSmall - 1; font.weight: Font.DemiBold }
            }

            // instalar / desinstalar / ya instalada
            Component {
                id: appC
                Rectangle {
                    id: ac
                    readonly property var cd: parent.card
                    readonly property var it: cd.item
                    readonly property int mid: parent.msgId
                    readonly property bool remove: cd.type === "remove"
                    implicitHeight: acCol.implicitHeight + 28
                    radius: Theme.radius
                    color: Theme.surfaceHigh
                    border.width: cd.status === "working" ? 2 : 1
                    border.color: cd.status === "working" ? Theme.primary : Theme.alpha(Theme.fg, 0.08)
                    ColumnLayout {
                        id: acCol
                        x: 14; y: 14
                        width: parent.width - 28
                        spacing: 10
                        RowLayout {
                            spacing: 12
                            ItemIcon { src: ac.it.icon ?? ("theme:" + ac.it.id) }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                Txt { Layout.fillWidth: true; text: ac.it.name; font.weight: Font.Bold; font.pixelSize: Theme.textLarge; elide: Text.ElideRight }
                                Txt {
                                    visible: !!ac.it.summary
                                    Layout.fillWidth: true
                                    text: ac.it.summary ?? ""
                                    color: Theme.fgMuted; font.pixelSize: Theme.textSmall
                                    wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                                }
                                Row {
                                    spacing: 6
                                    Badge { text: ac.it.sourceLabel ?? "" }
                                    Badge { text: ac.it.size ?? "" }
                                }
                            }
                        }
                        Txt {
                            visible: !!ac.it.warning && ac.cd.status === "ask"
                            Layout.fillWidth: true
                            text: ac.it.warning ?? ""
                            color: Theme.fgMuted; font.pixelSize: Theme.textSmall; wrapMode: Text.WordWrap
                        }
                        // trabajando: barra que va y viene
                        Rectangle {
                            visible: ac.cd.status === "working"
                            Layout.fillWidth: true
                            implicitHeight: 6; radius: 3
                            color: Theme.alpha(Theme.primary, 0.15)
                            clip: true
                            Rectangle {
                                width: parent.width * 0.35; height: parent.height; radius: 3
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: Theme.brandCyan }
                                    GradientStop { position: 0.5; color: Theme.brandIndigo }
                                    GradientStop { position: 1; color: Theme.brandViolet }
                                }
                                SequentialAnimation on x {
                                    loops: Animation.Infinite
                                    running: ac.cd.status === "working"
                                    NumberAnimation { from: -ac.width * 0.35; to: ac.width; duration: 1300; easing.type: Easing.InOutQuad }
                                }
                            }
                        }
                        Txt {
                            visible: ac.cd.status === "working" || ac.cd.status === "cancelled" || ac.cd.status === "error"
                            text: ac.cd.status === "working" ? (ac.remove ? "Desinstalando… te pedirá tu contraseña." : "Instalando… te pedirá tu contraseña. Puede tardar unos minutos.")
                                : ac.cd.status === "cancelled" ? "Cancelado" : "No se pudo terminar"
                            color: Theme.fgMuted; font.pixelSize: Theme.textSmall
                        }
                        RowLayout {
                            spacing: 8
                            visible: ac.cd.status === "ask" || (ac.cd.status === "done" && !ac.remove) || ac.cd.type === "installed"
                            PillButton {
                                visible: ac.cd.status === "ask"
                                text: ac.remove ? "Desinstalar" : "Instalar"
                                icon: ac.remove ? "delete" : "download"
                                primary: !ac.remove
                                danger: ac.remove
                                onClicked: Quarki.confirm(ac.mid)
                            }
                            PillButton { visible: ac.cd.status === "ask"; text: "Cancelar"; onClicked: Quarki.cancel(ac.mid) }
                            PillButton {
                                visible: (ac.cd.status === "done" && !ac.remove) || ac.cd.type === "installed"
                                text: "Abrir"; icon: "open_in_new"; primary: true
                                onClicked: Quarki.launchItem(ac.it)
                            }
                            Row {
                                visible: ac.cd.status === "done" && !ac.remove
                                spacing: 4
                                Icon { anchors.verticalCenter: parent.verticalCenter; text: "check_circle"; size: 18; fill: 1; color: Theme.primary }
                                Txt { anchors.verticalCenter: parent.verticalCenter; text: "Instalado"; color: Theme.primary; font.weight: Font.DemiBold }
                            }
                        }
                        Row {
                            visible: ac.cd.status === "done" && ac.remove
                            spacing: 4
                            Icon { anchors.verticalCenter: parent.verticalCenter; text: "check_circle"; size: 18; fill: 1; color: Theme.primary }
                            Txt { anchors.verticalCenter: parent.verticalCenter; text: "Desinstalado"; color: Theme.primary; font.weight: Font.DemiBold }
                        }
                        // ¿no era esta? otras opciones
                        Flow {
                            visible: ac.cd.status === "ask" && (ac.cd.alts?.length ?? 0) > 0
                            Layout.fillWidth: true
                            spacing: 6
                            Txt { height: 28; verticalAlignment: Text.AlignVCenter; text: "¿No es esta?"; color: Theme.fgMuted; font.pixelSize: Theme.textSmall }
                            Repeater {
                                model: ac.cd.alts ?? []
                                Rectangle {
                                    id: alt
                                    required property var modelData
                                    width: altT.implicitWidth + 20; height: 28; radius: 14
                                    color: altArea.containsMouse ? Theme.surfaceHighest : Theme.alpha(Theme.fg, 0.06)
                                    Txt { id: altT; anchors.centerIn: parent; text: alt.modelData.name + " · " + (alt.modelData.source === "flathub" ? "Flathub" : alt.modelData.source === "aur" ? "AUR" : "Arch"); font.pixelSize: Theme.textSmall }
                                    MouseArea { id: altArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quarki.chooseItem(ac.mid, alt.modelData) }
                                }
                            }
                        }
                    }
                }
            }

            // varias opciones parecidas
            Component {
                id: choicesC
                ColumnLayout {
                    id: cc
                    readonly property var cd: parent.card
                    readonly property int mid: parent.msgId
                    spacing: 6
                    Repeater {
                        model: cc.cd.items
                        Rectangle {
                            id: row
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 60; radius: Theme.radius
                            color: rowArea.containsMouse ? Theme.surfaceHighest : Theme.surfaceHigh
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                                spacing: 10
                                ItemIcon { implicitWidth: 36; implicitHeight: 36; src: row.modelData.icon }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 0
                                    Txt { Layout.fillWidth: true; text: row.modelData.name; font.weight: Font.Bold; elide: Text.ElideRight }
                                    Txt { Layout.fillWidth: true; text: row.modelData.summary; color: Theme.fgMuted; font.pixelSize: Theme.textSmall; elide: Text.ElideRight }
                                }
                                Icon { text: "chevron_right"; color: Theme.fgMuted }
                            }
                            MouseArea { id: rowArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quarki.chooseItem(cc.mid, row.modelData) }
                        }
                    }
                    PillButton { text: "Buscar en Steam"; icon: "sports_esports"; onClicked: win.steamSearch(cc.cd.query) }
                }
            }

            // un botón: apagar, Steam, Store o instalar la IA
            Component {
                id: actionC
                Row {
                    id: xc
                    readonly property var cd: parent.card
                    readonly property int mid: parent.msgId
                    readonly property var labels: ({ poweroff: ["Apagar", "power_settings_new"], reboot: ["Reiniciar", "restart_alt"], suspend: ["Suspender", "bedtime"] })
                    spacing: 8
                    PillButton {
                        visible: xc.cd.type === "power" && xc.cd.status === "ask"
                        text: xc.labels[xc.cd.action]?.[0] ?? ""; icon: xc.labels[xc.cd.action]?.[1] ?? ""
                        danger: true
                        onClicked: Quarki.confirm(xc.mid)
                    }
                    PillButton { visible: xc.cd.type === "power" && xc.cd.status === "ask"; text: "Cancelar"; onClicked: Quarki.cancel(xc.mid) }
                    PillButton { visible: xc.cd.type === "steam"; text: "Buscar en Steam"; icon: "sports_esports"; primary: true; onClicked: win.steamSearch(xc.cd.query) }
                    PillButton {
                        visible: xc.cd.type === "steam" || xc.cd.type === "store"
                        text: "Abrir Quantum Store"; icon: "storefront"
                        onClicked: { Quickshell.execDetached(["quantum-store"]); Shell.aiOpen = false; }
                    }
                    PillButton { visible: xc.cd.type === "aiSetup"; text: "Instalar mi IA"; icon: "psychology"; primary: true; onClicked: win.setup = true }
                }
            }

            function steamSearch(q: string): void {
                const url = "https://store.steampowered.com/search/?term=" + encodeURIComponent(q);
                Quickshell.execDetached(["sh", "-c", "if command -v steam >/dev/null; then steam \"steam://openurl/$1\"; else xdg-open \"$1\"; fi", "sh", url]);
                Shell.aiOpen = false;
            }
        }
    }
}
