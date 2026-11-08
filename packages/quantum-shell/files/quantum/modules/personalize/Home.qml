import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components

// Portada de Personalizar: tu estilo actual (con vista previa en vivo) y una tarjeta por sección, con un
// dibujo y un resumen de cómo la tienes. Al tocar una tarjeta se abre esa sección.
ColumnLayout {
    id: home
    spacing: 18
    signal go(string id)

    readonly property var styleNames: ({ quantum: "Quantum", clasico: "Clásico", moderno: "Moderno", muelle: "Muelle",
                                         gamer: "Gamer", minimal: "Minimal", custom: "Tu propio estilo" })
    readonly property string shapeNow: Settings.dock.shape && Settings.dock.shape !== "auto" ? Settings.dock.shape
        : !Settings.dock.floating && !Atomic.on ? "attached"
        : (Settings.layout.style === "single" || Settings.dock.position === "top") ? "floating" : "dock"

    // ------------------------------------------------------------ tu estilo
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 230
        radius: Theme.radiusLarge + 4
        clip: true
        color: Theme.surfaceContainer
        border.width: 1; border.color: Theme.alpha(Theme.fg, 0.06)
        MiniDesktop {
            id: mini
            anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.margins: 16
            width: height * 16 / 9
            v: Settings.visualState()
        }
        ColumnLayout {
            anchors.left: parent.left; anchors.right: mini.left; anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 26; anchors.rightMargin: 20
            spacing: 6
            Txt { text: "TU ESTILO ACTUAL"; font.pixelSize: Theme.textSmall; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Theme.primary }
            Txt { Layout.fillWidth: true; text: home.styleNames[Settings.ui.style] ?? Settings.ui.style; font.pixelSize: 32; font.weight: Font.Black; elide: Text.ElideRight }
            Txt { Layout.fillWidth: true; text: Serp.on ? "Con la forma Serpantium." : Atomic.on ? "Con la forma Atomic (cristal)." : "Con la forma Caelestial."
                  color: Theme.fgMuted }
            RowLayout {
                Layout.topMargin: 10
                spacing: 10
                PillButton { text: "Cambiar de estilo"; icon: "auto_awesome"; primary: true; onClicked: home.go("styles") }
                PillButton { text: "Compartir mi estilo"; icon: "ios_share"; onClicked: home.go("styles") }
            }
        }
    }

    // ------------------------------------------------------------ secciones
    GridLayout {
        Layout.fillWidth: true
        columns: home.width > 900 ? 4 : home.width > 640 ? 3 : 2
        columnSpacing: 14; rowSpacing: 14

        Tile {
            key: "colors"; title: "Fondo y colores"; icon: "wallpaper"
            summary: (Settings.appearance.mode === "light" ? "Claro" : "Oscuro") + " · " + (Settings.appearance.dynamicColors ? "colores del fondo" : "acento propio")
            Image {
                anchors.fill: parent
                readonly property string w: Settings.appearance.wallpaper
                source: w && w !== "quantum:live" ? Settings.stillUrl(w) : ""
                sourceSize: Qt.size(400, 220); fillMode: Image.PreserveAspectCrop; asynchronous: true
            }
            Image {
                visible: Settings.appearance.wallpaper === "quantum:live"
                anchors.centerIn: parent; height: parent.height * 0.8; width: height
                source: Quickshell.shellDir + "/assets/quantum-mark.svg"; sourceSize: Qt.size(160, 160)
            }
        }
        Tile {
            key: "bar"; title: "Barra de tareas"; icon: "dock_to_bottom"; badge: "Nuevo"
            summary: ({ floating: "Flotante", attached: "Pegada", dock: "Dock" })[home.shapeNow] + " · "
                     + (Settings.dock.position === "top" ? "arriba" : "abajo")
            Rectangle {
                readonly property bool atTop: Settings.dock.position === "top"
                readonly property real m: home.shapeNow === "attached" ? 0 : 10
                x: home.shapeNow === "dock" ? parent.width * 0.25 : m
                width: home.shapeNow === "dock" ? parent.width * 0.5 : parent.width - 2 * m
                height: 22; y: atTop ? m : parent.height - height - m
                radius: home.shapeNow === "attached" ? 0 : 9
                color: Theme.alpha(Theme.primary, 0.35); border.width: 1; border.color: Theme.alpha(Theme.fg, 0.15)
            }
        }
        Tile {
            key: "desktop"; title: "Escritorio"; icon: "desktop_windows"
            summary: (Settings.appearance.desktopIcons ?? true) ? "Con íconos" : "Sin íconos"
            Grid {
                x: 14; y: 14; columns: 2; spacing: 10
                Repeater { model: ["#4FD8FF", "#FFB04F", "#B14DFF"]; Rectangle { required property string modelData; width: 26; height: 26; radius: 7; color: Theme.alpha(modelData, 0.6) } }
            }
        }
        Tile {
            key: "windows"; title: "Ventanas"; icon: "web_asset"
            summary: ({ sharp: "Esquinas rectas", soft: "Esquinas suaves", round: "Esquinas redondas" })[Settings.windows.corners]
                     + " · " + ({ none: "sin animaciones", fast: "rápidas", normal: "animadas", smooth: "suaves" })[Settings.windows.animations]
            Rectangle {
                x: 22; y: 20; width: parent.width - 60; height: parent.height
                radius: ({ sharp: 3, soft: 10, round: 18 })[Settings.windows.corners]
                color: Theme.surfaceHighest; border.width: 1; border.color: Theme.alpha(Theme.fg, 0.12)
            }
        }
        Tile {
            key: "lock"; title: "Pantalla de bloqueo"; icon: "lock"
            summary: ((Settings.lock.left ?? []).length + (Settings.lock.right ?? []).length) + " tarjetas"
            Txt { anchors.centerIn: parent; text: Qt.formatTime(new Date(), Settings.clock.format24h ? "HH:mm" : "h:mm"); font.pixelSize: 34; font.weight: Font.Black }
        }
        Tile {
            key: "sounds"; title: "Sonidos"; icon: "music_note"
            summary: Settings.sounds.enabled ? "Estilo " + Settings.sounds.pack : "Desactivados"
            Icon { anchors.centerIn: parent; text: "graphic_eq"; size: 46; color: "#6EE7A6" }
        }
        Tile {
            key: "display"; title: "Pantalla"; icon: "brightness_6"
            summary: Settings.display.nightLight ? "Luz nocturna activada" : "Luz nocturna apagada"
            Icon { anchors.centerIn: parent; text: "nights_stay"; size: 46; fill: 1; color: "#FFB35C" }
        }
        Tile {
            key: "input"; title: "Mouse y touchpad"; icon: "mouse"
            summary: Settings.mouse.natural ? "Desplazamiento natural" : "Velocidad y clics"
            Icon { anchors.centerIn: parent; text: "mouse"; size: 46; color: "#9FB0FF" }
        }
    }

    PillButton {
        id: resetBtn
        Layout.alignment: Qt.AlignRight
        property bool sure: false
        text: sure ? "¿Seguro? Toca otra vez" : "Restablecer todo como viene Quantum"
        icon: "restart_alt"; danger: true
        onClicked: { if (!sure) { sure = true; sureTimer.restart(); return; } sure = false; Settings.resetAll(); }
        Timer { id: sureTimer; interval: 3000; onTriggered: resetBtn.sure = false }
    }

    // ------------------------------------------------------------ una tarjeta de sección
    component Tile: Rectangle {
        id: tile
        property string key: ""
        property string title: ""
        property string icon: ""
        property string summary: ""
        property string badge: ""
        default property alias art: artBox.data
        Layout.fillWidth: true
        implicitHeight: 196
        radius: Theme.radiusLarge
        clip: true
        color: area.containsMouse ? Theme.surfaceHigh : Theme.surfaceContainer
        border.width: 1; border.color: area.containsMouse ? Theme.alpha(Theme.primary, 0.45) : Theme.alpha(Theme.fg, 0.06)
        scale: area.pressed ? 0.97 : area.containsMouse ? 1.02 : 1
        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Rectangle {
            id: artBox
            width: parent.width; height: 116
            clip: true
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.alpha(Theme.primary, 0.14) }
                GradientStop { position: 1; color: Theme.alpha(Theme.primary, 0.03) }
            }
        }
        Rectangle {
            visible: tile.badge !== ""
            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10
            width: badgeT.implicitWidth + 16; height: 22; radius: 11; color: Qt.rgba(0, 0, 0, 0.6)
            Txt { id: badgeT; anchors.centerIn: parent; text: tile.badge; font.pixelSize: Theme.textSmall - 1; font.weight: Font.Bold; color: "white" }
        }
        ColumnLayout {
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: artBox.bottom
            anchors.margins: 14; anchors.topMargin: 12
            spacing: 3
            RowLayout {
                spacing: 8
                Icon { text: tile.icon; size: 19; color: Theme.primary }
                Txt { text: tile.title; font.weight: Font.Bold; font.pixelSize: Theme.textNormal + 1 }
            }
            Txt { Layout.fillWidth: true; text: tile.summary; color: Theme.fgMuted; font.pixelSize: Theme.textSmall + 1; elide: Text.ElideRight }
        }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: home.go(tile.key) }
    }
}
