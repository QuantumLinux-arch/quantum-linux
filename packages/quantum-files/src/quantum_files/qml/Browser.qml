import QtQuick

// Contenido de una carpeta, en cuadrícula (miniaturas) o en lista (detalles).
// Selección como en Windows: clic, Ctrl + clic, Mayús + clic y arrastrar un recuadro
// sobre el espacio vacío. Se puede arrastrar archivos a otras carpetas o a otras apps.
Item {
    id: br

    property var rawItems: []
    property string folder: ""            // carpeta donde caen los archivos soltados ("" = no se puede)
    property bool trashMode: false
    property bool searchMode: false
    property string emptyText: "Esta carpeta está vacía"
    property string emptyHint: "Arrastra archivos aquí o usa «Nuevo»."
    readonly property bool listMode: fm.prefs.view === "list"
    readonly property real zoom: fm.prefs.iconSize || 1

    signal activate(var entry)
    signal menuAt(var entry, real x, real y)
    signal dropped(var paths, string dest, bool copy)
    signal selectionChanged()

    // ---------------------------------------------------------------- orden y filtro
    readonly property var items: {
        const hidden = fm.prefs.showHidden;
        const key = fm.prefs.sortKey || "name", asc = fm.prefs.sortAsc !== false;
        const list = rawItems.filter(i => hidden || !i.hidden);
        const cmpName = (a, b) => a.name.localeCompare(b.name, "es", { numeric: true, sensitivity: "base" });
        list.sort((a, b) => {
            if (a.dir !== b.dir) return a.dir ? -1 : 1;           // carpetas primero
            let r = 0;
            if (key === "mtime") r = a.mtime - b.mtime;
            else if (key === "size") r = a.size - b.size;
            else if (key === "type") r = a.desc.localeCompare(b.desc, "es");
            if (r === 0) r = cmpName(a, b);
            return asc ? r : -r;
        });
        return list;
    }
    onItemsChanged: {
        // conserva la selección de lo que sigue existiendo
        const keep = {};
        let n = 0;
        for (const it of items) if (sel[it.path]) { keep[it.path] = true; n++; }
        sel = keep; selCount = n;
        if (pendingSelect !== "") { selectOnly(pendingSelect); if (pendingRename) startRename(pendingSelect); pendingSelect = ""; pendingRename = false; }
    }

    // ---------------------------------------------------------------- selección
    property var sel: ({})
    property int selCount: 0
    property int anchor: -1
    property int current: -1
    property string pendingSelect: ""
    property bool pendingRename: false
    onSelCountChanged: selectionChanged()

    function selectedPaths() { return items.filter(i => sel[i.path]).map(i => i.path); }
    function selectedEntries() { return items.filter(i => sel[i.path]); }
    function clear() { sel = ({}); selCount = 0; selectionChanged(); }
    function selectAll() { const s = {}; for (const i of items) s[i.path] = true; sel = s; selCount = items.length; selectionChanged(); }
    function selectOnly(path) {
        const s = {}; s[path] = true; sel = s; selCount = 1;
        current = anchor = items.findIndex(i => i.path === path);
        if (current >= 0) view.positionViewAtIndex(current, GridView.Contain);
        selectionChanged();
    }
    function clickSelect(index, mods) {
        const it = items[index];
        if (mods & Qt.ShiftModifier && anchor >= 0) {
            const s = (mods & Qt.ControlModifier) ? Object.assign({}, sel) : {};
            for (let i = Math.min(anchor, index); i <= Math.max(anchor, index); i++) s[items[i].path] = true;
            sel = s;
        } else if (mods & Qt.ControlModifier) {
            const s = Object.assign({}, sel);
            if (s[it.path]) delete s[it.path]; else s[it.path] = true;
            sel = s; anchor = index;
        } else {
            const s = {}; s[it.path] = true; sel = s; anchor = index;
        }
        current = index;
        selCount = Object.keys(sel).length;
        selectionChanged();
    }
    function move(dx, dy, mods) {
        if (!items.length) return;
        const cols = listMode ? 1 : Math.max(1, Math.floor(view.width / view.cellWidth));
        let i = current < 0 ? 0 : current + dx + dy * cols;
        i = Math.max(0, Math.min(items.length - 1, i));
        if (mods & Qt.ShiftModifier) { clickSelect(i, Qt.ShiftModifier); }
        else { clickSelect(i, 0); }
        view.positionViewAtIndex(i, GridView.Contain);
    }

    // ---------------------------------------------------------------- renombrar en el lugar
    property string renaming: ""
    property string renameError: ""
    function startRename(path) { renaming = path; renameError = ""; }
    function finishRename(path, text) {
        if (renaming !== path) return;
        const it = items.find(i => i.path === path);
        if (it && text !== it.name) {
            const err = fm.rename(path, text);
            if (err) { renameError = err; return; }
            pendingSelect = fm.parentOf(path) + "/" + text.trim();
        }
        renaming = "";
    }

    // ---------------------------------------------------------------- arrastrar
    property bool dragging: false
    Item {
        id: dragProxy
        width: 1; height: 1
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
        Drag.proposedAction: Qt.MoveAction
        Drag.onDragFinished: br.dragging = false
    }
    function startDrag(entry) {
        if (!sel[entry.path]) { const s = {}; s[entry.path] = true; sel = s; selCount = 1; }
        const uris = fm.uriList(selectedPaths());
        dragProxy.Drag.mimeData = { "text/uri-list": uris.join("\r\n") };
        dragProxy.Drag.imageSource = "";
        br.dragging = true;
        dragProxy.Drag.active = true;
    }
    function handleDrop(drop, dest) {
        if (!dest || !drop.hasUrls) return;
        const paths = fm.localPaths(drop.urls).filter(p => p !== dest);
        if (!paths.length) return;
        // desde esta misma ventana se mueve (Ctrl = copiar); desde otras apps se copia
        const copy = !br.dragging || (drop.modifiers & Qt.ControlModifier);
        drop.acceptProposedAction();
        br.dropped(paths, dest, copy);
    }

    // ---------------------------------------------------------------- vistas
    GridView {
        id: view
        anchors.fill: parent
        anchors.leftMargin: br.listMode ? 0 : 18
        anchors.topMargin: br.listMode ? 0 : 14
        clip: true
        model: br.items
        cellWidth: br.listMode ? width : Math.round(176 * br.zoom)
        cellHeight: br.listMode ? 44 : Math.round(176 * br.zoom) + 4
        boundsBehavior: Flickable.StopAtBounds
        interactive: false                    // la rueda sigue funcionando; arrastrar = recuadro
        header: br.listMode ? listHeader : null
        cacheBuffer: 600
        delegate: br.listMode ? rowDelegate : tileDelegate

        WheelHandler {
            onWheel: e => view.contentY = Math.max(view.originY, Math.min(view.contentY - e.angleDelta.y * 1.2,
                                                   view.originY + Math.max(0, view.contentHeight - view.height)))
        }

        // recuadro de selección sobre el espacio vacío (coordenadas del contenido)
        MouseArea {
            id: band
            z: -1
            parent: view.contentItem
            x: 0; y: view.originY
            width: Math.max(view.width, view.contentWidth); height: Math.max(view.height, view.contentHeight) + 400
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            preventStealing: true
            property point p0
            property bool active: false
            property var base: ({})
            function at(e) { return mapToItem(view.contentItem, e.x, e.y); }
            onPressed: e => {
                br.forceActiveFocus();
                if (e.button === Qt.RightButton) return;
                p0 = at(e); active = false;
                base = (e.modifiers & Qt.ControlModifier) ? Object.assign({}, br.sel) : {};
                if (!(e.modifiers & (Qt.ControlModifier | Qt.ShiftModifier))) br.clear();
            }
            onPositionChanged: e => {
                if (!(e.buttons & Qt.LeftButton)) return;
                const p = at(e);
                if (!active && Math.abs(p.x - p0.x) + Math.abs(p.y - p0.y) < 6) return;
                active = true;
                rect.x = Math.min(p0.x, p.x); rect.y = Math.min(p0.y, p.y);
                rect.width = Math.abs(p.x - p0.x); rect.height = Math.abs(p.y - p0.y);
                const s = Object.assign({}, base);
                const cols = br.listMode ? 1 : Math.max(1, Math.floor(view.width / view.cellWidth));
                const first = view.itemAtIndex(0);
                const top = first ? first.y : (br.listMode ? 36 : 0);
                for (let i = 0; i < br.items.length; i++) {
                    const cx = br.listMode ? 0 : (i % cols) * view.cellWidth, cy = top + Math.floor(i / cols) * view.cellHeight;
                    const cw = br.listMode ? view.width : view.cellWidth - 14, ch = view.cellHeight - (br.listMode ? 2 : 14);
                    if (cx < rect.x + rect.width && cx + cw > rect.x && cy < rect.y + rect.height && cy + ch > rect.y)
                        s[br.items[i].path] = true;
                }
                br.sel = s; br.selCount = Object.keys(s).length;
                // al llegar al borde, se desplaza
                const vy = p.y - view.contentY;
                if (vy > view.height - 20) view.contentY = Math.min(view.contentY + 14, view.originY + Math.max(0, view.contentHeight - view.height));
                else if (vy < 20) view.contentY = Math.max(view.originY, view.contentY - 14);
            }
            onReleased: { active = false; rect.width = 0; br.selectionChanged(); }
            onClicked: e => {
                if (e.button === Qt.RightButton) {
                    br.clear();
                    const p = mapToItem(null, e.x, e.y); br.menuAt(null, p.x, p.y);
                }
            }
        }
        Rectangle {
            id: rect
            parent: view.contentItem
            z: 50
            visible: band.active && width > 0
            color: theme.alpha(theme.accentStrong, 0.15)
            border.width: 1; border.color: theme.accent
            radius: 4
        }
        DropArea {
            anchors.fill: parent
            parent: view
            z: -2
            enabled: br.folder !== ""
            onDropped: drop => br.handleDrop(drop, br.folder)
        }
    }

    // vacía
    Column {
        anchors.centerIn: parent
        visible: br.items.length === 0
        spacing: 10
        Sym { anchors.horizontalCenter: parent.horizontalCenter; text: br.trashMode ? "delete" : br.searchMode ? "search_off" : "folder_open"; size: 64; color: theme.alpha(theme.fg, 0.25) }
        T { anchors.horizontalCenter: parent.horizontalCenter; text: br.emptyText; font.pixelSize: 17; font.weight: Font.DemiBold; color: theme.muted }
        T { anchors.horizontalCenter: parent.horizontalCenter; text: br.emptyHint; font.pixelSize: 13; color: theme.muted; opacity: 0.8 }
    }

    // ---------------------------------------------------------------- cuadrícula
    Component {
        id: tileDelegate
        Item {
            id: tile
            required property var modelData
            required property int index
            readonly property bool on: !!br.sel[modelData.path]
            readonly property bool cut: false
            width: view.cellWidth; height: view.cellHeight
            Rectangle {
                id: bgTile
                anchors.fill: parent; anchors.rightMargin: 14; anchors.bottomMargin: 14
                radius: theme.r
                color: tile.on ? theme.accentSoft : tma.containsMouse || drop.containsDrag ? theme.alpha(theme.fg, 0.06) : "transparent"
                border.width: tile.on || drop.containsDrag ? 2 : 0
                border.color: theme.accent
                Behavior on color { ColorAnimation { duration: 100 } }

                // miniatura o ícono
                Item {
                    id: pic
                    x: 10; y: 10; width: parent.width - 20; height: parent.height - 52
                    Rectangle {
                        anchors.fill: parent; radius: theme.r - 4; color: theme.cardHi; clip: true
                        visible: thumb.status === Image.Ready
                        Image {
                            id: thumb
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true; cache: true
                            source: tile.modelData.thumb
                            sourceSize: Qt.size(Math.round(320 * br.zoom), Math.round(240 * br.zoom))
                        }
                    }
                    Image {
                        visible: thumb.status !== Image.Ready
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) * 0.86; height: width
                        source: tile.modelData.dir ? theme.icon("folder-" + theme.folderColor + ",folder") : theme.icon(tile.modelData.icon)
                        sourceSize: Qt.size(128, 128)
                        asynchronous: true
                        opacity: tile.modelData.hidden ? 0.55 : 1
                    }
                }
                // check de seleccionado
                Rectangle {
                    visible: tile.on
                    x: 16; y: 16; width: 24; height: 24; radius: 12; color: theme.accentStrong
                    Sym { anchors.centerIn: parent; text: "check"; size: 17; color: theme.accentFg }
                }
                // nombre (o campo para renombrar)
                T {
                    visible: br.renaming !== tile.modelData.path
                    x: 8; y: pic.y + pic.height + 6; width: parent.width - 16; height: 34
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignTop
                    wrapMode: Text.WrapAnywhere; maximumLineCount: 2; elide: Text.ElideRight
                    text: tile.modelData.name; font.pixelSize: 13; lineHeight: 0.95
                    opacity: tile.modelData.hidden ? 0.6 : 1
                }
                Loader {
                    active: br.renaming === tile.modelData.path
                    x: 4; y: pic.y + pic.height + 2; width: parent.width - 8; height: 30
                    sourceComponent: renameField
                    onLoaded: item.entry = tile.modelData
                }
                MouseArea {
                    id: tma
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    property point p0
                    property bool armed: false
                    onPressed: e => {
                        br.forceActiveFocus();
                        p0 = Qt.point(e.x, e.y); armed = e.button === Qt.LeftButton;
                        if (e.button === Qt.LeftButton && !tile.on) br.clickSelect(tile.index, e.modifiers);
                    }
                    onPositionChanged: e => {
                        if (armed && !br.trashMode && Math.abs(e.x - p0.x) + Math.abs(e.y - p0.y) > 10) { armed = false; br.startDrag(tile.modelData); }
                    }
                    onClicked: e => {
                        if (e.button === Qt.RightButton) {
                            if (!tile.on) br.clickSelect(tile.index, 0);
                            const p = mapToItem(null, e.x, e.y); br.menuAt(tile.modelData, p.x, p.y);
                        } else if (e.button === Qt.MiddleButton && tile.modelData.dir) {
                            br.activate(Object.assign({ newTab: true }, tile.modelData));
                        } else if (tile.on && !(e.modifiers & (Qt.ShiftModifier | Qt.ControlModifier)) && br.selCount > 1) {
                            br.clickSelect(tile.index, 0);
                        } else if (tile.on && (e.modifiers & Qt.ControlModifier)) {
                            br.clickSelect(tile.index, e.modifiers);
                        }
                    }
                    onDoubleClicked: e => { if (e.button === Qt.LeftButton) br.activate(tile.modelData); }
                }
                DropArea {
                    id: drop
                    anchors.fill: parent
                    enabled: tile.modelData.dir && !tile.on && !br.trashMode
                    onDropped: d => br.handleDrop(d, tile.modelData.path)
                }
            }
        }
    }

    // ---------------------------------------------------------------- lista con detalles
    readonly property var cols: [0.46, 0.22, 0.2, 0.12]
    Component {
        id: listHeader
        Item {
            width: view.width; height: 36
            Row {
                x: 18; anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: [["name", "Nombre"], ["mtime", "Modificado"], ["type", "Tipo"], ["size", "Tamaño"]]
                    Item {
                        required property var modelData
                        required property int index
                        width: (view.width - 36) * br.cols[index]; height: 30
                        Row {
                            anchors.verticalCenter: parent.verticalCenter; spacing: 4
                            T { text: parent.parent.modelData[1]; font.pixelSize: 12; font.weight: Font.Bold; color: fm.prefs.sortKey === parent.parent.modelData[0] ? theme.accent : theme.muted }
                            Sym { visible: fm.prefs.sortKey === parent.parent.modelData[0]; text: fm.prefs.sortAsc !== false ? "arrow_upward" : "arrow_downward"; size: 14; color: theme.accent }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const k = parent.modelData[0];
                                if (fm.prefs.sortKey === k) fm.setPref("sortAsc", fm.prefs.sortAsc === false);
                                else { fm.setPref("sortKey", k); fm.setPref("sortAsc", k === "name" || k === "type"); }
                            }
                        }
                    }
                }
            }
            Rectangle { anchors.bottom: parent.bottom; x: 10; width: parent.width - 20; height: 1; color: theme.line }
        }
    }
    Component {
        id: rowDelegate
        Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool on: !!br.sel[modelData.path]
            width: view.width; height: view.cellHeight
            Rectangle {
                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; anchors.topMargin: 1; anchors.bottomMargin: 1
                radius: 8
                color: row.on ? theme.accentSoft : rma.containsMouse || rdrop.containsDrag ? theme.alpha(theme.fg, 0.05) : "transparent"
                border.width: rdrop.containsDrag ? 1 : 0; border.color: theme.accent
                Image {
                    x: 10; anchors.verticalCenter: parent.verticalCenter; width: 26; height: 26
                    source: row.modelData.dir ? theme.icon("folder-" + theme.folderColor + ",folder") : theme.icon(row.modelData.icon)
                    sourceSize: Qt.size(52, 52); asynchronous: true
                    opacity: row.modelData.hidden ? 0.55 : 1
                }
                readonly property real w: view.width - 36
                T { visible: br.renaming !== row.modelData.path; x: 46; width: parent.w * br.cols[0] - 40; anchors.verticalCenter: parent.verticalCenter; text: row.modelData.name; font.weight: row.on ? Font.DemiBold : Font.Normal }
                Loader {
                    active: br.renaming === row.modelData.path
                    x: 42; width: parent.w * br.cols[0] - 40; height: 30; anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: renameField
                    onLoaded: item.entry = row.modelData
                }
                T { x: 10 + parent.w * br.cols[0]; width: parent.w * br.cols[1]; anchors.verticalCenter: parent.verticalCenter; text: br.trashMode ? (row.modelData.origin || "") : fm.dateText(row.modelData.mtime); color: theme.muted; font.pixelSize: 13 }
                T { x: 10 + parent.w * (br.cols[0] + br.cols[1]); width: parent.w * br.cols[2]; anchors.verticalCenter: parent.verticalCenter; text: row.modelData.desc; color: theme.muted; font.pixelSize: 13 }
                T { x: 10 + parent.w * (br.cols[0] + br.cols[1] + br.cols[2]); width: parent.w * br.cols[3]; anchors.verticalCenter: parent.verticalCenter; text: row.modelData.dir ? "" : fm.sizeText(row.modelData.size); color: theme.muted; font.pixelSize: 13 }
                MouseArea {
                    id: rma
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    property point p0
                    property bool armed: false
                    onPressed: e => {
                        br.forceActiveFocus();
                        p0 = Qt.point(e.x, e.y); armed = e.button === Qt.LeftButton;
                        if (e.button === Qt.LeftButton && !row.on) br.clickSelect(row.index, e.modifiers);
                    }
                    onPositionChanged: e => { if (armed && !br.trashMode && Math.abs(e.x - p0.x) + Math.abs(e.y - p0.y) > 10) { armed = false; br.startDrag(row.modelData); } }
                    onClicked: e => {
                        if (e.button === Qt.RightButton) {
                            if (!row.on) br.clickSelect(row.index, 0);
                            const p = mapToItem(null, e.x, e.y); br.menuAt(row.modelData, p.x, p.y);
                        } else if (e.button === Qt.MiddleButton && row.modelData.dir) {
                            br.activate(Object.assign({ newTab: true }, row.modelData));
                        } else if (row.on && !(e.modifiers & (Qt.ShiftModifier | Qt.ControlModifier)) && br.selCount > 1) {
                            br.clickSelect(row.index, 0);
                        } else if (row.on && (e.modifiers & Qt.ControlModifier)) {
                            br.clickSelect(row.index, e.modifiers);
                        }
                    }
                    onDoubleClicked: e => { if (e.button === Qt.LeftButton) br.activate(row.modelData); }
                }
                DropArea {
                    id: rdrop
                    anchors.fill: parent
                    enabled: row.modelData.dir && !row.on && !br.trashMode
                    onDropped: d => br.handleDrop(d, row.modelData.path)
                }
            }
        }
    }

    // campo para renombrar: selecciona el nombre sin la extensión, como Windows
    Component {
        id: renameField
        Rectangle {
            property var entry
            radius: 6; color: theme.bg
            border.width: 2; border.color: br.renameError ? theme.danger : theme.accent
            TextInput {
                id: ti
                anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: br.listMode ? TextInput.AlignLeft : TextInput.AlignHCenter
                font.family: theme.font; font.pixelSize: 13; color: theme.fg
                selectionColor: theme.accentStrong; selectedTextColor: theme.accentFg
                clip: true
                // el archivo llega después de crear el campo (Loader.onLoaded): se prepara ahí
                function prepare() {
                    if (!parent.entry) return;
                    text = parent.entry.name;
                    forceActiveFocus();
                    const dot = !parent.entry.dir ? text.lastIndexOf(".") : -1;
                    select(0, dot > 0 ? dot : text.length);
                }
                Connections { target: ti.parent; function onEntryChanged() { ti.prepare(); } }
                Component.onCompleted: prepare()
                onAccepted: br.finishRename(parent.entry.path, text)
                Keys.onEscapePressed: { br.renaming = ""; br.forceActiveFocus(); }
                onActiveFocusChanged: if (!activeFocus && br.renaming === parent.entry.path) br.finishRename(parent.entry.path, text)
            }
            Rectangle {
                visible: br.renameError !== ""
                anchors.top: parent.bottom; anchors.topMargin: 4
                width: et.implicitWidth + 16; height: 26; radius: 6; color: theme.danger; z: 10
                T { id: et; anchors.centerIn: parent; text: br.renameError; font.pixelSize: 12; color: "white" }
            }
        }
    }

    // ---------------------------------------------------------------- teclado (flechas y Enter)
    focus: true
    Keys.onLeftPressed: e => move(-1, 0, e.modifiers)
    Keys.onRightPressed: e => move(1, 0, e.modifiers)
    Keys.onUpPressed: e => move(0, -1, e.modifiers)
    Keys.onDownPressed: e => move(0, 1, e.modifiers)
    function openSelected() { const s = selectedEntries(); if (s.length === 1) br.activate(s[0]); else if (s.length) fm.open(s.filter(i => !i.dir).map(i => i.path)); }
    Keys.onReturnPressed: openSelected()
    Keys.onEnterPressed: openSelected()
}
