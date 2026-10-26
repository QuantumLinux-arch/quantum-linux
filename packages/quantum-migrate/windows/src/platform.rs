//! Lo que se sabe de Windows: carpetas del usuario, unidades, ajustes, cuenta, programas,
//! navegadores, juegos de Steam y redes Wi-Fi. En Linux (solo para desarrollar la interfaz)
//! todo sale de una carpeta de prueba: PAQ_FAKE (el «usuario») y PAQ_FAKE_USB (el pendrive).

use std::path::{Path, PathBuf};

#[derive(Clone, Debug)]
pub struct Drive {
    pub root: PathBuf,
    pub label: String,
    pub fs: String,
    pub free: u64,
    pub total: u64,
    pub removable: bool,
}

impl Drive {
    pub fn name(&self) -> String {
        let letter = self.root.to_string_lossy().trim_end_matches(['\\', '/']).to_string();
        if self.label.is_empty() { format!("Pendrive ({letter})") } else { format!("{} ({letter})", self.label) }
    }
    /// FAT32 no acepta archivos de 4 GB o más: hay que partirlos.
    pub fn fat32(&self) -> bool { self.fs.eq_ignore_ascii_case("FAT32") || self.fs.eq_ignore_ascii_case("FAT") }
}

#[derive(Clone, Debug, Default, serde::Serialize)]
pub struct Settings {
    pub dark: bool,
    pub accent: String,
    pub timezone: String,
    pub locale: String,
    pub keyboards: Vec<String>,
    pub clock24h: bool,
}

#[derive(Clone, Debug)]
pub struct Browser {
    pub key: &'static str,
    pub title: &'static str,
    pub kind: &'static str, // chromium | firefox
    pub src: PathBuf,       // chromium: carpeta «User Data» · firefox: carpeta del perfil
    pub profiles: Vec<String>,
    pub process: &'static str,
}

#[derive(Clone, Debug)]
pub struct SteamGame {
    pub appid: String,
    pub name: String,
    pub installdir: String,
    pub manifest: PathBuf,
    pub dir: PathBuf,
    pub bytes: u64,
}

#[derive(Clone, Debug, serde::Serialize)]
pub struct Wifi {
    pub ssid: String,
    pub auth: String,
    pub key: String,
}

/// Lee los perfiles de Chromium que tienen favoritos.
fn chromium_profiles(user_data: &Path) -> Vec<String> {
    let mut out = vec![];
    if let Ok(rd) = std::fs::read_dir(user_data) {
        for e in rd.flatten() {
            let n = e.file_name().to_string_lossy().to_string();
            if (n == "Default" || n.starts_with("Profile ")) && e.path().join("Bookmarks").is_file() {
                out.push(n);
            }
        }
    }
    out.sort();
    out
}

/// Perfil principal de Firefox según profiles.ini.
fn firefox_profile(base: &Path) -> Option<PathBuf> {
    let ini = std::fs::read_to_string(base.join("profiles.ini")).ok()?;
    let (mut default_install, mut first, mut cur_path, mut cur_rel, mut cur_default) = (None, None, None, true, false);
    let mut flush = |p: &Option<String>, rel: bool, def: bool, first: &mut Option<PathBuf>, best: &mut Option<PathBuf>| {
        if let Some(p) = p {
            let path = if rel { base.join(p) } else { PathBuf::from(p) };
            if first.is_none() { *first = Some(path.clone()); }
            if def && best.is_none() { *best = Some(path); }
        }
    };
    let mut best: Option<PathBuf> = None;
    for line in ini.lines().map(str::trim) {
        if line.starts_with('[') {
            flush(&cur_path, cur_rel, cur_default, &mut first, &mut best);
            cur_path = None; cur_rel = true; cur_default = false;
        } else if let Some(v) = line.strip_prefix("Path=") {
            cur_path = Some(v.replace('/', std::path::MAIN_SEPARATOR_STR));
        } else if let Some(v) = line.strip_prefix("IsRelative=") {
            cur_rel = v == "1";
        } else if line == "Default=1" {
            cur_default = true;
        } else if let Some(v) = line.strip_prefix("Default=") {
            // sección [Install…]: el perfil que usa esa instalación de Firefox
            if default_install.is_none() { default_install = Some(base.join(v.replace('/', std::path::MAIN_SEPARATOR_STR))); }
        }
    }
    flush(&cur_path, cur_rel, cur_default, &mut first, &mut best);
    default_install.filter(|p| p.join("places.sqlite").is_file())
        .or(best.filter(|p| p.join("places.sqlite").is_file()))
        .or(first.filter(|p| p.join("places.sqlite").is_file()))
}

/// Navegadores con favoritos, a partir de las carpetas de datos (Local y Roaming).
pub fn browsers_in(local: &Path, roaming: &Path) -> Vec<Browser> {
    let mut out = vec![];
    for (key, title, dir, process) in [
        ("chrome", "Google Chrome", local.join("Google").join("Chrome").join("User Data"), "chrome.exe"),
        ("edge", "Microsoft Edge", local.join("Microsoft").join("Edge").join("User Data"), "msedge.exe"),
        ("brave", "Brave", local.join("BraveSoftware").join("Brave-Browser").join("User Data"), "brave.exe"),
    ] {
        let profiles = chromium_profiles(&dir);
        if !profiles.is_empty() {
            out.push(Browser { key, title, kind: "chromium", src: dir, profiles, process });
        }
    }
    let opera = roaming.join("Opera Software").join("Opera Stable");
    if opera.join("Bookmarks").is_file() {
        out.push(Browser { key: "opera", title: "Opera", kind: "chromium", src: opera.parent().unwrap().to_path_buf(),
                           profiles: vec!["Opera Stable".into()], process: "opera.exe" });
    }
    if let Some(p) = firefox_profile(&roaming.join("Mozilla").join("Firefox")) {
        out.push(Browser { key: "firefox", title: "Firefox", kind: "firefox", src: p, profiles: vec![], process: "firefox.exe" });
    }
    out
}

/// Valores "clave" "valor" de un archivo .vdf/.acf de Steam (sin anidar).
fn vdf_values(text: &str, key: &str) -> Vec<String> {
    let mut out = vec![];
    for line in text.lines() {
        let parts: Vec<&str> = line.split('"').collect();
        if parts.len() >= 4 && parts[1].eq_ignore_ascii_case(key) {
            out.push(parts[3].replace("\\\\", "\\"));
        }
    }
    out
}

/// Juegos de Steam instalados en todas las bibliotecas.
pub fn steam_games_in(steam: &Path) -> Vec<SteamGame> {
    let mut libs = vec![steam.to_path_buf()];
    if let Ok(t) = std::fs::read_to_string(steam.join("steamapps").join("libraryfolders.vdf")) {
        for p in vdf_values(&t, "path") {
            let p = PathBuf::from(p);
            if !libs.contains(&p) { libs.push(p); }
        }
    }
    // herramientas de Steam, no juegos
    const TOOLS: [&str; 4] = ["228980", "1070560", "1391110", "1628350"];
    let mut out: Vec<SteamGame> = vec![];
    for lib in libs {
        let apps = lib.join("steamapps");
        let Ok(rd) = std::fs::read_dir(&apps) else { continue };
        for e in rd.flatten() {
            let n = e.file_name().to_string_lossy().to_string();
            if !(n.starts_with("appmanifest_") && n.ends_with(".acf")) { continue; }
            let Ok(t) = std::fs::read_to_string(e.path()) else { continue };
            let get = |k: &str| vdf_values(&t, k).into_iter().next().unwrap_or_default();
            let (appid, name, installdir) = (get("appid"), get("name"), get("installdir"));
            if appid.is_empty() || installdir.is_empty() || TOOLS.contains(&appid.as_str()) { continue; }
            if name.starts_with("Proton") || name.starts_with("Steam Linux Runtime") { continue; }
            let dir = apps.join("common").join(&installdir);
            if !dir.is_dir() || out.iter().any(|g| g.appid == appid) { continue; }
            let bytes = get("SizeOnDisk").parse().unwrap_or(0);
            out.push(SteamGame { appid, name, installdir, manifest: e.path(), dir, bytes });
        }
    }
    out.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
    out
}

/// Programas que no vale la pena listar (partes de Windows, controladores, librerías).
pub fn is_noise(name: &str) -> bool {
    let l = name.to_lowercase();
    ["update for", "redistributable", "runtime", "driver", " sdk", "windows sdk", "visual c++", ".net", "microsoft edge webview",
     "security update", "hotfix", "kb", "directx", "vcredist", "service pack", "language pack", "intel(r)", "nvidia physx",
     "realtek", "amd software", "microsoft update health", "windows pc health", "teams machine-wide", "bonjour"]
        .iter().any(|w| l.contains(w)) || l.starts_with("microsoft visual")
}

// ======================================================================= Windows
#[cfg(windows)]
mod imp {
    use super::*;
    use std::os::windows::ffi::{OsStrExt, OsStringExt};
    use std::os::windows::process::CommandExt;
    use windows_sys::Win32::Storage::FileSystem::*;
    use windows_sys::Win32::System::Com::CoTaskMemFree;
    use windows_sys::Win32::UI::Shell::*;
    use winreg::enums::*;
    use winreg::RegKey;

    const NO_WINDOW: u32 = 0x0800_0000;

    fn wide(s: &str) -> Vec<u16> { std::ffi::OsStr::new(s).encode_wide().chain(Some(0)).collect() }
    fn from_wide(buf: &[u16]) -> String {
        let n = buf.iter().position(|&c| c == 0).unwrap_or(buf.len());
        std::ffi::OsString::from_wide(&buf[..n]).to_string_lossy().to_string()
    }

    fn known(id: &windows_sys::core::GUID) -> Option<PathBuf> {
        unsafe {
            let mut p: windows_sys::core::PWSTR = std::ptr::null_mut();
            if SHGetKnownFolderPath(id, 0, std::ptr::null_mut(), &mut p) != 0 || p.is_null() { return None; }
            let mut n = 0; while *p.add(n) != 0 { n += 1; }
            let s = std::ffi::OsString::from_wide(std::slice::from_raw_parts(p, n));
            CoTaskMemFree(p as _);
            Some(PathBuf::from(s))
        }
    }

    pub fn known_folders() -> Vec<(&'static str, &'static str, PathBuf)> {
        let list: [(&str, &str, &windows_sys::core::GUID); 7] = [
            ("desktop", "Escritorio", &FOLDERID_Desktop), ("documents", "Documentos", &FOLDERID_Documents),
            ("pictures", "Imágenes", &FOLDERID_Pictures), ("music", "Música", &FOLDERID_Music),
            ("videos", "Videos", &FOLDERID_Videos), ("downloads", "Descargas", &FOLDERID_Downloads),
            ("savedgames", "Partidas guardadas", &FOLDERID_SavedGames),
        ];
        list.iter().filter_map(|(k, t, id)| known(id).filter(|p| p.is_dir()).map(|p| (*k, *t, p))).collect()
    }

    pub fn drives() -> Vec<Drive> {
        let system = std::env::var("SystemDrive").unwrap_or("C:".into()).to_uppercase();
        let mask = unsafe { GetLogicalDrives() };
        let mut out = vec![];
        for i in 0..26u32 {
            if mask & (1 << i) == 0 { continue; }
            let letter = format!("{}:", (b'A' + i as u8) as char);
            if letter == system { continue; }
            let root = format!("{letter}\\");
            let w = wide(&root);
            let kind = unsafe { GetDriveTypeW(w.as_ptr()) };
            // 2 = extraíble (pendrive), 3 = fijo (discos USB grandes aparecen así)
            if kind != 2 && kind != 3 { continue; }
            let (mut free, mut total) = (0u64, 0u64);
            if unsafe { GetDiskFreeSpaceExW(w.as_ptr(), &mut free, &mut total, std::ptr::null_mut()) } == 0 { continue; }
            let mut label = [0u16; 261];
            let mut fsname = [0u16; 261];
            unsafe {
                GetVolumeInformationW(w.as_ptr(), label.as_mut_ptr(), 261, std::ptr::null_mut(), std::ptr::null_mut(),
                                      std::ptr::null_mut(), fsname.as_mut_ptr(), 261);
            }
            out.push(Drive { root: PathBuf::from(root), label: from_wide(&label), fs: from_wide(&fsname), free, total,
                             removable: kind == 2 });
        }
        // primero los pendrives
        out.sort_by_key(|d| !d.removable);
        out
    }

    pub fn user() -> (String, String) {
        let login = std::env::var("USERNAME").unwrap_or_default();
        let mut buf = [0u16; 256];
        let mut n = 256u32;
        // 3 = NameDisplay (nombre completo de la cuenta)
        let ok = unsafe { windows_sys::Win32::Security::Authentication::Identity::GetUserNameExW(3, buf.as_mut_ptr(), &mut n) };
        let name = if ok != 0 { from_wide(&buf) } else { String::new() };
        (login.clone(), if name.trim().is_empty() { login } else { name })
    }

    pub fn computer() -> String { std::env::var("COMPUTERNAME").unwrap_or_default() }

    pub fn settings() -> Settings {
        let hkcu = RegKey::predef(HKEY_CURRENT_USER);
        let hklm = RegKey::predef(HKEY_LOCAL_MACHINE);
        let dword = |k: &RegKey, path: &str, name: &str| k.open_subkey(path).ok().and_then(|s| s.get_value::<u32, _>(name).ok());
        let string = |k: &RegKey, path: &str, name: &str| k.open_subkey(path).ok().and_then(|s| s.get_value::<String, _>(name).ok());
        let dark = dword(&hkcu, r"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme") == Some(0);
        // AccentColor está en formato ABGR
        let accent = dword(&hkcu, r"Software\Microsoft\Windows\DWM", "AccentColor")
            .map(|v| format!("#{:02X}{:02X}{:02X}", v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF)).unwrap_or_default();
        let timezone = string(&hklm, r"SYSTEM\CurrentControlSet\Control\TimeZoneInformation", "TimeZoneKeyName").unwrap_or_default();
        let locale = string(&hkcu, r"Control Panel\International", "LocaleName").unwrap_or_default();
        let time = string(&hkcu, r"Control Panel\International", "sShortTime").unwrap_or("HH:mm".into());
        let clock24h = time.contains('H');
        let mut keyboards = vec![];
        if let Ok(k) = hkcu.open_subkey(r"Keyboard Layout\Preload") {
            let mut vals: Vec<(String, String)> = k.enum_values().flatten()
                .map(|(n, v)| (n, v.to_string())).collect();
            vals.sort();
            keyboards = vals.into_iter().map(|(_, v)| v).collect();
        }
        Settings { dark, accent, timezone, locale, keyboards, clock24h }
    }

    fn sid() -> Option<String> {
        let out = std::process::Command::new("whoami").args(["/user", "/fo", "csv", "/nh"]).creation_flags(NO_WINDOW).output().ok()?;
        let t = String::from_utf8_lossy(&out.stdout);
        t.split(',').nth(1).map(|s| s.trim().trim_matches('"').to_string()).filter(|s| s.starts_with("S-"))
    }

    /// Foto de la cuenta (bytes, extensión).
    pub fn account_picture() -> Option<(Vec<u8>, String)> {
        if let Some(sid) = sid() {
            let path = format!(r"SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\{sid}");
            if let Ok(k) = RegKey::predef(HKEY_LOCAL_MACHINE).open_subkey(path) {
                for name in ["Image448", "Image240", "Image192"] {
                    if let Ok(p) = k.get_value::<String, _>(name) {
                        if let Ok(b) = std::fs::read(&p) {
                            let ext = Path::new(&p).extension().map(|e| e.to_string_lossy().to_lowercase()).unwrap_or("jpg".into());
                            return Some((b, ext));
                        }
                    }
                }
            }
        }
        // cuentas Microsoft: archivo .accountpicture-ms con JPEG adentro (se toma el más grande)
        let dir = PathBuf::from(std::env::var("APPDATA").ok()?).join(r"Microsoft\Windows\AccountPictures");
        let mut best: Option<Vec<u8>> = None;
        for e in std::fs::read_dir(dir).ok()?.flatten() {
            let Ok(b) = std::fs::read(e.path()) else { continue };
            let mut i = 0;
            while let Some(s) = b[i..].windows(3).position(|w| w == [0xFF, 0xD8, 0xFF]) {
                let start = i + s;
                if let Some(end) = b[start..].windows(2).rposition(|w| w == [0xFF, 0xD9]) {
                    let img = b[start..start + end + 2].to_vec();
                    if best.as_ref().map_or(true, |x| img.len() > x.len()) { best = Some(img); }
                }
                i = start + 3;
                if i >= b.len() { break; }
            }
        }
        best.map(|b| (b, "jpg".into()))
    }

    pub fn wallpaper() -> Option<PathBuf> {
        let hkcu = RegKey::predef(HKEY_CURRENT_USER);
        if let Ok(p) = hkcu.open_subkey(r"Control Panel\Desktop").and_then(|k| k.get_value::<String, _>("WallPaper")) {
            let p = PathBuf::from(p);
            if p.is_file() { return Some(p); }
        }
        let t = PathBuf::from(std::env::var("APPDATA").ok()?).join(r"Microsoft\Windows\Themes\TranscodedWallpaper");
        t.is_file().then_some(t)
    }

    pub fn installed_apps() -> Vec<String> {
        let mut out = std::collections::BTreeSet::new();
        for (root, path) in [
            (HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"),
            (HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"),
            (HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Uninstall"),
        ] {
            let Ok(k) = RegKey::predef(root).open_subkey(path) else { continue };
            for sub in k.enum_keys().flatten() {
                let Ok(s) = k.open_subkey(&sub) else { continue };
                if s.get_value::<u32, _>("SystemComponent").unwrap_or(0) == 1 { continue; }
                if let Ok(n) = s.get_value::<String, _>("DisplayName") {
                    let n = n.trim().to_string();
                    if !n.is_empty() && !is_noise(&n) { out.insert(n); }
                }
            }
        }
        out.into_iter().collect()
    }

    pub fn browsers() -> Vec<Browser> {
        let local = PathBuf::from(std::env::var("LOCALAPPDATA").unwrap_or_default());
        let roaming = PathBuf::from(std::env::var("APPDATA").unwrap_or_default());
        browsers_in(&local, &roaming)
    }

    pub fn running(process: &str) -> bool {
        std::process::Command::new("tasklist").args(["/FI", &format!("IMAGENAME eq {process}"), "/NH"])
            .creation_flags(NO_WINDOW).output()
            .map(|o| String::from_utf8_lossy(&o.stdout).to_lowercase().contains(&process.to_lowercase()))
            .unwrap_or(false)
    }

    pub fn steam_games() -> Vec<SteamGame> {
        let Ok(p) = RegKey::predef(HKEY_CURRENT_USER).open_subkey(r"Software\Valve\Steam")
            .and_then(|k| k.get_value::<String, _>("SteamPath")) else { return vec![] };
        steam_games_in(&PathBuf::from(p.replace('/', "\\")))
    }

    pub fn wifi() -> Vec<Wifi> {
        let tmp = std::env::temp_dir().join(format!("pasar-a-quantum-wifi-{}", std::process::id()));
        let _ = std::fs::create_dir_all(&tmp);
        let _ = std::process::Command::new("netsh")
            .args(["wlan", "export", "profile", "key=clear", &format!("folder={}", tmp.display())])
            .creation_flags(NO_WINDOW).output();
        let mut out = vec![];
        if let Ok(rd) = std::fs::read_dir(&tmp) {
            for e in rd.flatten() {
                let Ok(raw) = std::fs::read(e.path()) else { continue };
                // netsh escribe UTF-8 (a veces con BOM) o UTF-16
                let x = if raw.starts_with(&[0xFF, 0xFE]) {
                    String::from_utf16_lossy(&raw[2..].chunks(2).map(|c| u16::from_le_bytes([c[0], *c.get(1).unwrap_or(&0)])).collect::<Vec<_>>())
                } else { String::from_utf8_lossy(&raw).to_string() };
                let tag = |t: &str| x.split(&format!("<{t}>")).nth(1).and_then(|r| r.split(&format!("</{t}>")).next()).map(|s| s.to_string());
                if let Some(ssid) = tag("name") {
                    out.push(Wifi { ssid: xml_unescape(&ssid), auth: tag("authentication").unwrap_or_default(),
                                    key: tag("keyMaterial").map(|k| xml_unescape(&k)).unwrap_or_default() });
                }
            }
        }
        let _ = std::fs::remove_dir_all(&tmp);
        out.sort_by(|a, b| a.ssid.cmp(&b.ssid));
        out.dedup_by(|a, b| a.ssid == b.ssid);
        out
    }

    fn xml_unescape(s: &str) -> String {
        s.replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&apos;", "'").replace("&amp;", "&")
    }

    pub fn open_folder(p: &Path) {
        let _ = std::process::Command::new("explorer").arg(p).spawn();
    }

    pub fn exe_drive() -> Option<PathBuf> {
        let exe = std::env::current_exe().ok()?;
        let s = exe.to_string_lossy().replace(r"\\?\", "");
        (s.len() >= 2 && &s[1..2] == ":").then(|| PathBuf::from(format!("{}\\", &s[..2].to_uppercase())))
    }
}

// =================================================== Linux (solo para desarrollar)
#[cfg(not(windows))]
mod imp {
    use super::*;
    fn fake() -> PathBuf { PathBuf::from(std::env::var("PAQ_FAKE").unwrap_or("/tmp/paq-fake".into())) }

    pub fn known_folders() -> Vec<(&'static str, &'static str, PathBuf)> {
        [("desktop", "Escritorio", "Desktop"), ("documents", "Documentos", "Documents"), ("pictures", "Imágenes", "Pictures"),
         ("music", "Música", "Music"), ("videos", "Videos", "Videos"), ("downloads", "Descargas", "Downloads"),
         ("savedgames", "Partidas guardadas", "Saved Games")]
            .iter().map(|(k, t, d)| (*k, *t, fake().join(d))).filter(|(_, _, p)| p.is_dir()).collect()
    }
    pub fn drives() -> Vec<Drive> {
        let Ok(usb) = std::env::var("PAQ_FAKE_USB") else { return vec![] };
        let fs = std::env::var("PAQ_FAKE_FS").unwrap_or("exFAT".into());
        let total: u64 = std::env::var("PAQ_FAKE_GB").ok().and_then(|g| g.parse().ok()).unwrap_or(64) * 1_000_000_000;
        vec![Drive { root: PathBuf::from(usb), label: "PENDRIVE".into(), fs, free: total - total / 20, total, removable: true }]
    }
    pub fn user() -> (String, String) { ("juan".into(), "Juan Pérez".into()) }
    pub fn computer() -> String { "PC-JUAN".into() }
    pub fn settings() -> Settings {
        Settings { dark: true, accent: "#0078D4".into(), timezone: "Pacific SA Standard Time".into(), locale: "es-CL".into(),
                   keyboards: vec!["0000080A".into()], clock24h: true }
    }
    pub fn account_picture() -> Option<(Vec<u8>, String)> { std::fs::read(fake().join("foto.png")).ok().map(|b| (b, "png".into())) }
    pub fn wallpaper() -> Option<PathBuf> { Some(fake().join("fondo.jpg")).filter(|p| p.is_file()) }
    pub fn installed_apps() -> Vec<String> {
        ["Discord", "Google Chrome", "Mozilla Firefox (x64 es-MX)", "OBS Studio", "Spotify", "Steam", "VLC media player",
         "WhatsApp", "Microsoft Office Hogar y Empresas 2021", "7-Zip 23.01 (x64)"].iter().map(|s| s.to_string()).collect()
    }
    pub fn browsers() -> Vec<Browser> { browsers_in(&fake().join("AppData/Local"), &fake().join("AppData/Roaming")) }
    pub fn running(_p: &str) -> bool { std::env::var("PAQ_FAKE_RUNNING").is_ok() }
    pub fn steam_games() -> Vec<SteamGame> { steam_games_in(&fake().join("Steam")) }
    pub fn wifi() -> Vec<Wifi> {
        vec![Wifi { ssid: "Casa".into(), auth: "WPA2PSK".into(), key: "contraseña-de-prueba".into() },
             Wifi { ssid: "Casa 5G".into(), auth: "WPA2PSK".into(), key: "otra-prueba".into() }]
    }
    pub fn open_folder(p: &Path) { let _ = std::process::Command::new("xdg-open").arg(p).spawn(); }
    pub fn exe_drive() -> Option<PathBuf> { std::env::var("PAQ_FAKE_USB").ok().map(PathBuf::from) }
}

pub use imp::*;
