//! «Instalar Quantum Linux»: instala Quantum desde Windows sin entrar a la BIOS.
//! Pregunta todo aquí (pendrive, cómo instalar, cuenta, apps, tus cosas), prepara el pendrive,
//! descarga Quantum, hace espacio y reinicia: el pendrive instala solo (ver quantum-installer).
#![cfg_attr(windows, windows_subsystem = "windows")]
#![allow(float_literal_f32_fallback)]

mod export;
#[allow(dead_code)]
mod icons;
mod platform;
mod setup;
mod ui;

use eframe::egui::{self, Color32, FontFamily, FontId, Margin, Pos2, Rect, RichText, Sense, Stroke, StrokeKind, Vec2};
use serde_json::json;
use setup::{Disk, PcInfo, GB};
use std::collections::HashSet;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;
use ui::*;

// ------------------------------------------------------------- catálogo de apps
struct AppOpt { id: &'static str, name: &'static str, note: &'static str, kind: &'static str, win: &'static [&'static str] }
const fn a(id: &'static str, name: &'static str, note: &'static str, kind: &'static str, win: &'static [&'static str]) -> AppOpt {
    AppOpt { id, name, note, kind, win }
}
// kind: app (Flathub) · game (Flathub) · steam (Steam) · ai (Ollama)
const SECTIONS: &[(&str, &str, &[AppOpt])] = &[
    ("Navegador", "Firefox ya viene incluido.", &[
        a("com.google.Chrome", "Google Chrome", "El de Google", "app", &["chrome"]),
        a("com.brave.Browser", "Brave", "Bloquea anuncios", "app", &["brave"]),
        a("com.opera.Opera", "Opera", "Con VPN gratis", "app", &["opera"]),
        a("com.microsoft.Edge", "Microsoft Edge", "El de Windows", "app", &[]),
    ]),
    ("Para el día a día", "", &[
        a("org.libreoffice.LibreOffice", "LibreOffice", "Abre archivos de Office", "app", &["office", "word", "excel"]),
        a("com.discordapp.Discord", "Discord", "Chat con tus amigos", "app", &["discord"]),
        a("com.spotify.Client", "Spotify", "Música", "app", &["spotify"]),
        a("com.obsproject.Studio", "OBS Studio", "Graba y transmite", "app", &["obs studio"]),
        a("org.videolan.VLC", "VLC", "Cualquier video", "app", &["vlc"]),
        a("org.telegram.desktop", "Telegram", "Mensajería", "app", &["telegram"]),
    ]),
    ("Juegos gratis", "Los de Steam te piden iniciar sesión (la cuenta es gratis).", &[
        a("org.vinegarhq.Sober", "Roblox", "Con tu cuenta de Roblox", "game", &["roblox"]),
        a("org.prismlauncher.PrismLauncher", "Minecraft", "Con tu cuenta de Minecraft", "game", &["minecraft"]),
        a("cs2", "Counter-Strike 2", "Steam", "steam", &[]),
        a("marvel-rivals", "Marvel Rivals", "Steam", "steam", &[]),
        a("efootball", "eFootball", "Steam", "steam", &[]),
        a("net.supertuxkart.SuperTuxKart", "SuperTuxKart", "Para PCs modestas", "game", &[]),
        a("com.heroicgameslauncher.hgl", "Epic Games y GOG", "Con Heroic", "app", &["epic games", "gog galaxy"]),
    ]),
    ("Emuladores", "", &[
        a("org.DolphinEmu.dolphin-emu", "Dolphin", "Wii y GameCube", "app", &["dolphin"]),
        a("org.ppsspp.PPSSPP", "PPSSPP", "PSP", "app", &["ppsspp"]),
        a("net.pcsx2.PCSX2", "PCSX2", "PlayStation 2", "app", &["pcsx2"]),
        a("org.libretro.RetroArch", "RetroArch", "Todas las retro", "app", &["retroarch"]),
    ]),
    ("Asistente con IA", "Funciona en tu PC, sin internet ni cuentas.", &[
        a("gemma3:1b", "IA ligera", "Para 4 GB de RAM", "ai", &[]),
        a("gemma3:4b", "IA equilibrada", "Para 8 GB de RAM", "ai", &[]),
    ]),
];

#[derive(PartialEq, Clone, Copy)]
enum Step { Welcome, Usb, Mode, Account, Apps, Things, Summary, Work, Done }

#[derive(Clone, PartialEq)]
enum Mode { Beside, Wipe(u32) }

#[derive(Default)]
struct WorkState {
    step: usize,          // índice en WORK
    frac: f32,
    detail: String,
    error: Option<String>,
    done: bool,
}
const WORK: [&str; 7] = ["Descargando Quantum Linux", "Preparando el pendrive", "Copiando Quantum al pendrive",
                         "Copiando tus cosas de Windows", "Guardando tus respuestas", "Haciendo espacio para Quantum",
                         "Preparando el reinicio"];

struct App {
    step: Step,
    pc: Arc<Mutex<Option<PcInfo>>>,
    drives: Vec<platform::Drive>,
    usb: Option<u32>,          // número de disco del pendrive
    mode: Option<Mode>,
    name: String,
    login: String,
    login_edited: bool,
    pw1: String,
    pw2: String,
    autologin: bool,
    chosen: HashSet<&'static str>,
    things: bool,
    things_size: Arc<Mutex<Option<u64>>>,
    work: Arc<Mutex<WorkState>>,
    cancel: Arc<AtomicBool>,
    logo: egui::TextureHandle,
    confirm_wipe: bool,
    room: Arc<Mutex<u8>>,      // «Hacer espacio»: 0 sin empezar, 1 trabajando, 2 listo
}

impl App {
    fn new(cc: &eframe::CreationContext) -> Self {
        setup_style(&cc.egui_ctx);
        let logo = load_png(&cc.egui_ctx, "logo", include_bytes!("../assets/logo.png"));
        let pc = Arc::new(Mutex::new(None));
        { let pc = pc.clone(); std::thread::spawn(move || { let i = setup::pc_info(); *pc.lock().unwrap() = Some(i); }); }
        let (_, name) = platform::user();
        // apps que ya usabas en Windows, marcadas desde el principio
        let installed: Vec<String> = platform::installed_apps().iter().map(|s| s.to_lowercase()).collect();
        let mut chosen = HashSet::new();
        for (_, _, opts) in SECTIONS {
            for o in opts.iter() {
                if o.win.iter().any(|w| installed.iter().any(|i| i.contains(w))) { chosen.insert(o.id); }
            }
        }
        let things_size = Arc::new(Mutex::new(None));
        {
            let ts = things_size.clone();
            std::thread::spawn(move || {
                let stop = AtomicBool::new(false);
                let total: u64 = platform::known_folders().iter().map(|(_, _, p)| export::measure(p, &stop).0).sum();
                *ts.lock().unwrap() = Some(total);
            });
        }
        let login = setup::login_from(&name);
        App {
            step: Step::Welcome, pc, drives: vec![], usb: None, mode: None, name, login, login_edited: false,
            pw1: String::new(), pw2: String::new(), autologin: false, chosen, things: true, things_size,
            work: Arc::new(Mutex::new(WorkState::default())), cancel: Arc::new(AtomicBool::new(false)), logo, confirm_wipe: false,
            room: Arc::new(Mutex::new(0)),
        }
    }

    fn pc(&self) -> Option<PcInfo> { self.pc.lock().unwrap().clone() }

    fn usb_disks(&self) -> Vec<Disk> {
        self.pc().map(|p| p.disks.into_iter().filter(|d| d.usb && !d.system).collect()).unwrap_or_default()
    }

    /// Lo que bloquea instalar (PC sin UEFI, sin espacio…)
    fn blocker(&self) -> Option<String> {
        let pc = self.pc()?;
        if !pc.uefi {
            return Some("Tu PC arranca en modo antiguo (BIOS). Para instalar Quantum, descarga el ISO y grábalo en un pendrive con Rufus o Ventoy.".into());
        }
        None
    }

    fn start(&mut self) {
        let pc = self.pc().unwrap();
        let usb = self.usb_disks().into_iter().find(|d| Some(d.number) == self.usb).unwrap();
        let mode = self.mode.clone().unwrap();
        let (target, qsize) = match &mode {
            Mode::Beside => (pc.system_disk().cloned().unwrap(), pc.beside_size()),
            Mode::Wipe(n) => (pc.disks.iter().find(|d| d.number == *n).cloned().unwrap(), 0),
        };
        let st = platform::settings();
        let mut apps = vec![]; let mut games = vec![]; let mut steam = vec![]; let mut ai = String::new();
        for (_, _, opts) in SECTIONS {
            for o in opts.iter().filter(|o| self.chosen.contains(o.id)) {
                match o.kind { "app" => apps.push(json!([o.id, o.name])), "game" => games.push(json!([o.id, o.name])),
                               "steam" => steam.push(json!([o.id, o.name])), _ => ai = o.id.to_string() }
            }
        }
        let host = format!("{}-quantum", self.login);
        let answers = json!({
            "format": 1,
            "mode": if mode == Mode::Beside { "free" } else { "wipe" },
            "disk": { "size": target.size, "serial": target.serial, "model": target.name },
            "minFree": qsize * 9 / 10,
            "user": { "name": self.name.trim(), "login": self.login, "password": setup::hash_password(&self.pw1), "autologin": self.autologin },
            "hostname": host,
            "locale": format!("{}.UTF-8", if st.locale.is_empty() { "es_CL".into() } else { st.locale.replace('-', "_") }),
            "timezone": setup::tz_linux(&st.timezone),
            "keyboard": { "layout": setup::kb_linux(st.keyboards.first().map(|s| s.as_str()).unwrap_or("")), "variant": "" },
            "apps": apps, "games": games, "steamGames": steam, "ai": ai,
            "secureboot": { "enabled": pc.secureboot, "mokPassword": "quantum" },
            "migrate": self.things,
        });
        let work = self.work.clone();
        let cancel = self.cancel.clone();
        let things = self.things;
        let bitlocker = pc.bitlocker;
        let shrink = !pc.uses_unallocated();
        let secureboot = pc.secureboot;
        let computer = platform::computer();
        std::thread::spawn(move || {
            let set = |i: usize, f: f32, d: &str| { let mut w = work.lock().unwrap(); w.step = i; w.frac = f; w.detail = d.to_string(); };
            let fail = |e: String| { work.lock().unwrap().error = Some(e); };
            // 1. descargar (o usar un ISO que esté junto al .exe)
            set(0, 0.0, "Buscando la versión más nueva…");
            let local = std::env::var("QUANTUM_ISO").ok().map(PathBuf::from).filter(|p| p.is_file()).or_else(|| {
                let dir = std::env::current_exe().ok()?.parent()?.to_path_buf();
                std::fs::read_dir(dir).ok()?.flatten().map(|e| e.path())
                    .find(|p| p.extension().is_some_and(|x| x.eq_ignore_ascii_case("iso")) && p.to_string_lossy().to_lowercase().contains("quantum"))
            });
            let iso = match local {
                Some(p) => p,
                None => {
                    let l = match setup::latest() { Ok(l) => l, Err(e) => return fail(format!("No pude conectarme a la página de Quantum: {e}")) };
                    let dst = std::env::temp_dir().join("quantum").join(format!("quantumlinux-{}.iso", l.version));
                    let r = setup::download(&l, &dst, &cancel, &|h, t| set(0, if t > 0 { h as f32 / t as f32 } else { 0.0 },
                        &format!("{} de {}", gb(h), gb(t))), &|m| set(0, 0.0, m));
                    if let Err(e) = r { return fail(e); }
                    dst
                }
            };
            // 2. pendrive
            set(1, 0.2, "Borrando y dando formato al pendrive…");
            let (boot, data) = match setup::prepare_usb(&usb) { Ok(x) => x, Err(e) => return fail(e) };
            // 3. copiar Quantum
            set(2, 0.0, "Abriendo el archivo de Quantum…");
            let src = match setup::mount_iso(&iso) { Ok(s) => s, Err(e) => return fail(format!("No pude abrir el ISO: {e}")) };
            let r = setup::copy_tree(&src, &PathBuf::from(&boot), &|h, t| set(2, h as f32 / t.max(1) as f32, &format!("{} de {}", gb(h), gb(t))));
            setup::unmount_iso(&iso);
            if let Err(e) = r { return fail(format!("No pude copiar Quantum al pendrive: {e}")); }
            // 4. tus cosas (con «Pasar a Quantum»)
            if things {
                set(3, 0.0, "Revisando tus archivos…");
                let drive = platform::Drive { root: PathBuf::from(data.clone().unwrap_or(boot.clone())), label: "QUANTUMDATA".into(),
                                              fs: "exFAT".into(), free: 0, total: 0, removable: true };
                let plan = export::Plan {
                    folders: platform::known_folders().into_iter().map(|(key, title, path)| export::FolderItem { key, title, path }).collect(),
                    account: true, browsers: platform::browsers(), wifi: platform::wifi(), steam: vec![],
                    apps: platform::installed_apps(), settings: platform::settings(), user: platform::user(),
                    computer: computer.clone(), picture: platform::account_picture(), wallpaper: platform::wallpaper(),
                    total: platform::known_folders().iter().map(|(_, _, p)| export::measure(p, &AtomicBool::new(false)).0).sum(),
                };
                let p = Arc::new(export::Progress::default());
                let p2 = p.clone();
                let h = std::thread::spawn(move || export::run(plan, drive, p2));
                while !h.is_finished() {
                    let t = p.total.load(Ordering::Relaxed).max(1); let d = p.done.load(Ordering::Relaxed);
                    set(3, d as f32 / t as f32, &p.section.lock().unwrap().clone());
                    std::thread::sleep(Duration::from_millis(200));
                }
                let fatal = p.fatal.lock().unwrap().clone();
                if let Some(e) = fatal { return fail(e); }
            }
            // 5. respuestas y llave de este PC
            set(4, 0.3, "Creando la llave de arranque seguro de este PC…");
            let dir = PathBuf::from(&boot).join("quantum-install");
            let _ = std::fs::create_dir_all(&dir);
            // por si el firmware no muestra «Enroll MOK»: la llave de Quantum queda en el pendrive para «Enroll key from disk»
            let _ = std::fs::write(dir.join("quantum.cer"), setup::QUANTUM_CER);
            let mok = if secureboot { match setup::machine_key(&dir, &computer) { Ok(c) => Some(c), Err(e) => return fail(format!("No pude crear la llave: {e}")) } } else { None };
            if let Err(e) = std::fs::write(dir.join("answers.json"), serde_json::to_vec_pretty(&answers).unwrap()) { return fail(e.to_string()); }
            // 6. espacio
            if mode == Mode::Beside && shrink {
                set(5, 0.2, "Achicando Windows (tus archivos no se tocan)…");
                if bitlocker { if let Err(e) = setup::suspend_bitlocker() { return fail(format!("No pude pausar BitLocker: {e}")); } }
                if let Err(e) = setup::shrink_c(qsize) { return fail(format!("Windows no dejó achicar el disco: {e}")); }
            }
            // 7. arranque
            set(6, 0.3, "Dejando todo listo para arrancar del pendrive…");
            if let Some(c) = mok {
                if let Err(e) = setup::request_mok(&[setup::QUANTUM_CER.to_vec(), c], "quantum") { return fail(e); }
            }
            let _ = setup::boot_next_usb(&boot);   // si el firmware no lo acepta, se elige el pendrive a mano
            let mut w = work.lock().unwrap(); w.step = 7; w.done = true;
        });
        self.step = Step::Work;
    }
}

fn header(ui: &mut egui::Ui, logo: &egui::TextureHandle, step: Step) {
    ui.horizontal(|ui| {
        ui.add(egui::Image::new(logo).fit_to_exact_size(Vec2::splat(34.0)));
        ui.label(RichText::new("Instalar Quantum Linux").size(18.0).family(bold()));
        let (r, _) = ui.allocate_exact_size(Vec2::new(46.0, 22.0), Sense::hover());
        ui.painter().rect_filled(r, 11.0, AMBER.gamma_multiply(0.2));
        ui.painter().text(r.center(), egui::Align2::CENTER_CENTER, "BETA", FontId::new(11.0, bold()), AMBER);
        let names = ["Pendrive", "Cómo", "Cuenta", "Apps", "Tus cosas", "Listo"];
        let cur = match step { Step::Welcome => 0, Step::Usb => 0, Step::Mode => 1, Step::Account => 2, Step::Apps => 3,
                               Step::Things | Step::Summary => 4, Step::Work | Step::Done => 5 };
        ui.add_space((ui.available_width() - 620.0).max(0.0));
        if step != Step::Welcome {
            for (i, n) in names.iter().enumerate() {
                let (r, _) = ui.allocate_exact_size(Vec2::new(22.0, 22.0), Sense::hover());
                let c = r.center();
                if i < cur { ui.painter().circle_filled(c, 10.0, INDIGO); ui.painter().text(c, egui::Align2::CENTER_CENTER, icons::CHECK, FontId::new(14.0, icon_font()), Color32::WHITE); }
                else if i == cur { ui.painter().circle_filled(c, 10.0, brand(i as f32 / 5.0)); ui.painter().text(c, egui::Align2::CENTER_CENTER, (i + 1).to_string(), FontId::new(11.0, bold()), Color32::WHITE); }
                else { ui.painter().circle_stroke(c, 9.0, Stroke::new(1.5, LINE)); ui.painter().text(c, egui::Align2::CENTER_CENTER, (i + 1).to_string(), FontId::new(11.0, semi()), MUTED); }
                ui.label(RichText::new(*n).size(13.0).color(if i <= cur { TEXT } else { MUTED }));
                if i < names.len() - 1 { ui.add_space(4.0); }
            }
        }
    });
}

fn field(ui: &mut egui::Ui, label: &str, value: &mut String, password: bool, hint: &str) -> bool {
    ui.label(RichText::new(label).size(14.0).family(semi()));
    let r = egui::Frame::new().fill(CARD).corner_radius(14).stroke(Stroke::new(1.0, LINE)).inner_margin(Margin::symmetric(14, 10)).show(ui, |ui| {
        ui.add(egui::TextEdit::singleline(value).password(password).hint_text(hint).font(FontId::new(16.0, FontFamily::Proportional))
               .frame(false).desired_width(ui.available_width()))
    }).inner;
    r.changed()
}

impl eframe::App for App {
    fn update(&mut self, ctx: &egui::Context, _f: &mut eframe::Frame) {
        ctx.request_repaint_after(Duration::from_millis(if self.step == Step::Work { 100 } else { 400 }));
        if self.step == Step::Work && self.work.lock().unwrap().done { self.step = Step::Done; }
        // pie con los botones
        let (can_next, next_label): (bool, &str) = match self.step {
            Step::Welcome => (self.pc().is_some() && self.blocker().is_none(), "Empezar"),
            Step::Usb => (self.usb.is_some(), "Siguiente"),
            Step::Mode => (self.mode.is_some() && (self.mode != Some(Mode::Wipe(0)) || true), "Siguiente"),
            Step::Account => (!self.name.trim().is_empty() && !self.login.is_empty() && self.pw1.len() >= 4 && self.pw1 == self.pw2, "Siguiente"),
            Step::Apps | Step::Things => (true, "Siguiente"),
            Step::Summary => (!matches!(self.mode, Some(Mode::Wipe(_))) || self.confirm_wipe, "Instalar Quantum"),
            _ => (false, ""),
        };
        if !matches!(self.step, Step::Work | Step::Done) {
            egui::TopBottomPanel::bottom("pie").frame(egui::Frame::new().fill(BG).inner_margin(Margin { left: 40, right: 40, top: 12, bottom: 20 }))
                .show_separator_line(false).show(ctx, |ui| {
                    ui.horizontal(|ui| {
                        if self.step == Step::Welcome {
                            ui.label(RichText::new("Respalda antes tus archivos importantes: es una versión beta.").size(13.0).color(MUTED));
                        }
                        ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                            if primary(ui, next_label, if self.step == Step::Summary { icons::DOWNLOAD } else { icons::ARROW_FORWARD }, can_next) {
                                self.step = match self.step {
                                    Step::Welcome => Step::Usb, Step::Usb => Step::Mode, Step::Mode => Step::Account,
                                    Step::Account => Step::Apps, Step::Apps => Step::Things, Step::Things => Step::Summary,
                                    s => s,
                                };
                                if self.step == Step::Summary && next_label == "Instalar Quantum" { self.start(); }
                            }
                            if self.step != Step::Welcome && secondary(ui, "Atrás", icons::ARROW_BACK) {
                                self.step = match self.step {
                                    Step::Usb => Step::Welcome, Step::Mode => Step::Usb, Step::Account => Step::Mode, Step::Apps => Step::Account,
                                    Step::Things => Step::Apps, Step::Summary => Step::Things, s => s,
                                };
                            }
                        });
                    });
                });
        }
        egui::CentralPanel::default().frame(egui::Frame::new().fill(BG).inner_margin(Margin::symmetric(40, 26))).show(ctx, |ui| {
            header(ui, &self.logo, self.step);
            ui.add_space(14.0);
            match self.step {
                Step::Welcome => self.welcome(ui),
                Step::Usb => self.usb_page(ui),
                Step::Mode => self.mode_page(ui),
                Step::Account => self.account(ui),
                Step::Apps => self.apps(ui),
                Step::Things => self.things_page(ui),
                Step::Summary => self.summary(ui),
                Step::Work => self.work_page(ui),
                Step::Done => self.done(ui),
            }
        });
    }
}

impl App {
    fn welcome(&mut self, ui: &mut egui::Ui) {
        let first = self.name.split_whitespace().next().unwrap_or("").to_string();
        ui.add_space(20.0);
        ui.horizontal(|ui| {
            ui.vertical(|ui| {
                ui.set_width((ui.available_width() - 300.0).max(420.0));
                ui.label(RichText::new(if first.is_empty() { "¡Hola!".to_string() } else { format!("¡Hola, {first}!") }).size(18.0).family(semi()).color(LILAC));
                ui.label(RichText::new("Instala Quantum Linux\nsin complicarte").size(38.0).family(bold()));
                ui.add_space(4.0);
                ui.label(RichText::new("Respondes unas preguntas, conectas un pendrive y Quantum se instala solo. No hace falta entrar a la BIOS ni saber de computadores.").size(16.0).color(MUTED));
                ui.add_space(14.0);
                for (g, t, title, d) in [
                    (icons::USB, 0.0, "Un pendrive de 8 GB o más", "Se borra: usa uno sin cosas importantes."),
                    (icons::DESKTOP_WINDOWS, 0.45, "Junto a Windows o en su lugar", "Tú eliges. Si lo dejas, al encender eliges cuál usar."),
                    (icons::FOLDER, 0.9, "Llévate tus cosas", "Tus archivos, tu foto, tu fondo y tus redes Wi-Fi."),
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
                ui.add_space(14.0);
                match (self.pc(), self.blocker()) {
                    (None, _) => { ui.horizontal(|ui| { ui.spinner(); ui.label(RichText::new("Revisando tu PC…").color(MUTED)); }); }
                    (Some(_), Some(b)) => { ui.label(RichText::new(b).size(14.0).color(AMBER)); }
                    (Some(p), None) => {
                        let ram = p.ram / GB;
                        ui.label(RichText::new(format!("Tu PC está listo: {} GB de RAM · {}", ram,
                            if p.secureboot { "arranque seguro activo" } else { "arranque seguro desactivado" })).size(13.5).color(GREEN));
                    }
                }
            });
            let (rect, _) = ui.allocate_exact_size(Vec2::new(280.0, 420.0), Sense::hover());
            let c = rect.center();
            let t = ui.input(|i| i.time) as f32;
            for k in 0..3 {
                let r = 120.0 + k as f32 * 16.0 + (t * 1.2 + k as f32).sin() * 3.0;
                ui.painter().circle_stroke(c, r, Stroke::new(1.5, brand(k as f32 / 2.0).gamma_multiply(0.35)));
            }
            ui.painter().circle_filled(c, 108.0, INDIGO.gamma_multiply(0.12));
            ui.painter().image(self.logo.id(), Rect::from_center_size(c, Vec2::splat(170.0)), Rect::from_min_max(Pos2::ZERO, Pos2::new(1.0, 1.0)), Color32::WHITE);
            ui.ctx().request_repaint_after(Duration::from_millis(33));
        });
    }

    fn usb_page(&mut self, ui: &mut egui::Ui) {
        ui.label(RichText::new("Conecta un pendrive").size(28.0).family(bold()));
        ui.label(RichText::new("De 8 GB o más. Se borra todo lo que tenga y ahí se prepara Quantum (y tus cosas, si las llevas).").size(15.0).color(MUTED));
        ui.add_space(12.0);
        // se vuelve a revisar cada pocos segundos por si lo conectan ahora
        if ui.input(|i| i.time) as u64 % 3 == 0 && !self.pc.lock().unwrap().is_none() {
            let pc = self.pc.clone();
            static BUSY: AtomicBool = AtomicBool::new(false);
            if !BUSY.swap(true, Ordering::Relaxed) {
                std::thread::spawn(move || { let i = setup::pc_info(); *pc.lock().unwrap() = Some(i); std::thread::sleep(Duration::from_secs(2)); BUSY.store(false, Ordering::Relaxed); });
            }
        }
        let disks = self.usb_disks();
        if disks.is_empty() {
            ui.horizontal(|ui| { ui.spinner(); ui.label(RichText::new("Esperando un pendrive…").size(16.0).color(MUTED)); });
        }
        let w = ui.available_width().min(760.0);
        for d in disks {
            let ok = d.size >= setup::MIN_USB;
            let on = self.usb == Some(d.number);
            let detail = if ok { format!("{} · se borrará todo lo que tiene", gb(d.size)) } else { format!("{} · es muy chico (mínimo 8 GB)", gb(d.size)) };
            if choice(ui, w, icons::USB, 0.3, if d.name.is_empty() { "Pendrive" } else { &d.name }, &detail, None, on, ok) { self.usb = Some(d.number); }
        }
    }

    fn mode_page(&mut self, ui: &mut egui::Ui) {
        let Some(pc) = self.pc() else { return };
        ui.label(RichText::new("¿Cómo quieres instalar Quantum?").size(28.0).family(bold()));
        ui.add_space(10.0);
        let w = ui.available_width().min(820.0);
        let size = pc.beside_size();
        let sys = pc.system_disk().cloned();
        if let Some(sd) = &sys {
            let ok = size >= setup::MIN_QUANTUM && sd.gpt;
            let detail = if ok && pc.uses_unallocated() { format!("Quantum usará {} de espacio sin usar del disco. Windows queda igual. Al encender eliges cuál usar.", gb(size)) }
                         else if ok { format!("Quantum usará {} y Windows se queda con el resto. Al encender eliges cuál usar.", gb(size)) }
                         else if !sd.gpt { "Tu disco usa el formato antiguo (MBR). Para instalar junto a Windows, usa el ISO.".to_string() }
                         else if pc.shrink_limited() {
                             format!("Tienes {} libres, pero Windows solo deja usar {}: algunos de sus archivos (hibernación, paginación) están al final del disco.",
                                     gb(pc.c_free), gb(size))
                         }
                         else { format!("No hay espacio suficiente: Quantum necesita al menos {} libres en Windows.", gb(2 * setup::MIN_QUANTUM)) };
            if choice(ui, w, icons::DESKTOP_WINDOWS, 0.1, "Junto a Windows (recomendado)", &detail,
                      ok.then_some(("No se borra nada de Windows: solo se usa espacio libre.", GREEN)), self.mode == Some(Mode::Beside), ok) {
                self.mode = Some(Mode::Beside);
            }
            // cuando Windows no deja achicar: botón para ordenar el disco y volver a medir
            if !ok && sd.gpt && pc.shrink_limited() {
                let st = *self.room.lock().unwrap();
                ui.horizontal(|ui| {
                    ui.add_space(20.0);
                    match st {
                        1 => { ui.spinner(); ui.label(RichText::new("Ordenando el disco de Windows… puede tardar varios minutos. No apagues el PC.").size(14.0).color(MUTED)); }
                        2 => { ui.label(RichText::new("Listo. Si sigue sin alcanzar, reinicia Windows y vuelve a abrir el instalador.").size(14.0).color(MUTED)); }
                        _ => {
                            if secondary(ui, "Hacer espacio", icons::BOLT) {
                                *self.room.lock().unwrap() = 1;
                                let (room, pcs) = (self.room.clone(), self.pc.clone());
                                std::thread::spawn(move || {
                                    let r = setup::make_room();
                                    setup::log(&format!("make_room: {r:?}"));
                                    let i = setup::pc_info();
                                    *pcs.lock().unwrap() = Some(i);
                                    *room.lock().unwrap() = 2;
                                });
                            }
                            ui.label(RichText::new("Apaga la hibernación y junta el espacio libre. No borra nada.").size(13.5).color(MUTED));
                        }
                    }
                });
            }
            ui.add_space(6.0);
            if choice(ui, w, icons::WARNING, 0.9, "Reemplazar Windows",
                      &format!("Quantum ocupa todo el disco ({}). Windows y todo lo que tiene se borran.", gb(sd.size)),
                      Some(("Si eliges «Llévate tus cosas», tus archivos se guardan antes en el pendrive.", AMBER)),
                      self.mode == Some(Mode::Wipe(sd.number)), true) {
                self.mode = Some(Mode::Wipe(sd.number)); self.confirm_wipe = false;
            }
        }
        for d in pc.disks.iter().filter(|d| !d.system && !d.usb && d.size >= 40 * GB) {
            ui.add_space(6.0);
            if choice(ui, w, icons::HARD_DRIVE, 0.5, &format!("En el disco {}", d.name), &format!("{} · se borra todo lo que tiene ese disco. Windows no se toca.", gb(d.size)),
                      None, self.mode == Some(Mode::Wipe(d.number)), true) {
                self.mode = Some(Mode::Wipe(d.number)); self.confirm_wipe = false;
            }
        }
    }

    fn account(&mut self, ui: &mut egui::Ui) {
        ui.label(RichText::new("Tu cuenta en Quantum").size(28.0).family(bold()));
        ui.label(RichText::new("Con esto entras a Quantum. Usa una contraseña que recuerdes.").size(15.0).color(MUTED));
        ui.add_space(12.0);
        ui.set_max_width(560.0);
        if field(ui, "Tu nombre", &mut self.name, false, "Por ejemplo: Juan Pérez") && !self.login_edited {
            self.login = setup::login_from(&self.name);
        }
        ui.add_space(6.0);
        if field(ui, "Nombre de usuario", &mut self.login, false, "juan") {
            self.login_edited = true;
            self.login = self.login.to_lowercase().chars().filter(|c| c.is_ascii_alphanumeric() || *c == '_' || *c == '-').collect();
        }
        ui.add_space(6.0);
        field(ui, "Contraseña", &mut self.pw1, true, "Mínimo 4 caracteres");
        ui.add_space(6.0);
        field(ui, "Repite la contraseña", &mut self.pw2, true, "");
        if !self.pw2.is_empty() && self.pw1 != self.pw2 { ui.label(RichText::new("Las contraseñas no coinciden").size(13.0).color(RED)); }
        ui.add_space(10.0);
        ui.checkbox(&mut self.autologin, RichText::new("Entrar sin pedir la contraseña al encender").size(14.5));
    }

    fn apps(&mut self, ui: &mut egui::Ui) {
        ui.label(RichText::new("Tus apps y juegos").size(28.0).family(bold()));
        ui.label(RichText::new("Ya marcamos las que usabas en Windows. Se instalan solas al entrar a Quantum por primera vez.").size(15.0).color(MUTED));
        egui::ScrollArea::vertical().auto_shrink([false, false]).show(ui, |ui| {
            let w = ui.available_width();
            let cols = if w > 900.0 { 3 } else { 2 };
            let cw = (w - 12.0 * (cols as f32 - 1.0)) / cols as f32 - 1.0;
            for (i, (title, hint, opts)) in SECTIONS.iter().enumerate() {
                section(ui, title, hint);
                for row in opts.chunks(cols) {
                    ui.horizontal(|ui| {
                        for (j, o) in row.iter().enumerate() {
                            let on = self.chosen.contains(o.id);
                            let glyph = match o.kind { "steam" | "game" => icons::SPORTS_ESPORTS, "ai" => icons::BOLT, _ => icons::APPS };
                            if choice(ui, cw, glyph, (i as f32 + j as f32 * 0.3) / 5.0, o.name, o.note, None, on, true) {
                                if on { self.chosen.remove(o.id); } else {
                                    if o.kind == "ai" { for x in opts.iter() { self.chosen.remove(x.id); } }
                                    self.chosen.insert(o.id);
                                }
                            }
                        }
                    });
                }
            }
        });
    }

    fn things_page(&mut self, ui: &mut egui::Ui) {
        ui.label(RichText::new("¿Te llevas tus cosas de Windows?").size(28.0).family(bold()));
        ui.label(RichText::new("Se copian al pendrive y Quantum las deja en su lugar. En Windows no se borra nada.").size(15.0).color(MUTED));
        ui.add_space(12.0);
        let w = ui.available_width().min(820.0);
        let size = *self.things_size.lock().unwrap();
        let detail = match size { Some(s) => format!("Escritorio, Documentos, Imágenes, Música, Videos y Descargas · {}", gb(s)), None => "Calculando…".into() };
        let usb = self.usb_disks().into_iter().find(|d| Some(d.number) == self.usb);
        let room = usb.map(|u| u.size.saturating_sub(8 * GB)).unwrap_or(0);
        let fits = size.is_none_or(|s| s <= room);
        if choice(ui, w, icons::FOLDER, 0.0, "Sí, llevar mis cosas", &detail,
                  (!fits).then_some(("No caben en el pendrive: usa uno más grande o no las lleves.", RED)), self.things, true) { self.things = true; }
        ui.add_space(6.0);
        ui.label(RichText::new("   También se llevan tu foto de cuenta, tu fondo, tu teclado, tus favoritos y tus redes Wi-Fi.").size(13.5).color(MUTED));
        ui.add_space(6.0);
        if choice(ui, w, icons::CLOSE, 0.6, "No, empezar de cero", "Podrás traerlas después con «Pasar a Quantum».", None, !self.things, true) { self.things = false; }
    }

    fn summary(&mut self, ui: &mut egui::Ui) {
        let Some(pc) = self.pc() else { return };
        ui.label(RichText::new("Todo listo para instalar").size(28.0).family(bold()));
        ui.add_space(10.0);
        let usb = self.usb_disks().into_iter().find(|d| Some(d.number) == self.usb).map(|d| d.name).unwrap_or_default();
        let how = match &self.mode {
            Some(Mode::Beside) => format!("Junto a Windows · Quantum usará {}", gb(pc.beside_size())),
            Some(Mode::Wipe(n)) => format!("Borrando el disco {}", pc.disks.iter().find(|d| d.number == *n).map(|d| d.name.clone()).unwrap_or_default()),
            None => String::new(),
        };
        let n_apps = self.chosen.len();
        for (g, t, v) in [(icons::USB, "Pendrive", format!("{usb} (se borra)")), (icons::DESKTOP_WINDOWS, "Instalación", how),
                          (icons::ACCOUNT_CIRCLE, "Cuenta", format!("{} ({})", self.name.trim(), self.login)),
                          (icons::APPS, "Apps y juegos", plural(n_apps, "elegida", "elegidas")),
                          (icons::FOLDER, "Tus cosas de Windows", if self.things { "Se llevan".into() } else { "No".into() })] {
            ui.horizontal(|ui| {
                icon(ui, g, 22.0, LILAC);
                ui.label(RichText::new(t).size(15.0).color(MUTED));
                ui.label(RichText::new(v).size(15.0).family(semi()));
            });
        }
        ui.add_space(12.0);
        ui.label(RichText::new("Primero se descarga Quantum (3,7 GB). Después el PC se reinicia solo y la instalación sigue sin que hagas nada, salvo una confirmación en una pantalla azul que te explicamos al final.").size(14.0).color(MUTED));
        if matches!(self.mode, Some(Mode::Wipe(_))) {
            ui.add_space(10.0);
            ui.checkbox(&mut self.confirm_wipe, RichText::new("Entiendo que ese disco se borra por completo").size(15.0).color(RED));
        }
    }

    fn work_page(&mut self, ui: &mut egui::Ui) {
        let w = self.work.lock().unwrap();
        ui.add_space(30.0);
        if let Some(e) = &w.error {
            ui.label(RichText::new("No se pudo terminar").size(30.0).family(bold()).color(AMBER));
            ui.label(RichText::new(e).size(16.0).color(MUTED));
            ui.label(RichText::new("No se cambió nada en Windows. Revisa el pendrive y tu conexión y vuelve a abrir el instalador.").size(14.0).color(MUTED));
            return;
        }
        let total = WORK.len() as f32;
        let k = ((w.step as f32 + w.frac) / total).min(1.0);
        ui.horizontal(|ui| {
            let (rect, _) = ui.allocate_exact_size(Vec2::new(280.0, 280.0), Sense::hover());
            let c = rect.center();
            ui.painter().circle_stroke(c, 110.0, Stroke::new(12.0, CARD_HI));
            let n = 120; let sweep = k.max(0.005) * std::f32::consts::TAU;
            let pts: Vec<Pos2> = (0..=n).map(|i| { let a = -std::f32::consts::FRAC_PI_2 + sweep * i as f32 / n as f32; c + Vec2::new(a.cos(), a.sin()) * 110.0 }).collect();
            for (i, seg) in pts.windows(2).enumerate() { ui.painter().line_segment([seg[0], seg[1]], Stroke::new(12.0, brand(i as f32 / n as f32))); }
            ui.painter().image(self.logo.id(), Rect::from_center_size(c, Vec2::splat(110.0)), Rect::from_min_max(Pos2::ZERO, Pos2::new(1.0, 1.0)), Color32::WHITE);
            ui.add_space(30.0);
            ui.vertical(|ui| {
                ui.label(RichText::new("Preparando todo").size(30.0).family(bold()));
                ui.label(RichText::new(format!("{:.0} % · Puedes seguir usando tu PC. No desconectes el pendrive.", k * 100.0)).size(15.0).color(MUTED));
                ui.add_space(10.0);
                for (i, s) in WORK.iter().enumerate() {
                    if i == 3 && !self.things { continue; }
                    if i == 5 && self.mode != Some(Mode::Beside) { continue; }
                    ui.horizontal(|ui| {
                        let (r, _) = ui.allocate_exact_size(Vec2::splat(26.0), Sense::hover());
                        if i < w.step { ui.painter().circle_filled(r.center(), 12.0, GREEN); ui.painter().text(r.center(), egui::Align2::CENTER_CENTER, icons::CHECK, FontId::new(16.0, icon_font()), Color32::WHITE); }
                        else if i == w.step { ui.painter().circle_filled(r.center(), 12.0, INDIGO); ui.painter().circle_filled(r.center(), 5.0 + (ui.input(|x| x.time) as f32 * 5.0).sin() * 1.5, Color32::WHITE); }
                        else { ui.painter().circle_stroke(r.center(), 11.0, Stroke::new(1.5, LINE)); }
                        ui.vertical(|ui| {
                            ui.label(RichText::new(*s).size(16.0).family(semi()).color(if i <= w.step { TEXT } else { MUTED }));
                            if i == w.step && !w.detail.is_empty() { ui.label(RichText::new(&w.detail).size(13.0).color(MUTED)); }
                        });
                    });
                }
            });
        });
    }

    fn done(&mut self, ui: &mut egui::Ui) {
        let secure = self.pc().map(|p| p.secureboot).unwrap_or(false);
        ui.add_space(10.0);
        ui.label(RichText::new("¡Todo listo! Ahora reinicia").size(32.0).family(bold()));
        ui.label(RichText::new("Deja el pendrive conectado. Quantum se instala solo y vuelve a arrancar ya instalado.").size(16.0).color(MUTED));
        ui.add_space(14.0);
        if secure {
            egui::Frame::new().fill(Color32::from_rgb(0x00, 0x00, 0xAA)).corner_radius(14).inner_margin(Margin::same(18)).show(ui, |ui| {
                ui.set_width(ui.available_width().min(760.0));
                ui.label(RichText::new("Vas a ver una pantalla azul (es normal, solo la primera vez):").size(16.0).family(semi()).color(Color32::WHITE));
                ui.add_space(6.0);
                for (i, t) in ["Toca una tecla", "Elige «Enroll MOK» y Enter", "Elige «Continue» y Enter", "Elige «Yes» y Enter",
                               "Escribe la clave quantum y Enter", "Elige «Reboot»"].iter().enumerate() {
                    ui.label(RichText::new(format!("{}. {t}", i + 1)).size(15.0).color(Color32::WHITE));
                }
                ui.add_space(4.0);
                ui.label(RichText::new("Así tu PC aprende a confiar en Quantum. Sin desactivar nada de seguridad.").size(13.0).color(Color32::from_rgb(0xC8, 0xD0, 0xFF)));
                ui.label(RichText::new("Si no aparece «Enroll MOK»: elige «Enroll key from disk», luego QUANTUMINST, quantum-install y quantum.cer; después Continue, Yes y Reboot.").size(13.0).color(Color32::from_rgb(0xC8, 0xD0, 0xFF)));
            });
        }
        ui.add_space(16.0);
        ui.label(RichText::new("Si el PC vuelve a abrir Windows, apágalo y al encender elige el pendrive en el menú de arranque (F12, F11 o Esc según la marca).").size(13.5).color(MUTED));
        ui.add_space(12.0);
        if primary(ui, "Reiniciar ahora", icons::ARROW_FORWARD, true) { setup::reboot(); ui.ctx().send_viewport_cmd(egui::ViewportCommand::Close); }
    }
}

fn main() -> eframe::Result {
    std::panic::set_hook(Box::new(|i| setup::log(&format!("ERROR: {i}"))));
    setup::log("inicio");
    // instalar-quantum --solo-llave: solo pide registrar la llave de Quantum (para probar el arranque seguro)
    if std::env::args().any(|a| a == "--solo-llave") {
        let r = setup::request_mok(&[setup::QUANTUM_CER.to_vec()], "quantum");
        setup::log(&format!("solo-llave: {r:?}"));
        return Ok(());
    }
    // instalar-quantum --solo-arranque E: — solo crea la entrada de arranque del pendrive (diagnóstico)
    if let Some(i) = std::env::args().position(|a| a == "--solo-arranque") {
        let l = std::env::args().nth(i + 1).unwrap_or("E:".into());
        let r = setup::boot_next_usb(&l);
        setup::log(&format!("solo-arranque: {r:?}"));
        return Ok(());
    }
    let icon = image::load_from_memory(include_bytes!("../assets/logo.png")).ok().map(|i| {
        let i = i.to_rgba8();
        Arc::new(egui::IconData { width: i.width(), height: i.height(), rgba: i.into_raw() })
    });
    let mut vp = egui::ViewportBuilder::default().with_inner_size([1040.0, 720.0]).with_min_inner_size([900.0, 640.0]).with_title("Instalar Quantum Linux");
    if let Some(i) = icon { vp = vp.with_icon(i); }
    let mut wgpu_options = eframe::egui_wgpu::WgpuConfiguration::default();
    if cfg!(windows) {
        if let eframe::egui_wgpu::WgpuSetup::CreateNew(ref mut c) = wgpu_options.wgpu_setup {
            c.instance_descriptor.backends = eframe::wgpu::Backends::DX12;
            c.power_preference = eframe::wgpu::PowerPreference::LowPower;
        }
    }
    let options = eframe::NativeOptions { viewport: vp, centered: true, renderer: eframe::Renderer::Wgpu, wgpu_options, ..Default::default() };
    let _ = StrokeKind::Inside;
    eframe::run_native("Instalar Quantum Linux", options, Box::new(|cc| Ok(Box::new(App::new(cc)))))
}
