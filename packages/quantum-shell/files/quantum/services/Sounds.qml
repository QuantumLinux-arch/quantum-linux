pragma Singleton

import QtQuick
import Quickshell

// Sonidos del sistema (creados para Quantum, en assets/sounds). Se reproducen con
// pw-play (PipeWire). Se activan, ajustan o apagan en Personalizar → Sonidos.
Singleton {
    id: root

    readonly property bool enabled: Settings.sounds.enabled
    readonly property real volume: Settings.sounds.volume

    // name: startup | volume | toggle-on | toggle-off | click | notification | lock | unlock | error | screenshot
    function play(name: string): void {
        if (!enabled && name !== "test") return;
        if (name === "test") name = "notification";
        if (name === "startup" && !Settings.sounds.startup) return;
        // no apilar el mismo sonido muchas veces (p. ej. al mover el volumen)
        const now = Date.now();
        if (now - (_last[name] ?? 0) < 70) return;
        _last[name] = now;
        Quickshell.execDetached(["pw-play", "--volume", String(Math.max(0, Math.min(1, volume))),
                                 Quickshell.shellDir + "/assets/sounds/" + name + ".oga"]);
    }
    property var _last: ({})

}
