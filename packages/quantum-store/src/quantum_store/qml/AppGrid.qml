import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Grilla de apps que se adapta al ancho.
GridLayout {
    id: g
    property var apps: []
    Layout.fillWidth: true
    columns: Math.max(1, Math.floor((width + 14) / 250))
    columnSpacing: 14
    rowSpacing: 14
    Repeater {
        model: g.apps
        AppCard { required property var modelData; required property int index; app: modelData; Layout.fillWidth: true }
    }
}
