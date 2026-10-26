// Pantalla de inicio de sesión de Quantum Linux (SDDM, Qt 6), con el mismo estilo
// que la pantalla de bloqueo (Super + L): el fondo del usuario difuminado, reloj con
// dígitos que ruedan, la foto en un hexágono con las órbitas de Quantum y la
// contraseña en una píldora. Todo entra con animación.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

Rectangle {
    id: root

    width: 1920
    height: 1080
    color: "#07060D"

    readonly property color accent: config.accent || "#c5c0ff"
    readonly property color accentText: config.accentText || "#2a1a9a"
    readonly property color cyan: "#4FD8FF"
    readonly property color indigo: "#6A5CFF"
    readonly property color violet: "#B14DFF"
    readonly property color errorColor: "#FF8A95"
    readonly property string iconFont: "Material Symbols Rounded"

    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property string error: ""
    property bool busy: false
    property bool success: false
    property var sessionNames: []

    // reloj de animación (segundos) y entrada (ms desde que aparece la pantalla)
    property real time: 0
    property real intro: 0
    FrameAnimation { running: true; onTriggered: { root.time += frameTime; root.intro += frameTime * 1000; } }
    function stage(start: real, len: real): real { return Math.max(0, Math.min(1, (intro - start) / len)); }
    function ease(t: real): real { return 1 - Math.pow(1 - t, 3); }
    function back(t: real): real { const c = 1.7; return 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2); }

    readonly property var current: users.count > 0 ? users.itemAt(userIndex) : null
    function currentUser(): string { return current?.login ?? userModel.lastUser; }

    function login(): void {
        if (busy || success)
            return;
        busy = true;
        error = "";
        sddm.login(currentUser(), password.text, sessionIndex);
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false;
            root.error = "Contraseña incorrecta";
            password.text = "";
            password.forceActiveFocus();
            shake.start();
        }
        function onLoginSucceeded() { root.busy = false; root.success = true; }
    }

    // ------------------------------------------------------------------ fondo
    // el fondo de cada usuario (lo deja quantum-theme); si no hay, el de Quantum
    Image {
        id: wall
        anchors.fill: parent
        readonly property string mine: "file:///var/lib/quantum/login/" + root.currentUser() + ".jpg"
        source: mine
        onStatusChanged: if (status === Image.Error && source.toString() !== "file://" + config.background) source = "file://" + config.background
        onMineChanged: source = mine
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.width / 2, root.height / 2)
        asynchronous: true
        scale: 1.08 - 0.04 * root.ease(root.stage(0, 1400))
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blur: 0.85; blurMax: 56; saturation: 0.15 }
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0.02, 0.02, 0.06, 0.55) }
            GradientStop { position: 0.5; color: Qt.rgba(0.02, 0.02, 0.06, 0.3) }
            GradientStop { position: 1; color: Qt.rgba(0.02, 0.02, 0.06, 0.7) }
        }
    }
    // estrellas que titilan
    Repeater {
        model: 60
        Rectangle {
            required property int index
            function rnd(k) { const s = Math.sin(index * 12.9898 + k * 78.233) * 43758.5453; return s - Math.floor(s); }
            x: rnd(1) * root.width; y: rnd(2) * root.height
            width: 1.5 + rnd(3) * 2; height: width; radius: width / 2; color: "white"
            opacity: (0.1 + 0.35 * rnd(4)) * (0.55 + 0.45 * Math.sin(root.time * (0.8 + rnd(6) * 1.6) + index)) * root.stage(200, 1200)
        }
    }

    // ------------------------------------------------------------------ centro
    Column {
        id: center
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -20
        spacing: 0
        opacity: root.success ? 0 : 1
        scale: root.success ? 1.06 : 1
        Behavior on opacity { NumberAnimation { duration: 400 } }
        Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.InCubic } }

        // hora: horas grandes y minutos al lado; cada dígito rueda al cambiar
        Row {
            id: clockRow
            readonly property real e: root.ease(root.stage(100, 700))
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16
            opacity: e
            transform: Translate { y: (1 - clockRow.e) * -40 }
            property date now: new Date()
            Timer { interval: 1000; running: true; repeat: true; onTriggered: clockRow.now = new Date() }
            Row {
                Repeater {
                    model: 2
                    RollDigit {
                        required property int index
                        ch: Qt.formatDateTime(clockRow.now, "HH").charAt(index)
                        color: root.accent
                        font.family: "Inter"
                        font.pixelSize: 180
                        font.weight: Font.Black
                        font.letterSpacing: -5
                        font.features: { "tnum": 1 }
                    }
                }
            }
            Row {
                anchors.top: parent.top
                anchors.topMargin: 26
                Repeater {
                    model: 2
                    RollDigit {
                        required property int index
                        ch: Qt.formatDateTime(clockRow.now, "mm").charAt(index)
                        color: "white"
                        font.family: "Inter"
                        font.pixelSize: 90
                        font.weight: Font.Black
                        font.letterSpacing: -3
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }
        Text {
            readonly property real e: root.ease(root.stage(240, 600))
            anchors.horizontalCenter: parent.horizontalCenter
            text: clockRow.now.toLocaleDateString(Qt.locale("es_CL"), "dddd • d MMMM").toUpperCase()
            font.family: "Inter"
            font.pixelSize: 20
            font.weight: Font.Bold
            font.letterSpacing: 1 + 8 * (1 - e)
            color: "white"
            opacity: e * 0.9
        }

        Item { width: 1; height: 34 }

        // foto en hexágono con las órbitas de Quantum girando detrás
        Item {
            id: avatarBox
            readonly property real e: root.stage(360, 800)
            anchors.horizontalCenter: parent.horizontalCenter
            width: 290; height: 200
            scale: root.back(e)
            rotation: (1 - root.ease(e)) * -12
            opacity: Math.min(1, e * 2)

            // resplandor que respira (rojo al fallar, verde al entrar)
            Rectangle {
                anchors.centerIn: parent
                width: 270; height: 270; radius: 135
                color: root.error ? root.errorColor : root.success ? "#3DDC84" : root.indigo
                Behavior on color { ColorAnimation { duration: 300 } }
                opacity: 0.32 + 0.1 * Math.sin(root.time * 1.6)
                scale: 1 + 0.06 * Math.sin(root.time * 1.6)
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64 }
            }
            Item {
                anchors.centerIn: parent
                width: 440; height: 440
                rotation: Math.sin(root.time * 0.35) * 8
                Repeater {
                    model: [-22, 0, 22]
                    Item {
                        id: orb
                        required property real modelData
                        required property int index
                        anchors.fill: parent
                        rotation: modelData
                        readonly property real a: root.time * (0.7 + index * 0.25) + index * 2.1
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                strokeWidth: 2
                                strokeColor: Qt.rgba(0.77, 0.75, 1, 0.28)
                                fillColor: "transparent"
                                PathAngleArc { centerX: 220; centerY: 220; radiusX: 212; radiusY: 52; startAngle: 0; sweepAngle: 360 }
                            }
                        }
                        Rectangle {
                            width: 12; height: 12; radius: 6
                            x: 220 + 212 * Math.cos(orb.a) - 6
                            y: 220 + 52 * Math.sin(orb.a) - 6
                            color: [root.cyan, root.indigo, root.violet][orb.index]
                            border.width: 2; border.color: "white"
                            z: Math.sin(orb.a) > 0 ? 2 : -1
                        }
                    }
                }
            }
            Item {
                id: avatar
                anchors.centerIn: parent
                width: 290; height: 200
                readonly property bool hasFace: face.status === Image.Ready
                Image {
                    id: face
                    visible: false
                    anchors.fill: parent
                    source: root.current?.icon ? "file://" + root.current.icon : ""
                    sourceSize: Qt.size(580, 400)
                    fillMode: Image.PreserveAspectCrop
                }
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeWidth: 3
                        strokeColor: root.error ? root.errorColor : Qt.rgba(1, 1, 1, 0.14)
                        fillColor: avatar.hasFace ? "transparent" : Qt.rgba(0.11, 0.1, 0.17, 0.92)
                        fillItem: avatar.hasFace ? face : null
                        startX: avatar.width * 0.22; startY: 0
                        PathLine { x: avatar.width * 0.78; y: 0 }
                        PathArc { x: avatar.width * 0.86; y: avatar.height * 0.08; radiusX: 28; radiusY: 28 }
                        PathLine { x: avatar.width; y: avatar.height * 0.46 }
                        PathArc { x: avatar.width; y: avatar.height * 0.54; radiusX: 28; radiusY: 28 }
                        PathLine { x: avatar.width * 0.86; y: avatar.height * 0.92 }
                        PathArc { x: avatar.width * 0.78; y: avatar.height; radiusX: 28; radiusY: 28 }
                        PathLine { x: avatar.width * 0.22; y: avatar.height }
                        PathArc { x: avatar.width * 0.14; y: avatar.height * 0.92; radiusX: 28; radiusY: 28 }
                        PathLine { x: 0; y: avatar.height * 0.54 }
                        PathArc { x: 0; y: avatar.height * 0.46; radiusX: 28; radiusY: 28 }
                        PathLine { x: avatar.width * 0.14; y: avatar.height * 0.08 }
                        PathArc { x: avatar.width * 0.22; y: 0; radiusX: 28; radiusY: 28 }
                    }
                }
                // sin foto: el logo de Quantum, meciéndose suave
                Image {
                    visible: !avatar.hasFace
                    anchors.centerIn: parent
                    width: 130; height: 130
                    source: "quantum-mark.svg"
                    sourceSize: Qt.size(260, 260)
                    rotation: Math.sin(root.time * 0.6) * 8
                }
            }
            // al entrar: check verde
            Rectangle {
                anchors.centerIn: parent
                width: 70; height: 70; radius: 35
                color: "#22B573"
                scale: root.success ? 1 : 0
                Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }
                Text { anchors.centerIn: parent; text: "check"; font.family: root.iconFont; font.pixelSize: 42; color: "white" }
            }
        }

        Item { width: 1; height: 18 }

        Text {
            readonly property real e: root.ease(root.stage(480, 600))
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.current ? (root.current.realName || root.current.login) : ""
            font.family: "Inter"
            font.pixelSize: 24
            font.weight: Font.Bold
            color: "white"
            opacity: e
        }

        Item { width: 1; height: 18 }

        // contraseña
        Item {
            id: fieldBox
            readonly property real e: root.ease(root.stage(560, 650))
            anchors.horizontalCenter: parent.horizontalCenter
            width: 340; height: 54
            opacity: e
            transform: Translate { y: (1 - fieldBox.e) * 30 }

            Rectangle {
                id: field
                width: parent.width; height: parent.height
                radius: 27
                color: Qt.rgba(0.11, 0.1, 0.17, 0.88)
                border.width: password.activeFocus || root.error ? 2 : 1
                border.color: root.error ? root.errorColor : password.activeFocus ? Qt.rgba(0.77, 0.75, 1, 0.7) : Qt.rgba(1, 1, 1, 0.1)
                Behavior on border.color { ColorAnimation { duration: 200 } }

                Text {
                    x: 20; anchors.verticalCenter: parent.verticalCenter
                    text: root.success ? "lock_open" : "lock"
                    font.family: root.iconFont; font.pixelSize: 20
                    color: root.success ? "#3DDC84" : Qt.rgba(1, 1, 1, 0.6)
                }
                TextInput {
                    id: password
                    anchors.fill: parent
                    anchors.leftMargin: 54
                    anchors.rightMargin: 56
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: "transparent"
                    selectionColor: "transparent"
                    selectedTextColor: "transparent"
                    cursorDelegate: Item {}
                    font.pixelSize: 17
                    focus: true
                    enabled: !root.busy && !root.success
                    onTextChanged: if (text) root.error = ""
                    onAccepted: root.login()
                    Keys.onUpPressed: root.userIndex = (root.userIndex + users.count - 1) % users.count
                    Keys.onDownPressed: root.userIndex = (root.userIndex + 1) % users.count
                    Component.onCompleted: forceActiveFocus()
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !password.text
                        text: root.busy ? "Verificando…" : root.error || "Escribe tu contraseña"
                        color: root.error ? root.errorColor : Qt.rgba(1, 1, 1, 0.55)
                        font.family: "Inter"
                        font.pixelSize: 15
                    }
                }
                // puntos que aparecen con rebote; al verificar hacen una ola
                Row {
                    x: 54; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 54 - 56
                    height: 24
                    clip: true
                    spacing: 7
                    Repeater {
                        model: password.text.length
                        Rectangle {
                            id: dot
                            required property int index
                            anchors.verticalCenter: parent.verticalCenter
                            width: 11; height: 11; radius: 5.5
                            color: root.success ? "#3DDC84" : root.accent
                            scale: 0
                            NumberAnimation on scale { to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
                            transform: Translate { y: root.busy ? -5 * Math.max(0, Math.sin(root.time * 9 - dot.index * 0.6)) : 0 }
                        }
                    }
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 7
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40; height: 40; radius: 20
                    color: password.text ? root.accent : "transparent"
                    Behavior on color { ColorAnimation { duration: 180 } }
                    scale: password.text ? 1 : 0.85
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                    Text {
                        anchors.centerIn: parent
                        text: root.busy ? "progress_activity" : "arrow_forward"
                        font.family: root.iconFont; font.pixelSize: 22
                        color: password.text ? root.accentText : "white"
                        rotation: root.busy ? root.time * 360 : 0
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.login() }
                }
            }
            SequentialAnimation {
                id: shake
                NumberAnimation { target: field; property: "x"; to: 16; duration: 45 }
                NumberAnimation { target: field; property: "x"; to: -14; duration: 70 }
                NumberAnimation { target: field; property: "x"; to: 9; duration: 60 }
                NumberAnimation { target: field; property: "x"; to: -5; duration: 50 }
                NumberAnimation { target: field; property: "x"; to: 0; duration: 40 }
            }
        }

        Item { width: 1; height: 14 }

        // Bloq Mayús
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Bloq Mayús está activado"
            font.family: "Inter"; font.pixelSize: 13; font.weight: Font.DemiBold
            color: "#FFC56B"
            opacity: keyboard.capsLock ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        Item { width: 1; height: 18 }

        // otros usuarios: se elige con un clic (o con ↑ ↓)
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            visible: users.count > 1
            opacity: root.ease(root.stage(700, 600))

            Repeater {
                id: users
                model: userModel

                Rectangle {
                    id: user
                    required property int index
                    required property string name
                    required property string realName
                    required property string icon
                    readonly property string login: name
                    readonly property bool selected: index === root.userIndex
                    width: chip.implicitWidth + 30
                    height: 38
                    radius: 19
                    color: selected ? Qt.rgba(0.77, 0.75, 1, 0.22) : Qt.rgba(0.11, 0.1, 0.17, 0.7)
                    border.width: 1
                    border.color: selected ? Qt.rgba(0.77, 0.75, 1, 0.6) : Qt.rgba(1, 1, 1, 0.1)
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Text {
                        id: chip
                        anchors.centerIn: parent
                        text: user.realName || user.name
                        font.family: "Inter"; font.pixelSize: 14
                        font.weight: user.selected ? Font.Bold : Font.Normal
                        color: "white"
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.userIndex = user.index; root.error = ""; password.text = ""; password.forceActiveFocus(); }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------ abajo
    component Pill: Rectangle {
        id: pill
        property string icon: ""
        property string label: ""
        signal clicked
        width: row.implicitWidth + 28
        height: 40
        radius: 20
        color: area.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0.11, 0.1, 0.17, 0.72)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.1)
        Behavior on color { ColorAnimation { duration: 150 } }
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8
            Text { visible: pill.icon !== ""; text: pill.icon; font.family: root.iconFont; font.pixelSize: 19; color: "white"; anchors.verticalCenter: parent.verticalCenter }
            Text { visible: pill.label !== ""; text: pill.label; font.family: "Inter"; font.pixelSize: 14; color: "white"; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pill.clicked() }
    }
    component RoundButton: Rectangle {
        id: rb
        property string icon: ""
        property string tip: ""
        signal clicked
        width: 46; height: 46; radius: 23
        color: ra.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0.11, 0.1, 0.17, 0.72)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.1)
        scale: ra.pressed ? 0.92 : ra.containsMouse ? 1.06 : 1
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
        Behavior on color { ColorAnimation { duration: 150 } }
        Text { anchors.centerIn: parent; text: rb.icon; font.family: root.iconFont; font.pixelSize: 22; color: "white" }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: 8
            text: rb.tip
            font.family: "Inter"; font.pixelSize: 12
            color: "white"
            opacity: ra.containsMouse ? 0.9 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
        MouseArea { id: ra; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rb.clicked() }
    }

    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 28
        spacing: 10
        opacity: root.ease(root.stage(800, 600))
        Pill {
            visible: sessionModel.rowCount() > 1
            icon: "desktop_windows"
            label: root.sessionNames[root.sessionIndex] ?? ""
            onClicked: root.sessionIndex = (root.sessionIndex + 1) % sessionModel.rowCount()
        }
        Pill {
            icon: "keyboard"
            label: (keyboard.layouts[keyboard.currentLayout]?.shortName ?? "").toUpperCase()
            visible: label !== ""
            onClicked: if (keyboard.layouts.length > 1) keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
        }
    }

    Repeater {
        id: sessions
        model: sessionModel
        onItemAdded: (i, item) => {
            const names = root.sessionNames.slice();
            names[i] = item.sessionName;
            root.sessionNames = names;
        }
        Item {
            required property string name
            readonly property string sessionName: name
        }
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 28
        spacing: 12
        opacity: root.ease(root.stage(800, 600))
        RoundButton { icon: "bedtime"; tip: "Suspender"; visible: sddm.canSuspend; onClicked: sddm.suspend() }
        RoundButton { icon: "restart_alt"; tip: "Reiniciar"; visible: sddm.canReboot; onClicked: sddm.reboot() }
        RoundButton { icon: "power_settings_new"; tip: "Apagar"; visible: sddm.canPowerOff; onClicked: sddm.powerOff() }
    }

    // marca abajo al centro
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 38
        spacing: 8
        opacity: 0.7 * root.ease(root.stage(900, 600))
        Image { source: "quantum-mark.svg"; width: 18; height: 18; sourceSize: Qt.size(36, 36); anchors.verticalCenter: parent.verticalCenter }
        Text { text: "Quantum Linux"; font.family: "Inter"; font.pixelSize: 13; color: "white"; anchors.verticalCenter: parent.verticalCenter }
    }
}
