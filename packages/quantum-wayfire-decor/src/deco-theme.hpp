#pragma once
#include <string>
#include <wayfire/render-manager.hpp>
#include <wayfire/scene-render.hpp>
#include "deco-button.hpp"

namespace wf
{
namespace decor
{
/**
 * A  class which manages the outlook of decorations.
 * It is responsible for determining the background colors, sizes, etc.
 */
class decoration_theme_t
{
  public:
    /** Create a new theme with the default parameters */
    decoration_theme_t();

    /** @return The available height for displaying the title */
    int get_title_height() const;
    /** @return The available border for resizing */
    int get_border_size() const;
    /** @return The scale factor for buttons */
    double get_button_scale() const;
    /** @return The vertical padding for buttons */
    int get_button_padding() const;
    /** Set the flags for buttons */
    void set_buttons(button_type_t flags);
    button_type_t button_flags;

    /**
     * Fill the given rectangle with the background color(s).
     *
     * @param data The render data (pass, target, damage)
     * @param rectangle The rectangle to redraw.
     * @param active Whether to use active or inactive colors
     */
    void render_background(const wf::scene::render_instruction_t& data,
        wf::geometry_t rectangle, bool active) const;

    /**
     * Render the given text on a cairo_surface_t with the given size.
     * The caller is responsible for freeing the memory afterwards.
     */
    cairo_surface_t *render_text(std::string text, int width, int height) const;

    /** Quantum: lo que cambia el dibujo del título (para volver a dibujarlo
     *  cuando cambian el tema o el color, no solo el texto o el tamaño). */
    std::string text_style_key() const
    {
        wf::color_t c = font_color;
        return (std::string)font + "|" + std::to_string(c.r) + "," + std::to_string(c.g) + "," +
               std::to_string(c.b) + "," + std::to_string(c.a) + "|" + std::to_string((double)font_scale);
    }

    struct button_state_t
    {
        /** Button width */
        double width;
        /** Button height */
        double height;
        /** Button outline size */
        double border;
        /** Progress of button hover, in range [-1, 1].
         * Negative numbers are usually used for pressed state. */
        double hover_progress;
    };

    /**
     * Get the icon for the given button.
     * The caller is responsible for freeing the memory afterwards.
     *
     * @param button The button type.
     * @param state The button state.
     */
    cairo_surface_t *get_button_surface(button_type_t button,
        const button_state_t& state) const;

  private:
    wf::option_wrapper_t<std::string> font{"quantum-decor/font"};
    wf::option_wrapper_t<wf::color_t> font_color{"quantum-decor/font_color"};
    wf::option_wrapper_t<int> title_height{"quantum-decor/title_height"};
    wf::option_wrapper_t<int> border_size{"quantum-decor/border_size"};
    wf::option_wrapper_t<double> font_scale{"quantum-decor/font_scale"};
    wf::option_wrapper_t<double> button_scale{"quantum-decor/button_scale"};
    wf::option_wrapper_t<int> button_padding{"quantum-decor/button_padding"};
    wf::option_wrapper_t<wf::color_t> active_color{"quantum-decor/active_color"};
    wf::option_wrapper_t<wf::color_t> inactive_color{"quantum-decor/inactive_color"};
    // Quantum: botones estilo Windows (símbolo claro, fondo solo al pasar el mouse)
    wf::option_wrapper_t<wf::color_t> button_icon_color{"quantum-decor/button_icon_color"};
    wf::option_wrapper_t<wf::color_t> button_hover_color{"quantum-decor/button_hover_color"};
    wf::option_wrapper_t<wf::color_t> close_hover_color{"quantum-decor/close_hover_color"};
};
}
}
