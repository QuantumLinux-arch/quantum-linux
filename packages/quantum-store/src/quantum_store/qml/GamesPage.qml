import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
    id: pg
    contentHeight: col.implicitHeight + 40
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}
    ColumnLayout {
        id: col
        x: 20; y: 10
        width: pg.width - 40
        spacing: 18
        T { text: "Juegos"; font.pixelSize: 32; font.weight: Font.ExtraBold }
        T { text: "Tiendas de juegos, emuladores y juegos para Linux. Steam ya viene instalado."; color: theme.muted; font.pixelSize: 15 }
        AppGrid { apps: (store.home || {}).games || [] }
        RowLayout {
            Layout.topMargin: 16
            spacing: 10
            Sym { text: "android"; size: 24; fill: 1; color: "#3DDC84" }
            T { text: "Juegos de Android"; font.pixelSize: 20; font.weight: Font.ExtraBold }
        }
        T {
            visible: !(store.android.games || []).length
            text: "Activa Android en la sección Android para ver juegos de F-Droid."
            color: theme.muted
        }
        AppGrid { apps: store.android.games || [] }
    }
}
