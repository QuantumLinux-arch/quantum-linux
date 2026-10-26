//! «Pasar a Quantum»: copia tus cosas de Windows a un pendrive para llevarlas a Quantum Linux.
//! Cuatro pasos: Bienvenida → Elige → Copiando → Listo. Interfaz con egui.
#![cfg_attr(windows, windows_subsystem = "windows")]
#![allow(float_literal_f32_fallback)] // egui 0.31 con Rust reciente: Stroke::new(1.0, …)

mod export;
#[allow(dead_code)]
mod icons;
mod platform;
mod ui;

use eframe::egui::{self, Color32, CornerRadius, FontFamily, FontId, Margin, Pos2, Rect, RichText, Sense, Stroke, StrokeKind, Vec2};
use export::{FolderItem, Plan, Progress};
use platform::{Browser, Drive, SteamGame, Wifi};
use std::collections::HashSet;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use ui::*;

// ------------------------------------------------------------- análisis
#[derive(Clone)]
struct FolderScan {
    item: FolderItem,
    bytes: Option<u64>,
    files: u64,
}

#[derive(Default)]
struct Scan {
    folders: Vec<FolderScan>,
    browsers: Vec<(Browser, u64, bool)>, // navegador, tamaño, ¿está abierto?
    steam: Option<Vec<SteamGame>>,
    wifi: Option<Vec<Wifi>>,
    apps: Vec<String>,
    picture: Option<(Vec<u8>, String)>,
    wallpaper: Option<PathBuf>,
    settings: platform::Settings,
    user: (String, String),
    computer: String,
    ready_basic: bool,
}

fn start_scan(scan: Arc<Mutex<Scan>>, stop: Arc<AtomicBool>) {
    std::thread::spawn(move || {
        {
            let mut s = scan.lock().unwrap();
            s.user = platform::user();
            s.computer = platform::computer();
            s.settings = platform::settings();
            s.folders = platform::known_folders().into_iter()
                .map(|(key, title, path)| FolderScan { item: FolderItem { key, title, path }, bytes: None, files: 0 }).collect();
        }
        let picture = platform::account_picture();
        let wallpaper = platform::wallpaper();
        let browsers: Vec<_> = platform::browsers().into_iter().map(|b| {
            let size = if b.kind == "chromium" {
                b.profiles.iter().filter_map(|p| std::fs::metadata(b.src.join(p).join("Bookmarks")).ok()).map(|m| m.len()).sum()
            } else {
                ["places.sqlite", "favicons.sqlite", "logins.json", "key4.db"].iter()
                    .filter_map(|f| std::fs::metadata(b.src.join(f)).ok()).map(|m| m.len()).sum()
            };
            let running = platform::running(b.process);
            (b, size, running)
        }).collect();
        let apps = platform::installed_apps();
        {
            let mut s = scan.lock().unwrap();
            s.picture = picture; s.wallpaper = wallpaper; s.browsers = browsers; s.apps = apps; s.ready_basic = true;
        }
        let steam = platform::steam_games();
        scan.lock().unwrap().steam = Some(steam);
        let wifi = platform::wifi();
        scan.lock().unwrap().wifi = Some(wifi);
        // tamaños de las carpetas (lo más lento)
        let n = scan.lock().unwrap().folders.len();
        for i in 0..n {
            if stop.load(Ordering::Relaxed) { return; }
            let path = scan.lock().unwrap().folders[i].item.path.clone();
            let (bytes, files) = export::measure(&path, &stop);
            let mut s = scan.lock().unwrap();
            s.folders[i].bytes = Some(bytes);
            s.folders[i].files = files;
        }
    });
}

// ------------------------------------------------------------------ app
#[derive(PartialEq, Clone, Copy)]
enum Step { Welcome, Choose, Copying, Done }

struct App {
    step: Step,
    scan: Arc<Mutex<Scan>>,
    stop: Arc<AtomicBool>,
    drives: Vec<Drive>,
    drive: usize,
    last_drives: Instant,
    chosen: HashSet<String>, // claves elegidas: folder:x, account, browser:x, wifi, steam:appid
    defaults_set: bool,
    show_games: bool,
    progress: Arc<Progress>,
    started: Instant,
    plan_total: u64,
    logo: egui::TextureHandle,
    photo: Option<egui::TextureHandle>,
    photo_tried: bool,
}

impl App {
    fn new(cc: &eframe::CreationContext) -> Self {
        setup_style(&cc.egui_ctx);
        let logo = load_png(&cc.egui_ctx, "logo", include_bytes!("../assets/logo.png"));
        let scan = Arc::new(Mutex::new(Scan::default()));
        let stop = Arc::new(AtomicBool::new(false));
        start_scan(scan.clone(), stop.clone());
        let drives = platform::drives();
        let exe = platform::exe_drive();
        let drive = drives.iter().position(|d| Some(&d.root) == exe.as_ref()).unwrap_or(0);
        App {
            step: Step::Welcome, scan, stop, drives, drive, last_drives: Instant::now(), chosen: HashSet::new(),
            defaults_set: false, show_games: false, progress: Arc::new(Progress::default()), started: Instant::now(),
            plan_total: 0, logo, photo: None, photo_tried: false,
        }
    }

    fn drive(&self) -> Option<&Drive> { self.drives.get(self.drive) }

    fn refresh_drives(&mut self) {
        if self.last_drives.elapsed() < Duration::from_secs(2) { return; }
        self.last_drives = Instant::now();
        let cur = self.drive().map(|d| d.root.clone());
        self.drives = platform::drives();
        self.drive = cur.and_then(|c| self.drives.iter().position(|d| d.root == c)).unwrap_or(0);
    }

    fn on(&self, k: &str) -> bool { self.chosen.contains(k) }
    fn toggle(&mut self, k: &str) { if !self.chosen.remove(k) { self.chosen.insert(k.to_string()); } }

    /// Lo elegido y cuánto ocupa.
    fn plan(&self) -> Plan {
        let s = self.scan.lock().unwrap();
        let folders: Vec<_> = s.folders.iter().filter(|f| self.on(&format!("folder:{}", f.item.key))).cloned().collect();
        let browsers: Vec<_> = s.browsers.iter().filter(|(b, _, _)| self.on(&format!("browser:{}", b.key))).cloned().collect();
        let steam: Vec<_> = s.steam.clone().unwrap_or_default().into_iter().filter(|g| self.on(&format!("steam:{}", g.appid))).collect();
        let account = self.on("account");
        let mut total: u64 = folders.iter().map(|f| f.bytes.unwrap_or(0)).sum::<u64>()
            + browsers.iter().map(|(_, b, _)| *b).sum::<u64>() + steam.iter().map(|g| g.bytes).sum::<u64>();
        if account {
            total += s.picture.as_ref().map(|p| p.0.len() as u64).unwrap_or(0);
            total += s.wallpaper.as_ref().and_then(|w| std::fs::metadata(w).ok()).map(|m| m.len()).unwrap_or(0);
        }
        Plan {
            folders: folders.into_iter().map(|f| f.item).collect(),
            account,
            browsers: browsers.into_iter().map(|(b, _, _)| b).collect(),
            wifi: if self.on("wifi") { s.wifi.clone().unwrap_or_default() } else { vec![] },
            steam,
            apps: s.apps.clone(),
            settings: s.settings.clone(),
            user: s.user.clone(),
            computer: s.computer.clone(),
            picture: if account { s.picture.clone() } else { None },
            wallpaper: if account { s.wallpaper.clone() } else { None },
            total,
        }
    }

    fn start_copy(&mut self) {
        let Some(drive) = self.drive().cloned() else { return };
        let plan = self.plan();
        self.plan_total = plan.total;
        self.progress = Arc::new(Progress::default());
        self.started = Instant::now();
        let p = self.progress.clone();
        std::thread::spawn(move || export::run(plan, drive, p));
        self.step = Step::Copying;
    }
}

/// Pasos arriba: 1 Bienvenida · 2 Elige · 3 Copia · 4 Listo
fn stepper(ui: &mut egui::Ui, step: Step) {
    let names = ["Bienvenida", "Elige", "Copia", "Listo"];
    let cur = match step { Step::Welcome => 0, Step::Choose => 1, Step::Copying => 2, Step::Done => 3 };
    ui.horizontal(|ui| {
        for (i, n) in names.iter().enumerate() {
            let (rect, _) = ui.allocate_exact_size(Vec2::new(26.0, 26.0), Sense::hover());
            let c = rect.center();
            if i < cur {
                ui.painter().circle_filled(c, 12.0, INDIGO);
                ui.painter().text(c, egui::Align2::CENTER_CENTER, icons::CHECK, FontId::new(16.0, icon_font()), Color32::WHITE);
            } else if i == cur {
                ui.painter().circle_filled(c, 12.0, brand(i as f32 / 3.0));
                ui.painter().text(c, egui::Align2::CENTER_CENTER, (i + 1).to_string(), FontId::new(13.0, bold()), Color32::WHITE);
            } else {
                ui.painter().circle_stroke(c, 11.0, Stroke::new(1.5, LINE));
                ui.painter().text(c, egui::Align2::CENTER_CENTER, (i + 1).to_string(), FontId::new(13.0, semi()), MUTED);
            }
            ui.label(RichText::new(*n).size(14.0).family(if i == cur { semi() } else { FontFamily::Proportional })
                .color(if i <= cur { TEXT } else { MUTED }));
            if i < 3 {
                let (r, _) = ui.allocate_exact_size(Vec2::new(28.0, 26.0), Sense::hover());
                ui.painter().line_segment([Pos2::new(r.left() + 2.0, r.center().y), Pos2::new(r.right() - 2.0, r.center().y)],
                                          Stroke::new(1.5, if i < cur { INDIGO } else { LINE }));
            }
        }
    });
}

// ------------------------------------------------------------------ pantallas
impl eframe::App for App {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        if self.step != Step::Copying { self.refresh_drives(); }
        ctx.request_repaint_after(Duration::from_millis(if self.step == Step::Copying { 100 } else { 500 }));
        if !self.photo_tried {
            if let Some((bytes, _)) = self.scan.lock().unwrap().picture.clone() {
                self.photo_tried = true;
                if let Ok(img) = image::load_from_memory(&bytes) {
                    let img = img.resize_to_fill(160, 160, image::imageops::FilterType::Triangle).to_rgba8();
                    let c = egui::ColorImage::from_rgba_unmultiplied([160, 160], img.as_raw());
                    self.photo = Some(ctx.load_texture("foto", c, egui::TextureOptions::LINEAR));
                }
            }
        }
        // elecciones por defecto: todas las carpetas, la cuenta, los navegadores y el Wi-Fi (no los juegos)
        if !self.defaults_set {
            let s = self.scan.lock().unwrap();
            if s.ready_basic && s.wifi.is_some() {
                let mut keys: Vec<String> = s.folders.iter().map(|f| format!("folder:{}", f.item.key)).collect();
                keys.push("account".into());
                keys.extend(s.browsers.iter().map(|(b, _, _)| format!("browser:{}", b.key)));
                if s.wifi.as_ref().is_some_and(|w| !w.is_empty()) { keys.push("wifi".into()); }
                drop(s);
                self.chosen.extend(keys);
                self.defaults_set = true;
            }
        }

        if self.step == Step::Choose {
            egui::TopBottomPanel::bottom("pie").frame(egui::Frame::new().fill(BG).inner_margin(Margin { left: 40, right: 40, top: 12, bottom: 20 }))
                .show_separator_line(false).show(ctx, |ui| self.footer(ui));
        }
        egui::CentralPanel::default().frame(egui::Frame::new().fill(BG).inner_margin(Margin::symmetric(40, 26))).show(ctx, |ui| {
            // cabecera
            ui.horizontal(|ui| {
                ui.add(egui::Image::new(&self.logo).fit_to_exact_size(Vec2::splat(34.0)));
                ui.label(RichText::new("Pasar a Quantum").size(18.0).family(bold()));
                // los pasos, alineados a la derecha (de izquierda a derecha)
                ui.add_space((ui.available_width() - 500.0).max(0.0));
                stepper(ui, self.step);
            });
            ui.add_space(14.0);
            match self.step {
                Step::Welcome => self.welcome(ui),
                Step::Choose => self.choose(ui),
                Step::Copying => self.copying(ui),
                Step::Done => self.done(ui),
            }
        });
    }

    fn on_exit(&mut self) {
        self.stop.store(true, Ordering::Relaxed);
        self.progress.cancel.store(true, Ordering::Relaxed);
    }
}

impl App {
    fn drive_card(&mut self, ui: &mut egui::Ui) {
        let w = ui.available_width().min(560.0);
        egui::Frame::new().fill(CARD).corner_radius(18).stroke(Stroke::new(1.0, LINE)).inner_margin(Margin::same(18)).show(ui, |ui| {
            ui.set_width(w - 36.0);
            ui.horizontal(|ui| {
                let (r, _) = ui.allocate_exact_size(Vec2::splat(44.0), Sense::hover());
                badge(ui.painter(), r.center(), 22.0, icons::USB, 0.3);
                ui.add_space(6.0);
                if let Some(d) = self.drive().cloned() {
                    ui.vertical(|ui| {
                        ui.label(RichText::new("Se guardará en").size(13.0).color(MUTED));
                        ui.label(RichText::new(d.name()).size(17.0).family(semi()));
                        ui.label(RichText::new(format!("{} libres de {}", gb(d.free), gb(d.total))).size(13.0).color(MUTED));
                    });
                    if self.drives.len() > 1 {
                        ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                            let names: Vec<String> = self.drives.iter().map(|d| d.name()).collect();
                            egui::ComboBox::from_id_salt("drive").selected_text("Cambiar").width(120.0).show_ui(ui, |ui| {
                                for (i, n) in names.iter().enumerate() { ui.selectable_value(&mut self.drive, i, n); }
                            });
                        });
                    }
                } else {
                    ui.vertical(|ui| {
                        ui.label(RichText::new("Conecta un pendrive").size(17.0).family(semi()).color(AMBER));
                        ui.label(RichText::new("Usa uno con espacio para tus archivos. Lo detectamos solos.").size(13.0).color(MUTED));
                    });
                }
            });
        });
    }

    fn welcome(&mut self, ui: &mut egui::Ui) {
        let name = self.scan.lock().unwrap().user.1.split_whitespace().next().unwrap_or("").to_string();
        ui.add_space(18.0);
        ui.horizontal(|ui| {
            ui.vertical(|ui| {
                ui.set_width((ui.available_width() - 300.0).max(420.0));
                ui.label(RichText::new(if name.is_empty() { "¡Hola!".to_string() } else { format!("¡Hola, {name}!") })
                    .size(18.0).family(semi()).color(LILAC));
                ui.label(RichText::new("Lleva tus cosas de Windows\na Quantum Linux").size(38.0).family(bold()));
                ui.add_space(4.0);
                ui.label(RichText::new("Copiamos tus archivos, tu cuenta y tus juegos a un pendrive. Después, al conectarlo en Quantum, todo se acomoda solo.")
                    .size(16.0).color(MUTED));
                ui.add_space(14.0);
                for (g, t, title, d) in [
                    (icons::FOLDER, 0.0, "Tus archivos y fotos", "Escritorio, Documentos, Imágenes, Música, Videos y Descargas."),
                    (icons::ACCOUNT_CIRCLE, 0.45, "Tu cuenta y tus ajustes", "Tu foto, tu fondo, el modo oscuro, la hora y el teclado."),
                    (icons::SPORTS_ESPORTS, 0.9, "Navegadores, Wi-Fi y juegos", "Tus favoritos, tus redes y tus juegos de Steam."),
                ] {
                    ui.horizontal(|ui| {
                        let (r, _) = ui.allocate_exact_size(Vec2::splat(40.0), Sense::hover());
                        ui.painter().circle_filled(r.center(), 20.0, brand(t).gamma_multiply(0.22));
                        ui.painter().text(r.center(), egui::Align2::CENTER_CENTER, g, FontId::new(22.0, icon_font()), brand(t));
                        ui.vertical(|ui| {
                            ui.spacing_mut().item_spacing.y = 1.0;
                            ui.label(RichText::new(title).size(15.5).family(semi()));
                            ui.label(RichText::new(d).size(13.5).color(MUTED));
                        });
                    });
                }
                ui.add_space(16.0);
                self.drive_card(ui);
                ui.add_space(18.0);
                let ready = self.drive().is_some();
                if primary(ui, "Empezar", icons::ARROW_FORWARD, ready) { self.step = Step::Choose; }
                ui.add_space(6.0);
                ui.label(RichText::new("No se borra ni se cambia nada de tu PC: solo se copia.").size(13.0).color(MUTED));
            });
            // ilustración: el logo grande con órbitas
            let (rect, _) = ui.allocate_exact_size(Vec2::new(280.0, 420.0), Sense::hover());
            let c = rect.center();
            let t = ui.input(|i| i.time) as f32;
            for k in 0..3 {
                let r = 120.0 + k as f32 * 16.0 + (t * 1.2 + k as f32).sin() * 3.0;
                ui.painter().circle_stroke(c, r, Stroke::new(1.5, brand(k as f32 / 2.0).gamma_multiply(0.35)));
            }
            ui.painter().circle_filled(c, 108.0, INDIGO.gamma_multiply(0.12));
            ui.painter().image(self.logo.id(), Rect::from_center_size(c, Vec2::splat(170.0)),
                               Rect::from_min_max(Pos2::ZERO, Pos2::new(1.0, 1.0)), Color32::WHITE);
            ui.ctx().request_repaint_after(Duration::from_millis(33));
        });
    }

    fn choose(&mut self, ui: &mut egui::Ui) {
        ui.label(RichText::new("¿Qué quieres llevar?").size(28.0).family(bold()));
        ui.label(RichText::new("Ya marcamos lo más importante. Toca una tarjeta para quitarla o agregarla.").size(15.0).color(MUTED));
        egui::ScrollArea::vertical().auto_shrink([false, false]).show(ui, |ui| {
            let w = ui.available_width();
            let cols = if w > 900.0 { 3 } else { 2 };
            let cw = (w - 12.0 * (cols as f32 - 1.0)) / cols as f32 - 1.0;
            let (folders, browsers, steam, wifi, user, has_pic, has_wall, settings) = {
                let s = self.scan.lock().unwrap();
                (s.folders.clone(), s.browsers.clone(), s.steam.clone(), s.wifi.clone(), s.user.clone(),
                 s.picture.is_some(), s.wallpaper.is_some(), s.settings.clone())
            };

            section(ui, "Tus archivos", "");
            let folder_icon = |k: &str| match k {
                "desktop" => icons::DESKTOP_WINDOWS, "documents" => icons::DESCRIPTION, "pictures" => icons::IMAGE,
                "music" => icons::MUSIC_NOTE, "videos" => icons::MOVIE, "downloads" => icons::DOWNLOAD, _ => icons::SAVE,
            };
            let mut clicked: Vec<String> = vec![];
            for row in folders.chunks(cols) {
                ui.horizontal(|ui| {
                    for (i, f) in row.iter().enumerate() {
                        let key = format!("folder:{}", f.item.key);
                        let detail = match f.bytes {
                            Some(b) => format!("{} · {}", gb(b), plural(f.files as usize, "archivo", "archivos")),
                            None => "Calculando…".into(),
                        };
                        if choice(ui, cw, folder_icon(f.item.key), i as f32 / 3.0, f.item.title, &detail, None, self.on(&key), true) {
                            clicked.push(key);
                        }
                    }
                });
            }

            section(ui, "Tu cuenta", "Para que Quantum se sienta como tu PC desde el primer minuto.");
            let mut bits = vec![];
            if has_pic { bits.push("tu foto"); }
            if has_wall { bits.push("tu fondo"); }
            bits.push(if settings.dark { "modo oscuro" } else { "modo claro" });
            bits.push(if settings.clock24h { "hora de 24 horas" } else { "hora de 12 horas" });
            bits.push("zona horaria y teclado");
            let detail = format!("{}: {}", if user.1.is_empty() { "Tu cuenta".to_string() } else { user.1.clone() }, bits.join(", "));
            ui.horizontal(|ui| {
                if choice(ui, cw * 2.0 + 12.0, icons::ACCOUNT_CIRCLE, 0.45, "Foto, fondo y ajustes", &detail, None, self.on("account"), true) {
                    clicked.push("account".into());
                }
                if let Some(ph) = &self.photo {
                    let (r, _) = ui.allocate_exact_size(Vec2::new(84.0, 84.0), Sense::hover());
                    ui.painter().add(egui::epaint::RectShape::filled(r, 42.0, Color32::WHITE)
                        .with_texture(ph.id(), Rect::from_min_max(Pos2::ZERO, Pos2::new(1.0, 1.0))));
                }
            });

            if !browsers.is_empty() {
                section(ui, "Navegadores", "Tus favoritos. De Firefox también tus contraseñas guardadas.");
                for row in browsers.chunks(cols) {
                    ui.horizontal(|ui| {
                        for (i, (b, _size, running)) in row.iter().enumerate() {
                            let key = format!("browser:{}", b.key);
                            let detail = if b.kind == "firefox" { "Favoritos, historial y contraseñas".to_string() }
                                         else { format!("Favoritos ({})", plural(b.profiles.len(), "perfil", "perfiles")) };
                            let note = running.then(|| (format!("Cierra {} antes de copiar", b.title), AMBER));
                            let note_ref = note.as_ref().map(|(s, c)| (s.as_str(), *c));
                            if choice(ui, cw, icons::PUBLIC, 0.2 + i as f32 * 0.3, b.title, &detail, note_ref, self.on(&key), true) {
                                clicked.push(key);
                            }
                        }
                    });
                }
            }

            section(ui, "Redes Wi-Fi", "");
            match &wifi {
                None => { ui.label(RichText::new("Buscando tus redes…").color(MUTED)); }
                Some(w) if w.is_empty() => { ui.label(RichText::new("No hay redes Wi-Fi guardadas en este PC.").color(MUTED)); }
                Some(w) => {
                    let names: Vec<&str> = w.iter().take(3).map(|x| x.ssid.as_str()).collect();
                    let more = if w.len() > 3 { format!(" y {} más", w.len() - 3) } else { String::new() };
                    let detail = format!("{}{}", names.join(", "), more);
                    ui.horizontal(|ui| {
                        if choice(ui, cw * 2.0 + 12.0, icons::WIFI, 0.6, &plural(w.len(), "red con su contraseña", "redes con su contraseña"), &detail,
                                  Some(("Las contraseñas quedan legibles en el pendrive: guárdalo bien. Quantum te ofrece borrarlas después.", AMBER)),
                                  self.on("wifi"), true) {
                            clicked.push("wifi".into());
                        }
                    });
                }
            }

            section(ui, "Juegos de Steam", "Funcionan en Quantum sin volver a descargarlos. Pesan mucho: elige solo los que quepan.");
            match &steam {
                None => { ui.label(RichText::new("Buscando tus juegos…").color(MUTED)); }
                Some(g) if g.is_empty() => { ui.label(RichText::new("No encontramos juegos de Steam instalados.").color(MUTED)); }
                Some(games) => {
                    let n_on = games.iter().filter(|g| self.on(&format!("steam:{}", g.appid))).count();
                    let label = if self.show_games { "Ocultar la lista".to_string() } else {
                        format!("Ver {} · {} elegidos", plural(games.len(), "juego", "juegos"), n_on)
                    };
                    if secondary(ui, &label, icons::SPORTS_ESPORTS) { self.show_games = !self.show_games; }
                    if self.show_games {
                        ui.add_space(6.0);
                        for row in games.chunks(cols) {
                            ui.horizontal(|ui| {
                                for (i, g) in row.iter().enumerate() {
                                    let key = format!("steam:{}", g.appid);
                                    if choice(ui, cw, icons::SPORTS_ESPORTS, 0.7 + i as f32 * 0.1, &g.name, &gb(g.bytes), None, self.on(&key), true) {
                                        clicked.push(key);
                                    }
                                }
                            });
                        }
                    }
                }
            }
            ui.add_space(12.0);
            ui.horizontal(|ui| {
                icon(ui, icons::APPS, 20.0, MUTED);
                let n = self.scan.lock().unwrap().apps.len();
                let what = if n == 1 { "tu programa instalado".to_string() } else { format!("tus {n} programas instalados") };
                ui.label(RichText::new(format!("También anotamos {what} para ofrecerte sus versiones en Quantum.")).size(13.5).color(MUTED));
            });
            for k in clicked { self.toggle(&k); }
        });

    }

    /// Pie: cuánto ocupa lo elegido, si cabe, y los botones.
    fn footer(&mut self, ui: &mut egui::Ui) {
        let plan = self.plan();
        let free = self.drive().map(|d| d.free).unwrap_or(0);
        let fits = plan.total <= free;
        {
            ui.horizontal(|ui| {
                ui.vertical(|ui| {
                    ui.set_width((ui.available_width() - 360.0).max(300.0));
                    let measuring = self.scan.lock().unwrap().folders.iter().any(|f| f.bytes.is_none());
                    let chosen = if plan.total == 0 && self.chosen.is_empty() { "Nada elegido".to_string() }
                                 else if plan.total < 1_048_576 { "Menos de 1 MB".to_string() } else { gb(plan.total) };
                    let txt = format!("{chosen}{} · {} libres en el pendrive", if measuring { " (calculando…)" } else { "" }, gb(free));
                    ui.label(RichText::new(txt).size(15.0).family(semi()).color(if fits { TEXT } else { RED }));
                    let (r, _) = ui.allocate_exact_size(Vec2::new(ui.available_width(), 10.0), Sense::hover());
                    ui.painter().rect_filled(r, 5.0, CARD_HI);
                    let k = if free == 0 { 1.0 } else { (plan.total as f64 / free as f64).min(1.0) as f32 };
                    if k > 0.0 {
                        let fill = Rect::from_min_size(r.min, Vec2::new((r.width() * k).max(10.0), r.height()));
                        if fits { pill(ui.painter(), fill, 1.0, 0.0, k); } else { ui.painter().rect_filled(fill, 5.0, RED); }
                    }
                    if !fits {
                        ui.label(RichText::new("No cabe en el pendrive: quita algo o usa uno más grande.").size(13.0).color(RED));
                    }
                });
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    let name = self.drive().map(|d| d.root.to_string_lossy().trim_end_matches(['\\', '/']).to_string()).unwrap_or_default();
                    let any = !self.chosen.is_empty();
                    if primary(ui, &format!("Copiar a {name}"), icons::ARROW_FORWARD, fits && any) { self.start_copy(); }
                    if secondary(ui, "Atrás", icons::ARROW_BACK) { self.step = Step::Welcome; }
                });
            });
        }
    }

    fn copying(&mut self, ui: &mut egui::Ui) {
        let p = self.progress.clone();
        if p.finished.load(Ordering::Relaxed) { self.step = Step::Done; }
        let total = p.total.load(Ordering::Relaxed).max(1);
        let done = p.done.load(Ordering::Relaxed).min(total);
        let k = done as f64 / total as f64;
        ui.add_space(40.0);
        ui.vertical_centered(|ui| {
            let (rect, _) = ui.allocate_exact_size(Vec2::new(200.0, 200.0), Sense::hover());
            let c = rect.center();
            let t = ui.input(|i| i.time) as f32;
            // anillo de avance
            ui.painter().circle_stroke(c, 86.0, Stroke::new(12.0, CARD_HI));
            let n = 120;
            let sweep = (k as f32).max(0.005) * std::f32::consts::TAU;
            let pts: Vec<Pos2> = (0..=n).map(|i| {
                let a = -std::f32::consts::FRAC_PI_2 + sweep * i as f32 / n as f32;
                c + Vec2::new(a.cos(), a.sin()) * 86.0
            }).collect();
            for w in pts.windows(2).enumerate() {
                let (i, seg) = w;
                ui.painter().line_segment([seg[0], seg[1]], Stroke::new(12.0, brand(i as f32 / n as f32)));
            }
            ui.painter().circle_filled(pts[pts.len() - 1], 6.0 + (t * 4.0).sin() * 1.0, Color32::WHITE);
            ui.painter().text(c - Vec2::new(0.0, 8.0), egui::Align2::CENTER_CENTER, format!("{:.0} %", k * 100.0),
                              FontId::new(40.0, bold()), TEXT);
            ui.painter().text(c + Vec2::new(0.0, 28.0), egui::Align2::CENTER_CENTER, "copiado", FontId::new(14.0, FontFamily::Proportional), MUTED);
            ui.add_space(16.0);
            let section = p.section.lock().unwrap().clone();
            ui.label(RichText::new(if section.is_empty() { "Preparando…".to_string() } else { format!("Copiando {section}") })
                .size(24.0).family(bold()));
            let cur = p.current.lock().unwrap().clone();
            ui.label(RichText::new(cur).size(14.0).color(MUTED));
            ui.add_space(8.0);
            let secs = self.started.elapsed().as_secs_f64();
            let eta = if done > 50_000_000 && secs > 5.0 {
                let left = (total - done) as f64 / (done as f64 / secs);
                if left > 3600.0 { format!(" · quedan unas {:.0} h", left / 3600.0) }
                else if left > 90.0 { format!(" · quedan unos {:.0} min", left / 60.0) }
                else { " · queda menos de un minuto".to_string() }
            } else { String::new() };
            ui.label(RichText::new(format!("{} de {}{}", gb(done), gb(total), eta)).size(15.0).family(semi()));
            ui.add_space(26.0);
            ui.label(RichText::new("Puedes seguir usando tu PC. No desconectes el pendrive.").size(13.5).color(MUTED));
            ui.add_space(12.0);
            if secondary(ui, "Cancelar", icons::CLOSE) {
                p.cancel.store(true, Ordering::Relaxed);
            }
        });
    }

    fn done(&mut self, ui: &mut egui::Ui) {
        let p = self.progress.clone();
        let cancelled = p.cancel.load(Ordering::Relaxed);
        let fatal = p.fatal.lock().unwrap().clone();
        let errors = p.errors.lock().unwrap().len();
        let name = self.scan.lock().unwrap().user.1.split_whitespace().next().unwrap_or("").to_string();
        ui.add_space(30.0);
        ui.vertical_centered(|ui| {
            let (rect, _) = ui.allocate_exact_size(Vec2::new(140.0, 140.0), Sense::hover());
            let ok = fatal.is_none() && !cancelled;
            if ok {
                ui.painter().circle_filled(rect.center(), 64.0, GREEN.gamma_multiply(0.18));
                ui.painter().text(rect.center(), egui::Align2::CENTER_CENTER, icons::CHECK_CIRCLE, FontId::new(96.0, icon_font()), GREEN);
            } else {
                ui.painter().circle_filled(rect.center(), 64.0, AMBER.gamma_multiply(0.18));
                ui.painter().text(rect.center(), egui::Align2::CENTER_CENTER, icons::WARNING, FontId::new(84.0, icon_font()), AMBER);
            }
            ui.add_space(8.0);
            let title = if let Some(f) = &fatal { let _ = f; "No se pudo terminar".to_string() }
                        else if cancelled { "Copia cancelada".to_string() }
                        else if name.is_empty() { "¡Listo!".to_string() } else { format!("¡Listo, {name}!") };
            ui.label(RichText::new(title).size(34.0).family(bold()));
            if let Some(f) = &fatal {
                ui.label(RichText::new(f).size(15.0).color(MUTED));
            } else if cancelled {
                ui.label(RichText::new("Lo que alcanzó a copiarse queda en el pendrive. Si vuelves a empezar, sigue desde ahí.").size(15.0).color(MUTED));
            } else {
                ui.label(RichText::new("Tus cosas ya están en el pendrive. Ahora:").size(17.0).color(MUTED));
                ui.add_space(14.0);
                for (i, (g, t)) in [(icons::DOWNLOAD, "Instala Quantum Linux en tu PC"),
                                    (icons::USB, "Entra a tu cuenta y conecta este pendrive"),
                                    (icons::CELEBRATION, "Quantum lo detecta y acomoda todo solo")].iter().enumerate() {
                    ui.allocate_ui_with_layout(Vec2::new(460.0, 48.0), egui::Layout::left_to_right(egui::Align::Center), |ui| {
                        let (r, _) = ui.allocate_exact_size(Vec2::splat(40.0), Sense::hover());
                        badge(ui.painter(), r.center(), 20.0, g, i as f32 / 2.0);
                        ui.label(RichText::new(format!("{}. {t}", i + 1)).size(17.0).family(semi()));
                    });
                }
                if errors > 0 {
                    ui.add_space(10.0);
                    ui.label(RichText::new(format!("{} no se pudieron copiar porque estaban abiertos o protegidos. Si los necesitas, ciérralos y vuelve a abrir esta app: solo copiará lo que falte.",
                        plural(errors, "archivo", "archivos"))).size(13.5).color(AMBER));
                }
            }
            ui.add_space(24.0);
            ui.horizontal(|ui| {
                let w = 220.0 + 240.0;
                ui.add_space((ui.available_width() - w).max(0.0) / 2.0);
                if let Some(d) = self.drive().cloned() {
                    if secondary(ui, "Ver en el pendrive", icons::FOLDER_OPEN) { export::open_result(&d); }
                }
                if fatal.is_some() || cancelled {
                    if primary(ui, "Volver a intentar", icons::ARROW_FORWARD, true) { self.step = Step::Choose; }
                } else if primary(ui, "Cerrar", "", true) {
                    ui.ctx().send_viewport_cmd(egui::ViewportCommand::Close);
                }
            });
        });
    }
}

fn main() -> eframe::Result {
    let icon = image::load_from_memory(include_bytes!("../assets/logo.png")).ok().map(|i| {
        let i = i.to_rgba8();
        Arc::new(egui::IconData { width: i.width(), height: i.height(), rgba: i.into_raw() })
    });
    let mut vp = egui::ViewportBuilder::default().with_inner_size([1040.0, 720.0]).with_min_inner_size([900.0, 640.0])
        .with_title("Pasar a Quantum");
    if let Some(i) = icon { vp = vp.with_icon(i); }
    // DirectX 12 en Windows (si no hay tarjeta gráfica, Windows usa WARP, su render por software);
    // OpenGL no sirve: sin drivers solo hay OpenGL 1.1
    let mut wgpu_options = eframe::egui_wgpu::WgpuConfiguration::default();
    if cfg!(windows) {
        if let eframe::egui_wgpu::WgpuSetup::CreateNew(ref mut c) = wgpu_options.wgpu_setup {
            c.instance_descriptor.backends = eframe::wgpu::Backends::DX12;
            c.power_preference = eframe::wgpu::PowerPreference::LowPower;
        }
    }
    let options = eframe::NativeOptions { viewport: vp, renderer: eframe::Renderer::Wgpu, wgpu_options, ..Default::default() };
    eframe::run_native("Pasar a Quantum", options, Box::new(|cc| Ok(Box::new(App::new(cc)))))
}
