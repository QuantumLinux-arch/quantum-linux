/* Navegación del instalador de Quantum Linux: progreso a la izquierda y
   botones redondeados a la derecha (Siguiente con el degradado de Quantum).
   SPDX-License-Identifier: GPL-3.0-or-later
*/
import io.calamares.ui 1.0
import io.calamares.core 1.0

import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: nav
    color: "#13121C"
    height: 76

    readonly property int current: ViewManager.currentStepIndex
    // ViewManager.rowCount() no avisa cambios: se cuentan los pasos con un Repeater
    readonly property int count: counter.count
    Repeater { id: counter; model: ViewManager; Item {} }
    // los textos de Calamares traen «&» para atajos de teclado
    function clean(s) { return (s || "").replace("&", ""); }

    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: "#22202D" }

    component NavButton: Rectangle {
        id: b
        property string text
        property string kind: "tonal"   // "primary" | "tonal" | "ghost"
        signal clicked
        implicitWidth: label.implicitWidth + 48
        implicitHeight: 44
        radius: 22
        opacity: enabled ? 1 : 0.4
        color: kind === "tonal" ? (area.containsMouse ? "#35343E" : "#2A2933") : kind === "ghost" ? (area.containsMouse ? "#22202D" : "transparent") : "transparent"
        gradient: kind === "primary" ? g : null
        scale: area.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: 120 } }
        Gradient {
            id: g
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#4FD8FF" }
            GradientStop { position: 0.5; color: "#6A5CFF" }
            GradientStop { position: 1.0; color: "#B14DFF" }
        }
        Text {
            id: label
            anchors.centerIn: parent
            text: b.text
            font.family: "Inter"; font.pixelSize: 15; font.weight: Font.Bold
            color: b.kind === "ghost" ? "#9C95B8" : "#FFFFFF"
        }
        MouseArea {
            id: area
            anchors.fill: parent
            enabled: b.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: b.clicked()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 28
        anchors.rightMargin: 22
        spacing: 12

        // progreso
        ColumnLayout {
            spacing: 6
            Text {
                text: "Paso " + (nav.current + 1) + " de " + nav.count
                color: "#9C95B8"
                font.family: "Inter"; font.pixelSize: 13; font.weight: Font.DemiBold
            }
            Rectangle {
                implicitWidth: 220; implicitHeight: 6; radius: 3
                color: "#2A2933"
                Rectangle {
                    height: parent.height; radius: 3
                    width: parent.width * (nav.current + 1) / Math.max(1, nav.count)
                    Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#4FD8FF" }
                        GradientStop { position: 0.5; color: "#6A5CFF" }
                        GradientStop { position: 1.0; color: "#B14DFF" }
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }

        NavButton {
            text: nav.clean(ViewManager.quitLabel)
            kind: "ghost"
            enabled: ViewManager.quitEnabled
            visible: ViewManager.quitVisible
            onClicked: ViewManager.quit()
        }
        NavButton {
            text: nav.clean(ViewManager.backLabel)
            kind: "tonal"
            enabled: ViewManager.backEnabled
            visible: ViewManager.backAndNextVisible
            onClicked: ViewManager.back()
        }
        NavButton {
            text: nav.clean(ViewManager.nextLabel)
            kind: "primary"
            enabled: ViewManager.nextEnabled
            visible: ViewManager.backAndNextVisible
            onClicked: ViewManager.next()
        }
    }
}
