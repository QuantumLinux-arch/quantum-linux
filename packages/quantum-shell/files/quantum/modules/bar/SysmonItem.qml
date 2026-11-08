import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components

// «Uso del PC»: procesador y memoria en dos barritas. Clic: abre Mi PC en el Centro Quantum.
DockButton {
    id: root
    tip: "Procesador " + Math.round(SysInfo.cpu * 100) + " % · Memoria " + Math.round(SysInfo.ram * 100) + " %"
    implicitWidth: row.implicitWidth + 18
    Component.onCompleted: SysInfo.users++
    Component.onDestruction: SysInfo.users--
    onClicked: Quickshell.execDetached(["quantum-center", "--page", "sistema"])

    component Meter: ColumnLayout {
        property string label: ""
        property real value: 0
        spacing: 3
        Txt { text: label + " " + Math.round(value * 100) + "%"; font.pixelSize: Theme.textSmall - 1; font.weight: Font.DemiBold; color: Theme.fg }
        Rectangle {
            Layout.preferredWidth: 46; implicitHeight: 4; radius: 2
            color: Theme.alpha(Theme.fg, 0.14)
            Rectangle {
                width: parent.width * Math.min(1, value); height: parent.height; radius: 2
                color: value > 0.85 ? Theme.error : Theme.primary
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
    }
    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 10
        Meter { label: "CPU"; value: SysInfo.cpu }
        Meter { label: "RAM"; value: SysInfo.ram }
    }
}
