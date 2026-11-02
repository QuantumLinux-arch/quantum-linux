import QtQuick

// Colores: Caelestial toma los del sistema (quantum-theme); Serpantium usa los suyos.
QtObject {
    readonly property bool serp: drivers.serp
    readonly property var c: drivers.colors || ({})
    function col(n, f) { return c[n] !== undefined ? c[n] : f; }
    readonly property bool dark: serp || (c.mode || "dark") !== "light"

    readonly property color bg: serp ? "#17111A" : col("surface", "#100E1C")
    readonly property color side: serp ? "#130E14" : col("surface_container_low", "#16142A")
    readonly property color card: serp ? "#1F171D" : col("surface_container", "#1E1B33")
    readonly property color cardHi: serp ? "#2A2027" : col("surface_container_high", "#2A2645")
    readonly property color line: dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color accent: serp ? "#F4A7C9" : col("primary", "#C5C0FF")
    readonly property color fg: serp ? "#F3E7ED" : col("on_surface", "#ECEAF5")
    readonly property color muted: serp ? "#A3919B" : col("on_surface_variant", "#A3A0B5")
    readonly property color cyan: "#4FD8FF"
    readonly property color indigo: "#6A5CFF"
    readonly property color violet: "#B14DFF"
    readonly property color danger: "#FF6B7A"
    readonly property string font: serp ? "JetBrains Mono" : "Inter"
    readonly property string icons: "Material Symbols Rounded"
    readonly property int r: serp ? 10 : 18

    function alpha(k, a) { const q = Qt.color(k); return Qt.rgba(q.r, q.g, q.b, a); }
}
