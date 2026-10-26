import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Ficha de una app: ícono, botón instalar/abrir/quitar, capturas, descripción y datos.
Flickable {
    id: pg
    contentHeight: col.implicitHeight + 40
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}
    readonly property var d: store.details || ({})
    readonly property var job: (store.jobs || []).find(j => j.key === d.key && j.state === "running")
    onDChanged: contentY = 0

    BusyIndicator { anchors.centerIn: parent; running: !!pg.d.loading; visible: running }

    ColumnLayout {
        id: col
        x: 20; y: 10
        width: pg.width - 40
        spacing: 24
        visible: !pg.d.loading && !!pg.d.name

        RowLayout {
            Layout.fillWidth: true
            spacing: 24
            Rectangle {
                implicitWidth: 128; implicitHeight: 128; radius: 32
                color: theme.card
                Image {
                    anchors.centerIn: parent
                    width: 100; height: 100
                    source: theme.iconSource(pg.d.icon)
                    sourceSize: Qt.size(200, 200)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                T { Layout.fillWidth: true; text: pg.d.name || ""; font.pixelSize: 34; font.weight: Font.ExtraBold }
                T { Layout.fillWidth: true; text: pg.d.summary || ""; color: theme.muted; font.pixelSize: 16; wrapMode: Text.WordWrap; maximumLineCount: 2 }
                RowLayout {
                    spacing: 8
                    SourceChip { source: pg.d.source || "arch" }
                    T { visible: !!pg.d.version; text: "v" + (pg.d.version || ""); color: theme.muted; font.pixelSize: 13 }
                }
            }
            ColumnLayout {
                spacing: 10
                Layout.alignment: Qt.AlignVCenter
                Btn {
                    objectName: "btn-install"
                    visible: !pg.job && !pg.d.installed
                    Layout.preferredWidth: 180
                    text: "Instalar"; icon: "download"
                    onClicked: store.install(pg.d.key, pg.d.name)
                }
                Btn {
                    objectName: "btn-open"
                    visible: !pg.job && !!pg.d.installed
                    Layout.preferredWidth: 180
                    text: "Abrir"; icon: "open_in_new"
                    onClicked: store.launch(pg.d.key)
                }
                Btn {
                    visible: !pg.job && !!pg.d.installed
                    Layout.preferredWidth: 180
                    text: "Desinstalar"; icon: "delete"; style: "danger"
                    onClicked: store.remove(pg.d.key, pg.d.name)
                }
                // progreso
                ColumnLayout {
                    visible: !!pg.job
                    Layout.preferredWidth: 220
                    spacing: 6
                    RowLayout {
                        T { Layout.fillWidth: true; text: pg.job ? (pg.job.kind === "remove" ? "Desinstalando…" : "Instalando…") : ""; font.weight: Font.Bold }
                        T { text: pg.job && pg.job.progress >= 0 ? Math.round(pg.job.progress * 100) + "%" : ""; color: theme.muted }
                    }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 8; radius: 4; color: theme.highest
                        Rectangle { height: parent.height; radius: 4; color: theme.primary
                            width: parent.width * (pg.job && pg.job.progress >= 0 ? pg.job.progress : 0.15)
                            Behavior on width { NumberAnimation { duration: 200 } } }
                    }
                    Btn { small: true; style: "outline"; text: "Cancelar"; onClicked: store.cancel(pg.d.key) }
                }
            }
        }

        // aviso AUR
        Rectangle {
            visible: !!pg.d.warning
            Layout.fillWidth: true
            implicitHeight: warn.implicitHeight + 28
            radius: 18
            color: theme.alpha("#E5A50A", 0.12)
            border.width: 1
            border.color: theme.alpha("#E5A50A", 0.4)
            RowLayout {
                id: warn
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12
                Sym { text: "shield"; color: "#E5A50A"; fill: 1 }
                T { Layout.fillWidth: true; text: pg.d.warning || ""; wrapMode: Text.WordWrap; font.pixelSize: 13 }
            }
        }

        // capturas
        ListView {
            visible: (pg.d.screenshots || []).length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: 340
            orientation: ListView.Horizontal
            spacing: 16
            clip: true
            model: pg.d.screenshots || []
            delegate: Rectangle {
                required property string modelData
                height: 340
                width: shot.status === Image.Ready ? Math.min(620, shot.implicitWidth * 340 / Math.max(1, shot.implicitHeight)) : 540
                radius: 20
                color: theme.card
                clip: true
                Image { id: shot; anchors.fill: parent; source: theme.web(parent.modelData); fillMode: Image.PreserveAspectCrop; asynchronous: true }
                BusyIndicator { anchors.centerIn: parent; running: shot.status === Image.Loading }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 24
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 10
                T { text: "Descripción"; font.pixelSize: 20; font.weight: Font.ExtraBold }
                T { Layout.fillWidth: true; text: pg.d.description || pg.d.summary || ""; wrapMode: Text.WordWrap; color: theme.muted; font.pixelSize: 14; lineHeight: 1.3; elide: Text.ElideNone }
            }
            Rectangle {
                Layout.preferredWidth: 300
                Layout.alignment: Qt.AlignTop
                implicitHeight: facts.implicitHeight + 32
                radius: 22
                color: theme.card
                ColumnLayout {
                    id: facts
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 16
                    spacing: 12
                    Repeater {
                        model: (pg.d.facts || []).filter(f => f[1])
                        ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 2
                            T { text: parent.modelData[0]; font.pixelSize: 11; font.weight: Font.Bold; color: theme.muted; font.capitalization: Font.AllUppercase }
                            T { Layout.fillWidth: true; text: parent.modelData[1]; font.pixelSize: 14 }
                        }
                    }
                }
            }
        }
    }
}
