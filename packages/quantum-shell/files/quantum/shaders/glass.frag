#version 440
// Cristal Cuántico (shell Atomic): un rectángulo redondeado de cristal que refracta el fondo en
// los bordes como una lupa, lo desenfoca, separa los colores en el borde y tiene reflejo de luz.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 boxSize;     // tamaño del cristal (px)
    vec2 orig;        // esquina superior izquierda del cristal en la pantalla (px)
    vec2 scr;         // tamaño de la pantalla (px)
    vec2 light;       // dirección de la luz (hacia dónde está)
    float radius;
    float bevel;      // ancho del borde que refracta
    float refr;       // cuánto dobla el borde
    float dim;        // oscurecer (para leer el texto)
    float tint;       // lechoso
    float hasTex;     // 0: no hay fondo para refractar (fondo vivo)
    float glow;       // brillo extra (al transformarse)
};
layout(binding = 1) uniform sampler2D blurred;
layout(binding = 2) uniform sampler2D sharp;

float box(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 p = qt_TexCoord0 * boxSize;
    vec2 c = boxSize * 0.5;
    vec2 rel = p - c;
    float r = min(radius, min(c.x, c.y));
    float sdf = box(rel, c, r);
    vec2 n = vec2(box(rel + vec2(1.0, 0.0), c, r) - box(rel - vec2(1.0, 0.0), c, r),
                  box(rel + vec2(0.0, 1.0), c, r) - box(rel - vec2(0.0, 1.0), c, r));
    n = n / max(length(n), 1e-4);
    float inner = clamp(-sdf / bevel, 0.0, 1.0);
    float lens = pow(1.0 - inner, 2.2);
    vec2 g = orig + p;
    vec3 col;
    if (hasTex > 0.5) {
        float mixb = 0.55 + 0.45 * inner;
        vec2 uR = (g + n * refr * lens * 1.10) / scr;
        vec2 uG = (g + n * refr * lens) / scr;
        vec2 uB = (g + n * refr * lens * 0.90) / scr;
        col.r = mix(texture(sharp, uR).r, texture(blurred, uR).r, mixb);
        col.g = mix(texture(sharp, uG).g, texture(blurred, uG).g, mixb);
        col.b = mix(texture(sharp, uB).b, texture(blurred, uB).b, mixb);
    } else {
        col = mix(vec3(0.10, 0.08, 0.22), vec3(0.05, 0.04, 0.10), qt_TexCoord0.y);
    }
    col = col * (1.0 - tint) + tint;
    col = col * dim + 0.02;
    vec2 L = normalize(light);
    float facing = clamp(dot(n, L), 0.0, 1.0);
    float spec = pow(facing, 3.0) * pow(1.0 - inner, 1.5) * (0.85 + glow)
               + pow(clamp(1.0 - p.y / (boxSize.y * 0.55), 0.0, 1.0), 3.0) * 0.10;
    float rim = exp(-pow((sdf + 1.2) / 1.1, 2.0)) * (0.35 + 0.65 * facing) * (1.0 + glow);
    col += vec3(spec + rim);
    float back = clamp(dot(-n, L), 0.0, 1.0) * pow(1.0 - inner, 2.0) * (0.11 + 0.3 * glow);
    col += back * vec3(0.42, 0.36, 1.0);
    float aa = clamp(-sdf + 0.5, 0.0, 1.0);
    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * aa * qt_Opacity;
}
