// Recibe un reporte de «Ayuda y sugerencias» (JSON) y crea un issue en el repositorio privado de reportes.
const REPO = "QuantumLinux-arch/quantum-reportes";
const MAX_BODY = 200_000;                       // bytes
const hits = new Map();                         // límite simple por IP (por instancia)

const clean = (s, n) => String(s ?? "").replace(/\u0000/g, "").slice(0, n);
const fence = s => clean(s, 60_000).replace(/```/g, "ʼʼʼ");   // que no rompa los bloques de código

export default async (req) => {
  if (req.method !== "POST") return new Response("Usa POST", { status: 405 });
  const ip = req.headers.get("x-nf-client-connection-ip") || "?";
  const now = Date.now(), list = (hits.get(ip) || []).filter(t => now - t < 3600_000);
  if (list.length >= 10) return Response.json({ ok: false, error: "demasiados envíos" }, { status: 429 });
  list.push(now); hits.set(ip, list);

  const raw = await req.text();
  if (raw.length > MAX_BODY) return Response.json({ ok: false, error: "muy grande" }, { status: 413 });
  let d;
  try { d = JSON.parse(raw); } catch { return Response.json({ ok: false, error: "JSON inválido" }, { status: 400 }); }

  const tipo = d.tipo === "Problema" ? "problema" : d.tipo === "Sugerencia" ? "sugerencia" : null;
  const titulo = clean(d.titulo, 120).trim();
  const mensaje = clean(d.mensaje, 8000).trim();
  if (!tipo || !titulo) return Response.json({ ok: false, error: "faltan datos" }, { status: 400 });

  const labels = [tipo];
  if (d.caida) labels.push("caída");
  let body = `**Área:** ${clean(d.area, 60) || "—"} · **Fecha:** ${clean(d.fecha, 40) || "—"} · **Contacto:** ${clean(d.contacto, 200) || "—"}\n\n`;
  if (d.caida) body += `> ⚠️ ${clean(d.caida, 200)}\n\n`;
  body += `### Mensaje\n\n${mensaje || "_(sin mensaje)_"}\n`;
  if (d.pc) body += `\n<details><summary>Datos del PC</summary>\n\n\`\`\`\n${fence(d.pc)}\n\`\`\`\n</details>\n`;
  if (d.registros) body += `\n<details><summary>Registros</summary>\n\n\`\`\`\n${fence(d.registros)}\n\`\`\`\n</details>\n`;

  const r = await fetch(`https://api.github.com/repos/${REPO}/issues`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${process.env.GITHUB_TOKEN}`,
      "Accept": "application/vnd.github+json",
      "User-Agent": "quantum-ayuda-relay",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ title: titulo, body, labels }),
  });
  if (!r.ok) return Response.json({ ok: false, error: "GitHub " + r.status }, { status: 502 });
  return Response.json({ ok: true });
};
