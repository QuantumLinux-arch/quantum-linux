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
        T { text: "Tus apps"; font.pixelSize: 32; font.weight: Font.ExtraBold }
        T { text: "Lo que instalaste desde Flathub, la comunidad (AUR) y Android."; color: theme.muted; font.pixelSize: 15 }
        AppGrid { apps: (store.installed || []).concat(store.android.apps || []) }
        T {
            visible: !(store.installed || []).length && !(store.android.apps || []).length
            text: "Todavía no instalaste nada. Explora el Inicio."
            color: theme.muted; font.pixelSize: 16
        }
    }
}
