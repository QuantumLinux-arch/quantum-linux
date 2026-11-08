pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

// Íconos del escritorio, como en Windows: lo que hay en la carpeta Escritorio (archivos, carpetas y accesos
// directos .desktop) más la Papelera. Cada ícono recuerda su casilla (se pueden arrastrar).
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    property string dir: ""
    readonly property alias files: folder
    readonly property bool enabled: Settings.appearance.desktopIcons ?? true

    // carpeta Escritorio según el idioma (xdg-user-dir); si no está configurada, ~/Escritorio
    Process {
        running: true
        command: ["sh", "-c", "xdg-user-dir DESKTOP 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let d = text.trim();
                if (!d || d === root.home) d = root.home + "/Escritorio";
                root.dir = d;
                Quickshell.execDetached(["mkdir", "-p", d]);
            }
        }
    }

    FolderListModel {
        id: folder
        folder: root.dir ? "file://" + root.dir : ""
        showDirsFirst: true
        showHidden: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
    }

    // ¿Hay algo en la papelera? (para el ícono lleno o vacío)
    FolderListModel {
        id: trash
        folder: "file://" + root.home + "/.local/share/Trash/files"
        showHidden: true
        showDotAndDotDot: false
    }
    readonly property bool trashFull: trash.count > 0

    // ------------------------------------------------------------ casillas guardadas
    FileView {
        id: posFile
        path: root.home + "/.config/quantum/desktop-icons.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()
        JsonAdapter {
            id: pos
            property var slots: ({})        // nombre → [columna, fila]
        }
    }

    // Casilla de cada ícono: la guardada si está libre; si no, la siguiente libre (de arriba abajo, columna por
    // columna, como en Windows). La Papelera va primero.
    function layout(rows: int): var {
        rows = Math.max(1, rows);
        const names = ["\u0001papelera"];
        for (let i = 0; i < folder.count; i++) names.push(folder.get(i, "fileName"));
        const saved = pos.slots ?? {};
        const used = {}, out = {};
        for (const n of names) {
            const s = saved[n];
            if (s && s[1] < rows && !used[s[0] + "," + s[1]]) { out[n] = s; used[s[0] + "," + s[1]] = true; }
        }
        let k = 0;
        for (const n of names) {
            if (out[n]) continue;
            while (used[Math.floor(k / rows) + "," + (k % rows)]) k++;
            out[n] = [Math.floor(k / rows), k % rows];
            used[out[n][0] + "," + out[n][1]] = true;
        }
        return out;
    }

    // Mover un ícono a otra casilla (si está ocupada, intercambian lugar)
    function move(name: string, col: int, row: int, current: var): void {
        const s = Object.assign({}, current);
        const other = Object.keys(s).find(n => n !== name && s[n][0] === col && s[n][1] === row);
        if (other) s[other] = s[name];
        s[name] = [col, row];
        pos.slots = s;
    }

    // ícono según la extensión (los temas de íconos usan nombres de tipo MIME)
    function iconForSuffix(ext: string): string {
        const m = {
            pdf: "application-pdf", txt: "text-x-generic", md: "text-x-generic", log: "text-x-generic",
            doc: "x-office-document", docx: "x-office-document", odt: "x-office-document", rtf: "x-office-document",
            xls: "x-office-spreadsheet", xlsx: "x-office-spreadsheet", ods: "x-office-spreadsheet", csv: "x-office-spreadsheet",
            ppt: "x-office-presentation", pptx: "x-office-presentation", odp: "x-office-presentation",
            mp3: "audio-x-generic", wav: "audio-x-generic", flac: "audio-x-generic", ogg: "audio-x-generic", m4a: "audio-x-generic",
            mp4: "video-x-generic", mkv: "video-x-generic", webm: "video-x-generic", avi: "video-x-generic", mov: "video-x-generic",
            zip: "package-x-generic", rar: "package-x-generic", "7z": "package-x-generic", gz: "package-x-generic",
            xz: "package-x-generic", zst: "package-x-generic", tar: "package-x-generic",
            exe: "application-x-ms-dos-executable", msi: "application-x-msi", iso: "application-x-cd-image",
            sh: "application-x-shellscript", py: "text-x-python", html: "text-html", svg: "image-svg+xml",
            appimage: "application-x-executable", deb: "application-x-deb", apk: "application-vnd.android.package-archive"
        };
        return m[ext] ?? "text-x-generic";
    }

    // Ordenar: todos vuelven a su lugar automático (columna por columna)
    function resetPositions(): void { pos.slots = ({}); }

    // ------------------------------------------------------------ acciones
    function open(path: string, isDesktopFile: bool): void {
        if (path === "trash") Quickshell.execDetached(["quantum-files", "quantum:trash"]);
        else if (isDesktopFile) Quickshell.execDetached(["gio", "launch", path]);
        else Quickshell.execDetached(["xdg-open", path]);
    }
    function showInFiles(path: string): void { Quickshell.execDetached(["quantum-files", path.substring(0, path.lastIndexOf("/"))]); }
    function toTrash(path: string): void { Quickshell.execDetached(["gio", "trash", path]); }
    function emptyTrash(): void { Quickshell.execDetached(["gio", "trash", "--empty"]); }
    function newFolder(): void {
        Quickshell.execDetached(["sh", "-c", "d=\"$1/Nueva carpeta\"; n=2; while [ -e \"$d\" ]; do d=\"$1/Nueva carpeta ($n)\"; n=$((n+1)); done; mkdir \"$d\"", "sh", root.dir]);
    }
    // Anclar una app al escritorio: copia su .desktop (desde donde esté instalada)
    function pinApp(id: string): void {
        Quickshell.execDetached(["sh", "-c",
            "id=\"$1\"; dest=\"$2\"; mkdir -p \"$dest\"; " +
            "for d in \"$HOME/.local/share/applications\" \"$HOME/.local/share/flatpak/exports/share/applications\" " +
            "/var/lib/flatpak/exports/share/applications /usr/local/share/applications /usr/share/applications; do " +
            "f=\"$d/${id%.desktop}.desktop\"; if [ -f \"$f\" ]; then cp \"$f\" \"$dest/\" && chmod +x \"$dest/$(basename \"$f\")\"; " +
            "gio set \"$dest/$(basename \"$f\")\" metadata::trusted true 2>/dev/null; exit 0; fi; done; exit 1",
            "sh", id, root.dir]);
    }
}
