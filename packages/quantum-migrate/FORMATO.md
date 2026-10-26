# Formato del pendrive «Pasar a Quantum»

La app de Windows (`windows/`, «Pasar a Quantum.exe») escribe en la raíz del pendrive la carpeta

    Quantum - Mis cosas de Windows/
        manifest.json         ← qué se copió (lo lee quantum-migrate)
        wifi.json             ← redes Wi-Fi con su contraseña (solo si se eligió; en texto plano)
        Cuenta/foto.*         ← foto de la cuenta de Windows
        Cuenta/fondo.*        ← fondo de pantalla
        Archivos/<Carpeta>/…  ← Escritorio, Documentos, Imágenes, Música, Videos, Descargas, Partidas guardadas
        Navegadores/<clave>/… ← chromium: <perfil>/Bookmarks · firefox: places.sqlite, favicons.sqlite, logins.json, key4.db
        Steam/appmanifest_<id>.acf y Steam/common/<carpeta del juego>/…

Archivos de más de 4 GB en pendrives FAT32 se parten en `<nombre>.qpart001`, `.qpart002`, …
(cada parte de 4 000 000 000 bytes) y se listan en `split`.

## manifest.json

```json
{
  "format": 1,
  "id": "20261024-221500-PC-JUAN",
  "created": "2026-10-24T22:15:00",
  "complete": true,
  "computer": "PC-JUAN",
  "user": { "login": "juan", "name": "Juan Pérez" },
  "settings": { "dark": true, "accent": "#0078D4", "timezone": "Pacific SA Standard Time",
                "locale": "es-CL", "keyboards": ["0000080A"], "clock24h": true },
  "account": { "picture": "Cuenta/foto.jpg", "wallpaper": "Cuenta/fondo.jpg" },
  "folders": [ { "key": "documents", "title": "Documentos", "dir": "Archivos/Documentos", "files": 120, "bytes": 123456 } ],
  "browsers": [ { "key": "chrome", "title": "Google Chrome", "kind": "chromium", "dir": "Navegadores/chrome", "profiles": ["Default"] },
                { "key": "firefox", "title": "Firefox", "kind": "firefox", "dir": "Navegadores/firefox" } ],
  "wifi": "wifi.json",
  "apps": ["Discord", "Google Chrome", "Spotify"],
  "steam": [ { "appid": "730", "name": "Counter-Strike 2", "dir": "Steam/common/Counter-Strike Global Offensive",
               "manifest": "Steam/appmanifest_730.acf", "bytes": 30000000000 } ],
  "split": [ { "path": "Archivos/Videos/pelicula.mkv", "parts": 2, "bytes": 6000000000 } ],
  "errors": ["Archivos/Documentos/bloqueado.docx"]
}
```

`complete` es `false` mientras se copia: si quedó así, la copia se cortó (Quantum avisa y ofrece usar lo que haya).

## wifi.json

```json
[ { "ssid": "Casa", "auth": "WPA2PSK", "key": "contraseña" } ]
```
