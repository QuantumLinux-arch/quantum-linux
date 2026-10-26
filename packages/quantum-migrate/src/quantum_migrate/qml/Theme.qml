import QtQuick

// Colores del sistema (los mismos que el shell, vía quantum-theme) y medidas (copiado de Fotón).
QtObject {
    readonly property var c: store.colors || ({})
    function col(n, f) { return c[n] !== undefined ? c[n] : f; }
    readonly property bool dark: (c.mode || "dark") !== "light"

    readonly property color bg: col("surface", "#13121c")
    readonly property color low: col("surface_container_low", "#1b1a24")
    readonly property color card: col("surface_container", "#1f1f28")
    readonly property color high: col("surface_container_high", "#2a2933")
    readonly property color highest: col("surface_container_highest", "#35343e")
    readonly property color fg: col("on_surface", "#e4e0ee")
    readonly property color muted: col("on_surface_variant", "#c8c4d4")
    readonly property color outline: col("outline_variant", "#474553")
    readonly property color primary: col("primary", "#c5c0ff")
    readonly property color onPrimary: col("on_primary", "#2a1a9a")
    readonly property color primaryContainer: col("primary_container", "#6a5cff")
    readonly property color onPrimaryContainer: col("on_primary_container", "#ffffff")
    readonly property color tertiary: col("tertiary", "#ffb68b")
    readonly property color error: col("error", "#ffb4ab")

    readonly property color cyan: "#4FD8FF"
    readonly property color indigo: "#6A5CFF"
    readonly property color violet: "#B14DFF"

    readonly property string font: "Inter"
    readonly property string icons: "Material Symbols Rounded"
    readonly property int anim: 260

    function alpha(k, a) { const q = Qt.color(k); return Qt.rgba(q.r, q.g, q.b, a); }
    function iconSource(icon) {
        if (!icon) return "image://icon/package-x-generic";
        return icon.indexOf("theme:") === 0 ? "image://icon/" + icon.slice(6) : web(icon);
    }
    function web(url) { return url && url.indexOf("http") === 0 ? "image://web/" + encodeURIComponent(url) : (url || ""); }
    function sourceColor(s) {
        return s === "flathub" ? "#4A90E2" : s === "arch" ? "#1793D1" : s === "aur" ? "#E5A50A" : "#3DDC84";
    }
    function sourceName(s) {
        return s === "flathub" ? "Flathub" : s === "arch" ? "Arch" : s === "aur" ? "Comunidad" : "Android";
    }
}
