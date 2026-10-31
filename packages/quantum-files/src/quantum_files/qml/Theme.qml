import QtQuick

// Colores y medidas: Caelestial toma los colores del sistema (quantum-theme, los mismos
// del shell); Serpantium usa los suyos fijos (oscuro + rosado, letra monoespaciada).
QtObject {
    readonly property bool serp: fm.serp
    readonly property var c: fm.colors || ({})
    function col(n, f) { return c[n] !== undefined ? c[n] : f; }
    readonly property bool dark: serp || (c.mode || "dark") !== "light"

    readonly property color bg: serp ? "#17111A" : col("surface", "#15141D")
    readonly property color side: serp ? "#130E14" : col("surface_container_low", "#1B1A26")
    readonly property color card: serp ? "#1F171D" : col("surface_container", "#22212E")
    readonly property color cardHi: serp ? "#2A2027" : col("surface_container_high", "#2D2B3C")
    readonly property color line: dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color accent: serp ? "#F4A7C9" : col("primary", "#C5C0FF")
    readonly property color accentStrong: serp ? "#F4A7C9" : col("primary_container", "#6A5CFF")
    readonly property color accentFg: serp ? "#3A1028" : col("on_primary_container", "#FFFFFF")
    readonly property color accentSoft: alpha(accentStrong, serp ? 0.16 : 0.2)
    readonly property color fg: serp ? "#F3E7ED" : col("on_surface", "#ECEAF5")
    readonly property color muted: serp ? "#A3919B" : col("on_surface_variant", "#A3A0B5")
    readonly property color danger: "#FF6B7A"
    readonly property color warn: "#FFB547"
    readonly property string font: serp ? "JetBrains Mono" : "Inter"
    readonly property string icons: "Material Symbols Rounded"
    readonly property int r: serp ? 10 : 14
    readonly property int pillR: serp ? 9 : 18
    readonly property string folderColor: serp ? "pink" : "violet"
    readonly property int anim: 220

    function alpha(k, a) { const q = Qt.color(k); return Qt.rgba(q.r, q.g, q.b, a); }
    function icon(names) { return "image://icon/" + encodeURIComponent(names); }
    function folderIcon(key) { return icon("folder-" + folderColor + (key ? "-" + key : "") + ",folder" + (key ? "-" + key : "") + ",folder"); }
}
