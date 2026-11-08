pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland

// Gestor de ventanas (Wayfire) a través de protocolos estándar de Wayland:
// ventanas abiertas para la barra de tareas y la pantalla donde mostrar paneles.
Singleton {
    id: root

    readonly property var windows: ToplevelManager.toplevels.values
    readonly property var active: ToplevelManager.activeToplevel

    // Los paneles se abren en la pantalla de la ventana activa (o en la primera).
    readonly property var screen: active?.screens?.[0] ?? Quickshell.screens[0]

    // Las ventanas propias del shell (Personalizar) llegan como «org.quickshell».
    function iconFor(appId: string): string {
        if (appId === "org.quickshell") return "quantum-personalize";
        return DesktopEntries.heuristicLookup(appId)?.icon ?? appId;
    }

    // Grupos de la barra de tareas: fijadas primero (en su orden) y luego las
    // demás abiertas. Cada grupo: { id, name, icon, entry, pinned, wins }.
    // Se cachea y solo se recalcula cuando cambia el estado real (evita parpadeo).
    property var groups: []

    function updateGroups(): void {
        const pinned = (Settings.dock.pinned ?? []).slice();
        const out = [];
        const byId = {};
        const add = (id, entry, isPinned) => {
            const g = { id, entry, pinned: isPinned, wins: [],
                        name: entry?.name ?? root.nameFor(id), icon: entry?.icon ?? root.iconFor(id) };
            byId[id] = g;
            out.push(g);
            return g;
        };
        for (let i = 0; i < pinned.length; i++) {
            const pid = pinned[i];
            const e = DesktopEntries.byId(pid) ?? DesktopEntries.heuristicLookup(pid);
            if (e)
                add(e.id, e, true);
            else
                add(pid, null, true);
        }
        for (let i = 0; i < root.windows.length; i++) {
            const w = root.windows[i];
            const e = DesktopEntries.heuristicLookup(w.appId);
            const id = e?.id ?? w.appId;
            const g = byId[id] ?? add(id, e, false);
            if (g.wins.indexOf(w) === -1)
                g.wins.push(w);
        }
        groups = out;
    }

    Component.onCompleted: updateGroups()
    onWindowsChanged: updateGroups()
    Connections {
        target: ToplevelManager.toplevels
        function onValuesChanged(): void { root.updateGroups(); }
    }
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged(): void { root.updateGroups(); }
    }
    Connections {
        target: Settings.dock
        function onPinnedChanged(): void { root.updateGroups(); }
    }

    function togglePin(id: string): void {
        const list = (Settings.dock.pinned ?? []).slice();
        const i = list.indexOf(id);
        if (i >= 0) list.splice(i, 1);
        else list.push(id);
        Settings.setPinned(list);
    }

    // Mueve una app de la barra a la posición «to» (índice entre todos los íconos).
    // Las fijadas van primero: si se suelta una app no fijada entre las fijadas, queda fijada ahí.
    function moveGroup(id: string, to: int): void {
        const list = (Settings.dock.pinned ?? []).slice();
        const from = list.indexOf(id);
        if (from >= 0) {
            list.splice(from, 1);
            list.splice(Math.max(0, Math.min(list.length, to)), 0, id);
        } else if (to <= list.length) {
            list.splice(Math.max(0, to), 0, id);
        } else {
            return;
        }
        Settings.setPinned(list);
    }

    function nameFor(appId: string): string {
        if (appId === "org.quickshell") return "Personalizar";
        return DesktopEntries.heuristicLookup(appId)?.name ?? appId;
    }

    // Clic en la barra de tareas: si ya está activa se minimiza, si no, se enfoca.
    function toggle(win: Toplevel): void {
        if (win.activated && !win.minimized)
            win.minimized = true;
        else
            win.activate();
    }

    // Super + número (como en Windows): la app en esa posición de la barra. Cerrada: se abre. Abierta: se enfoca;
    // si ya está al frente se minimiza; con varias ventanas, cada vez pasa a la siguiente.
    function activateSlot(n: int): void {
        const g = groups[n - 1];
        if (!g) return;
        const wins = g.wins;
        if (!wins.length) {
            if (g.entry) Apps.launch(g.entry);
            return;
        }
        if (wins.length === 1) { toggle(wins[0]); return; }
        const cur = wins.findIndex(w => w.activated && !w.minimized);
        const next = wins[(cur + 1) % wins.length];
        next.activate();
    }

    // «Mostrar escritorio» (como el rincón de Windows): minimiza todo; otra vez, vuelve a como estaba
    property var _hidden: []
    function toggleDesktop(): void {
        const vis = ToplevelManager.toplevels.values.filter(w => !w.minimized);
        if (vis.length) {
            _hidden = vis;
            for (const w of vis) w.minimized = true;
        } else {
            for (const w of _hidden) { try { w.minimized = false; } catch (e) {} }
            if (_hidden.length) _hidden[_hidden.length - 1].activate();
            _hidden = [];
        }
    }

    function logout(): void {
        Quickshell.execDetached(["sh", "-c", "loginctl terminate-session \"$XDG_SESSION_ID\""]);
    }
}
