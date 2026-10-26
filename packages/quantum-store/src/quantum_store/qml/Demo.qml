import QtQuick

// Demostración guiada para grabar videos: un cursor recorre la tienda.
Item {
    id: demo
    anchors.fill: parent

    function find(name, it) {
        it = it || window.contentItem;
        if (it.objectName === name && it.visible) return it;
        const kids = it.children ? Array.from(it.children) : [];
        if (it.contentItem && kids.indexOf(it.contentItem) < 0) kids.push(it.contentItem);
        for (const k of kids) { const r = find(name, k); if (r) return r; }
        return null;
    }
    function moveTo(name, dur) {
        const it = find(name);
        if (!it) { console.warn("demo: no encontré", name); return; }
        const p = it.mapToItem(demo, it.width * 0.5, it.height * 0.5);
        mx.to = p.x; my.to = p.y; mx.duration = my.duration = dur || 700;
        move.restart();
    }
    function click() { ripple.restart(); }
    function scroll(name, y, dur) {
        const f = find(name); if (!f) return;
        sc.target = f; sc.to = y; sc.duration = dur || 900; sc.restart();
    }
    function typeText(s) {
        const box = find("search"); box.forceActiveFocus(); box.text = "";
        let i = 0;
        typer.fn = () => { box.text = s.slice(0, ++i); if (i >= s.length) typer.stop(); };
        typer.start();
    }

    // Guion: [segundos, acción]
    readonly property var steps: [
        [0.0, () => { store.mark("start"); cursor.x = demo.width * 0.62; cursor.y = demo.height * 0.55; }],
        [1.6, () => moveTo("search")],
        [2.4, () => click()],
        [2.6, () => typeText("discord")],
        [3.5, () => { store.search("discord"); window.go("buscar"); store.mark("search"); }],
        [4.8, () => moveTo("card-flathub:com.discordapp.Discord")],
        [5.6, () => { click(); window.openApp("flathub:com.discordapp.Discord"); store.mark("details"); }],
        [6.9, () => moveTo("btn-install")],
        [7.7, () => { click(); store.install("flathub:com.discordapp.Discord", "Discord"); store.mark("install"); }],
        [10.6, () => moveTo("nav-android")],
        [11.4, () => { click(); find("search").text = ""; window.go("android"); store.mark("android"); }],
        [12.6, () => scroll("flick-android", 230, 1000)],
        [14.0, () => moveTo("card-android:io.anuke.mindustry")],
        [14.8, () => { click(); window.openApp("android:io.anuke.mindustry"); store.mark("apk"); }],
        [16.0, () => moveTo("btn-install")],
        [16.8, () => { click(); store.install("android:io.anuke.mindustry", "Mindustry"); }],
        [20.0, () => store.mark("end")],
    ]
    property int idx: 0
    property real t0: 0
    Timer {
        id: runner
        interval: 16; repeat: true
        onTriggered: {
            const t = (Date.now() - demo.t0) / 1000;
            while (demo.idx < demo.steps.length && demo.steps[demo.idx][0] <= t) demo.steps[demo.idx++][1]();
            if (demo.idx >= demo.steps.length) stop();
        }
    }
    // empezar cuando la portada ya cargó
    Timer {
        interval: 200; repeat: true; running: true
        onTriggered: if ((store.home.popular || []).length && (store.android.games || []).length) {
            stop(); starter.start();
        }
    }
    Timer { id: starter; interval: 2500; onTriggered: { window.showMaximized(); demo.t0 = Date.now() + 1500; runner.start(); } }
    Timer { id: typer; interval: 95; repeat: true; property var fn; onTriggered: fn() }

    ParallelAnimation {
        id: move
        NumberAnimation { id: mx; target: cursor; property: "x"; easing.type: Easing.InOutCubic }
        NumberAnimation { id: my; target: cursor; property: "y"; easing.type: Easing.InOutCubic }
    }
    NumberAnimation { id: sc; property: "contentY"; easing.type: Easing.InOutCubic }

    Item {
        id: cursor
        width: 1; height: 1
        Rectangle {
            id: ring
            anchors.centerIn: parent
            width: 0; height: width; radius: width / 2
            color: "transparent"; border.width: 3; border.color: theme.primary
        }
        Image {
            x: -3; y: -2
            source: "../assets/cursor.svg"
            sourceSize: Qt.size(64, 64)
            width: 30; height: 30
            scale: press.running ? 0.85 : 1
            Behavior on scale { NumberAnimation { duration: 90 } }
        }
    }
    ParallelAnimation {
        id: ripple
        NumberAnimation { target: ring; property: "width"; from: 10; to: 64; duration: 420; easing.type: Easing.OutCubic }
        NumberAnimation { target: ring; property: "opacity"; from: 1; to: 0; duration: 420 }
        PauseAnimation { id: press; duration: 140 }
    }
}
