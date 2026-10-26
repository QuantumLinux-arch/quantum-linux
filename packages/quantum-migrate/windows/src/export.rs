//! Copia lo elegido al pendrive (en segundo plano) y escribe manifest.json (ver FORMATO.md).

use crate::platform::{self, Browser, Drive, Settings, SteamGame, Wifi};
use serde_json::{json, Value};
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex};

pub const FOLDER: &str = "Quantum - Mis cosas de Windows";
const PART: u64 = 4_000_000_000; // FAT32 no acepta archivos de 4 GiB o más

#[derive(Clone)]
pub struct FolderItem {
    pub key: &'static str,
    pub title: &'static str,
    pub path: PathBuf,
}

/// Lo que el usuario eligió.
#[derive(Clone)]
pub struct Plan {
    pub folders: Vec<FolderItem>,
    pub account: bool,
    pub browsers: Vec<Browser>,
    pub wifi: Vec<Wifi>,
    pub steam: Vec<SteamGame>,
    pub apps: Vec<String>,
    pub settings: Settings,
    pub user: (String, String),
    pub computer: String,
    pub picture: Option<(Vec<u8>, String)>,
    pub wallpaper: Option<PathBuf>,
    pub total: u64,
}

#[derive(Default)]
pub struct Progress {
    pub total: AtomicU64,
    pub done: AtomicU64,
    pub files: AtomicU64,
    pub cancel: AtomicBool,
    pub finished: AtomicBool,
    pub section: Mutex<String>,
    pub current: Mutex<String>,
    pub errors: Mutex<Vec<String>>,
    pub fatal: Mutex<Option<String>>,
}

impl Progress {
    fn set(&self, section: &str, current: &str) {
        *self.section.lock().unwrap() = section.to_string();
        *self.current.lock().unwrap() = current.to_string();
    }
    fn cancelled(&self) -> bool { self.cancel.load(Ordering::Relaxed) }
}

/// ¿Vale la pena copiar este archivo? (no los de sistema que Windows pone en cada carpeta)
fn skip_name(name: &str) -> bool {
    let l = name.to_lowercase();
    l == "desktop.ini" || l == "thumbs.db" || l.starts_with("~$") || l.ends_with(".tmp") || l == ".ds_store"
}

#[cfg(windows)]
fn is_link(md: &std::fs::Metadata) -> bool {
    use std::os::windows::fs::MetadataExt;
    md.file_attributes() & 0x400 != 0 // reparse point: accesos de compatibilidad («Mis documentos»), enlaces
}
#[cfg(not(windows))]
fn is_link(md: &std::fs::Metadata) -> bool { md.file_type().is_symlink() }

/// Recorre una carpeta: (archivo, ruta relativa, tamaño).
pub fn walk(root: &Path) -> impl Iterator<Item = (PathBuf, PathBuf, u64)> + '_ {
    walkdir::WalkDir::new(root).follow_links(false).into_iter()
        .filter_entry(|e| e.depth() == 0 || std::fs::symlink_metadata(e.path()).map(|m| !is_link(&m)).unwrap_or(false))
        .flatten()
        .filter(|e| e.file_type().is_file() && !skip_name(&e.file_name().to_string_lossy()))
        .filter_map(move |e| {
            let size = e.metadata().map(|m| m.len()).unwrap_or(0);
            let rel = e.path().strip_prefix(root).ok()?.to_path_buf();
            Some((e.path().to_path_buf(), rel, size))
        })
}

/// Tamaño total y cantidad de archivos.
pub fn measure(root: &Path, stop: &AtomicBool) -> (u64, u64) {
    let (mut bytes, mut files) = (0u64, 0u64);
    for (_, _, s) in walk(root) {
        if stop.load(Ordering::Relaxed) { break; }
        bytes += s;
        files += 1;
    }
    (bytes, files)
}

fn same(src: &std::fs::Metadata, dst: &Path) -> bool {
    let Ok(d) = std::fs::metadata(dst) else { return false };
    if d.len() != src.len() { return false; }
    let (a, b) = (filetime::FileTime::from_last_modification_time(src), filetime::FileTime::from_last_modification_time(&d));
    // FAT guarda la hora con 2 s de precisión
    (a.unix_seconds() - b.unix_seconds()).abs() <= 2
}

/// Copia un archivo con avance; en FAT32 parte los de 4 GB o más. Devuelve Some(partes) si lo partió.
fn copy_file(src: &Path, dst: &Path, fat32: bool, p: &Progress) -> std::io::Result<Option<u32>> {
    let md = std::fs::metadata(src)?;
    let len = md.len();
    if let Some(parent) = dst.parent() { std::fs::create_dir_all(parent)?; }
    let mtime = filetime::FileTime::from_last_modification_time(&md);
    let split = fat32 && len >= PART;
    let parts = if split { len.div_ceil(PART) as u32 } else { 1 };
    let part_path = |i: u32| -> PathBuf {
        if split { PathBuf::from(format!("{}.qpart{:03}", dst.display(), i + 1)) } else { dst.to_path_buf() }
    };
    // ya copiado (por ejemplo, si se cortó y se vuelve a empezar)
    if !split && same(&md, dst) {
        p.done.fetch_add(len, Ordering::Relaxed);
        return Ok(None);
    }
    if split && (0..parts).all(|i| std::fs::metadata(part_path(i)).map(|m| m.len() == PART.min(len - i as u64 * PART)).unwrap_or(false)) {
        p.done.fetch_add(len, Ordering::Relaxed);
        return Ok(Some(parts));
    }
    let mut input = std::fs::File::open(src)?;
    let mut buf = vec![0u8; 4 << 20];
    for i in 0..parts {
        let target = part_path(i);
        let tmp = PathBuf::from(format!("{}.copiando", target.display()));
        let mut out = std::fs::File::create(&tmp)?;
        let mut left = if split { PART.min(len - i as u64 * PART) } else { u64::MAX };
        while left > 0 {
            if p.cancelled() { drop(out); let _ = std::fs::remove_file(&tmp); return Err(std::io::Error::other("cancelado")); }
            let want = buf.len().min(left.min(usize::MAX as u64) as usize);
            let n = input.read(&mut buf[..want])?;
            if n == 0 { break; }
            out.write_all(&buf[..n])?;
            left = left.saturating_sub(n as u64);
            p.done.fetch_add(n as u64, Ordering::Relaxed);
        }
        out.flush()?;
        drop(out);
        let _ = std::fs::remove_file(&target);
        std::fs::rename(&tmp, &target)?;
        let _ = filetime::set_file_mtime(&target, mtime);
    }
    Ok(split.then_some(parts))
}

struct Ctx<'a> {
    base: PathBuf,
    fat32: bool,
    p: &'a Progress,
    split: Vec<Value>,
}

impl Ctx<'_> {
    /// Copia una carpeta completa a base/rel. Devuelve (archivos, bytes).
    fn tree(&mut self, section: &str, src: &Path, rel: &str) -> (u64, u64) {
        let (mut files, mut bytes) = (0u64, 0u64);
        for (path, r, size) in walk(src) {
            if self.p.cancelled() { break; }
            self.p.set(section, &r.to_string_lossy());
            let dst = self.base.join(rel).join(&r);
            match copy_file(&path, &dst, self.fat32, self.p) {
                Ok(parts) => {
                    files += 1; bytes += size;
                    self.p.files.fetch_add(1, Ordering::Relaxed);
                    if let Some(n) = parts {
                        let relp = Path::new(rel).join(&r).to_string_lossy().replace('\\', "/");
                        self.split.push(json!({ "path": relp, "parts": n, "bytes": size }));
                    }
                }
                Err(e) if e.to_string() == "cancelado" => break,
                Err(_) => {
                    // en uso o sin permiso: se anota y se sigue (y se cuenta como hecho para la barra)
                    self.p.done.fetch_add(size, Ordering::Relaxed);
                    self.p.errors.lock().unwrap().push(Path::new(rel).join(&r).to_string_lossy().replace('\\', "/"));
                }
            }
        }
        (files, bytes)
    }

    fn one(&mut self, section: &str, src: &Path, rel: &str) -> bool {
        self.p.set(section, &src.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_default());
        let size = std::fs::metadata(src).map(|m| m.len()).unwrap_or(0);
        match copy_file(src, &self.base.join(rel), self.fat32, self.p) {
            Ok(_) => true,
            Err(_) => {
                self.p.done.fetch_add(size, Ordering::Relaxed);
                self.p.errors.lock().unwrap().push(rel.to_string());
                false
            }
        }
    }
}

fn now() -> (String, String) {
    // fecha local sin dependencias: segundos desde 1970 → AAAA-MM-DD hh:mm:ss (UTC)
    let s = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0) as i64;
    let (days, rem) = (s.div_euclid(86400), s.rem_euclid(86400));
    let (h, m, sec) = (rem / 3600, rem % 3600 / 60, rem % 60);
    // algoritmo de Howard Hinnant (días civiles)
    let z = days + 719468;
    let era = z.div_euclid(146097);
    let doe = z - era * 146097;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let mo = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = yoe + era * 400 + if mo <= 2 { 1 } else { 0 };
    (format!("{y:04}-{mo:02}-{d:02}T{h:02}:{m:02}:{sec:02}Z"), format!("{y:04}{mo:02}{d:02}-{h:02}{m:02}{sec:02}"))
}

fn write_manifest(base: &Path, m: &Value) -> std::io::Result<()> {
    let tmp = base.join("manifest.json.tmp");
    std::fs::write(&tmp, serde_json::to_vec_pretty(m).unwrap())?;
    let _ = std::fs::remove_file(base.join("manifest.json"));
    std::fs::rename(tmp, base.join("manifest.json"))
}

/// Hace todo. Se llama en un hilo aparte.
pub fn run(plan: Plan, drive: Drive, p: Arc<Progress>) {
    p.total.store(plan.total, Ordering::Relaxed);
    let base = drive.root.join(FOLDER);
    let result = (|| -> std::io::Result<()> {
        std::fs::create_dir_all(&base)?;
        let (created, stamp) = now();
        let mut ctx = Ctx { base: base.clone(), fat32: drive.fat32(), p: &p, split: vec![] };
        let mut m = json!({
            "format": 1,
            "id": format!("{stamp}-{}", plan.computer),
            "created": created,
            "complete": false,
            "computer": plan.computer,
            "user": { "login": plan.user.0, "name": plan.user.1 },
            "settings": if plan.account { serde_json::to_value(&plan.settings).unwrap() } else { Value::Null },
            "account": {},
            "folders": [],
            "browsers": [],
            "wifi": Value::Null,
            "apps": plan.apps,
            "steam": [],
            "split": [],
            "errors": [],
        });
        write_manifest(&base, &m)?;

        // ---- cuenta: foto y fondo
        if plan.account {
            p.set("Tu cuenta", "Foto y fondo de pantalla");
            std::fs::create_dir_all(base.join("Cuenta"))?;
            if let Some((bytes, ext)) = &plan.picture {
                let rel = format!("Cuenta/foto.{ext}");
                if std::fs::write(base.join(&rel), bytes).is_ok() { m["account"]["picture"] = json!(rel); }
                p.done.fetch_add(bytes.len() as u64, Ordering::Relaxed);
            }
            if let Some(w) = &plan.wallpaper {
                // TranscodedWallpaper no tiene extensión: es un JPEG
                let ext = w.extension().map(|e| e.to_string_lossy().to_lowercase()).unwrap_or("jpg".into());
                let rel = format!("Cuenta/fondo.{ext}");
                if ctx.one("Tu cuenta", w, &rel) { m["account"]["wallpaper"] = json!(rel); }
            }
        }

        // ---- carpetas
        for f in &plan.folders {
            if p.cancelled() { break; }
            let rel = format!("Archivos/{}", f.title);
            let (files, bytes) = ctx.tree(f.title, &f.path, &rel);
            m["folders"].as_array_mut().unwrap().push(json!({ "key": f.key, "title": f.title, "dir": rel, "files": files, "bytes": bytes }));
            write_manifest(&base, &m)?;
        }

        // ---- navegadores
        for b in &plan.browsers {
            if p.cancelled() { break; }
            let rel = format!("Navegadores/{}", b.key);
            if b.kind == "chromium" {
                let mut ok = vec![];
                for prof in &b.profiles {
                    let src = b.src.join(prof).join("Bookmarks");
                    if ctx.one(b.title, &src, &format!("{rel}/{prof}/Bookmarks")) { ok.push(prof.clone()); }
                }
                if !ok.is_empty() {
                    m["browsers"].as_array_mut().unwrap().push(json!({ "key": b.key, "title": b.title, "kind": "chromium", "dir": rel, "profiles": ok }));
                }
            } else {
                let mut any = false;
                for f in ["places.sqlite", "favicons.sqlite", "logins.json", "key4.db"] {
                    let src = b.src.join(f);
                    if src.is_file() && ctx.one(b.title, &src, &format!("{rel}/{f}")) { any = true; }
                }
                if any {
                    m["browsers"].as_array_mut().unwrap().push(json!({ "key": b.key, "title": b.title, "kind": "firefox", "dir": rel }));
                }
            }
            write_manifest(&base, &m)?;
        }

        // ---- juegos de Steam
        for g in &plan.steam {
            if p.cancelled() { break; }
            let title = format!("Steam: {}", g.name);
            let manifest = format!("Steam/appmanifest_{}.acf", g.appid);
            ctx.one(&title, &g.manifest, &manifest);
            let rel = format!("Steam/common/{}", g.installdir);
            let (_, bytes) = ctx.tree(&title, &g.dir, &rel);
            m["steam"].as_array_mut().unwrap().push(json!({ "appid": g.appid, "name": g.name, "dir": rel, "manifest": manifest, "bytes": bytes }));
            write_manifest(&base, &m)?;
        }

        // ---- Wi-Fi
        if !plan.wifi.is_empty() && !p.cancelled() {
            p.set("Redes Wi-Fi", "");
            std::fs::write(base.join("wifi.json"), serde_json::to_vec_pretty(&plan.wifi).unwrap())?;
            m["wifi"] = json!("wifi.json");
        }

        m["split"] = json!(ctx.split);
        m["errors"] = json!(*p.errors.lock().unwrap());
        m["complete"] = json!(!p.cancelled());
        write_manifest(&base, &m)?;
        Ok(())
    })();
    if let Err(e) = result {
        let msg = if e.kind() == std::io::ErrorKind::StorageFull || e.raw_os_error() == Some(112) {
            "El pendrive se llenó. Libera espacio o usa uno más grande y vuelve a intentar: lo ya copiado no se repite.".to_string()
        } else {
            format!("No se pudo escribir en el pendrive: {e}")
        };
        *p.fatal.lock().unwrap() = Some(msg);
    }
    p.finished.store(true, Ordering::Relaxed);
}

pub fn open_result(drive: &Drive) { platform::open_folder(&drive.root.join(FOLDER)); }
