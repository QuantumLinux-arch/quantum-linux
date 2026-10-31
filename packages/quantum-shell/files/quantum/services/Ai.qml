pragma Singleton

import QtQuick
import Quickshell

// Cerebro de Quarki para conversar: una IA local con Ollama (en tu PC, sin internet ni cuentas).
// Las órdenes comunes (abrir, instalar, volumen…) las entiende Quarki.qml sin IA.
// status: checking | missing (Ollama no está) | nomodel (sin modelos) | ready
Singleton {
    id: root

    readonly property string host: Quickshell.env("QUANTUM_OLLAMA_HOST") || "http://127.0.0.1:11434"
    property string status: "checking"
    property var models: []
    readonly property string model: models.indexOf(Settings.ai.model) >= 0 ? Settings.ai.model : (models[0] ?? "")
    property bool busy: false
    property var _xhr: null

    // Personalidad de Quarki. Las etiquetas [[…]] las convierte Quarki.qml en acciones
    // (abrir e instalar siempre pasan por su tarjeta de confirmación cuando hace falta).
    readonly property string systemPrompt:
        "Eres Quarki, el asistente y mascota de Quantum Linux: una pequeña estrella de luz con un aro que gira. " +
        "Quantum es una distribución basada en Arch Linux pensada para quienes vienen de Windows y para jugar. " +
        "Hablas en español neutro, con tuteo, de forma cercana y tranquila, con frases cortas y algo de humor suave. " +
        "No exageras con signos de exclamación, no usas emojis ni frases infantiles. Las personas no saben de Linux: " +
        "usa pasos numerados cuando expliques algo y evita la terminal salvo que sea necesario (si la usas, explica cada comando). " +
        "Datos de Quantum: escritorio Quantum Shell sobre Wayfire. Atajos: Super+Espacio abre el menú de apps, Super+P abre Personalizar " +
        "(estilos, colores, fondo, barra, ventanas, pantalla de bloqueo), Super+W cambia el fondo, Super+N abre el centro de control, " +
        "Super+L bloquea, Super+H te abre a ti, Super+G activa el modo juego, Super+E abre Archivos, Impr Pant toma capturas. " +
        "Apps: Quantum Store (apps de Arch, Flathub y AUR con un clic), Fotón (biblioteca de juegos de Steam, Epic y GOG), " +
        "Archivos (explorador), Centro Quantum (ajustes, modo rendimiento, «Vengo de Windows»). Steam con Proton ya viene instalado. " +
        "Puedes hacer cosas en el PC. Si la persona te pide abrir, instalar o desinstalar algo, responde con una frase muy corta " +
        "y agrega al final UNA etiqueta exacta: [[abrir: nombre]], [[instalar: nombre]] o [[desinstalar: nombre]] " +
        "(el nombre de la app o juego, sin nada más). Si recomiendas un juego o app, sugiere instalarlo con la etiqueta. " +
        "Nunca inventes que ya hiciste algo sin la etiqueta. " +
        "Si no sabes algo, dilo con honestidad y sugiere preguntar en el Discord de Quantum: discord.gg/qWmEb9xHkZ.";

    function check(): void {
        status = "checking";
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            if (x.status !== 200) { status = "missing"; return; }
            try {
                models = JSON.parse(x.responseText).models.map(m => m.name);
            } catch (e) { models = []; }
            status = models.length ? "ready" : "nomodel";
        };
        x.open("GET", host + "/api/tags");
        x.send();
    }

    function stop(): void {
        if (_xhr) { _xhr.abort(); _xhr = null; }
        busy = false;
    }

    // Conversa con el modelo: history = [{ role: user|assistant, content }].
    // onDelta(textoAcumulado) mientras llega la respuesta; onDone(textoFinal, error).
    function chat(history: var, onDelta: var, onDone: var): void {
        if (busy || status !== "ready") { onDone("", "La IA no está lista."); return; }
        busy = true;
        const x = new XMLHttpRequest();
        _xhr = x;
        let seen = 0, acc = "", err = "";
        const consume = () => {
            const t = x.responseText;
            const end = t.lastIndexOf("\n");
            if (end < seen) return;
            for (const line of t.substring(seen, end).split("\n")) {
                if (!line.trim()) continue;
                try {
                    const j = JSON.parse(line);
                    if (j.message?.content) { acc += j.message.content; onDelta(acc); }
                    if (j.error) err = j.error;
                } catch (e) {}
            }
            seen = end + 1;
        };
        x.onreadystatechange = () => {
            if (x.readyState === XMLHttpRequest.LOADING) consume();
            if (x.readyState === XMLHttpRequest.DONE) {
                consume();
                if (x.status !== 200 && !acc && !err) err = "No pude conectarme con la IA. ¿Está encendido el servicio de Ollama?";
                busy = false;
                _xhr = null;
                onDone(acc, err);
            }
        };
        x.open("POST", host + "/api/chat");
        x.setRequestHeader("Content-Type", "application/json");
        x.send(JSON.stringify({
            model: model,
            stream: true,
            think: false,
            messages: [{ role: "system", content: systemPrompt }].concat(history)
        }));
    }
}
