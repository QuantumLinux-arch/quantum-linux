import QtQuick
import QtQuick.Window

// Archivos: ventana principal. Sin barra de título del sistema: las pestañas y los
// botones de ventana van arriba, como en Windows 11 (se arrastra desde ahí).
Window {
    id: win
    width: 1320; height: 820
    minimumWidth: 760; minimumHeight: 480
    visible: true
    title: currentTitle + " — Archivos"
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint

    Theme { id: theme }

    // ---------------------------------------------------------------- pestañas e historial
    // Rutas especiales: quantum:home, quantum:recent, quantum:favorites, quantum:trash, quantum:search
    property var tabs: []
    property int cur: 0
    readonly property var tab: tabs[cur] || { path: "quantum:home", back: [], fwd: [] }
    readonly property string path: tab.path
    readonly property bool special: path.indexOf("quantum:") === 0
    readonly property string currentTitle: titleFor(path)
    property string searchQuery: ""
    property string searchFolder: ""
    property int searchToken: 0
    property bool searching: false
    property string loadError: ""
    property bool showDetails: fm.prefs.details !== false

    function titleFor(p) {
        if (p === "quantum:home") return "Inicio";
        if (p === "quantum:recent") return "Recientes";
        if (p === "quantum:favorites") return "Favoritos";
        if (p === "quantum:trash") return "Papelera";
        if (p === "quantum:search") return "Buscar «" + searchQuery + "»";
        if (p === fm.home) return fm.userName;
        if (p === "/") return "Quantum";
        const pl = fm.places.find(x => x.path === p);
        if (pl) return pl.name;
        const dr = fm.drives.find(x => x.mount === p);
        if (dr) return dr.name;
        return p.split("/").pop();
    }
    function iconFor(p) {
        return p === "quantum:home" ? "home" : p === "quantum:recent" ? "schedule" : p === "quantum:favorites" ? "star"
             : p === "quantum:trash" ? "delete" : p === "quantum:search" ? "search" : "folder";
    }
    function setTab(t) { const a = tabs.slice(); a[cur] = t; tabs = a; }
    function go(p, push) {
        if (!p) return;
        if (p.indexOf("quantum:") !== 0 && !fm.isDir(p)) { toast("Esa carpeta no existe"); return; }
        if (p === path && push !== false) { reload(); return; }
        const t = Object.assign({}, tab);
        if (push !== false) { t.back = tab.back.concat([tab.path]).slice(-50); t.fwd = []; }
        t.path = p;
        setTab(t);
        reload();
    }
    function goBack() { if (!tab.back.length) return; const t = Object.assign({}, tab); t.fwd = [t.path].concat(t.fwd); t.path = t.back[t.back.length - 1]; t.back = t.back.slice(0, -1); setTab(t); reload(); }
    function goForward() { if (!tab.fwd.length) return; const t = Object.assign({}, tab); t.back = t.back.concat([t.path]); t.path = t.fwd[0]; t.fwd = t.fwd.slice(1); setTab(t); reload(); }
    function goUp() { if (!special && path !== "/") go(fm.parentOf(path)); }
    function newTab(p) { tabs = tabs.concat([{ path: p || "quantum:home", back: [], fwd: [] }]); cur = tabs.length - 1; reload(); }
    function closeTab(i) {
        if (tabs.length === 1) { win.close(); return; }
        const a = tabs.slice(); a.splice(i, 1); tabs = a;
        if (cur >= tabs.length) cur = tabs.length - 1; else if (i < cur) cur--;
        reload();
    }
    function switchTab(i) { cur = i; reload(); }

    function reload() {
        loadError = "";
        browser.renaming = "";
        if (path !== "quantum:search") { searching = false; }
        if (path === "quantum:home") { home.refresh(); return; }
        if (path === "quantum:trash") { browser.rawItems = fm.trashList(); return; }
        if (path === "quantum:recent") { browser.rawItems = fm.recent(); return; }
        if (path === "quantum:favorites") { browser.rawItems = (fm.prefs.favorites || []).filter(p => fm.isDir(p) || true).map(p => fm.info(p)).filter(e => e.mtime > 0); return; }
        if (path === "quantum:search") return;
        const r = fm.list(path);
        loadError = r.ok ? "" : r.error;
        browser.rawItems = r.items;
    }
    function startSearch(q) {
        q = q.trim();
        if (!q) { if (path === "quantum:search") goBack(); return; }
        searchQuery = q;
        searchFolder = special ? (path === "quantum:search" ? searchFolder : fm.home) : path;
        if (path !== "quantum:search") go("quantum:search"); else setTab(tab);
        browser.rawItems = [];
        searching = true;
        searchToken = fm.search(searchFolder, q);
    }
    Connections {
        target: fm
        function onSearchResults(token, items, done) {
            if (token !== win.searchToken || win.path !== "quantum:search") return;
            browser.rawItems = browser.rawItems.concat(items);
            if (done) win.searching = false;
        }
        function onDirChanged(p) { if (p === win.path) win.reload(); }
        function onToast(msg) { win.toast(msg); }
        function onJobFinished(title, err) {
            win.toast(err ? (err === "Cancelado" ? "Cancelado" : err) : "Listo: " + title.charAt(0).toLowerCase() + title.slice(1));
            if (win.path === "quantum:trash") win.reload();
        }
        function onPrefsChanged() { if (win.path === "quantum:favorites") win.reload(); }
        function onDrivesChanged() { if (win.path === "quantum:home") home.refresh(); }
    }

    Component.onCompleted: {
        const start = startPaths && startPaths.length ? startPaths : ["quantum:home"];
        tabs = start.map(p => ({ path: p, back: [], fwd: [] }));
        cur = 0;
        reload();
        if (demoAction) demo.start();
    }

    // ---------------------------------------------------------------- acciones
    readonly property var selected: { browser.sel; browser.items; return browser.selectedEntries(); }
    function selPaths() { return browser.selectedPaths(); }
    function openEntry(e) {
        if (!e) return;
        if (e.dir) { if (e.newTab) newTab(e.path); else go(e.path); }
        else if (path === "quantum:trash") toast("Restáuralo para abrirlo");
        else fm.open([e.path]);
    }
    function copy() { const p = selPaths(); if (p.length && path !== "quantum:trash") fm.setClipboard(p, false); }
    function cut() { const p = selPaths(); if (p.length && path !== "quantum:trash") fm.setClipboard(p, true); }
    function paste() { if (!special) fm.paste(path); }
    function rename() { const s = browser.selectedEntries(); if (s.length === 1 && path !== "quantum:trash") browser.startRename(s[0].path); }
    function del(forever) {
        const p = selPaths();
        if (!p.length) return;
        if (forever || path === "quantum:trash") confirm.ask(p);
        else fm.trash(p);
    }
    function newFolder() {
        if (special) return;
        const p = fm.newFolder(path, "Nueva carpeta");
        if (p) { browser.pendingSelect = p; browser.pendingRename = true; reload(); }
    }
    function newFile() {
        if (special) return;
        const p = fm.newFile(path, "Documento nuevo.txt");
        if (p) { browser.pendingSelect = p; browser.pendingRename = true; reload(); }
    }
    function openDrive(d) {
        let m = d.mount;
        if (!m) m = fm.mount(d.dev);
        if (m) go(m);
    }

    // menús de clic derecho
    function itemMenu(e, x, y) {
        const many = browser.selCount > 1;
        const trash = path === "quantum:trash";
        if (trash) {
            menu.popup(x, y, [
                { icon: "restore_from_trash", text: "Restaurar", run: () => fm.restore(selPaths()) },
                { sep: true },
                { icon: "delete_forever", text: "Eliminar para siempre", danger: true, run: () => del(true) }
            ]);
            return;
        }
        const apps = fm.appsFor(e.path);
        const openWith = apps.map(a => ({ img: theme.icon(a.icon), text: a.name + (a["default"] ? "  ·  predeterminada" : ""), run: () => fm.openWith(a.id, selPaths(), false) }));
        const isImg = e.type && e.type.indexOf("image/") === 0;
        const fav = (fm.prefs.favorites || []).indexOf(e.path) >= 0;
        menu.popup(x, y, [
            { icon: "open_in_new", text: "Abrir", keys: "Enter", bold: true, run: () => many ? fm.open(selPaths().filter(p => !fm.isDir(p))) : openEntry(e) },
            { icon: "tab", text: "Abrir en una pestaña nueva", visible: e.dir && !many, run: () => newTab(e.path) },
            { icon: "apps", text: "Abrir con", visible: !e.dir && openWith.length > 0, sub: openWith },
            { sep: true },
            { icon: "wallpaper", text: "Usar como fondo de pantalla", visible: isImg && !many, run: () => fm.setWallpaper(e.path) },
            { icon: "folder_zip", text: "Comprimir en ZIP", run: () => fm.compress(selPaths(), fm.parentOf(e.path)) },
            { icon: "unarchive", text: "Descomprimir aquí", visible: !many && fm.isArchive(e.path), run: () => fm.extract(e.path) },
            { icon: "star", text: fav ? "Quitar de Favoritos" : "Agregar a Favoritos", visible: !many, run: () => fm.toggleFavorite(e.path) },
            { icon: "terminal", text: "Abrir terminal aquí", visible: e.dir && !many, run: () => fm.terminal(e.path) },
            { icon: "folder_open", text: "Abrir la ubicación", visible: special && !many, run: () => go(fm.parentOf(e.path)) },
            { sep: true },
            { icon: "info", text: "Propiedades", keys: "Alt+Enter", run: () => fm.setPref("details", true) }
        ], [
            { icon: "content_cut", text: "Cortar (Ctrl+X)", run: cut },
            { icon: "content_copy", text: "Copiar (Ctrl+C)", run: copy },
            { icon: "drive_file_rename_outline", text: "Renombrar (F2)", enabled: !many, run: rename },
            { icon: "delete", text: "Enviar a la Papelera (Supr)", run: () => del(false) }
        ]);
    }
    function bgMenu(x, y) {
        if (path === "quantum:trash") {
            menu.popup(x, y, [{ icon: "delete_sweep", text: "Vaciar la Papelera", danger: true, run: () => confirm.askEmpty() }]);
            return;
        }
        if (special) return;
        menu.popup(x, y, [
            { icon: "add", text: "Nuevo", sub: [
                { img: theme.folderIcon(""), text: "Carpeta", keys: "Ctrl+Mayús+N", run: newFolder },
                { img: theme.icon("text-x-generic"), text: "Documento de texto", run: newFile }
            ] },
            { icon: "content_paste", text: "Pegar", keys: "Ctrl+V", visible: fm.canPaste, run: paste },
            { sep: true },
            { icon: "swap_vert", text: "Ordenar por", sub: sortItems() },
            { icon: fm.prefs.view === "list" ? "view_list" : "grid_view", text: "Ver", sub: viewItems() },
            { icon: fm.prefs.showHidden ? "visibility_off" : "visibility", text: fm.prefs.showHidden ? "Esconder archivos ocultos" : "Mostrar archivos ocultos", keys: "Ctrl+H", run: () => fm.setPref("showHidden", !fm.prefs.showHidden) },
            { sep: true },
            { icon: "select_all", text: "Seleccionar todo", keys: "Ctrl+A", run: () => browser.selectAll() },
            { icon: "terminal", text: "Abrir terminal aquí", run: () => fm.terminal(path) },
            { icon: "star", text: (fm.prefs.favorites || []).indexOf(path) >= 0 ? "Quitar de Favoritos" : "Agregar a Favoritos", run: () => fm.toggleFavorite(path) }
        ]);
    }
    function sortItems() {
        const k = fm.prefs.sortKey || "name";
        return [
            { icon: "sort_by_alpha", text: "Nombre", checked: k === "name", run: () => { fm.setPref("sortKey", "name"); fm.setPref("sortAsc", true); } },
            { icon: "schedule", text: "Fecha de modificación", checked: k === "mtime", run: () => { fm.setPref("sortKey", "mtime"); fm.setPref("sortAsc", false); } },
            { icon: "category", text: "Tipo", checked: k === "type", run: () => { fm.setPref("sortKey", "type"); fm.setPref("sortAsc", true); } },
            { icon: "straighten", text: "Tamaño", checked: k === "size", run: () => { fm.setPref("sortKey", "size"); fm.setPref("sortAsc", false); } },
            { sep: true },
            { icon: fm.prefs.sortAsc !== false ? "arrow_upward" : "arrow_downward", text: fm.prefs.sortAsc !== false ? "Ascendente" : "Descendente", run: () => fm.setPref("sortAsc", fm.prefs.sortAsc === false) }
        ];
    }
    function viewItems() {
        const v = fm.prefs.view, z = fm.prefs.iconSize || 1;
        return [
            { icon: "grid_view", text: "Íconos grandes", checked: v !== "list" && z >= 1.2, run: () => { fm.setPref("view", "grid"); fm.setPref("iconSize", 1.3); } },
            { icon: "grid_view", text: "Íconos medianos", checked: v !== "list" && z < 1.2 && z >= 0.85, run: () => { fm.setPref("view", "grid"); fm.setPref("iconSize", 1.0); } },
            { icon: "apps", text: "Íconos pequeños", checked: v !== "list" && z < 0.85, run: () => { fm.setPref("view", "grid"); fm.setPref("iconSize", 0.72); } },
            { icon: "view_list", text: "Detalles", checked: v === "list", run: () => fm.setPref("view", "list") }
        ];
    }

    // avisos cortos abajo al centro
    property string toastText: ""
    function toast(t) { toastText = t; toastTimer.restart(); }
    Timer { id: toastTimer; interval: 2800; onTriggered: win.toastText = "" }

    // ---------------------------------------------------------------- marco de la ventana
    Rectangle {
        id: frame
        anchors.fill: parent
        anchors.margins: win.visibility === Window.Maximized || win.visibility === Window.FullScreen ? 0 : 1
        radius: win.visibility === Window.Maximized ? 0 : theme.r
        color: theme.bg
        border.width: win.visibility === Window.Maximized ? 0 : 1
        border.color: theme.serp ? theme.alpha(theme.accent, 0.2) : theme.alpha(theme.fg, 0.1)
        clip: true

        // halo de Serpantium
        Rectangle { visible: theme.serp; x: parent.width * 0.55; y: -parent.height * 0.4; width: parent.width * 0.75; height: width; radius: width / 2; color: Qt.rgba(1, 1, 1, 0.012); border.width: 1; border.color: theme.alpha(theme.accent, 0.05) }

        // -------------------------------- pestañas + botones de ventana
        Item {
            id: tabsBar
            width: parent.width; height: 46
            MouseArea {
                anchors.fill: parent
                onPressed: win.startSystemMove()
                onDoubleClicked: win.visibility = win.visibility === Window.Maximized ? Window.Windowed : Window.Maximized
            }
            Row {
                x: 10; anchors.bottom: parent.bottom; spacing: 4
                Repeater {
                    model: win.tabs
                    Rectangle {
                        id: tb
                        required property var modelData
                        required property int index
                        readonly property bool on: index === win.cur
                        width: Math.min(220, (tabsBar.width - 260) / Math.max(1, win.tabs.length)); height: 38
                        radius: theme.serp ? 8 : 12
                        color: on ? theme.side : tma.containsMouse ? theme.alpha(theme.fg, 0.05) : "transparent"
                        Rectangle { visible: tb.on; anchors.bottom: parent.bottom; width: parent.width; height: 12; color: theme.side }
                        Row {
                            x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                            Sym { anchors.verticalCenter: parent.verticalCenter; text: win.iconFor(tb.modelData.path); size: 17; fill: 1; color: tb.on ? theme.accent : theme.muted }
                            T { anchors.verticalCenter: parent.verticalCenter; width: tb.width - 76; text: win.titleFor(tb.modelData.path); font.pixelSize: 13; color: tb.on ? theme.fg : theme.muted }
                        }
                        MouseArea {
                            id: tma; anchors.fill: parent; hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onClicked: e => e.button === Qt.MiddleButton ? win.closeTab(tb.index) : win.switchTab(tb.index)
                        }
                        Btn {
                            anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                            width: 26; height: 26; flat: true; icon: "close"
                            visible: tb.on || tma.containsMouse
                            onClicked: win.closeTab(tb.index)
                        }
                    }
                }
                Btn { anchors.verticalCenter: parent.verticalCenter; width: 34; height: 34; flat: true; icon: "add"; tip: "Pestaña nueva (Ctrl+T)"; onClicked: win.newTab(win.special ? "quantum:home" : win.path) }
            }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                Repeater {
                    model: [["remove", () => win.showMinimized()], ["crop_square", () => win.visibility = win.visibility === Window.Maximized ? Window.Windowed : Window.Maximized], ["close", () => win.close()]]
                    Rectangle {
                        id: wb
                        required property var modelData
                        required property int index
                        width: 44; height: 32; radius: 8
                        color: wma.containsMouse ? (index === 2 ? "#E5484D" : theme.alpha(theme.fg, 0.08)) : "transparent"
                        Sym { anchors.centerIn: parent; text: wb.index === 1 && win.visibility === Window.Maximized ? "filter_none" : wb.modelData[0]; size: wb.index === 1 ? 16 : 19; color: wma.containsMouse && wb.index === 2 ? "white" : theme.fg }
                        MouseArea { id: wma; anchors.fill: parent; hoverEnabled: true; onClicked: wb.modelData[1]() }
                    }
                }
            }
        }

        // -------------------------------- navegación: ruta y búsqueda
        Rectangle {
            id: nav
            y: tabsBar.height; width: parent.width; height: 60; color: theme.side
            Row {
                x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                Btn { flat: true; icon: "arrow_back"; tip: "Atrás (Alt+←)"; enabled_: win.tab.back.length > 0; onClicked: win.goBack() }
                Btn { flat: true; icon: "arrow_forward"; tip: "Adelante (Alt+→)"; enabled_: win.tab.fwd.length > 0; onClicked: win.goForward() }
                Btn { flat: true; icon: "arrow_upward"; tip: "Subir (Alt+↑)"; enabled_: !win.special && win.path !== "/"; onClicked: win.goUp() }
                Btn { flat: true; icon: "refresh"; tip: "Actualizar (F5)"; onClicked: win.reload() }
            }
            // ruta: trozos clicables; clic en el espacio libre (o Ctrl+L) para escribirla
            Rectangle {
                id: pathBar
                x: 176; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - searchBox.width - 30; height: 40; radius: theme.pillR
                color: theme.card; border.width: 1; border.color: pathEdit.activeFocus ? theme.accent : theme.line
                property bool editing: false
                MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: pathBar.edit() }
                function edit() { if (win.special) return; editing = true; pathEdit.text = win.path; pathEdit.forceActiveFocus(); pathEdit.selectAll(); }
                Row {
                    visible: !pathBar.editing
                    x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                    clip: true
                    width: parent.width - 24
                    Sym { anchors.verticalCenter: parent.verticalCenter; text: win.iconFor(win.path) === "folder" ? "folder_open" : win.iconFor(win.path); size: 18; fill: 1; color: theme.accent; width: 26 }
                    Repeater {
                        model: win.special ? [{ name: win.currentTitle, path: win.path }] : fm.crumbs(win.path)
                        Row {
                            required property var modelData
                            required property int index
                            spacing: 2
                            Sym { anchors.verticalCenter: parent.verticalCenter; visible: parent.index > 0; text: "chevron_right"; size: 18; color: theme.muted }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: ct.implicitWidth + 16; height: 28; radius: 7
                                color: cma.containsMouse || cdrop.containsDrag ? theme.accentSoft : "transparent"
                                T { id: ct; anchors.centerIn: parent; text: parent.parent.modelData.name; font.pixelSize: 14 }
                                MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.go(parent.parent.modelData.path) }
                                DropArea { id: cdrop; anchors.fill: parent; enabled: !win.special; onDropped: d => browser.handleDrop(d, parent.parent.modelData.path) }
                            }
                        }
                    }
                }
                TextInput {
                    id: pathEdit
                    visible: pathBar.editing
                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: theme.font; font.pixelSize: 14; color: theme.fg
                    selectionColor: theme.accentStrong; selectedTextColor: theme.accentFg
                    clip: true
                    onAccepted: { pathBar.editing = false; win.go(fm.expand(text)); browser.forceActiveFocus(); }
                    Keys.onEscapePressed: { pathBar.editing = false; browser.forceActiveFocus(); }
                    onActiveFocusChanged: if (!activeFocus) pathBar.editing = false
                }
            }
            Rectangle {
                id: searchBox
                anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                width: Math.min(340, parent.width * 0.26); height: 40; radius: theme.pillR
                color: theme.card; border.width: 1; border.color: search.activeFocus ? theme.accent : theme.line
                Sym { x: 12; anchors.verticalCenter: parent.verticalCenter; text: win.searching ? "progress_activity" : "search"; size: 19; color: theme.muted
                      RotationAnimation on rotation { running: win.searching; from: 0; to: 360; duration: 900; loops: Animation.Infinite } }
                TextInput {
                    id: search
                    anchors.fill: parent; anchors.leftMargin: 42; anchors.rightMargin: 36
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: theme.font; font.pixelSize: 14; color: theme.fg
                    selectionColor: theme.accentStrong; selectedTextColor: theme.accentFg
                    clip: true
                    onTextChanged: searchTimer.restart()
                    onAccepted: { searchTimer.stop(); win.startSearch(text); }
                    Keys.onEscapePressed: { text = ""; browser.forceActiveFocus(); }
                    T {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !search.text
                        width: parent.width
                        text: "Buscar en " + (win.special ? (win.path === "quantum:search" ? win.titleFor(win.searchFolder) : "tu carpeta") : win.currentTitle)
                        color: theme.muted
                    }
                }
                Timer { id: searchTimer; interval: 450; onTriggered: if (search.text.trim().length >= 2 || (search.text === "" && win.path === "quantum:search")) win.startSearch(search.text) }
                Btn { visible: search.text !== ""; anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter; width: 30; height: 30; flat: true; icon: "close"; onClicked: { search.text = ""; win.startSearch(""); } }
            }
        }

        // -------------------------------- barra de comandos
        Rectangle {
            id: cmd
            y: nav.y + nav.height; width: parent.width; height: 54; color: theme.side
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: theme.line }
            readonly property bool trash: win.path === "quantum:trash"
            Row {
                x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                visible: !cmd.trash
                Btn { icon: "add"; label: "Nuevo"; primary: true; enabled_: !win.special
                      onClicked: { const p = mapToItem(null, 0, height + 6); menu.popup(p.x, p.y, [
                          { img: theme.folderIcon(""), text: "Carpeta", keys: "Ctrl+Mayús+N", run: win.newFolder },
                          { img: theme.icon("text-x-generic"), text: "Documento de texto", run: win.newFile }]); } }
                Rectangle { width: 1; height: 26; anchors.verticalCenter: parent.verticalCenter; color: theme.line }
                Btn { icon: "content_cut"; tip: "Cortar (Ctrl+X)"; enabled_: browser.selCount > 0 && !win.special || (win.special && browser.selCount > 0); onClicked: win.cut() }
                Btn { icon: "content_copy"; tip: "Copiar (Ctrl+C)"; enabled_: browser.selCount > 0; onClicked: win.copy() }
                Btn { icon: "content_paste"; tip: "Pegar (Ctrl+V)"; enabled_: fm.canPaste && !win.special; onClicked: win.paste() }
                Btn { icon: "drive_file_rename_outline"; tip: "Renombrar (F2)"; enabled_: browser.selCount === 1; onClicked: win.rename() }
                Btn { icon: "delete"; tip: "Enviar a la Papelera (Supr)"; enabled_: browser.selCount > 0; onClicked: win.del(false) }
                Rectangle { width: 1; height: 26; anchors.verticalCenter: parent.verticalCenter; color: theme.line }
                Btn { icon: "swap_vert"; label: "Ordenar"; onClicked: { const p = mapToItem(null, 0, height + 6); menu.popup(p.x, p.y, win.sortItems()); } }
                Btn { icon: fm.prefs.view === "list" ? "view_list" : "grid_view"; label: "Ver"; onClicked: { const p = mapToItem(null, 0, height + 6); menu.popup(p.x, p.y, win.viewItems()); } }
            }
            Row {
                x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                visible: cmd.trash
                Btn { icon: "restore_from_trash"; label: "Restaurar"; primary: true; enabled_: browser.selCount > 0; onClicked: fm.restore(win.selPaths()) }
                Btn { icon: "delete_forever"; label: "Eliminar para siempre"; enabled_: browser.selCount > 0; onClicked: win.del(true) }
                Btn { icon: "delete_sweep"; label: "Vaciar la Papelera"; enabled_: browser.items.length > 0; onClicked: confirm.askEmpty() }
            }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                Btn { icon: fm.prefs.showHidden ? "visibility" : "visibility_off"; label: "Ocultos"; on: !!fm.prefs.showHidden; onClicked: fm.setPref("showHidden", !fm.prefs.showHidden) }
                Btn { icon: "dock_to_left"; label: "Detalles"; on: win.showDetails; onClicked: fm.setPref("details", !win.showDetails) }
            }
        }

        // -------------------------------- barra lateral
        Rectangle {
            id: sidebar
            y: cmd.y + cmd.height; width: 250; height: parent.height - y; color: theme.side
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: theme.line }
            component SideItem: Rectangle {
                id: si
                property string icon: ""
                property string img: ""
                property string text: ""
                property string target: ""
                property bool on: win.path === target
                property bool eject: false
                signal clicked()
                signal ejectClicked()
                width: parent ? parent.width : 0; height: 36; radius: theme.serp ? 8 : 10
                color: on ? theme.accentSoft : sdrop.containsDrag ? theme.alpha(theme.accent, 0.25) : sma.containsMouse ? theme.alpha(theme.fg, 0.05) : "transparent"
                Rectangle { visible: si.on; anchors.verticalCenter: parent.verticalCenter; width: 3; height: 18; radius: 2; color: theme.accent }
                Image { visible: si.img !== ""; x: 12; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; source: si.img; sourceSize: Qt.size(44, 44) }
                Sym { visible: si.img === ""; x: 12; anchors.verticalCenter: parent.verticalCenter; width: 22; text: si.icon; fill: si.on ? 1 : 0; color: si.on ? theme.accent : theme.fg }
                T { x: 44; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 44 - (si.eject ? 38 : 10); text: si.text; font.weight: si.on ? Font.DemiBold : Font.Normal }
                MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: si.clicked() }
                Btn { visible: si.eject; anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter; width: 30; height: 30; flat: true; icon: "eject"; tip: "Expulsar"; onClicked: si.ejectClicked() }
                DropArea { id: sdrop; anchors.fill: parent; enabled: si.target !== "" && si.target.indexOf("quantum:") !== 0; onDropped: d => browser.handleDrop(d, si.target) }
            }
            Flickable {
                anchors.fill: parent
                contentHeight: side.implicitHeight + 24
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: side
                    x: 10; y: 12; width: sidebar.width - 20; spacing: 2
                    SideItem { icon: "home"; text: "Inicio"; target: "quantum:home"; onClicked: win.go(target) }
                    SideItem { icon: "schedule"; text: "Recientes"; target: "quantum:recent"; onClicked: win.go(target) }
                    SideItem { icon: "star"; text: "Favoritos"; target: "quantum:favorites"; onClicked: win.go(target) }
                    Item { width: 1; height: 10 }
                    T { x: 12; height: 22; text: theme.serp ? "ACCESOS RÁPIDOS" : "Accesos rápidos"; font.pixelSize: 11; font.weight: Font.Bold; color: theme.muted }
                    Repeater {
                        model: fm.places
                        SideItem { required property var modelData; img: theme.folderIcon(modelData.key); text: modelData.name; target: modelData.path; onClicked: win.go(target) }
                    }
                    SideItem { img: theme.icon("user-home,folder-home"); text: fm.userName.charAt(0).toUpperCase() + fm.userName.slice(1); target: fm.home; onClicked: win.go(target) }
                    Item { width: 1; height: 10 }
                    T { x: 12; height: 22; text: theme.serp ? "ESTE EQUIPO" : "Este equipo"; font.pixelSize: 11; font.weight: Font.Bold; color: theme.muted }
                    Repeater {
                        model: fm.drives
                        SideItem {
                            required property var modelData
                            img: theme.icon(modelData.icon + ",drive-harddisk"); text: modelData.name
                            target: modelData.mount
                            eject: modelData.removable && modelData.mount !== ""
                            onClicked: win.openDrive(modelData)
                            onEjectClicked: { if (win.path.indexOf(modelData.mount) === 0) win.go("quantum:home"); fm.eject(modelData.dev); }
                        }
                    }
                    Item { width: 1; height: 10 }
                    SideItem { img: theme.icon("user-trash-full,user-trash"); text: "Papelera"; target: "quantum:trash"; onClicked: win.go(target) }
                }
            }
        }

        // -------------------------------- contenido
        Item {
            id: content
            x: sidebar.width; y: sidebar.y
            width: parent.width - x - (details.visible ? details.width : 0); height: parent.height - y - status.height

            HomeView {
                id: home
                anchors.fill: parent
                visible: win.path === "quantum:home"
                onGo: p => win.go(p)
                onOpenFile: p => fm.open([p])
                onOpenDrive: d => win.openDrive(d)
                onMenuFor: (e, x, y) => { browser.clear(); win.itemMenuHome(e, x, y); }
            }
            Browser {
                id: browser
                anchors.fill: parent
                visible: win.path !== "quantum:home" && win.loadError === ""
                folder: win.special ? "" : win.path
                trashMode: win.path === "quantum:trash"
                searchMode: win.path === "quantum:search"
                emptyText: trashMode ? "La Papelera está vacía" : searchMode ? (win.searching ? "Buscando…" : "No encontré nada con «" + win.searchQuery + "»")
                         : win.path === "quantum:favorites" ? "Todavía no tienes favoritos" : win.path === "quantum:recent" ? "Nada reciente por aquí" : "Esta carpeta está vacía"
                emptyHint: trashMode ? "Lo que borres llega aquí y lo puedes recuperar." : searchMode ? "Busco en " + win.titleFor(win.searchFolder) + " y sus subcarpetas."
                         : win.path === "quantum:favorites" ? "Clic derecho en una carpeta → «Agregar a Favoritos»." : win.special ? "" : "Arrastra archivos aquí o usa «Nuevo»."
                onActivate: e => win.openEntry(e)
                onMenuAt: (e, x, y) => e ? win.itemMenu(e, x, y) : win.bgMenu(x, y)
                onDropped: (paths, dest, copy) => fm.transfer(paths, dest, !copy)
            }
            Column {
                anchors.centerIn: parent
                visible: win.loadError !== "" && win.path !== "quantum:home"
                spacing: 10
                Sym { anchors.horizontalCenter: parent.horizontalCenter; text: "lock"; size: 56; color: theme.alpha(theme.fg, 0.3) }
                T { anchors.horizontalCenter: parent.horizontalCenter; text: win.loadError; font.pixelSize: 16; color: theme.muted }
            }
        }

        Details {
            id: details
            anchors.right: parent.right
            y: sidebar.y; width: 320; height: parent.height - y - status.height
            visible: win.showDetails && win.path !== "quantum:home" && parent.width > 1000
            entries: win.selected
            folder: win.special ? "" : win.path
            onOpenEntry: e => win.openEntry(e)
        }

        // -------------------------------- barra de estado
        Rectangle {
            id: status
            anchors.bottom: parent.bottom; width: parent.width; height: 34; color: theme.side
            Rectangle { width: parent.width; height: 1; color: theme.line }
            T {
                x: sidebar.width + 18; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 12; color: theme.muted
                text: {
                    if (win.path === "quantum:home") return fm.places.length + " accesos rápidos · " + fm.drives.length + (fm.drives.length === 1 ? " disco" : " discos");
                    const n = browser.items.length;
                    let t = n === 1 ? "1 elemento" : n + " elementos";
                    if (browser.selCount > 0) t += " · " + browser.selCount + (browser.selCount === 1 ? " seleccionado" : " seleccionados") + " (" + fm.totalSize(browser.selectedPaths()) + ")";
                    return t;
                }
            }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                visible: win.path !== "quantum:home"
                Btn { width: 28; height: 28; flat: true; icon: "view_list"; on: fm.prefs.view === "list"; tip: "Detalles"; onClicked: fm.setPref("view", "list") }
                Btn { width: 28; height: 28; flat: true; icon: "grid_view"; on: fm.prefs.view !== "list"; tip: "Íconos"; onClicked: fm.setPref("view", "grid") }
                // tamaño de los íconos
                Item {
                    width: 120; height: 28
                    visible: fm.prefs.view !== "list"
                    Rectangle {
                        id: zt
                        anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: theme.cardHi
                        readonly property real k: ((fm.prefs.iconSize || 1) - 0.6) / 1.0
                        Rectangle { width: parent.width * zt.k; height: 4; radius: 2; color: theme.accentStrong }
                        Rectangle { x: parent.width * zt.k - 6; anchors.verticalCenter: parent.verticalCenter; width: 12; height: 12; radius: 6; color: theme.fg }
                    }
                    MouseArea {
                        anchors.fill: parent
                        function set(x) { fm.setPref("iconSize", Math.round((0.6 + Math.max(0, Math.min(1, x / width))) * 20) / 20); }
                        onPressed: e => set(e.x)
                        onPositionChanged: e => { if (pressed) set(e.x); }
                    }
                }
            }
        }

        // -------------------------------- tareas en curso (copias, papelera…)
        Column {
            anchors.right: parent.right; anchors.bottom: status.top; anchors.margins: 18
            spacing: 10
            z: 50
            Repeater {
                model: fm.jobs
                Rectangle {
                    id: job
                    required property var modelData
                    width: 420; height: 104; radius: theme.r
                    color: theme.serp ? "#1A1318" : Qt.lighter(theme.card, 1.08)
                    border.width: 1; border.color: theme.serp ? theme.alpha(theme.accent, 0.3) : theme.alpha(theme.fg, 0.12)
                    Rectangle { z: -1; anchors.fill: parent; anchors.topMargin: 6; anchors.bottomMargin: -8; radius: parent.radius + 2; color: "black"; opacity: 0.25 }
                    Sym { x: 18; y: 18; text: "content_copy"; size: 26; color: theme.accent }
                    T { x: 58; y: 14; width: parent.width - 150; text: job.modelData.title; font.weight: Font.DemiBold }
                    T { x: 58; y: 36; width: parent.width - 80; text: Math.round(job.modelData.frac * 100) + " %" + (job.modelData.left ? " · " + job.modelData.left : "") + (job.modelData.paused ? " · en pausa" : ""); font.pixelSize: 12; color: theme.muted }
                    T { x: 58; y: 54; width: parent.width - 80; text: job.modelData.label; font.pixelSize: 11; color: theme.muted; opacity: 0.8 }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 10; y: 10; spacing: 2
                        visible: job.modelData.cancellable
                        Btn { width: 32; height: 32; flat: true; icon: job.modelData.paused ? "play_arrow" : "pause"; tip: job.modelData.paused ? "Seguir" : "Pausar"; onClicked: fm.pauseJob(job.modelData.id) }
                        Btn { width: 32; height: 32; flat: true; icon: "close"; tip: "Cancelar"; onClicked: fm.cancelJob(job.modelData.id) }
                    }
                    Rectangle {
                        x: 18; y: 80; width: parent.width - 36; height: 8; radius: 4; color: theme.cardHi
                        Rectangle {
                            width: Math.max(8, parent.width * job.modelData.frac); height: 8; radius: 4
                            Behavior on width { NumberAnimation { duration: 240 } }
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: theme.serp ? "#F4A7C9" : "#4FD8FF" }
                                GradientStop { position: 1; color: theme.serp ? "#E07BAA" : "#B14DFF" }
                            }
                        }
                    }
                }
            }
        }

        // aviso corto
        Rectangle {
            anchors.horizontalCenter: content.horizontalCenter
            anchors.bottom: status.top; anchors.bottomMargin: 18
            width: tt.implicitWidth + 36; height: 42; radius: 21
            color: theme.serp ? "#2A2027" : "#2E2D3A"
            border.width: 1; border.color: theme.alpha(theme.accent, 0.3)
            opacity: win.toastText ? 1 : 0
            scale: win.toastText ? 1 : 0.9
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
            z: 60
            T { id: tt; anchors.centerIn: parent; text: win.toastText; color: "white"; font.pixelSize: 13 }
        }

        // -------------------------------- confirmar borrar para siempre
        Rectangle {
            id: confirm
            anchors.fill: parent
            z: 900
            color: Qt.rgba(0, 0, 0, 0.45)
            visible: paths.length > 0 || emptying
            property var paths: []
            property bool emptying: false
            function ask(p) { paths = p; emptying = false; }
            function askEmpty() { paths = []; emptying = true; }
            MouseArea { anchors.fill: parent; onClicked: { confirm.paths = []; confirm.emptying = false; } }
            Rectangle {
                anchors.centerIn: parent
                width: 460; height: cc.implicitHeight + 48; radius: theme.r + 6
                color: theme.card; border.width: 1; border.color: theme.line
                MouseArea { anchors.fill: parent }
                Column {
                    id: cc
                    x: 24; y: 24; width: parent.width - 48; spacing: 12
                    Sym { text: "delete_forever"; size: 36; color: theme.danger }
                    T { width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: 18; font.weight: Font.Bold
                        text: confirm.emptying ? "¿Vaciar la Papelera?" : confirm.paths.length === 1 ? "¿Eliminar para siempre?" : "¿Eliminar " + confirm.paths.length + " elementos para siempre?" }
                    T { width: parent.width; wrapMode: Text.WordWrap; color: theme.muted
                        text: "No se puede deshacer: no pasa por la Papelera." }
                    Row {
                        anchors.right: parent.right; spacing: 10
                        Btn { label: "Cancelar"; onClicked: { confirm.paths = []; confirm.emptying = false; } }
                        Btn { label: "Eliminar"; icon: "delete_forever"; primary: true
                              onClicked: { if (confirm.emptying) fm.emptyTrash(); else fm.deleteForever(confirm.paths); confirm.paths = []; confirm.emptying = false; } }
                    }
                }
            }
        }

        Menu { id: menu }
    }

    // en Inicio, el clic derecho de un acceso rápido o un reciente
    function itemMenuHome(e, x, y) {
        menu.popup(x, y, [
            { icon: "open_in_new", text: "Abrir", bold: true, run: () => e.dir ? go(e.path) : fm.open([e.path]) },
            { icon: "tab", text: "Abrir en una pestaña nueva", visible: e.dir, run: () => newTab(e.path) },
            { icon: "folder_open", text: "Abrir la ubicación", visible: !e.dir, run: () => go(fm.parentOf(e.path)) },
            { icon: "terminal", text: "Abrir terminal aquí", visible: e.dir, run: () => fm.terminal(e.path) }
        ]);
    }

    // -------------------------------- bordes para cambiar el tamaño
    Repeater {
        model: [[Qt.LeftEdge, Qt.SizeHorCursor], [Qt.RightEdge, Qt.SizeHorCursor], [Qt.TopEdge, Qt.SizeVerCursor], [Qt.BottomEdge, Qt.SizeVerCursor],
                [Qt.LeftEdge | Qt.TopEdge, Qt.SizeFDiagCursor], [Qt.RightEdge | Qt.BottomEdge, Qt.SizeFDiagCursor],
                [Qt.RightEdge | Qt.TopEdge, Qt.SizeBDiagCursor], [Qt.LeftEdge | Qt.BottomEdge, Qt.SizeBDiagCursor]]
        MouseArea {
            required property var modelData
            readonly property int e: modelData[0]
            enabled: win.visibility !== Window.Maximized
            cursorShape: modelData[1]
            x: (e & Qt.RightEdge) ? win.width - 6 : 0
            y: (e & Qt.BottomEdge) ? win.height - 6 : 0
            width: (e & (Qt.LeftEdge | Qt.RightEdge)) && !(e & (Qt.TopEdge | Qt.BottomEdge)) ? 6 : (e & (Qt.TopEdge | Qt.BottomEdge)) && !(e & (Qt.LeftEdge | Qt.RightEdge)) ? win.width : 12
            height: (e & (Qt.TopEdge | Qt.BottomEdge)) && !(e & (Qt.LeftEdge | Qt.RightEdge)) ? 6 : (e & (Qt.LeftEdge | Qt.RightEdge)) && !(e & (Qt.TopEdge | Qt.BottomEdge)) ? win.height : 12
            onPressed: win.startSystemResize(e)
        }
    }

    // -------------------------------- atajos (como en Windows)
    Shortcut { sequence: StandardKey.Copy; onActivated: win.copy() }
    Shortcut { sequence: StandardKey.Cut; onActivated: win.cut() }
    Shortcut { sequence: StandardKey.Paste; onActivated: win.paste() }
    Shortcut { sequence: StandardKey.SelectAll; onActivated: browser.selectAll() }
    Shortcut { sequence: "F2"; onActivated: win.rename() }
    Shortcut { sequence: "Delete"; onActivated: win.del(false) }
    Shortcut { sequence: "Shift+Delete"; onActivated: win.del(true) }
    Shortcut { sequence: "Ctrl+T"; onActivated: win.newTab(win.special ? "quantum:home" : win.path) }
    Shortcut { sequence: "Ctrl+W"; onActivated: win.closeTab(win.cur) }
    Shortcut { sequence: "Ctrl+Tab"; onActivated: win.switchTab((win.cur + 1) % win.tabs.length) }
    Shortcut { sequence: "Ctrl+Shift+Tab"; onActivated: win.switchTab((win.cur + win.tabs.length - 1) % win.tabs.length) }
    Shortcut { sequences: ["Alt+Left", "Back"]; onActivated: win.goBack() }
    Shortcut { sequences: ["Alt+Right", "Forward"]; onActivated: win.goForward() }
    Shortcut { sequence: "Alt+Up"; onActivated: win.goUp() }
    Shortcut { sequence: "Backspace"; onActivated: win.goBack() }
    Shortcut { sequences: ["Ctrl+L", "F4"]; onActivated: pathBar.edit() }
    Shortcut { sequences: ["Ctrl+F", "F3"]; onActivated: { search.forceActiveFocus(); search.selectAll(); } }
    Shortcut { sequence: "Ctrl+H"; onActivated: fm.setPref("showHidden", !fm.prefs.showHidden) }
    Shortcut { sequences: ["F5", "Ctrl+R"]; onActivated: win.reload() }
    Shortcut { sequence: "Ctrl+Shift+N"; onActivated: win.newFolder() }
    Shortcut { sequence: "Alt+Return"; onActivated: fm.setPref("details", !win.showDetails) }
    Shortcut { sequences: ["Ctrl+=", "Ctrl++"]; onActivated: fm.setPref("iconSize", Math.min(1.6, (fm.prefs.iconSize || 1) + 0.1)) }
    Shortcut { sequence: "Ctrl+-"; onActivated: fm.setPref("iconSize", Math.max(0.6, (fm.prefs.iconSize || 1) - 0.1)) }
    Shortcut { sequence: "Escape"; onActivated: { if (menu.open) menu.close(); else browser.clear(); } }

    // -------------------------------- capturas de prueba (QUANTUM_FILES_DEMO)
    // ej.: "select:1,2,5;menu:5;job" → selecciona, abre el menú de clic derecho y guarda la captura
    Timer {
        id: demo
        interval: 1500
        onTriggered: {
            for (const part of demoAction.split(";")) {
                const [k, v] = part.split(":");
                if (k === "select") { const s = {}; for (const i of v.split(",")) { const it = browser.items[+i]; if (it) s[it.path] = true; } browser.sel = s; browser.selCount = Object.keys(s).length; }
                if (k === "menu") win.itemMenu(browser.items[+v], sidebar.width + 330, 420);
                if (k === "view") fm.setPref("view", v);
                if (k === "toast") win.toast(v);
            }
            if (shotPath) shot.start();
        }
    }
    Timer { id: shot; interval: 900; onTriggered: frame.grabToImage(r => { r.saveToFile(shotPath); Qt.quit(); }) }
}
