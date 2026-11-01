pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.services

// Quarki, el asistente de Quantum (vive en la barra de tareas; Super + H).
// Las órdenes comunes las entiende aquí mismo, sin IA ni internet: abrir apps y carpetas,
// instalar y desinstalar (siempre con una tarjeta para confirmar), volumen, brillo, modo
// oscuro, modo juego, fondo, capturas, actualizaciones, apagar… Lo demás lo conversa con la
// IA local (Ai.qml, Ollama) si está instalada; la IA también puede pedir acciones con
// etiquetas [[abrir: …]], [[instalar: …]] o [[desinstalar: …]].
Singleton {
    id: root

    // [{ id, from: "me"|"quarki", text, card }]   card: null o { type, status, … }
    property var messages: []
    property int _next: 1
    property string userName: Quickshell.env("QUANTUM_USER_NAME") || ""

    // ------------------------------------------------------------- ánimo
    property bool happy: false
    readonly property bool thinking: searchProc.running || ownerProc.running || Ai.busy
    readonly property bool working: jobProc.running
    property string jobName: ""
    readonly property string mood: working ? "work" : thinking ? "think" : happy ? "done" : Shell.aiOpen ? "awake" : "sleep"
    readonly property string statusText: working ? (jobKind === "remove" ? "Desinstalando " : "Instalando ") + jobName + "…"
        : thinking ? "Pensando…" : Ai.status === "ready" ? "Listo para ayudarte" : "Listo para ayudarte · sin IA"
    function celebrate(): void { happy = true; happyTimer.restart(); }
    Timer { id: happyTimer; interval: 2400; onTriggered: root.happy = false }

    // ------------------------------------------------------------- mensajes
    function say(text: string, card: var): int {
        const id = _next++;
        messages = messages.concat([{ id: id, from: "quarki", text: text, card: card ?? null }]);
        return id;
    }
    function patch(id: int, changes: var): void {
        messages = messages.map(m => m.id === id ? Object.assign({}, m, changes) : m);
    }
    function patchCard(id: int, changes: var): void {
        messages = messages.map(m => m.id === id ? Object.assign({}, m, { card: Object.assign({}, m.card, changes) }) : m);
    }
    function clear(): void {
        Ai.stop();
        messages = [];
    }
    function pick(list: var): string { return list[Math.floor(Math.random() * list.length)]; }
    function hello(): string {
        const h = new Date().getHours();
        return (h < 6 ? "Hola" : h < 12 ? "Buenos días" : h < 20 ? "Buenas tardes" : "Buenas noches") + (userName ? ", " + userName : "");
    }

    // --------------------------------------------------------------- entrada
    function ask(raw: string): void {
        raw = raw.trim();
        if (!raw) return;
        messages = messages.concat([{ id: _next++, from: "me", text: raw, card: null }]);
        const clauses = splitClauses(clean(raw));
        if (clauses.length > 1 ? !runChain(clauses) : !handle(raw)) converse();
    }

    // «abre firefox y busca queso cheddar» → dos pedidos (solo se corta en «y»/«luego» si sigue una orden)
    readonly property string verbs: "abre|abrir|abreme|busca|buscar|buscame|instala|instalame|instalar|descarga|pon|ponme|sube|baja|cambia|activa|" +
        "desactiva|cierra|juega|toma|bloquea|apaga|reinicia|desinstala|borra|quita|muestra|muestrame|ve|entra|silencia|reproduce|dime"
    function splitClauses(t: string): var {
        const re = new RegExp("\\s+(?:y luego|y despues|y tambien|y|luego|despues|tambien)\\s+(?=(?:" + verbs + ")\\b)");
        return t.split(re).map(c => c.trim()).filter(c => c);
    }
    function runChain(clauses: var): bool {
        let any = false;
        for (let i = 0; i < clauses.length; i++) {
            // «abre el navegador y busca X»: el navegador se abre directo con la búsqueda
            const o = openMatch(clauses[i]), sq = i + 1 < clauses.length ? webQuery(clauses[i + 1]) : null;
            if (o && sq && sq.site !== "store") {
                const app = findApp(target(o[1]));
                if (app && isBrowser(app)) { webSearch(sq, app); any = true; i++; continue; }
            }
            if (handle(clauses[i])) any = true;
        }
        return any;
    }

    function norm(s: string): string {
        return (s ?? "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase()
            .replace(/[¿?¡!.,;:"«»()]/g, " ").replace(/\s+/g, " ").trim();
    }
    // quita lo que no cambia el pedido: «oye Quarki, ¿me puedes abrir Firefox, por favor?» → «abrir firefox»
    function clean(s: string): string {
        let t = norm(s), prev = "";
        while (t !== prev) {
            prev = t;
            t = t.replace(/^(oye|hey|hola|quarki|porfa|por favor|puedes|podrias|me puedes|me podrias|quiero que|necesito que|ayudame a|me ayudas a|seria posible|sera posible|dale|y)\s+/, "")
                 .replace(/\s+(por favor|porfa|porfis|quarki|gracias|ahora|ya|rapido)$/, "");
        }
        return t;
    }
    function target(s: string): string {
        let t = s.trim(), prev = "";
        while (t !== prev) {
            prev = t;
            t = t.replace(/^(el|la|los|las|un|una|unos|mi|mis|algun|alguna|de|del|al|a)\s+/, "")
                 .replace(/^(juego|juegos|app|apps|aplicacion|programa|software)\s+/, "")
                 .replace(/\s+(en mi (pc|computador|computadora|compu)|en el (pc|computador)|para jugar|por favor)$/, "");
        }
        return t;
    }

    // Cómo llama la gente a cada tipo de app (también como en Windows). Se busca primero por
    // id y si no por la categoría que declara cada app (TerminalEmulator, WebBrowser…), así
    // «abre la terminal» encuentra kitty, Konsole o la que haya.
    readonly property var appKinds: [
        { words: ["terminal", "consola", "cmd", "simbolo del sistema", "linea de comandos", "powershell", "terminal de comandos"],
          ids: ["kitty"], cats: ["TerminalEmulator"] },
        { words: ["navegador", "internet", "navegador web", "explorador web", "edge", "microsoft edge", "el internet"],
          ids: ["firefox"], cats: ["WebBrowser"] },
        { words: ["archivos", "explorador", "explorador de archivos", "carpetas", "mis archivos", "explorador de windows",
                  "administrador de archivos", "gestor de archivos"], ids: ["quantum-files"], cats: ["FileManager"] },
        { words: ["tienda", "store", "quantum store", "tienda de apps", "microsoft store", "app store", "play store"], ids: ["quantum-store"], cats: [] },
        { words: ["ajustes", "configuracion", "panel de control", "centro quantum", "configuracion del sistema", "opciones"],
          ids: ["quantum-center"], cats: ["Settings"] },
        { words: ["juegos", "mis juegos", "foton", "biblioteca", "biblioteca de juegos"], ids: ["foton", "quantum-foton"], cats: [] },
        { words: ["editor de texto", "bloc de notas", "notepad", "notas", "editor", "block de notas"], ids: [], cats: ["TextEditor"] },
        { words: ["calculadora"], ids: [], cats: ["Calculator"] },
        { words: ["administrador de tareas", "monitor del sistema", "task manager", "monitor", "procesos"], ids: [], cats: ["Monitor"] },
        { words: ["reproductor de musica", "musica", "spotify"], ids: [], cats: ["Music"] },
        { words: ["reproductor de video", "reproductor de videos", "reproductor", "peliculas", "vlc"], ids: [], cats: ["Video", "Player"] },
        { words: ["visor de imagenes", "visor de fotos", "fotos", "galeria"], ids: [], cats: ["Viewer"] },
    ]
    // páginas web que la gente abre como si fueran apps
    readonly property var sites: ({
        "youtube": "https://www.youtube.com", "google": "https://www.google.com", "gmail": "https://mail.google.com",
        "netflix": "https://www.netflix.com", "twitch": "https://www.twitch.tv", "tiktok": "https://www.tiktok.com",
        "instagram": "https://www.instagram.com", "facebook": "https://www.facebook.com", "twitter": "https://x.com", "x": "https://x.com",
        "whatsapp web": "https://web.whatsapp.com", "wikipedia": "https://es.wikipedia.org", "chatgpt": "https://chatgpt.com",
        "github": "https://github.com", "reddit": "https://www.reddit.com", "amazon": "https://www.amazon.com",
        "mercado libre": "https://www.mercadolibre.com", "outlook": "https://outlook.live.com", "drive": "https://drive.google.com",
        "google drive": "https://drive.google.com", "canva": "https://www.canva.com", "classroom": "https://classroom.google.com"
    })
    readonly property var installAliases: ({
        "obs": ["obs studio", ""], "roblox": ["sober", "Roblox en Linux funciona con Sober."],
        "word": ["libreoffice", "En Linux se usa LibreOffice: es gratis y abre tus archivos de Word, Excel y PowerPoint."],
        "excel": ["libreoffice", "En Linux se usa LibreOffice: es gratis y abre tus archivos de Word, Excel y PowerPoint."],
        "powerpoint": ["libreoffice", "En Linux se usa LibreOffice: es gratis y abre tus archivos de Word, Excel y PowerPoint."],
        "office": ["libreoffice", "En Linux se usa LibreOffice: es gratis y abre tus archivos de Word, Excel y PowerPoint."],
        "photoshop": ["gimp", "Photoshop no existe para Linux; GIMP es la alternativa gratis más parecida."],
        "whatsapp": ["zapzap", "WhatsApp no tiene app para Linux; ZapZap es una muy buena para usarlo."],
        "chrome": ["google chrome", ""], "vs code": ["visual studio code", ""], "vscode": ["visual studio code", ""]
    })
    readonly property var folders: ({
        "descargas": "DOWNLOAD", "documentos": "DOCUMENTS", "imagenes": "PICTURES", "fotos": "PICTURES",
        "musica": "MUSIC", "videos": "VIDEOS", "escritorio": "DESKTOP"
    })

    // Devuelve true si lo entendió (y ya respondió)
    function handle(raw: string): bool {
        const t = clean(raw);
        let m;
        if (!t) { say(pick(["¿Sí? Aquí estoy.", "Dime, te escucho."])); return true; }

        // --------------------------------------------------- conversación corta
        if (/^(hola|holi|holaa+|buenas|buenos dias|buenas tardes|buenas noches|hey|que tal|como estas|como andas|que onda)$/.test(t)) {
            say(pick([hello() + ". ¿En qué te ayudo?", "Hola. Aquí estoy, ¿qué necesitas?", hello() + ". Dime qué hacemos."]));
            return true;
        }
        if (/^(gracias|muchas gracias|mil gracias|grax|genial|perfecto|excelente|buenisimo|bien|ok|okay|vale|listo|eres el mejor|te quiero)$/.test(t)) {
            say(pick(["De nada. Aquí estaré si me necesitas.", "Para eso estoy.", "Cuando quieras.", "Con gusto."]));
            celebrate();
            return true;
        }
        if (/(quien eres|como te llamas|que eres|tu nombre)/.test(t)) {
            say("Soy **Quarki**, el asistente de Quantum. Vivo en tu barra de tareas: me duermo cuando no me usas y despierto cuando me necesitas. Puedo abrir e instalar apps y juegos, cambiar ajustes y responder tus dudas.");
            return true;
        }
        if (/^(ayuda|help|que puedes hacer|que sabes hacer|que haces|como funcionas|que te puedo pedir)/.test(t)) {
            say("Puedo hacer cosas por ti. Prueba con:\n\n" +
                "- «Abre Firefox» o «abre mis descargas»\n- «Instálame Minecraft» o «desinstala Discord»\n" +
                "- «Sube el volumen», «brillo al 60», «modo oscuro»\n- «Activa el modo juego» o «cambia el fondo»\n" +
                "- «Busca actualizaciones», «toma una captura», «bloquea el PC»\n\n" +
                (Ai.status === "ready" ? "Y puedes preguntarme lo que quieras sobre Quantum o tu PC." : "Para conversar de cualquier tema, instala mi IA desde el botón de abajo."));
            return true;
        }

        // ------------------------------------------------------------- sonido
        if (/(silencia|mutea|quita el (sonido|audio)|sin (sonido|audio)|^mute$|^silencio$)/.test(t)) {
            if (Audio.sink?.audio) Audio.sink.audio.muted = true;
            say("Listo, sin sonido."); return true;
        }
        if (/(activa|pon|devuelve|vuelve) el (sonido|audio)|quita el silencio|desmutea|desilencia/.test(t)) {
            if (Audio.sink?.audio) Audio.sink.audio.muted = false;
            say("Sonido de vuelta, al " + Math.round(Audio.volume * 100) + " %."); return true;
        }
        if ((m = t.match(/(?:volumen|sonido)\s+(?:al|a|en)?\s*(\d{1,3})/)) || (m = t.match(/(\d{1,3})\s*(?:%|por ciento)?\s+de\s+(?:volumen|sonido)/))) {
            Audio.setVolume(Math.min(100, +m[1]) / 100);
            say("Volumen al " + Math.min(100, +m[1]) + " %."); return true;
        }
        if (/(sube|subir|subas|aumenta|aumentar|mas) (el |un poco el |un poco )?(volumen|sonido)|mas fuerte|subele/.test(t)) {
            Audio.setVolume(Audio.volume + (/mucho|harto/.test(t) ? 0.25 : 0.1));
            say("Subí el volumen al " + Math.round(Audio.volume * 100) + " %."); return true;
        }
        if (/(baja|bajar|bajes|disminuye|menos) (el |un poco el |un poco )?(volumen|sonido)|mas bajo|mas despacio|bajale/.test(t)) {
            Audio.setVolume(Audio.volume - (/mucho|harto/.test(t) ? 0.25 : 0.1));
            say("Bajé el volumen al " + Math.round(Audio.volume * 100) + " %."); return true;
        }

        // -------------------------------------------------------------- brillo
        if (/brillo/.test(t)) {
            if (!Brightness.available) { say("Esta pantalla no deja cambiar el brillo desde el PC; usa los botones del monitor."); return true; }
            if ((m = t.match(/brillo\s+(?:al|a|en)?\s*(\d{1,3})/))) Brightness.set(Math.min(100, +m[1]) / 100);
            else if (/(sube|subir|subas|aumenta|mas)/.test(t)) Brightness.step(/mucho/.test(t) ? 0.25 : 0.1);
            else if (/(baja|bajar|bajes|disminuye|menos)/.test(t)) Brightness.step(/mucho/.test(t) ? -0.25 : -0.1);
            else { say("El brillo está al " + Math.round(Brightness.value * 100) + " %. Dime «sube el brillo» o «brillo al 70»."); return true; }
            say("Brillo al " + Math.round(Brightness.value * 100) + " %."); return true;
        }

        // ------------------------------------------------------------ aspecto
        if (/(modo|tema) oscuro|pon(lo|me)? oscuro|oscurece/.test(t)) {
            Settings.set("appearance", "mode", "dark"); say("Listo, modo oscuro."); celebrate(); return true;
        }
        if (/(modo|tema) claro|pon(lo|me)? claro/.test(t)) {
            Settings.set("appearance", "mode", "light"); say("Listo, modo claro."); celebrate(); return true;
        }
        if (/modo juego/.test(t)) {
            const off = /(desactiva|desactivar|desactives|apaga|apagar|quita|quitar|sal|salir|termina)/.test(t);
            Shell.setGameMode(!off);
            say(off ? "Modo juego desactivado." : "Modo juego activado: el PC le da toda la potencia a tus juegos y silencia las notificaciones. Que te vaya bien.");
            celebrate(); return true;
        }
        if (/luz nocturna|filtro de luz azul|luz azul/.test(t)) {
            const off = /(desactiva|apaga|quita)/.test(t);
            if (Settings.display.nightLight === off) Shell.toggleNightLight();
            say(off ? "Luz nocturna apagada." : "Luz nocturna encendida: la pantalla queda más cálida para tus ojos."); return true;
        }
        if (/(cambia|cambiar|cambies|pon|ponme|otro|nuevo|elegir|elige) (el |un |de |mi )?fondo|fondo de pantalla|fondo animado/.test(t)) {
            say("Te abro los fondos: elige el que más te guste.");
            later(() => { Shell.aiOpen = false; Shell.toggleWallpapers(); }); return true;
        }
        if (/^personaliza|personalizar|cambiar (el )?estilo|cambia (el )?estilo|estilo del escritorio/.test(t)) {
            say("Te abro Personalizar."); later(() => { Shell.aiOpen = false; Shell.personalize(); }); return true;
        }
        if (/^(wifi|wi fi|internet|red)$|conecta(rme)? (a|al) (wifi|internet|red)|(abre|ver) (el )?wifi/.test(t)) {
            say("Te muestro las redes."); later(() => { Shell.aiOpen = false; Shell.openWifi(); }); return true;
        }

        // ------------------------------------------------------- sistema
        if (/actualiza|actualizar|actualizaciones|actualices|update/.test(t)) {
            if (Updates.count > 0) {
                say("Hay " + Updates.count + (Updates.count === 1 ? " actualización" : " actualizaciones") + ". Te abro la ventana para instalarlas.");
                later(() => { Shell.aiOpen = false; Updates.update(); });
            } else {
                Updates.check();
                say("Revisé y tienes todo al día. Si aparece algo nuevo, te aviso en la barra.");
            }
            return true;
        }
        if (/captura|pantallazo|screenshot|foto (a|de) la pantalla/.test(t)) {
            const region = /(parte|recorte|recortar|zona|seleccion)/.test(t);
            say(region ? "Elige con el mouse la parte que quieres capturar." : "Listo, tomo la captura.");
            later(() => { Shell.aiOpen = false; Quickshell.execDetached(["sh", "-c", "sleep 0.5; quantum-screenshot " + (region ? "region" : "screen")]); });
            return true;
        }
        if (/^(bloquea|bloquear|bloquees)( el| la)?( pc| pantalla| computador| sesion)?$/.test(t)) {
            say("Bloqueando…"); later(() => { Shell.aiOpen = false; Shell.lock(); }); return true;
        }
        if (/(apaga|apagar|apagues)( el| la)? (pc|computador|computadora|equipo|maquina|compu)|^apagar$|^apaga$/.test(t)) {
            say("¿Apago el PC? Guarda tus cosas antes.", { type: "power", action: "poweroff", status: "ask" }); return true;
        }
        if (/(reinicia|reiniciar|reinicies)( el| la)?( pc| computador| computadora| equipo| maquina| compu)?$/.test(t)) {
            say("¿Reinicio el PC? Guarda tus cosas antes.", { type: "power", action: "reboot", status: "ask" }); return true;
        }
        if (/(suspende|suspender|suspendas|a dormir|duerme el pc)/.test(t)) {
            say("¿Suspendo el PC? Se despierta al mover el mouse o tocar una tecla.", { type: "power", action: "suspend", status: "ask" }); return true;
        }
        if (/cierra(r)? (la )?sesion|cerrar sesion/.test(t)) {
            say("Te abro el menú de apagado."); later(() => { Shell.aiOpen = false; Shell.toggleSession(); }); return true;
        }

        // ------------------------------------------------------- preguntas rápidas
        if (/que hora (es|son)|^hora$/.test(t)) {
            say("Son las " + Qt.formatTime(new Date(), "HH:mm") + "."); return true;
        }
        if (/que (dia|fecha) es|^fecha$|en que dia estamos/.test(t)) {
            say("Hoy es " + Qt.locale("es_CL").toString(new Date(), "dddd d 'de' MMMM 'de' yyyy") + "."); return true;
        }
        if (/bateria/.test(t) && !/instal/.test(t)) {
            const b = UPower.displayDevice;
            if (!b?.isLaptopBattery) { say("Este PC no tiene batería: va enchufado a la corriente."); return true; }
            say("La batería está al " + Math.round(b.percentage * 100) + " %" + (b.state === UPowerDeviceState.Charging ? " y cargando." : "."));
            return true;
        }

        // ------------------------------------------------------- tus juegos y apps
        if (/(cuantos|cuales|que|mis|lista de|muestrame|ver)( mis)? juegos|juegos (tengo|tenemos|hay|instalados)/.test(t)) {
            answerGames(); return true;
        }
        if (/(cuantas|cuales|que|mis)( mis)? (apps|aplicaciones|programas)|(apps|aplicaciones|programas) (tengo|tenemos|hay|instalad)/.test(t)) {
            const n = Apps.all.length;
            say("Tienes **" + n + "** apps instaladas. Las ves todas en el menú de Inicio (Super + Espacio), y en Quantum Store encuentras más.");
            return true;
        }

        // ------------------------------------------------------------ carpetas
        if ((m = t.match(/^(?:abre|abrir|abreme|abras|muestra|muestrame|ve a|ir a|entra a)\s+(?:la carpeta (?:de )?|mis |la de |las |los |el )?(descargas|documentos|imagenes|fotos|musica|videos|escritorio|carpeta personal|inicio|home)$/))) {
            const key = folders[m[1]];
            Quickshell.execDetached(["sh", "-c", key ? "xdg-open \"$(xdg-user-dir " + key + ")\"" : "xdg-open \"$HOME\""]);
            say("Listo, abrí " + (key ? "tus " + m[1] : "tu carpeta personal") + "."); celebrate(); return true;
        }

        // ---------------------------------------------------- buscar en internet
        const sq = webQuery(t);
        if (sq) {
            if (sq.site === "store") installApp(target(sq.q));
            else webSearch(sq, null);
            return true;
        }

        // ------------------------------------------------- instalar y desinstalar
        if ((m = t.match(/^(?:desinstala|desinstalar|desinstales|borra|borrar|borres|elimina|eliminar|elimines|quita|quitar|quites)(?:me|lo|la|le)?\s+(.+)$/))) {
            removeApp(target(m[1])); return true;
        }
        if ((m = t.match(/^(?:instala|instalar|instales|descarga|descargar|descargues|baja|bajar|bajes|consigue|consigueme|agrega|agregar)(?:me|lo|la|le)?\s+(.+)$/))
            || (m = t.match(/^quiero (?:instalar|descargar|tener|bajar)\s+(.+)$/))) {
            installApp(target(m[1])); return true;
        }

        // --------------------------------------------------------------- abrir
        if ((m = openMatch(t))) {
            openApp(target(m[1])); return true;
        }
        return false;
    }
    function openMatch(t: string): var {
        return t.match(/^(?:abre|abrir|abreme|abras|ejecuta|ejecutar|ejecutes|inicia|iniciar|inicies|lanza|lanzar|entra a|entrar a|ve a|pon|ponme|juega|jugar|jugar a|quiero jugar|quiero jugar a|quiero usar|usa|usar)(?:me|lo|la)?\s+(.+)$/);
    }

    // «busca queso cheddar», «busca X en youtube», «busca minecraft en la tienda»
    function webQuery(t: string): var {
        const m = t.match(/^(?:busca|buscar|busques|buscame|googlea|googlear|investiga)(?:me|lo|la)?\s+(?:en (google|internet|la web|youtube|la tienda|la store|tienda|store)\s+)?(.+?)(?:\s+en (google|internet|la web|youtube|la tienda|la store|tienda|store))?$/);
        if (!m || /^actualizacion/.test(m[2])) return null;
        const where = m[1] || m[3] || "";
        return { q: m[2].replace(/^(sobre|acerca de|informacion de|info de)\s+/, ""),
                 site: /youtube/.test(where) ? "youtube" : /tienda|store/.test(where) ? "store" : "google" };
    }
    function isBrowser(app: var): bool {
        return Array.from(app?.categories ?? []).indexOf("WebBrowser") >= 0;
    }
    // abre la búsqueda; con un navegador elegido, en ese navegador
    function webSearch(sq: var, app: var): void {
        const url = sq.site === "youtube" ? "https://www.youtube.com/results?search_query=" + encodeURIComponent(sq.q)
                                          : "https://www.google.com/search?q=" + encodeURIComponent(sq.q);
        if (app) {
            const cmd = (app.command?.length ? Array.from(app.command) : (app.exec ?? "").split(/\s+/)).filter(a => a && !/^%[a-zA-Z]$/.test(a));
            Quickshell.execDetached(cmd.concat([url]));
        } else {
            Qt.openUrlExternally(url);
        }
        say("Busqué «" + sq.q + "» en " + (sq.site === "youtube" ? "YouTube" : "Google") + (app ? " con **" + app.name + "**." : "."));
        celebrate();
        later(() => { Shell.aiOpen = false; });
    }

    // pequeña pausa para que se vea la respuesta antes de cerrar el panel
    function later(fn: var): void { laterTimer.fn = fn; laterTimer.restart(); }
    Timer { id: laterTimer; property var fn: null; interval: 650; onTriggered: if (fn) fn() }

    // -------------------------------------------------------------- abrir apps
    function findApp(q: string): var {
        const qn = norm(q);
        const all = Apps.all;
        const kind = appKinds.find(k => k.words.indexOf(qn) >= 0);
        if (kind) {
            for (const id of kind.ids) {
                const a = all.find(e => e.id === id);
                if (a) return a;
            }
            for (const c of kind.cats) {
                const a = all.find(e => Array.from(e.categories ?? []).indexOf(c) >= 0);
                if (a) return a;
            }
        }
        const qq = qn;
        const list = Apps.search(q);
        for (const a of list.slice(0, 4)) {
            const name = norm(a.name);
            if (name.includes(qq) || qq.includes(name) || norm(a.genericName).includes(qq) || norm(a.keywords).includes(qq) || norm(a.id) === qq)
                return a;
        }
        return null;
    }
    function openApp(q: string): void {
        if (!q) { say("¿Qué quieres que abra?"); return; }
        const app = findApp(q);
        if (app) {
            Apps.launch(app);
            say(pick(["Listo, abrí **" + app.name + "**.", "Abriendo **" + app.name + "**.", "Ahí va **" + app.name + "**."]));
            celebrate();
            later(() => { Shell.aiOpen = false; });     // como el menú de Inicio: se aparta
            return;
        }
        // ¿uno de tus juegos? (Steam, Heroic…: los mismos de Fotón)
        const g = findGame(q);
        if (g) {
            Quickshell.execDetached(g.launch);
            say("Abriendo **" + g.name + "**. Que lo disfrutes.");
            celebrate();
            later(() => { Shell.aiOpen = false; });
            return;
        }
        // ¿una página web? (YouTube, Gmail…)
        const site = sites[norm(q)];
        if (site) {
            Qt.openUrlExternally(site);
            say("Abrí **" + q.replace(/^./, c => c.toUpperCase()) + "** en el navegador.");
            celebrate();
            later(() => { Shell.aiOpen = false; });
            return;
        }
        say("No tienes **" + q + "** instalado. Lo busco en la Store…");
        installApp(q, true);
    }
    function openId(ids: var): void {
        const list = Array.isArray(ids) ? ids : [ids];
        const a = Apps.all.find(e => list.indexOf(e.id) >= 0);
        if (!a) return;
        Apps.launch(a);
        later(() => { Shell.aiOpen = false; });
    }

    // ------------------------------------------------------------ tus juegos
    property var games: []
    property double gamesAt: 0
    property bool gamesPending: false          // alguien preguntó y la lista todavía no llegaba
    function refreshGames(): void {
        if (!gamesProc.running && Date.now() - gamesAt > 60000) gamesProc.running = true;
    }
    Process {
        id: gamesProc
        command: root.helper.concat(["games"])
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.games = JSON.parse(text); } catch (e) { root.games = []; }
                root.gamesAt = Date.now();
                if (root.gamesPending) { root.gamesPending = false; root.answerGames(); }
            }
        }
    }
    function findGame(q: string): var {
        const qn = norm(q);
        if (qn.length < 3) return null;
        return games.find(g => norm(g.name) === qn) ?? games.find(g => norm(g.name).includes(qn) || qn.includes(norm(g.name))) ?? null;
    }
    function answerGames(): void {
        if (gamesProc.running || !gamesAt) { gamesPending = true; refreshGames(); return; }
        const fotonCard = { type: "app", id: ["foton", "quantum-foton"], label: "Abrir Fotón", icon: "sports_esports" };
        const n = games.length;
        if (!n) {
            say("Todavía no encontré juegos instalados. Puedes instalarlos desde Steam o desde la tienda de Fotón.", fotonCard);
            return;
        }
        const names = games.slice(0, 5).map(g => g.name);
        say("Tienes **" + n + "** " + (n === 1 ? "juego" : "juegos") + ": " + names.join(", ") +
            (n > 5 ? " y " + (n - 5) + " más." : ".") + " Los ves todos en Fotón.", fotonCard);
    }

    // --------------------------------------------------------------- instalar
    readonly property var helper: ["env", "PYTHONPATH=" + (Quickshell.env("QUANTUM_STORE_SRC") || "/usr/lib/quantum-store"),
                                   "python3", "-m", "quantum_store.quarki"]
    property int searchMsg: 0
    property string searchQuery: ""

    function installApp(q: string, quiet: bool): void {
        if (!q) { say("¿Qué quieres que instale?"); return; }
        if (searchProc.running) { say("Dame un segundo, sigo buscando lo anterior."); return; }
        const alias = installAliases[q];
        if (alias && alias[1]) say(alias[1]);
        searchQuery = q;
        searchMsg = say(quiet ? "" : "Buscando **" + q + "**…", { type: "loading" });
        searchProc.command = helper.concat(["search", alias ? alias[0] : q]);
        searchProc.running = true;
    }
    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: {
                let items = [];
                try { items = JSON.parse(text); } catch (e) {}
                const q = root.searchQuery;
                if (!items.length) {
                    root.patch(root.searchMsg, { text: "No encontré **" + q + "** en la Store. Si es un juego de Steam, búscalo ahí:",
                                                 card: { type: "steam", query: q } });
                    return;
                }
                const best = items[0];
                if (best.weak) {
                    root.patch(root.searchMsg, { text: "No encontré exactamente **" + q + "**. ¿Es alguno de estos?",
                                                 card: { type: "choices", items: items.slice(0, 3), query: q } });
                    return;
                }
                if (best.installed) {
                    root.patch(root.searchMsg, { text: "**" + best.name + "** ya está instalado.", card: { type: "installed", item: best } });
                    return;
                }
                root.patch(root.searchMsg, { text: "Encontré **" + best.name + "**. ¿Lo instalo?",
                                             card: { type: "install", status: "ask", item: best, alts: items.slice(1, 3) } });
            }
        }
    }
    // elegir una de las alternativas: la tarjeta pasa a pedir confirmación
    function chooseItem(msgId: int, item: var): void {
        if (item.installed) { patch(msgId, { text: "**" + item.name + "** ya está instalado.", card: { type: "installed", item: item } }); return; }
        patch(msgId, { text: "¿Instalo **" + item.name + "**?", card: { type: "install", status: "ask", item: item, alts: [] } });
    }

    // ------------------------------------------------------------- desinstalar
    property int ownerMsg: 0
    property string ownerName: ""
    function removeApp(q: string): void {
        if (!q) { say("¿Qué quieres que desinstale?"); return; }
        const app = findApp(q);
        if (!app) { say("No encontré **" + q + "** entre tus apps. Revisa cómo se llama en el menú de Inicio."); return; }
        if (ownerProc.running) { say("Dame un segundo."); return; }
        ownerName = app.name;
        ownerMsg = say("", { type: "loading" });
        ownerProc.command = helper.concat(["owner", app.id]);
        ownerProc.running = true;
    }
    Process {
        id: ownerProc
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {};
                try { r = JSON.parse(text); } catch (e) { r = { error: "x" }; }
                const name = root.ownerName;
                if (r.error === "protected") {
                    root.patch(root.ownerMsg, { text: "**" + name + "** es parte de Quantum y lo necesitas para que el escritorio funcione, así que no lo voy a desinstalar.", card: null });
                } else if (r.error) {
                    root.patch(root.ownerMsg, { text: "No pude saber cómo se instaló **" + name + "**. Puedes quitarlo desde Quantum Store.", card: { type: "store" } });
                } else {
                    r.name = name;
                    root.patch(root.ownerMsg, { text: "¿Desinstalo **" + name + "**?" + (r.requiredBy?.length ? " Ojo: otras cosas lo usan (" + r.requiredBy.join(", ") + ")." : ""),
                                                card: { type: "remove", status: "ask", item: r } });
                }
            }
        }
    }

    // --------------------------------------------------- confirmar (tarjetas)
    property int jobMsg: 0
    property string jobKind: ""
    property var jobItem: null
    function confirm(msgId: int): void {
        const msg = messages.find(m => m.id === msgId);
        if (!msg?.card) return;
        const c = msg.card;
        if (c.type === "power") {
            patchCard(msgId, { status: "done" });
            later(() => {
                Shell.aiOpen = false;
                Quickshell.execDetached(["systemctl", c.action]);
            });
            return;
        }
        if (c.type !== "install" && c.type !== "remove") return;
        if (jobProc.running) { say("Estoy terminando con " + jobName + ". Cuando acabe, lo hago."); return; }
        jobMsg = msgId;
        jobKind = c.type;
        jobItem = c.item;
        jobName = c.item.name;
        patchCard(msgId, { status: "working" });
        // QUANTUM_QUARKI_DEMO=<segundos>: para grabar videos, la descarga se reemplaza por una espera
        const demo = Quickshell.env("QUANTUM_QUARKI_DEMO");
        jobProc.command = demo ? ["sleep", demo] : c.type === "install" ? c.item.install : c.item.remove;
        jobProc.running = true;
    }
    function cancel(msgId: int): void {
        patchCard(msgId, { status: "cancelled" });
        say(pick(["Está bien, no hago nada.", "Ok, lo dejamos así.", "Cancelado."]));
    }
    Process {
        id: jobProc
        stdout: StdioCollector { id: jobOut }
        stderr: StdioCollector { id: jobErr }
        onExited: code => {
            const item = root.jobItem, name = root.jobName, inst = root.jobKind === "install";
            if (code === 0) {
                root.patchCard(root.jobMsg, { status: "done" });
                root.say(inst ? "Listo, **" + name + "** ya está instalado." : "Listo, desinstalé **" + name + "**.");
                root.celebrate();
                Sounds.play("notification");
            } else if (code === 126 || code === 127) {
                // pkexec: se cerró la ventana de la contraseña
                root.patchCard(root.jobMsg, { status: "ask" });
                root.say("No escribiste la contraseña, así que no hice nada. Cuando quieras, vuelve a apretar el botón.");
            } else {
                root.patchCard(root.jobMsg, { status: "error" });
                root.say(inst ? "No pude instalar **" + name + "**. Revisa tu internet e inténtalo de nuevo, o búscalo en Quantum Store."
                              : "No pude desinstalar **" + name + "**. Inténtalo desde Quantum Store.", { type: "store" });
                console.warn("Quarki:", (jobErr.text || jobOut.text).slice(-600));
                Sounds.play("error");
            }
            if (!Shell.aiOpen)
                Quickshell.execDetached(["notify-send", "-a", "Quarki", "-i", "quantum-assistant",
                    code === 0 ? (inst ? name + " ya está instalado" : name + " se desinstaló") : "Quarki no pudo terminar",
                    code === 0 ? "Puedes abrirlo desde el menú de Inicio." : "Ábreme para ver qué pasó."]);
        }
    }
    // botón de una acción propuesta por la IA
    function runOrder(msgId: int, cmd: string): void {
        const msg = messages.find(m => m.id === msgId);
        if (msg?.card) patchCard(msgId, { done: (msg.card.done ?? []).concat([cmd]) });
        if (!handle(cmd)) say("No supe cómo hacer «" + cmd + "».");
    }
    // texto del botón: «abre stardew valley» → «Abre stardew valley»
    function orderLabel(cmd: string): string {
        let t = cmd;
        // los nombres de tus juegos y apps, bien escritos («stardew valley» → «Stardew Valley»)
        for (const n of games.map(g => g.name).concat(Apps.all.map(a => a.name))) {
            if (n.length < 4) continue;
            const i = norm(t).indexOf(norm(n));
            if (i >= 0 && norm(t).length === t.length) t = t.substring(0, i) + n + t.substring(i + n.length);
        }
        return t.replace(/^./, c => c.toUpperCase());
    }

    function launchItem(item: var): void {
        Quickshell.execDetached(helper.concat(["launch", item.source, item.id]));
        say("Abriendo **" + item.name + "**.");
        celebrate();
        later(() => { Shell.aiOpen = false; });
    }

    // ------------------------------------------------------------ conversar (IA)
    function converse(): void {
        if (Ai.status !== "ready") {
            say(pick(["Eso todavía no lo sé hacer.", "Mmm, eso no lo entendí."]) +
                " Puedo abrir e instalar apps y juegos, cambiar el volumen, el brillo o el fondo, y más (escribe «ayuda»). " +
                "Para conversar de cualquier tema, instala mi IA: funciona en tu PC, sin cuentas.", { type: "aiSetup" });
            return;
        }
        const history = messages.filter(m => m.text && !m.card?.type?.match(/loading/))
            .slice(-12).map(m => ({ role: m.from === "me" ? "user" : "assistant", content: m.text }));
        const id = say("", { type: "loading" });
        const appNames = Apps.all.map(a => a.name).slice(0, 80);
        const facts = "Datos reales de este PC (úsalos y no inventes otros): " +
            (userName ? "la persona se llama " + userName + ". " : "") +
            "Hay " + Apps.all.length + " apps instaladas: " + appNames.join(", ") + ". " +
            "Hay " + games.length + " juegos instalados" + (games.length ? ": " + games.slice(0, 40).map(g => g.name).join(", ") : "") + ". " +
            "Para hacer algo en el PC escribe, sola en la última línea, la etiqueta [[orden: pedido simple]], por ejemplo " +
            "[[orden: abre la terminal]], [[orden: busca recetas con queso en internet]], [[orden: sube el volumen]], " +
            "[[orden: modo oscuro]], [[orden: instala minecraft]] o [[orden: abre hades]]. Puedes poner varias etiquetas.";
        Ai.chat(history,
            acc => root.patch(id, { text: root.stripTags(acc), card: null }),
            (text, err) => {
                if (err && !text) { root.patch(id, { text: "No pude responder: " + err, card: null }); return; }
                // lo que la IA propone hacer queda como botones: se hace solo si la persona lo aprieta
                const re = /\[\[\s*(orden|abrir|instalar|desinstalar|buscar)\s*:\s*([^\]]+?)\s*\]\]/gi;
                const verbs = { abrir: "abre ", instalar: "instala ", desinstalar: "desinstala ", buscar: "busca " };
                const orders = [];
                let mm;
                while ((mm = re.exec(text)) !== null) {
                    const v = mm[1].toLowerCase();
                    const cmd = (v === "orden" ? "" : verbs[v]) + mm[2].trim();
                    if (orders.indexOf(cmd) < 0 && orders.length < 4) orders.push(cmd);
                }
                root.patch(id, { text: root.stripTags(text) || (orders.length ? "¿Lo hago?" : "Hecho."),
                                 card: orders.length ? { type: "orders", items: orders } : null });
            }, facts);
    }
    // quita las etiquetas de acciones y deja la voz de Quarki: sin «¡…!» ni muletillas al empezar
    function stripTags(s: string): string {
        return (s ?? "").replace(/\[\[[^\]]*(\]\]|$)/g, "")
            .replace(/¡/g, "").replace(/!+/g, ".").replace(/\.\.(?!\.)/g, ".")
            .replace(/^\s*(qu[eé] buena pregunta|buena pregunta|excelente pregunta|claro que s[ií]|por supuesto( que s[ií])?|claro|hola)[.,:]?\s*/i, "")
            .replace(/^\s*(qu[eé] buena pregunta|buena pregunta|claro que s[ií]|por supuesto( que s[ií])?)[.,:]?\s*/i, "")
            .replace(/^./, c => c.toUpperCase())
            .replace(/\s+$/, "");
    }

    // --------------------------------------------------------------- inicio
    Component.onCompleted: { Ai.check(); refreshGames(); if (!userName) nameProc.running = true; }
    Connections {
        target: Shell
        function onAiOpenChanged() {
            if (!Shell.aiOpen) return;
            if (Ai.status !== "ready") Ai.check();
            root.refreshGames();
        }
    }
    Process {
        id: nameProc
        command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = text.trim().split(/\s+/)[0] ?? "";
                root.userName = n || "";
            }
        }
    }

    // qs -c quantum ipc call quarki ask "abre firefox"
    IpcHandler {
        target: "quarki"
        function ask(text: string): void { Shell.aiOpen = true; root.ask(text); }
        function confirm(): void { const c = root.messages.slice().reverse().find(m => m.card?.status === "ask"); if (c) root.confirm(c.id); }
        function clear(): void { root.clear(); }
    }
}
