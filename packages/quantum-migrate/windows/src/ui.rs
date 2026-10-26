//! Piezas de interfaz comunes de las apps de Windows de Quantum (colores, fuentes, botones, tarjetas).
#![allow(dead_code)]

use crate::icons;
use eframe::egui::{self, Color32, CornerRadius, FontFamily, FontId, Pos2, Rect, RichText, Sense, Stroke, StrokeKind, Vec2};
use std::sync::Arc;

// ------------------------------------------------------------------ colores
pub const BG: Color32 = Color32::from_rgb(0x0E, 0x0C, 0x18);
pub const CARD: Color32 = Color32::from_rgb(0x1A, 0x17, 0x28);
pub const CARD_HI: Color32 = Color32::from_rgb(0x22, 0x1E, 0x35);
pub const CARD_ON: Color32 = Color32::from_rgb(0x26, 0x20, 0x46);
pub const LINE: Color32 = Color32::from_rgb(0x2E, 0x2A, 0x42);
pub const TEXT: Color32 = Color32::from_rgb(0xF2, 0xEF, 0xFA);
pub const MUTED: Color32 = Color32::from_rgb(0xA7, 0xA1, 0xC2);
pub const CYAN: Color32 = Color32::from_rgb(0x4F, 0xD8, 0xFF);
pub const INDIGO: Color32 = Color32::from_rgb(0x6A, 0x5C, 0xFF);
pub const VIOLET: Color32 = Color32::from_rgb(0xB1, 0x4D, 0xFF);
pub const LILAC: Color32 = Color32::from_rgb(0x8F, 0x7B, 0xFF);
pub const GREEN: Color32 = Color32::from_rgb(0x34, 0xD3, 0x99);
pub const AMBER: Color32 = Color32::from_rgb(0xFF, 0xB5, 0x47);
pub const RED: Color32 = Color32::from_rgb(0xFF, 0x6B, 0x7A);

pub fn semi() -> FontFamily { FontFamily::Name("semi".into()) }
pub fn bold() -> FontFamily { FontFamily::Name("bold".into()) }
pub fn icon_font() -> FontFamily { FontFamily::Name("icons".into()) }

pub fn lerp(a: Color32, b: Color32, t: f32) -> Color32 {
    let f = |x: u8, y: u8| (x as f32 + (y as f32 - x as f32) * t).round() as u8;
    Color32::from_rgb(f(a.r(), b.r()), f(a.g(), b.g()), f(a.b(), b.b()))
}
/// Degradado de Quantum: cian → índigo → violeta.
pub fn brand(t: f32) -> Color32 { if t < 0.5 { lerp(CYAN, INDIGO, t * 2.0) } else { lerp(INDIGO, VIOLET, (t - 0.5) * 2.0) } }

/// Píldora con el degradado (botones y barras): círculos en las puntas y un rectángulo degradado al medio.
pub fn pill(p: &egui::Painter, r: Rect, alpha: f32, t0: f32, t1: f32) {
    let rad = r.height() / 2.0;
    let fade = |c: Color32| c.gamma_multiply(alpha);
    if r.width() <= r.height() {
        p.circle_filled(r.center(), rad.min(r.width() / 2.0), fade(brand(t0)));
        return;
    }
    p.circle_filled(Pos2::new(r.left() + rad, r.center().y), rad, fade(brand(t0)));
    p.circle_filled(Pos2::new(r.right() - rad, r.center().y), rad, fade(brand(t1)));
    let mid = Rect::from_min_max(Pos2::new(r.left() + rad, r.top()), Pos2::new(r.right() - rad, r.bottom()));
    let mut mesh = egui::Mesh::default();
    let steps = 24;
    for i in 0..=steps {
        let k = i as f32 / steps as f32;
        let x = mid.left() + mid.width() * k;
        let c = fade(brand(t0 + (t1 - t0) * k));
        mesh.colored_vertex(Pos2::new(x, mid.top()), c);
        mesh.colored_vertex(Pos2::new(x, mid.bottom()), c);
        if i > 0 {
            let n = (i * 2) as u32;
            mesh.add_triangle(n - 2, n - 1, n);
            mesh.add_triangle(n - 1, n, n + 1);
        }
    }
    p.add(egui::Shape::mesh(mesh));
}

pub fn gb(b: u64) -> String {
    let g = b as f64 / 1_073_741_824.0;
    let s = if g >= 100.0 { format!("{g:.0} GB") } else if g >= 1.0 { format!("{g:.1} GB") } else if b >= 1_048_576 {
        format!("{:.0} MB", b as f64 / 1_048_576.0)
    } else if b > 0 { "menos de 1 MB".into() } else { "vacía".into() };
    s.replace('.', ",")
}

pub fn plural(n: usize, one: &str, many: &str) -> String { if n == 1 { format!("1 {one}") } else { format!("{n} {many}") } }

pub fn load_png(ctx: &egui::Context, name: &str, bytes: &[u8]) -> egui::TextureHandle {
    let img = image::load_from_memory(bytes).map(|i| i.to_rgba8()).unwrap_or_else(|_| image::RgbaImage::new(1, 1));
    let c = egui::ColorImage::from_rgba_unmultiplied([img.width() as usize, img.height() as usize], img.as_raw());
    ctx.load_texture(name, c, egui::TextureOptions::LINEAR)
}

pub fn setup_style(ctx: &egui::Context) {
    let mut fonts = egui::FontDefinitions::default();
    let add = |f: &mut egui::FontDefinitions, n: &str, b: &'static [u8]| {
        f.font_data.insert(n.into(), Arc::new(egui::FontData::from_static(b)));
    };
    add(&mut fonts, "inter", include_bytes!("../assets/Inter-Regular.ttf"));
    add(&mut fonts, "inter-semi", include_bytes!("../assets/Inter-SemiBold.ttf"));
    add(&mut fonts, "inter-bold", include_bytes!("../assets/Inter-ExtraBold.ttf"));
    add(&mut fonts, "icons", include_bytes!("../assets/Icons.ttf"));
    fonts.families.insert(FontFamily::Proportional, vec!["inter".into(), "icons".into()]);
    fonts.families.insert(semi(), vec!["inter-semi".into(), "icons".into()]);
    fonts.families.insert(bold(), vec!["inter-bold".into(), "icons".into()]);
    fonts.families.insert(icon_font(), vec!["icons".into()]);
    ctx.set_fonts(fonts);

    let mut v = egui::Visuals::dark();
    v.panel_fill = BG;
    v.window_fill = CARD;
    v.override_text_color = Some(TEXT);
    v.selection.bg_fill = INDIGO;
    v.widgets.noninteractive.bg_stroke = Stroke::new(1.0, LINE);
    for w in [&mut v.widgets.inactive, &mut v.widgets.hovered, &mut v.widgets.active, &mut v.widgets.open] {
        w.corner_radius = CornerRadius::same(12);
    }
    v.widgets.inactive.weak_bg_fill = CARD_HI;
    v.widgets.hovered.weak_bg_fill = Color32::from_rgb(0x2C, 0x27, 0x44);
    // siempre oscuro, aunque Windows esté en modo claro (si no, egui cambia solo de tema)
    ctx.options_mut(|o| o.theme_preference = egui::ThemePreference::Dark);
    ctx.set_visuals_of(egui::Theme::Dark, v.clone());
    ctx.set_visuals_of(egui::Theme::Light, v.clone());
    ctx.set_visuals(v);
    ctx.style_mut(|s| {
        s.spacing.item_spacing = Vec2::new(10.0, 10.0);
        s.spacing.button_padding = Vec2::new(16.0, 10.0);
        s.text_styles.insert(egui::TextStyle::Body, FontId::new(15.0, FontFamily::Proportional));
        s.text_styles.insert(egui::TextStyle::Button, FontId::new(15.0, semi()));
        s.spacing.scroll = egui::style::ScrollStyle::thin();
    });
}

// --------------------------------------------------------- piezas de interfaz
pub fn icon(ui: &mut egui::Ui, glyph: &str, size: f32, color: Color32) {
    ui.label(RichText::new(glyph).family(icon_font()).size(size).color(color));
}

/// Círculo con el degradado y un ícono blanco.
pub fn badge(p: &egui::Painter, center: Pos2, r: f32, glyph: &str, t: f32) {
    p.circle_filled(center, r, brand(t));
    p.text(center, egui::Align2::CENTER_CENTER, glyph, FontId::new(r * 1.05, icon_font()), Color32::WHITE);
}

/// Botón principal (píldora con degradado). Devuelve true si se hizo clic.
pub fn primary(ui: &mut egui::Ui, text: &str, glyph: &str, enabled: bool) -> bool {
    let font = FontId::new(17.0, semi());
    let galley = ui.painter().layout_no_wrap(text.to_string(), font.clone(), Color32::WHITE);
    let w = galley.size().x + 64.0 + if glyph.is_empty() { 0.0 } else { 28.0 };
    let (rect, resp) = ui.allocate_exact_size(Vec2::new(w, 54.0), if enabled { Sense::click() } else { Sense::hover() });
    let hovered = enabled && resp.hovered();
    let r = if hovered { rect.expand(1.5) } else { rect };
    if enabled {
        // brillo suave detrás
        ui.painter().rect_filled(r.translate(Vec2::new(0.0, 6.0)).shrink2(Vec2::new(10.0, 6.0)), 27.0, INDIGO.gamma_multiply(0.25));
    }
    pill(ui.painter(), r, if enabled { 1.0 } else { 0.35 }, 0.0, 1.0);
    let mut x = r.center().x - (galley.size().x + if glyph.is_empty() { 0.0 } else { 28.0 }) / 2.0;
    ui.painter().galley(Pos2::new(x, r.center().y - galley.size().y / 2.0), galley, Color32::WHITE);
    if !glyph.is_empty() {
        x = r.right() - 32.0 - 14.0;
        let _ = x;
        let gx = r.center().x + (ui.painter().layout_no_wrap(text.to_string(), font, Color32::WHITE).size().x - 0.0) / 2.0 - 6.0;
        ui.painter().text(Pos2::new(gx + 20.0, r.center().y), egui::Align2::CENTER_CENTER, glyph,
                          FontId::new(22.0, icon_font()), Color32::WHITE);
    }
    if hovered { ui.ctx().set_cursor_icon(egui::CursorIcon::PointingHand); }
    resp.clicked()
}

/// Botón secundario (contorno).
pub fn secondary(ui: &mut egui::Ui, text: &str, glyph: &str) -> bool {
    let font = FontId::new(16.0, semi());
    let galley = ui.painter().layout_no_wrap(text.to_string(), font, TEXT);
    let extra = if glyph.is_empty() { 0.0 } else { 28.0 };
    let (rect, resp) = ui.allocate_exact_size(Vec2::new(galley.size().x + 48.0 + extra, 54.0), Sense::click());
    let fill = if resp.hovered() { CARD_HI } else { Color32::TRANSPARENT };
    ui.painter().rect(rect, 27.0, fill, Stroke::new(1.5, LINE), StrokeKind::Inside);
    let left = rect.center().x - (galley.size().x + extra) / 2.0;
    if !glyph.is_empty() {
        ui.painter().text(Pos2::new(left + 10.0, rect.center().y), egui::Align2::CENTER_CENTER, glyph, FontId::new(22.0, icon_font()), TEXT);
    }
    ui.painter().galley(Pos2::new(left + extra, rect.center().y - galley.size().y / 2.0), galley, TEXT);
    if resp.hovered() { ui.ctx().set_cursor_icon(egui::CursorIcon::PointingHand); }
    resp.clicked()
}

/// Casilla redonda con check.
pub fn check(p: &egui::Painter, c: Pos2, on: bool) {
    if on {
        p.circle_filled(c, 13.0, INDIGO);
        p.text(c, egui::Align2::CENTER_CENTER, icons::CHECK, FontId::new(18.0, icon_font()), Color32::WHITE);
    } else {
        p.circle_stroke(c, 12.0, Stroke::new(2.0, Color32::from_rgb(0x4A, 0x46, 0x66)));
    }
}

/// Tarjeta seleccionable: ícono, título, detalle, y a la derecha el check. Devuelve true si se hizo clic.
#[allow(clippy::too_many_arguments)]
pub fn choice(ui: &mut egui::Ui, w: f32, glyph: &str, t: f32, title: &str, detail: &str, note: Option<(&str, Color32)>, on: bool, enabled: bool) -> bool {
    let alpha = if enabled { 1.0 } else { 0.45 };
    let maxw = w - 72.0 - 52.0;
    let (tg, dg, ng) = {
        let p = ui.painter();
        (p.layout(title.to_string(), FontId::new(16.0, semi()), TEXT.gamma_multiply(alpha), maxw),
         p.layout(detail.to_string(), FontId::new(13.5, FontFamily::Proportional), MUTED.gamma_multiply(alpha), maxw),
         note.map(|(n, color)| p.layout(n.to_string(), FontId::new(12.5, semi()), color, w - 36.0)))
    };
    let block = tg.size().y + 3.0 + dg.size().y;
    let head = (block + 36.0).max(84.0);
    let h = head + ng.as_ref().map(|g| g.size().y + 10.0).unwrap_or(0.0);
    let (rect, resp) = ui.allocate_exact_size(Vec2::new(w, h), if enabled { Sense::click() } else { Sense::hover() });
    let p = ui.painter();
    let hovered = enabled && resp.hovered();
    p.rect(rect, 18.0, if on { CARD_ON } else if hovered { CARD_HI } else { CARD },
           Stroke::new(if on { 2.0 } else { 1.0 }, if on { LILAC } else { LINE }), StrokeKind::Inside);
    let top = rect.top() + head / 2.0;
    p.circle_filled(Pos2::new(rect.left() + 38.0, top), 22.0, brand(t).gamma_multiply(0.22 * alpha + 0.05));
    p.text(Pos2::new(rect.left() + 38.0, top), egui::Align2::CENTER_CENTER, glyph, FontId::new(24.0, icon_font()), brand(t).gamma_multiply(alpha));
    let tx = rect.left() + 72.0;
    let y0 = top - block / 2.0;
    p.galley(Pos2::new(tx, y0), tg.clone(), TEXT);
    p.galley(Pos2::new(tx, y0 + tg.size().y + 3.0), dg, MUTED);
    if let Some(ng) = ng {
        let c = note.map(|n| n.1).unwrap_or(AMBER);
        p.galley(Pos2::new(rect.left() + 18.0, rect.bottom() - ng.size().y - 12.0), ng, c);
    }
    if enabled { check(p, Pos2::new(rect.right() - 30.0, top), on); }
    if hovered { ui.ctx().set_cursor_icon(egui::CursorIcon::PointingHand); }
    resp.clicked()
}

pub fn section(ui: &mut egui::Ui, title: &str, hint: &str) {
    ui.add_space(14.0);
    ui.label(RichText::new(title).size(19.0).family(bold()));
    if !hint.is_empty() { ui.label(RichText::new(hint).size(13.5).color(MUTED)); }
    ui.add_space(4.0);
}

