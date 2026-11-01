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
    }
}
