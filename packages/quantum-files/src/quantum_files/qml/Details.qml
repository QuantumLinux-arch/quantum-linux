import QtQuick

// Panel de detalles (a la derecha): vista previa y datos de lo seleccionado, con
// botones para lo más usado según el tipo (abrir, fondo de pantalla, descomprimir).
Rectangle {
    id: d
    property var entries: []
    property string folder: ""
    readonly property var one: entries.length === 1 ? entries[0] : null
    readonly property bool isImage: !!one && one.type.indexOf("image/") === 0
    signal openEntry(var entry)
    color: theme.side

    property var folderInfo: null
    onFolderChanged: folderInfo = folder ? fm.info(folder) : null

    Rectangle { width: 1; height: parent.height; color: theme.line }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: col
            x: 22; y: 22; width: d.width - 44; spacing: 14

            // vista previa
            Rectangle {
                width: parent.width; height: Math.round(width * 0.68); radius: theme.r
                color: theme.cardHi; clip: true
                Image {
                    id: prev
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    // con varios seleccionados, la miniatura del primero que tenga
                    source: { const e = d.entries.find(x => x.thumb); return e ? e.thumb : ""; }
                    sourceSize: Qt.size(640, 440)
                }
                Image {
                    visible: prev.status !== Image.Ready
                    anchors.centerIn: parent
                    width: parent.height * 0.6; height: width
                    sourceSize: Qt.size(160, 160)
                    source: d.entries.length > 1 ? theme.icon("edit-copy,folder-documents")
                          : d.one ? (d.one.dir ? theme.folderIcon("") : theme.icon(d.one.icon))
                          : theme.folderIcon("")
                }
                Rectangle {
                    visible: d.entries.length > 1
                    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10
                    width: 30; height: 30; radius: 15; color: theme.accentStrong
                    T { anchors.centerIn: parent; text: d.entries.length; font.weight: Font.Bold; font.pixelSize: 13; color: theme.accentFg }
                }
            }

            T {
                width: parent.width; wrapMode: Text.WrapAnywhere; maximumLineCount: 3
                font.pixelSize: 17; font.weight: Font.Bold
                text: d.entries.length > 1 ? d.entries.length + " elementos seleccionados"
                    : d.one ? d.one.name : (d.folderInfo ? d.folderInfo.name : "")
            }
            T {
                visible: d.entries.length > 1
                width: parent.width
                text: d.entries.length > 1 ? d.entries[0].name + " y " + (d.entries.length - 1) + " más" : ""
                color: theme.muted; font.pixelSize: 13
            }
            Rectangle { width: parent.width; height: 1; color: theme.line }

            Repeater {
                model: {
                    if (d.entries.length > 1) {
                        const types = [...new Set(d.entries.map(e => e.desc))];
                        return [["Tipo", types.length === 1 ? types[0] : "Varios tipos"],
                                ["Tamaño total", fm.totalSize(d.entries.map(e => e.path))],
                                ["Carpetas", String(d.entries.filter(e => e.dir).length)]];
                    }
                    const e = d.one || d.folderInfo;
                    if (!e) return [];
                    const where = fm.parentOf(e.path);
                    const out = [["Tipo", e.desc]];
                    if (!e.dir) out.push(["Tamaño", fm.sizeText(e.size)]);
                    out.push(["Ubicación", where.indexOf(fm.home) === 0 ? (where.slice(fm.home.length + 1).split("/").join(" › ") || fm.userName) : where]);
                    out.push(["Modificado", fm.dateText(e.mtime)]);
                    if (e.origin) out.push(["Estaba en", e.origin]);
                    return out;
                }
                Item {
                    required property var modelData
                    width: col.width; height: Math.max(22, val.implicitHeight)
                    T { text: parent.modelData[0]; font.pixelSize: 13; color: theme.muted }
                    T {
                        id: val
                        anchors.right: parent.right
                        width: parent.width - 110
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.Wrap; maximumLineCount: 3      // corta entre palabras si se puede
                        text: parent.modelData[1]; font.pixelSize: 13
                    }
                }
            }
            Rectangle { width: parent.width; height: 1; color: theme.line; visible: !!d.one }

            Flow {
                width: parent.width; spacing: 8
                visible: !!d.one
                Btn { icon: "open_in_new"; label: "Abrir"; primary: true; onClicked: d.openEntry(d.one) }
                Btn { visible: d.isImage; icon: "wallpaper"; label: "Usar como fondo"; on: true; onClicked: fm.setWallpaper(d.one.path) }
                Btn { visible: !!d.one && fm.isArchive(d.one.path); icon: "unarchive"; label: "Descomprimir aquí"; on: true; onClicked: fm.extract(d.one.path) }
                Btn { visible: !!d.one && d.one.dir; icon: "star"; label: (fm.prefs.favorites || []).indexOf(d.one ? d.one.path : "") >= 0 ? "Quitar de Favoritos" : "Agregar a Favoritos"; on: true; onClicked: fm.toggleFavorite(d.one.path) }
            }
        }
    }
}
