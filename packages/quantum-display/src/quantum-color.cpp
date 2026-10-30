// quantum-color: filtro de saturación de Quantum Linux para Wayfire.
// Basado en el plugin «invert» de Wayfire 0.11 (MIT). Pinta cada pantalla con un shader
// que mezcla cada color con su gris: 0 = blanco y negro, 1 = normal, 2 = el doble de vivo.
// quantum-theme solo carga este plugin si la saturación no es 1 y no hay Modo juego,
// porque es una pasada extra por cuadro (cuesta un poco en juegos).
#include <wayfire/per-output-plugin.hpp>
#include <wayfire/output.hpp>
#include <wayfire/opengl.hpp>
#include <wayfire/render-manager.hpp>

static const char *vertex_shader =
    R"(
#version 100
attribute highp vec2 position;
attribute highp vec2 uvPosition;
varying highp vec2 uvpos;
void main() {
    gl_Position = vec4(position.xy, 0.0, 1.0);
    uvpos = uvPosition;
}
)";

static const char *fragment_shader =
    R"(
#version 100
varying highp vec2 uvpos;
uniform sampler2D smp;
uniform highp float saturation;
void main()
{
    highp vec4 tex = texture2D(smp, uvpos);
    highp float gray = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
    gl_FragColor = vec4(clamp(mix(vec3(gray), tex.rgb, saturation), 0.0, 1.0), 1.0);
}
)";

class quantum_color_screen : public wf::per_output_plugin_instance_t
{
    wf::post_hook_t hook;
    wf::option_wrapper_t<double> saturation{"quantum-color/saturation"};
    bool active = false;
    OpenGL::program_t program;

    void update()
    {
        bool want = std::abs((double)saturation - 1.0) > 0.001;
        if (want && !active)
        {
            output->render->add_post(&hook);
        } else if (!want && active)
        {
            output->render->rem_post(&hook);
        }

        active = want;
        output->render->damage_whole();
    }

  public:
    void init() override
    {
        if (!wf::get_core().is_gles2())
        {
            LOGE("quantum-color: necesita el renderizador GLES2");
            return;
        }

        hook = [=] (wf::auxilliary_buffer_t& source, const wf::render_buffer_t& destination)
        {
            render(source, destination);
        };

        wf::gles::run_in_context([&]
        {
            program.set_simple(OpenGL::compile_program(vertex_shader, fragment_shader));
        });

        saturation.set_callback([=] () { update(); });
        update();
    }

    void render(wf::auxilliary_buffer_t& source, const wf::render_buffer_t& destination)
    {
        static const float vertexData[] = {-1.0f, -1.0f, 1.0f, -1.0f, 1.0f, 1.0f, -1.0f, 1.0f};
        static const float coordData[]  = {0.0f, 0.0f, 1.0f, 0.0f, 1.0f, 1.0f, 0.0f, 1.0f};

        wf::gles::run_in_context([&]
        {
            wf::gles::bind_render_buffer(destination);
            program.use(wf::TEXTURE_TYPE_RGBA);
            GL_CALL(glBindTexture(GL_TEXTURE_2D, wf::gles_texture_t::from_aux(source).tex_id));
            GL_CALL(glActiveTexture(GL_TEXTURE0));
            program.attrib_pointer("position", 2, 0, vertexData);
            program.attrib_pointer("uvPosition", 2, 0, coordData);
            program.uniform1f("saturation", (float)(double)saturation);
            GL_CALL(glDisable(GL_BLEND));
            GL_CALL(glDrawArrays(GL_TRIANGLE_FAN, 0, 4));
            GL_CALL(glEnable(GL_BLEND));
            GL_CALL(glBindTexture(GL_TEXTURE_2D, 0));
            program.deactivate();
        });
    }

    void fini() override
    {
        if (active)
        {
            output->render->rem_post(&hook);
            output->render->damage_whole();
        }

        wf::gles::run_in_context_if_gles([&] { program.free_resources(); });
    }
};

DECLARE_WAYFIRE_PLUGIN(wf::per_output_plugin_t<quantum_color_screen>);
