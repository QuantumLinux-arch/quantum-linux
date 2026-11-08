import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.components

// Íconos del escritorio (pantalla principal), como en Windows: clic para seleccionar, doble clic para abrir,
// arrastrar para moverlos de casilla y clic derecho para el menú. Van encima del fondo y debajo de las ventanas.
PanelWindow {
    id: win

    screen: Quickshell.screens[0]
    visible: Desktop.enabled && Desktop.dir !== ""
    WlrLayershell.namespace: "quantum-desktop-icons"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Normal          // respeta la barra y el dock
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    readonly property int cellW: 96
    readonly property int cellH: 108
    readonly property int pad: 14
    readonly property int rows: Math.max(1, Math.floor((height - 2 * pad) / cellH))
    readonly property int cols: Math.max(1, Math.floor((width - 2 * pad) / cellW))
    // se recalcula cuando cambian los archivos o las casillas guardadas
    property var slots: ({})
    function relayout(): void { slots = Desktop.layout(rows); }
    onRowsChanged: relayout()
    Connections { target: Desktop.files; function onCountChanged() { win.relayout(); } }
    Connections { target: Desktop; function onDirChanged() { win.relayout(); } }
    Timer { interval: 400; running: true; onTriggered: win.relayout() }   // la carpeta termina de leerse

    property string selected: ""
    // menú: "" = cerrado; si no, a qué ícono pertenece ("" de escritorio vacío → "\u0002")
    property string menuFor: ""
    property var menuItem: null
    property point menuAt: Qt.point(0, 0)
    function openMenu(key: string, item: var, x: real, y: real): void {
        menuFor = key; menuItem = item;
        menuAt = Qt.point(Math.min(x, width - menu.width - 8), Math.min(y, height - menu.height - 8));
    }
    function closeMenu(): void { menuFor = ""; menuItem = null; }

    // escritorio vacío: quitar la selección y menú del escritorio
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: e => {
            win.selected = "";
            if (e.button === Qt.RightButton) win.openMenu("\u0002", null, e.x, e.y);
            else win.closeMenu();
        }
    }

    // ------------------------------------------------------------ un ícono
    component DeskIcon: Item {
        id: ic
        property string key: ""           // nombre del archivo (o la Papelera)
        property string path: ""
        property string title: ""
        property string iconName: ""
        property string thumb: ""
        property bool isDesktopFile: false
        readonly property var slot: win.slots[key] ?? [0, 0]
        readonly property real homeX: win.pad + slot[0] * win.cellW
        readonly property real homeY: win.pad + slot[1] * win.cellH
        readonly property bool on: win.selected === key
        width: win.cellW; height: win.cellH
        x: homeX
        y: homeY
        z: area.drag.active ? 10 : 0
        Behavior on x { enabled: !area.drag.active; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: !area.drag.active; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        opacity: area.drag.active ? 0.8 : 1

        Rectangle {
            anchors.fill: parent; anchors.margins: 3
            radius: Theme.radiusSmall
            color: ic.on ? Theme.alpha(Theme.primary, 0.32) : area.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
            border.width: ic.on ? 1 : 0
            border.color: Theme.alpha(Theme.primary, 0.7)
        }
        Item {
            id: pic
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8; width: 52; height: 52
            AppIcon { anchors.centerIn: parent; size: 48; name: ic.iconName; visible: ic.thumb === "" }
            ClippingRectangle {
                visible: ic.thumb !== ""
                anchors.centerIn: parent
                width: 52; height: 40; radius: 6
                color: "transparent"
                border.width: 2; border.color: "white"
                Image { anchors.fill: parent; source: ic.thumb; sourceSize: Qt.size(104, 80); fillMode: Image.PreserveAspectCrop; asynchronous: true }
            }
        }
        // nombre con sombra, legible sobre cualquier fondo
        Txt {
            x: 5; y: pic.y + pic.height + 7; width: parent.width - 8
            horizontalAlignment: Text.AlignHCenter
            text: ic.title; color: Qt.rgba(0, 0, 0, 0.75)
            font.pixelSize: Theme.textSmall; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
        }
        Txt {
            x: 4; y: pic.y + pic.height + 6; width: parent.width - 8
            horizontalAlignment: Text.AlignHCenter
            text: ic.title; color: "white"
            font.pixelSize: Theme.textSmall; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            drag.target: ic
            drag.threshold: 8
            onPressed: e => {
                win.selected = ic.key;
                if (e.button === Qt.RightButton) {
                    const p = ic.mapToItem(win.contentItem, e.x, e.y);
                    win.openMenu(ic.key, ic, p.x, p.y);
                } else win.closeMenu();
            }
            onDoubleClicked: e => { if (e.button === Qt.LeftButton) Desktop.open(ic.path, ic.isDesktopFile); }
            onReleased: {
                if (!drag.active && ic.x === ic.homeX && ic.y === ic.homeY) return;
                // a la casilla más cercana
                const c = Math.max(0, Math.min(win.cols - 1, Math.round((ic.x - win.pad) / win.cellW)));
                const r = Math.max(0, Math.min(win.rows - 1, Math.round((ic.y - win.pad) / win.cellH)));
                Desktop.move(ic.key, c, r, win.slots);
                win.relayout();
                ic.x = Qt.binding(() => ic.homeX); ic.y = Qt.binding(() => ic.homeY);
            }
        }
    }

    // ------------------------------------------------------------ los íconos
    DeskIcon {
        key: "\u0001papelera"
        path: "trash"
        title: "Papelera"
        iconName: Desktop.trashFull ? "user-trash-full" : "user-trash"
    }
    Repeater {
        model: Desktop.files
        DeskIcon {
            id: f
            required property string fileName
            required property string filePath
            required property bool fileIsDir
            required property string fileSuffix
            readonly property string ext: fileSuffix.toLowerCase()
            key: fileName
            path: filePath
            isDesktopFile: !fileIsDir && ext === "desktop"
            // los .desktop muestran el nombre y el ícono de la app
            title: isDesktopFile ? (entry.name || fileName.replace(/\.desktop$/, "")) : fileName
            iconName: fileIsDir ? "folder" : isDesktopFile ? entry.icon : Desktop.iconForSuffix(ext)
            thumb: !fileIsDir && ["png", "jpg", "jpeg", "webp", "gif", "bmp"].includes(ext) ? "file://" + filePath : ""

            QtObject {
                id: entry
                property string name: ""
                property string icon: "application-x-executable"
            }
            FileView {
                path: f.isDesktopFile ? f.filePath : ""
                printErrors: false
                onLoaded: {
                    const t = text();
                    const sec = t.split(/^\[/m).find(s => s.startsWith("Desktop Entry]")) ?? t;
                    const loc = Qt.locale().name;                 // p. ej. es_CL
                    const get = k => {
                        for (const key of [k + "[" + loc + "]", k + "[" + loc.split("_")[0] + "]", k]) {
                            const m = sec.match(new RegExp("^" + key.replace(/[\[\]]/g, "\\$&") + "=(.*)$", "m"));
                            if (m) return m[1].trim();
                        }
                        return "";
                    };
                    entry.name = get("Name");
                    entry.icon = get("Icon") || "application-x-executable";
                }
            }
        }
    }

    // ------------------------------------------------------------ menú de clic derecho
    Rectangle {
        id: menu
        visible: win.menuFor !== ""
        x: win.menuAt.x; y: win.menuAt.y
        width: 230
        height: col.implicitHeight + 12
        radius: Theme.radius
        color: Theme.alpha(Theme.surface, 0.97)
        border.width: 1; border.color: Theme.outlineVariant
        z: 100
        readonly property bool onTrash: win.menuFor === "\u0001papelera"
        readonly property bool onEmpty: win.menuFor === "\u0002"
        readonly property var items: onEmpty ? [
                { i: "create_new_folder", t: "Nueva carpeta", f: () => Desktop.newFolder() },
                { i: "folder_open", t: "Abrir la carpeta Escritorio", f: () => Desktop.open(Desktop.dir, false) },
                { i: "wallpaper", t: "Cambiar fondo de pantalla", f: () => Shell.toggleWallpapers() },
                { i: "palette", t: "Personalizar", f: () => Shell.personalize() },
            ] : onTrash ? [
                { i: "open_in_new", t: "Abrir", f: () => Desktop.open("trash", false) },
                { i: "delete_forever", t: "Vaciar la papelera", f: () => Desktop.emptyTrash(), danger: true },
            ] : [
                { i: "open_in_new", t: "Abrir", f: () => Desktop.open(win.menuItem.path, win.menuItem.isDesktopFile) },
                { i: "folder_open", t: "Mostrar en Archivos", f: () => Desktop.showInFiles(win.menuItem.path) },
                { i: "delete", t: "Mover a la papelera", f: () => Desktop.toTrash(win.menuItem.path), danger: true },
            ]
        Column {
            id: col
            x: 6; y: 6; width: parent.width - 12
            Repeater {
                model: menu.items
                Rectangle {
                    id: row
                    required property var modelData
                    width: col.width; height: 38; radius: Theme.radiusSmall
                    color: rowArea.containsMouse ? Theme.surfaceHigh : "transparent"
                    Icon { x: 12; anchors.verticalCenter: parent.verticalCenter; text: row.modelData.i; size: 19
                           color: row.modelData.danger ? Theme.error : Theme.fgMuted }
                    Txt { x: 42; anchors.verticalCenter: parent.verticalCenter; text: row.modelData.t
                          color: row.modelData.danger ? Theme.error : Theme.fg }
                    MouseArea {
                        id: rowArea
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { const f = row.modelData.f; win.closeMenu(); f(); }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "desktop"
        function pin(id: string): void { Desktop.pinApp(id); }
        function newFolder(): void { Desktop.newFolder(); }
    }
}
