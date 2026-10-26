# Archivo de respuestas de la instalación automática

El instalador de Windows (`Instalar Quantum.exe`) deja en el pendrive, en la partición
con etiqueta `QUANTUMINST` (FAT32/exFAT), la carpeta `quantum-install/` con:

    answers.json                     ← este archivo
    MOK.key, MOK.crt                 ← llave de arranque seguro de este PC (si se creó en Windows)
    ../Quantum - Mis cosas de Windows/   ← lo que copió «Pasar a Quantum» (opcional)

```json
{
  "format": 1,
  "mode": "free",                       // "free": usa el espacio libre que dejó Windows · "wipe": borra el disco
  "disk": { "size": 512110190592, "serial": "S4EVNX0N...", "model": "Samsung SSD 970" },
  "minFree": 40000000000,               // (free) el hueco libre más grande debe medir al menos esto
  "user": { "name": "Juan Pérez", "login": "juan", "password": "$6$...", "autologin": false },
  "hostname": "juan-quantum",
  "locale": "es_CL.UTF-8",
  "timezone": "America/Santiago",
  "keyboard": { "layout": "latam", "variant": "" },
  "apps": [ ["com.google.Chrome", "Google Chrome"] ],     // Flathub, se instalan al primer inicio
  "games": [ ["net.supertuxkart.SuperTuxKart", "SuperTuxKart"] ],
  "steamGames": [ ["cs2", "Counter-Strike 2"] ],
  "ai": "",                             // modelo de Ollama o ""
  "secureboot": { "enabled": true, "mokPassword": "quantum" },
  "migrate": true                       // pasar «Mis cosas de Windows» al primer inicio
}
```

La contraseña va cifrada (SHA-512 crypt), nunca en texto plano.
