import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: window
    width: 1280
    height: 820
    minimumWidth: 980
    minimumHeight: 640
    visible: true
    title: "Quantum Store"
    color: theme.bg
    onClosing: store.quitWhenIdle()

    property string page: startPage
    property string prevPage: "inicio"
    function go(p) { if (p !== page) { prevPage = page; page = p; } }
    function openApp(key) { store.openDetails(key); go("detalle"); }

    Theme { id: theme }

    readonly property var nav: [
        { id: "inicio", icon: "home", text: "Inicio" },
        { id: "juegos", icon: "sports_esports", text: "Juegos" },
        { id: "android", icon: "android", text: "Android" },
        { id: "instaladas", icon: "apps", text: "Tus apps" },
    ]

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ------------------------------------------------------- barra lateral
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 232
            color: theme.low

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 6

                RowLayout {
                    Layout.bottomMargin: 22
                    Layout.leftMargin: 4
                    spacing: 10
                    Image {
                        source: "../assets/quantum-mark.svg"
                        sourceSize: Qt.size(80, 80)
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                    }
                    ColumnLayout {
                        spacing: -2
                        T { text: "Quantum"; font.pixelSize: 20; font.weight: Font.ExtraBold }
                        T { text: "STORE"; font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 4; color: theme.muted }
                    }
                }

                Repeater {
                    model: window.nav
                    Rectangle {
                        id: navItem
                        required property var modelData
                        objectName: "nav-" + modelData.id
                        readonly property bool on: window.page === modelData.id
                            || (window.page === "detalle" && window.prevPage === modelData.id)
                        Layout.fillWidth: true
                        implicitHeight: 48
                        radius: 24
                        color: on ? theme.primaryContainer : navArea.containsMouse ? theme.high : "transparent"
                        Behavior on color { ColorAnimation { duration: 180 } }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            spacing: 14
                            Sym { text: navItem.modelData.icon; fill: navItem.on ? 1 : 0; color: navItem.on ? theme.onPrimaryContainer : theme.fg }
                            T {
                                Layout.fillWidth: true
                                text: navItem.modelData.text
                                font.pixelSize: 15
                                font.weight: navItem.on ? Font.Bold : Font.Medium
                                color: navItem.on ? theme.onPrimaryContainer : theme.fg
                            }
                            Rectangle {
                                visible: navItem.modelData.id === "android" && (store.android.status || "") === "running"
                                Layout.rightMargin: 14
                                implicitWidth: 8; implicitHeight: 8; radius: 4
                                color: "#3DDC84"
                            }
                        }
                        MouseArea {
                            id: navArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.go(navItem.modelData.id)
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // Trabajos en curso (instalaciones)
                Repeater {
                    model: store.jobs
                    Rectangle {
                        id: jobCard
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: jobCol.implicitHeight + 24
                        radius: 18
                        color: theme.card
                        border.width: 1
                        border.color: modelData.state === "error" ? theme.error : theme.alpha(theme.fg, 0.06)
                        ColumnLayout {
                            id: jobCol
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                            anchors.margins: 12
                            spacing: 6
                            RowLayout {
                                Sym {
                                    text: jobCard.modelData.state === "done" ? "check_circle"
                                        : jobCard.modelData.state === "error" ? "error"
                                        : jobCard.modelData.kind === "remove" ? "delete" : "download"
                                    size: 18; fill: 1
                                    color: jobCard.modelData.state === "error" ? theme.error : theme.primary
                                }
                                T { Layout.fillWidth: true; text: jobCard.modelData.name; font.weight: Font.Bold; font.pixelSize: 13 }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 6
                                radius: 3
                                color: theme.highest
                                clip: true
                                Rectangle {
                                    readonly property real p: jobCard.modelData.progress
                                    height: parent.height
                                    radius: 3
                                    width: p < 0 ? parent.width * 0.3 : parent.width * p
                                    x: p < 0 ? (parent.width * 0.7) * (0.5 + 0.5 * Math.sin(indet.t)) : 0
                                    color: theme.primary
                                    Behavior on width { NumberAnimation { duration: 200 } }
                                }
                            }
                            T { Layout.fillWidth: true; text: jobCard.modelData.line; font.pixelSize: 11; color: theme.muted }
                        }
                    }
                }
                QtObject {
                    id: indet
                    property real t: 0
                    property var timer: Timer { interval: 30; running: store.jobs.length > 0; repeat: true; onTriggered: indet.t += 0.06 }
                }

                T {
                    visible: store.dryrun && !demoMode
                    Layout.fillWidth: true
                    text: "Modo simulación"
                    font.pixelSize: 11
                    color: theme.tertiary
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // ------------------------------------------------------- contenido
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // barra superior con búsqueda
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 20
                Layout.bottomMargin: 6
                spacing: 12
                Rectangle {
                    visible: window.page === "detalle" || window.page === "buscar"
                    implicitWidth: 48; implicitHeight: 48; radius: 24
                    color: backArea.containsMouse ? theme.high : theme.card
                    Sym { anchors.centerIn: parent; text: "arrow_back" }
                    MouseArea { id: backArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { window.page = window.prevPage === "detalle" ? "inicio" : window.prevPage; search.text = ""; } }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 720
                    implicitHeight: 52
                    radius: 26
                    color: theme.card
                    border.width: search.activeFocus ? 2 : 1
                    border.color: search.activeFocus ? theme.primary : theme.alpha(theme.fg, 0.06)
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 16
                        spacing: 12
                        Sym { text: "search"; color: theme.muted }
                        TextInput {
                            id: search
                            objectName: "search"
                            Layout.fillWidth: true
                            font.family: theme.font
                            font.pixelSize: 16
                            color: theme.fg
                            clip: true
                            selectionColor: theme.primary
                            onTextEdited: searchTimer.restart()
                            Keys.onReturnPressed: { searchTimer.stop(); searchTimer.triggered(); }
                            T {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !search.text
                                text: "Busca apps, juegos o paquetes…"
                                font.pixelSize: 16
                                color: theme.muted
                            }
                        }
                        Sym { visible: search.text !== ""; text: "close"; color: theme.muted
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { search.text = ""; window.page = window.prevPage; } } }
                    }
                    Timer {
                        id: searchTimer
                        interval: 450
                        onTriggered: {
                            if (search.text.trim().length >= 2) { store.search(search.text); window.go("buscar"); }
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: ["inicio", "juegos", "android", "instaladas", "buscar", "detalle"].indexOf(window.page)
                HomePage {}
                GamesPage {}
                AndroidPage {}
                InstalledPage {}
                SearchPage {}
                DetailsPage {}
            }
        }
    }

    // aviso flotante
    Rectangle {
        id: toast
        property string msg: ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: shown ? 28 : -60
        property bool shown: false
        width: toastText.implicitWidth + 48
        height: 48
        radius: 24
        color: theme.highest
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        T { id: toastText; anchors.centerIn: parent; text: toast.msg; font.weight: Font.DemiBold }
        Timer { id: toastTimer; interval: 3200; onTriggered: toast.shown = false }
        Connections {
            target: store
            function onToast(m) { toast.msg = m; toast.shown = true; toastTimer.restart(); }
        }
    }

    // demostración guiada para los videos (QUANTUM_STORE_DEMO=1)
    Loader { anchors.fill: parent; active: demoMode; source: "Demo.qml"; z: 100 }

    // soltar un .apk sobre la ventana lo instala
    DropArea {
        anchors.fill: parent
        onDropped: d => {
            for (const u of d.urls) if (String(u).toLowerCase().endsWith(".apk")) { store.openApk(String(u)); window.go("android"); }
        }
    }
}
