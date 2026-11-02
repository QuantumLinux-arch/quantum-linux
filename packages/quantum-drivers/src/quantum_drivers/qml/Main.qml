import QtQuick
import QtQuick.Layouts
import QtQuick.Window

// Drivers: muestra cada tarjeta gráfica con el driver que usa. Si es una NVIDIA sin el suyo,
// una tarjeta grande ofrece instalarlo con un clic; mientras se instala, los pasos en vivo.
Window {
    id: win
    width: 860
    height: 640
    minimumWidth: 760
    minimumHeight: 560
    visible: true
    title: "Drivers"
    color: theme.bg

    Theme { id: theme }

    readonly property var gpus: drivers.info.gpus ?? []
    readonly property var need: gpus.find(g => g.needs) ?? null
    readonly property var brandColor: ({ nvidia: "#76B900", amd: "#ED1C24", intel: "#0071C5", otra: "#9AA0A6" })

    component Grad: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: theme.cyan }
        GradientStop { position: 0.5; color: theme.indigo }
        GradientStop { position: 1; color: theme.violet }
    }
    component Pill: Rectangle {
        id: pill
        property string text: ""
        property string icon: ""
        property bool primary: false
        signal clicked
        implicitWidth: pr.implicitWidth + 44; implicitHeight: 48; radius: 24
        color: primary ? "transparent" : pa.containsMouse ? theme.cardHi : theme.card
        gradient: primary ? pg : null
        border.width: primary ? 0 : 1; border.color: theme.line
        scale: pa.pressed ? 0.95 : pa.containsMouse ? 1.03 : 1
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
        Grad { id: pg }
        Row {
            id: pr
            anchors.centerIn: parent; spacing: 8
            Sym { anchors.verticalCenter: parent.verticalCenter; visible: pill.icon !== ""; text: pill.icon; size: 20; fill: 1; color: pill.primary ? "white" : theme.fg }
            T { anchors.verticalCenter: parent.verticalCenter; text: pill.text; font.weight: Font.Bold; font.pixelSize: 15; color: pill.primary ? "white" : theme.fg }
        }
        MouseArea { id: pa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pill.clicked() }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 18

        RowLayout {
            spacing: 14
            Image { source: assetsDir + "/quantum-drivers.svg"; sourceSize: Qt.size(104, 104); Layout.preferredWidth: 52; Layout.preferredHeight: 52 }
            ColumnLayout {
                spacing: 0
                T { text: "Drivers"; font.pixelSize: 26; font.weight: Font.Black }
                T { text: "Para que tu tarjeta gráfica rinda al máximo"; color: theme.muted }
            }
        }

        // ---------------------------------------------------- hace falta el driver
        Rectangle {
            visible: !!win.need
            Layout.fillWidth: true
            implicitHeight: needCol.implicitHeight + 48
            radius: 26
            color: theme.alpha(theme.indigo, 0.14)
            border.width: 2
            border.color: theme.alpha(theme.violet, 0.55)
            ColumnLayout {
                id: needCol
                anchors.fill: parent
                anchors.margins: 24
                spacing: 10
                RowLayout {
                    spacing: 12
                    Sym { text: "rocket_launch"; size: 30; fill: 1; color: theme.cyan }
                    T { Layout.fillWidth: true; text: "Tu NVIDIA puede rendir mucho más"; font.pixelSize: 22; font.weight: Font.Black }
                }
                T {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap; elide: Text.ElideNone
                    color: theme.muted
                    text: win.need ? "Ahora usa un driver básico que no saca todo su poder: los juegos pueden ir lentos o no abrir. " +
                                     "Instala el driver de NVIDIA (" + win.need.variantName + ") y aprovecha tu tarjeta al máximo." : ""
                }
                T {
                    visible: !!win.need && win.need.aur
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap; elide: Text.ElideNone
                    color: theme.muted; font.pixelSize: 12
                    text: "Es una tarjeta antigua: su driver se prepara en tu PC y puede tardar unos 10 minutos."
                }
                RowLayout {
                    Layout.topMargin: 6
                    spacing: 10
                    Pill { primary: true; icon: "download"; text: "Instalar el driver"; onClicked: drivers.install() }
                    Pill { text: "Más tarde"; onClicked: drivers.later() }
                }
            }
        }

        // ------------------------------------------------------------ todo bien
        Rectangle {
            visible: !win.need
            Layout.fillWidth: true
            implicitHeight: 96
            radius: 26
            color: theme.alpha(theme.cyan, 0.1)
            border.width: 1; border.color: theme.alpha(theme.cyan, 0.4)
            RowLayout {
                anchors.fill: parent; anchors.margins: 22
                spacing: 14
                Sym { text: "verified"; size: 34; fill: 1; color: theme.cyan }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    T { text: "Todo listo"; font.pixelSize: 20; font.weight: Font.Black }
                    T { Layout.fillWidth: true; text: "Tu tarjeta gráfica ya usa el mejor driver. No hay que hacer nada."; color: theme.muted }
                }
            }
        }

        T { Layout.topMargin: 4; text: "Tus tarjetas gráficas"; font.pixelSize: 17; font.weight: Font.Bold }
        Repeater {
            model: win.gpus
            Rectangle {
                id: gpuCard
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 76
                radius: 20
                color: theme.card
                RowLayout {
                    anchors.fill: parent; anchors.margins: 16
                    spacing: 14
                    Rectangle {
                        implicitWidth: 44; implicitHeight: 44; radius: 14
                        color: theme.alpha(win.brandColor[gpuCard.modelData.brand] ?? "#9AA0A6", 0.2)
                        Sym { anchors.centerIn: parent; text: "memory"; size: 24; color: win.brandColor[gpuCard.modelData.brand] ?? theme.fg }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        T { Layout.fillWidth: true; text: gpuCard.modelData.name; font.weight: Font.Bold }
                        T { text: "Driver: " + gpuCard.modelData.driver; color: theme.muted; font.pixelSize: 12 }
                    }
                    Rectangle {
                        implicitWidth: st.implicitWidth + 22; implicitHeight: 28; radius: 14
                        color: gpuCard.modelData.needs ? theme.alpha("#FFB547", 0.18) : theme.alpha(theme.cyan, 0.16)
                        T { id: st; anchors.centerIn: parent; text: gpuCard.modelData.needs ? "Falta el driver" : "Funcionando bien"
                            color: gpuCard.modelData.needs ? "#FFB547" : theme.cyan; font.pixelSize: 12; font.weight: Font.DemiBold }
                    }
                }
            }
        }
        T {
            visible: drivers.info.vm ?? false
            text: "Estás en una máquina virtual: aquí no hace falta instalar drivers de gráfica."
            color: theme.muted; font.pixelSize: 12
        }
        Item { Layout.fillHeight: true }
    }

    // ------------------------------------------------------------ instalando
    Rectangle {
        anchors.fill: parent
        visible: opacity > 0
        opacity: drivers.job !== "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        color: theme.bg
        MouseArea { anchors.fill: parent }
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 18
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 150; implicitHeight: 150
                Rectangle {
                    anchors.centerIn: parent
                    width: 150; height: 150; radius: 75
                    color: "transparent"; border.width: 4; border.color: theme.alpha(theme.indigo, 0.25)
                }
                // arco que gira mientras instala
                Canvas {
                    id: arc
                    anchors.fill: parent
                    visible: drivers.job === "running"
                    property real a: 0
                    RotationAnimation on a { running: drivers.job === "running"; from: 0; to: 360; duration: 1400; loops: Animation.Infinite }
                    rotation: a
                    onPaint: {
                        const c = getContext("2d"); c.reset();
                        const g = c.createLinearGradient(0, 0, width, height);
                        g.addColorStop(0, "#4FD8FF"); g.addColorStop(1, "#B14DFF");
                        c.strokeStyle = g; c.lineWidth = 6; c.lineCap = "round";
                        c.beginPath(); c.arc(width / 2, height / 2, 73, 0, Math.PI * 1.2); c.stroke();
                    }
                }
                Image {
                    anchors.centerIn: parent
                    width: 82; height: 82
                    source: assetsDir + "/quantum-drivers.svg"
                    sourceSize: Qt.size(164, 164)
                }
            }
            T {
                Layout.alignment: Qt.AlignHCenter
                text: drivers.job === "done" ? "Driver instalado" : drivers.job === "error" ? "No se pudo instalar" : "Instalando el driver…"
                font.pixelSize: 28; font.weight: Font.Black
            }
            Column {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                visible: drivers.job !== "error"
                Repeater {
                    model: ["Descargando el driver", "Preparándolo para tu sistema", "Activándolo"]
                    Row {
                        id: srow
                        required property string modelData
                        required property int index
                        readonly property bool ok: drivers.step > index + 1 || drivers.job === "done"
                        readonly property bool now: drivers.step === index + 1 && drivers.job === "running"
                        spacing: 10
                        Sym { text: srow.ok ? "check_circle" : srow.now ? "progress_activity" : "radio_button_unchecked"; size: 20; fill: srow.ok ? 1 : 0
                              color: srow.ok ? theme.cyan : srow.now ? theme.accent : theme.muted
                              RotationAnimation on rotation { running: srow.now; from: 0; to: 360; duration: 1000; loops: Animation.Infinite } }
                        T { text: srow.modelData; color: srow.ok || srow.now ? theme.fg : theme.muted; font.pixelSize: 15 }
                    }
                }
            }
            T {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 480
                visible: drivers.job === "done" || drivers.job === "error"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap; elide: Text.ElideNone
                color: theme.muted
                text: drivers.job === "done" ? "Reinicia el PC para empezar a usarlo. Si algo no te gusta, Cronos puede volver a como estaba antes."
                                             : (drivers.stepText || "Algo salió mal.") + " Revisa tu internet e inténtalo de nuevo."
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                visible: drivers.job === "done" || drivers.job === "error"
                spacing: 10
                Pill { text: drivers.job === "done" ? "Más tarde" : "Volver"; onClicked: drivers.job === "done" ? Qt.quit() : drivers.reset() }
                Pill { visible: drivers.job === "done"; primary: true; icon: "restart_alt"; text: "Reiniciar ahora"; onClicked: drivers.reboot() }
            }
        }
    }
}
