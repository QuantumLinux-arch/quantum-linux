import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Resultados agrupados por origen.
Flickable {
    id: pg
    objectName: "flick-buscar"
    contentHeight: col.implicitHeight + 40
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}
    readonly property var r: store.results || ({})
    readonly property var groups: [
        { src: "flathub", title: "Apps (Flathub)", note: "" },
        { src: "arch", title: "Paquetes de Arch", note: "" },
        { src: "aur", title: "Comunidad (AUR)", note: "Hechos por la comunidad, no revisados por Arch" },
        { src: "android", title: "Android (F-Droid)", note: "Se abren con Android dentro de Quantum" },
    ]
    ColumnLayout {
        id: col
        x: 20; y: 10
        width: pg.width - 40
        spacing: 16
        T { text: "Resultados para «" + (pg.r.query || "") + "»"; font.pixelSize: 26; font.weight: Font.ExtraBold }
        Repeater {
            model: pg.groups
            ColumnLayout {
                id: grp
                required property var modelData
                readonly property var apps: pg.r[modelData.src] || []
                readonly property bool loading: (store.busy || []).some(b => b.startsWith("search") && b.endsWith(":" + grp.modelData.src))
                Layout.fillWidth: true
                spacing: 10
                visible: apps.length > 0 || loading
                RowLayout {
                    spacing: 10
                    SourceChip { source: grp.modelData.src }
                    T { text: grp.modelData.title; font.pixelSize: 18; font.weight: Font.Bold }
                    T { text: grp.loading ? "buscando…" : grp.apps.length + " resultados"; color: theme.muted; font.pixelSize: 13 }
                }
                T { visible: grp.modelData.note !== ""; text: grp.modelData.note; color: theme.muted; font.pixelSize: 12 }
                AppGrid { apps: grp.apps.slice(0, 12) }
            }
        }
        T {
            visible: (store.busy || []).length === 0 && ["flathub", "arch", "aur", "android"].every(s => !(pg.r[s] || []).length)
            text: "No encontré nada. Prueba con otra palabra."
            color: theme.muted
            font.pixelSize: 16
        }
    }
}
