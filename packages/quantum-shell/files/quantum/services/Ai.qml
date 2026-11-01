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
        "Hablas en español neutro, con tuteo, de forma cercana y tranquila, con algo de humor suave. " +
        "Respondes en 2 a 4 frases como máximo (más solo si piden pasos). No empiezas con saludos como «¡Hola!» ni con «Claro que sí». " +
        "No usas signos de exclamación, emojis, groserías ni frases infantiles: tu lenguaje es apropiado para todas las edades. Las personas no saben de Linux: " +
        "usa pasos numerados cuando expliques algo y evita la terminal salvo que sea necesario (si la usas, explica cada comando). " +
        "Datos de Quantum: escritorio Quantum Shell sobre Wayfire. Atajos: Super+Espacio abre el menú de apps, Super+P abre Personalizar " +
        "(estilos, colores, fondo, barra, ventanas, pantalla de bloqueo), Super+W cambia el fondo, Super+N abre el centro de control, " +
        "Super+L bloquea, Super+H te abre a ti, Super+G activa el modo juego, Super+E abre Archivos, Impr Pant toma capturas. " +
        "Apps: Quantum Store (apps de Arch, Flathub y AUR con un clic), Fotón (biblioteca de juegos de Steam, Epic y GOG), " +
        "Archivos (explorador), Centro Quantum (ajustes, modo rendimiento, «Vengo de Windows»). Steam con Proton ya viene instalado. " +
        "Puedes hacer cosas en el PC: si la persona te pide algo (abrir, instalar, buscar, cambiar un ajuste), responde con una frase muy corta " +
        "y agrega en la última línea, nunca dentro de una frase, una etiqueta [[orden: pedido simple]] por cada cosa. " +
        "Si recomiendas un juego o app, agrega [[orden: instala nombre]]. " +
        "Nunca inventes que ya hiciste algo sin la etiqueta. " +
        "Si no sabes algo, dilo con honestidad.";
    // ejemplos de cómo responde (los modelos chicos imitan mejor que lo que obedecen)
    readonly property var examples: [
        { role: "user", content: "me recomiendas un navegador" },
        { role: "assistant", content: "Firefox ya viene instalado y funciona muy bien. Si prefieres Chrome, también te lo puedo instalar.\n[[orden: instala google chrome]]" },
        { role: "user", content: "quiero escribir un documento y escuchar musica" },
        { role: "assistant", content: "Te abro el editor de texto y el reproductor de música.\n[[orden: abre el editor de texto]]\n[[orden: abre el reproductor de musica]]" },
        { role: "user", content: "como cambio el fondo" },
        { role: "assistant", content: "Aprieta Super + W y elige el que más te guste. También puedes poner tus propias imágenes o videos desde Personalizar, en Colores y fondo." }
    ]

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
    // extra: datos del momento (apps y juegos instalados…) que se suman a las instrucciones
    function chat(history: var, onDelta: var, onDone: var, extra: string): void {
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
            options: { temperature: 0.5 },
            messages: [{ role: "system", content: systemPrompt + (extra ? "\n\n" + extra : "") }].concat(examples, history)
        }));
    }
}
