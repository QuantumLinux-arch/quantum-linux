import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

// Android con Waydroid: activar, catálogo F-Droid, apps instaladas y abrir APK propios.
Flickable {
    id: pg
    objectName: "flick-android"
    contentHeight: col.implicitHeight + 40
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}
    readonly property var a: store.android || ({})
    readonly property string st: a.status || "checking"
    readonly property bool setting: (store.jobs || []).some(j => j.key === "android:setup" && j.state === "running")

    FileDialog {
        id: apkDialog
        title: "Elige un APK"
        nameFilters: ["Apps de Android (*.apk)"]
        onAccepted: store.openApk(String(selectedFile))
    }

    ColumnLayout {
        id: col
        x: 20; y: 10
        width: pg.width - 40
        spacing: 22

        // ---------------------------------------------------------- cabecera
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 220
            radius: 30
            clip: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#0E3B2B" }
                GradientStop { position: 1; color: "#1F7A4D" }
            }
            Sym {
                anchors.right: parent.right
                anchors.rightMargin: 40
                anchors.verticalCenter: parent.verticalCenter
                text: "android"; size: 220; fill: 1
                color: Qt.rgba(0.24, 0.86, 0.52, 0.35)
            }
            ColumnLayout {
                anchors.left: parent.left
                anchors.leftMargin: 40
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.6
                spacing: 10
                T { text: "Apps de Android"; color: "white"; font.pixelSize: 36; font.weight: Font.ExtraBold }
                T {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: Qt.rgba(1, 1, 1, 0.85)
                    font.pixelSize: 16
                    text: pg.st === "running" ? "Android está activo. Tus apps se abren en su propia ventana, como cualquier programa."
                        : "Juega y usa apps de Android en tu PC, cada una en su propia ventana."
                }
                RowLayout {
                    Layout.topMargin: 8
                    spacing: 10
                    Btn {
                        visible: pg.st === "uninitialized" || pg.st === "missing"
                        text: pg.setting ? "Activando…" : "Activar Android"
                        icon: "power_settings_new"
                        onClicked: if (!pg.setting) store.setupAndroid()
                    }
                    Btn { visible: pg.st === "stopped"; text: "Iniciar Android"; icon: "play_arrow"; onClicked: store.startAndroid() }
                    Btn {
                        visible: pg.st === "running" || pg.st === "stopped"
                        text: "Abrir un APK"; icon: "upload_file"
                        style: pg.st === "running" ? "filled" : "tonal"
                        onClicked: apkDialog.open()
                    }
                }
                T {
                    visible: pg.st === "uninitialized" || pg.st === "missing"
                    text: "Se descarga Android una sola vez (cerca de 1 GB)."
                    color: Qt.rgba(1, 1, 1, 0.7); font.pixelSize: 12
                }
            }
        }

        // ---------------------------------------------------- apps instaladas
        ColumnLayout {
            visible: (pg.a.apps || []).length > 0
            Layout.fillWidth: true
            spacing: 12
            T { text: "Tus apps de Android"; font.pixelSize: 20; font.weight: Font.ExtraBold }
            Flow {
                Layout.fillWidth: true
                spacing: 14
                Repeater {
                    model: pg.a.apps || []
                    Rectangle {
                        id: tile
                        required property var modelData
                        width: 112; height: 120; radius: 22
                        color: tileArea.containsMouse ? theme.high : theme.card
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: 56; implicitHeight: 56; radius: 18
                                color: theme.alpha("#3DDC84", 0.16)
                                Sym { anchors.centerIn: parent; text: "android"; size: 32; fill: 1; color: "#3DDC84" }
                            }
                            T { Layout.maximumWidth: 96; Layout.alignment: Qt.AlignHCenter; text: tile.modelData.name; font.pixelSize: 12; font.weight: Font.DemiBold }
                        }
                        MouseArea { id: tileArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: store.launch(tile.modelData.key) }
                    }
                }
            }
        }

        // ----------------------------------------------------------- catálogo
        Rectangle {
            visible: !pg.a.catalog
            Layout.fillWidth: true
            implicitHeight: catRow.implicitHeight + 40
            radius: 24
            color: theme.card
            RowLayout {
                id: catRow
                anchors.fill: parent
                anchors.margins: 20
                spacing: 18
                Sym { text: "storefront"; size: 40; fill: 1; color: theme.primary }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    T { text: "Catálogo de F-Droid"; font.pixelSize: 17; font.weight: Font.Bold }
                    T { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: theme.muted; font.pixelSize: 13
                        text: "Más de 4.000 apps y juegos libres y gratis, sin publicidad ni rastreo. Descarga el catálogo para verlas aquí." }
                }
                Btn {
                    text: (store.busy || []).indexOf("catalog") >= 0 ? "Descargando…" : "Descargar catálogo"
                    icon: "download"; style: "tonal"
                    onClicked: if ((store.busy || []).indexOf("catalog") < 0) store.downloadCatalog()
                }
            }
        }
        Shelf { title: "Juegos"; icon: "sports_esports"; apps: pg.a.games || [] }
        Shelf { title: "Novedades en F-Droid"; icon: "new_releases"; apps: pg.a.newest || [] }

        // ------------------------------------------------------- arrastrar APK
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 110
            radius: 24
            color: "transparent"
            border.width: 2
            border.color: theme.outline
            RowLayout {
                anchors.centerIn: parent
                spacing: 14
                Sym { text: "move_to_inbox"; size: 34; color: theme.muted }
                ColumnLayout {
                    spacing: 2
                    T { text: "Arrastra un archivo .apk a esta ventana"; font.pixelSize: 15; font.weight: Font.Bold }
                    T { text: "También puedes hacer doble clic en un APK desde Archivos."; color: theme.muted; font.pixelSize: 13 }
                }
            }
        }
    }
}
