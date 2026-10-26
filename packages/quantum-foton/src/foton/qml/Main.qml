import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Fotón: biblioteca de juegos de Quantum Linux.
ApplicationWindow {
    id: window
    width: 1320
    height: 840
    minimumWidth: 980
    minimumHeight: 640
    visible: true
    title: "Fotón"
    color: theme.bg

    Theme { id: theme }

    property string tab: startTab || ((foton.games || []).length ? "library" : "store")
    readonly property bool compact: width < 1500          // botones de arriba solo con ícono
    property string filter: "all"
    readonly property string query: search.text.toLowerCase()
    readonly property var sources: [
        { id: "all", text: "Todos" }, { id: "steam", text: "Steam" }, { id: "foton", text: "Tienda Fotón" },
        { id: "windows", text: "Windows" }, { id: "epic", text: "Epic" }, { id: "gog", text: "GOG" },
        { id: "amazon", text: "Amazon" }, { id: "local", text: "Otros" },
    ]
    readonly property var all: foton.games || []
    readonly property var shown: all.filter(g => (filter === "all" || g.source === filter)
        && (!search.text || g.name.toLowerCase().indexOf(search.text.toLowerCase()) >= 0))
    readonly property var featured: all.length ? all[0] : null
    function srcName(s) { return { steam: "Steam", epic: "Epic", gog: "GOG", amazon: "Amazon", local: "Instalado", windows: "Windows", foton: "Fotón" }[s] || s; }
    function specName(s) { return { bajo: "Corre en PCs modestas", medio: "Pide una PC intermedia", alto: "Pide una PC potente" }[s] || ""; }
    function img(u) { return u ? (u.indexOf("http") === 0 ? theme.web(u) : u) : ""; }
    function ago(ts) {
        if (!ts) return "";
        const d = Math.floor((Date.now() / 1000 - ts) / 86400);
        return d <= 0 ? "Jugaste hoy" : d === 1 ? "Jugaste ayer" : d < 30 ? "Jugaste hace " + d + " días" : "Hace tiempo que no juegas";
    }

    Flickable {
        id: page
        anchors.fill: parent
        contentHeight: col.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        ColumnLayout {
            id: col
            x: 28; y: 22
            width: page.width - 56
            spacing: 24

            // ------------------------------------------------ cabecera
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                Mark { implicitWidth: 46; implicitHeight: 46; color: theme.fg }
                T { text: "Fotón"; font.pixelSize: 28; font.weight: Font.Black }
                Item { Layout.preferredWidth: 14 }
                // pestañas
                Rectangle {
                    implicitWidth: tabsRow.implicitWidth + 8; implicitHeight: 48; radius: 24
                    color: theme.card
                    Row {
                        id: tabsRow
                        anchors.centerIn: parent
                        spacing: 4
                        Repeater {
                            model: [{ id: "library", t: "Biblioteca", i: "grid_view" }, { id: "store", t: "Tienda", i: "storefront" }]
                            Rectangle {
                                id: tabBtn
                                required property var modelData
                                readonly property bool on: window.tab === modelData.id
                                width: tabTxt.implicitWidth + 64; height: 40; radius: 20
                                color: on ? theme.primaryContainer : tabArea.containsMouse ? theme.high : "transparent"
                                Behavior on color { ColorAnimation { duration: 160 } }
                                Row {
                                    anchors.centerIn: parent; spacing: 8
                                    Sym { text: tabBtn.modelData.i; size: 20; fill: tabBtn.on ? 1 : 0; color: tabBtn.on ? theme.onPrimaryContainer : theme.fg; anchors.verticalCenter: parent.verticalCenter }
                                    T { id: tabTxt; text: tabBtn.modelData.t; font.weight: Font.Bold; color: tabBtn.on ? theme.onPrimaryContainer : theme.fg; anchors.verticalCenter: parent.verticalCenter }
                                }
                                MouseArea { id: tabArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { window.tab = tabBtn.modelData.id; page.contentY = 0; } }
                            }
                        }
                    }
                }
                Item { Layout.preferredWidth: 6 }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 200
                    Layout.maximumWidth: 460
                    implicitHeight: 48; radius: 24
                    color: theme.card
                    border.width: search.activeFocus ? 2 : 1
                    border.color: search.activeFocus ? theme.primary : theme.alpha(theme.fg, 0.06)
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 16; spacing: 10
                        Sym { text: "search"; color: theme.muted }
                        TextInput {
                            id: search
                            Layout.fillWidth: true
                            font.family: theme.font; font.pixelSize: 15; color: theme.fg; clip: true
                            selectionColor: theme.primary
                            T { anchors.verticalCenter: parent.verticalCenter; visible: !search.text; text: window.tab === "store" ? "Buscar en la tienda…" : "Buscar en tus juegos…"; color: theme.muted; font.pixelSize: 15 }
                        }
                    }
                }
                Item { Layout.fillWidth: true; Layout.maximumWidth: 200 }
                // herramientas
                ToolPill {
                    icon: "add"; text: "Agregar juego"
                    onClicked: addGame.open()
                }
                ToolPill {
                    icon: "sports_esports"; text: "Modo juego"
                    on: foton.tools.gamemode
                    onClicked: foton.setGamemode(!on)
                }
                ToolPill {
                    icon: "speed"; text: "Mostrar FPS"
                    on: foton.tools.fps
                    onClicked: foton.setFps(!on)
                }
                ToolPill {
                    visible: foton.tools.steam
                    icon: foton.tools.ge.busy ? "downloading" : "rocket_launch"
                    text: foton.tools.ge.busy ? "Proton-GE " + Math.round(foton.tools.ge.progress * 100) + "%"
                        : foton.tools.ge.installed ? foton.tools.ge.installed : "Instalar Proton-GE"
                    on: !!foton.tools.ge.installed
                    onClicked: foton.installGe()
                }
            }

            Library { visible: window.tab === "library"; Layout.fillWidth: true }
            Store { visible: window.tab === "store"; Layout.fillWidth: true }
        }
    }

    GameDetail { id: detail; anchors.fill: parent }
    Component.onCompleted: {
        if (startOpen.indexOf("detail:") === 0) detail.show({ id: startOpen.slice(7) });
        else if (startOpen === "add") addGame.open();
        if (startScroll) scrollTimer.start();
    }
    Timer { id: scrollTimer; interval: 1500; onTriggered: page.contentY = startScroll }
    AddGame { id: addGame; anchors.fill: parent }

    // aviso flotante
    Rectangle {
        id: toast
        property string msg: ""
        property bool shown: false
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: shown ? 28 : -70
        width: Math.min(parent.width - 60, toastText.implicitWidth + 56)
        height: 52; radius: 26
        color: theme.highest
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        RowLayout {
            anchors.centerIn: parent
            spacing: 10
            Sym { text: "rocket_launch"; fill: 1; color: theme.primary }
            T { id: toastText; text: toast.msg; font.weight: Font.DemiBold; Layout.maximumWidth: window.width - 140 }
        }
        Timer { id: toastTimer; interval: 4000; onTriggered: toast.shown = false }
        Connections { target: foton; function onToast(m) { toast.msg = m; toast.shown = true; toastTimer.restart(); } }
    }
}
