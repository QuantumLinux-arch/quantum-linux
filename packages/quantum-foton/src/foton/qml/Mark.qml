import QtQuick
import QtQuick.Shapes

// Logo de Fotón (monocromo, del color que se pida): núcleo de luz, estela y destello.
Item {
    id: m
    property color color: "white"
    implicitWidth: 48
    implicitHeight: 48
    Shape {
        width: 128; height: 128
        scale: Math.min(m.width, m.height) / 128
        transformOrigin: Item.TopLeft
        x: (m.width - 128 * scale) / 2
        y: (m.height - 128 * scale) / 2
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: m.color; strokeColor: "transparent"
            PathSvg { path: "M99.4 49.75 A19 19 0 1 1 61.4 49.75 A19 19 0 1 1 99.4 49.75 Z" }
        }
        ShapePath {
            fillColor: m.color; strokeColor: "transparent"
            PathSvg { path: "M47.2 67.45 Q28.8 84.55 16.4 113.75 Q48.6 101.35 62.7 82.95 A11 11 0 0 0 47.2 67.45 Z" }
        }
        ShapePath {
            fillColor: "transparent"; strokeColor: m.color; strokeWidth: 7; capStyle: ShapePath.RoundCap
            PathSvg { path: "M64.4 22.05 A32 32 0 0 1 108.1 65.75" }
        }
    }
}
