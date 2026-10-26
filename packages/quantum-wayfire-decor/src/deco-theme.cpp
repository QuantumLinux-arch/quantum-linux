#include "deco-theme.hpp"
#include <wayfire/core.hpp>
#include <wayfire/opengl.hpp>
#include <config.h>

namespace wf
{
namespace decor
{
/** Create a new theme with the default parameters */
decoration_theme_t::decoration_theme_t()
{}

/** @return The available height for displaying the title */
int decoration_theme_t::get_title_height() const
{
    return title_height;
}

/** @return The available border for resizing */
int decoration_theme_t::get_border_size() const
{
    return border_size;
}

/** @return The scale factor for buttons */
double decoration_theme_t::get_button_scale() const
{
    return button_scale;
}

/** @return The vertical padding for buttons */
int decoration_theme_t::get_button_padding() const
{
    return button_padding;
}

/** @return The available border for resizing */
void decoration_theme_t::set_buttons(button_type_t flags)
{
    button_flags = flags;
}

/**
 * Fill the given rectangle with the background color(s).
 *
 * @param fb The target framebuffer, must have been bound already
 * @param rectangle The rectangle to redraw.
 * @param scissor The GL scissor rectangle to use.
 * @param active Whether to use active or inactive colors
 */
void decoration_theme_t::render_background(const wf::scene::render_instruction_t& data,
    wf::geometry_t rectangle, bool active) const
{
    wf::color_t color = active ? active_color : inactive_color;
    data.pass->add_rect(color, data.target, rectangle, data.damage);
}

/**
 * Render the given text on a cairo_surface_t with the given size.
 * The caller is responsible for freeing the memory afterwards.
 */
cairo_surface_t*decoration_theme_t::render_text(std::string text,
    int width, int height) const
{
    const auto format = CAIRO_FORMAT_ARGB32;
    auto surface = cairo_image_surface_create(format, width, height);

    if (height == 0)
    {
        return surface;
    }

    wf::color_t color = font_color;
    auto cr = cairo_create(surface);

    const float font_size = height * font_scale;

    PangoFontDescription *font_desc;
    PangoLayout *layout;

    // render text
    font_desc = pango_font_description_from_string(((std::string)font).c_str());
    pango_font_description_set_absolute_size(font_desc, font_size * PANGO_SCALE);

    layout = pango_cairo_create_layout(cr);
    pango_layout_set_font_description(layout, font_desc);
    pango_layout_set_text(layout, text.c_str(), text.size());
    // Quantum: margen a la izquierda del título y título centrado verticalmente
    {
        int lw, lh;
        pango_layout_get_pixel_size(layout, &lw, &lh);
        cairo_move_to(cr, height * 0.45, std::max(0.0, (height - lh) / 2.0));
    }
    cairo_set_source_rgba(cr, color.r, color.g, color.b, color.a);
    pango_cairo_show_layout(cr, layout);
    pango_font_description_free(font_desc);
    g_object_unref(layout);
    cairo_destroy(cr);

    return surface;
}

cairo_surface_t*decoration_theme_t::get_button_surface(button_type_t button,
    const button_state_t& state) const
{
    cairo_surface_t *button_surface = cairo_image_surface_create(
        CAIRO_FORMAT_ARGB32, state.width, state.height);

    auto cr = cairo_create(button_surface);
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_BEST);

    /* Clear the button background */
    cairo_set_operator(cr, CAIRO_OPERATOR_CLEAR);
    cairo_set_source_rgba(cr, 0, 0, 0, 0);
    cairo_rectangle(cr, 0, 0, state.width, state.height);
    cairo_fill(cr);

    cairo_set_operator(cr, CAIRO_OPERATOR_OVER);

    /* Quantum: botones como en Windows. Sin hover solo se ve el símbolo;
     * al pasar el mouse aparece un fondo redondeado (rojo en cerrar). */
    const wf::color_t icon  = button_icon_color;
    const wf::color_t hover = (button == BUTTON_CLOSE) ?
        (wf::color_t)close_hover_color : (wf::color_t)button_hover_color;
    const double p = state.hover_progress;

    if (p > 1e-3)
    {
        const double w = state.width, h = state.height, r = std::min(w, h) * 0.22;
        cairo_new_sub_path(cr);
        cairo_arc(cr, w - r, r, r, -M_PI / 2, 0);
        cairo_arc(cr, w - r, h - r, r, 0, M_PI / 2);
        cairo_arc(cr, r, h - r, r, M_PI / 2, M_PI);
        cairo_arc(cr, r, r, r, M_PI, 3 * M_PI / 2);
        cairo_close_path(cr);
        cairo_set_source_rgba(cr, hover.r, hover.g, hover.b, hover.a * p);
        cairo_fill(cr);
    }

    /* El símbolo: blanco puro sobre el rojo de cerrar */
    const bool white = (button == BUTTON_CLOSE) && p > 0.5;
    cairo_set_source_rgba(cr, white ? 1.0 : icon.r, white ? 1.0 : icon.g,
        white ? 1.0 : icon.b, icon.a);
    cairo_set_antialias(cr, CAIRO_ANTIALIAS_BEST);
    cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND);
    const double lw = std::max(1.0, state.height / 16.0);
    cairo_set_line_width(cr, lw);
    const double cx = state.width / 2.0, cy = state.height / 2.0;
    const double s  = std::min(state.width, state.height) * 0.19;
    switch (button)
    {
      case BUTTON_CLOSE:
        cairo_move_to(cr, cx - s, cy - s);
        cairo_line_to(cr, cx + s, cy + s);
        cairo_move_to(cr, cx + s, cy - s);
        cairo_line_to(cr, cx - s, cy + s);
        cairo_stroke(cr);
        break;

      case BUTTON_TOGGLE_MAXIMIZE:
        cairo_rectangle(cr, cx - s, cy - s, 2 * s, 2 * s);
        cairo_stroke(cr);
        break;

      case BUTTON_MINIMIZE:
        cairo_move_to(cr, cx - s, cy);
        cairo_line_to(cr, cx + s, cy);
        cairo_stroke(cr);
        break;

      default:
        assert(false);
    }

    cairo_fill(cr);
    cairo_destroy(cr);

    return button_surface;
}
}
}
