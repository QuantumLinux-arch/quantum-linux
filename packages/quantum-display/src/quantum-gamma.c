// quantum-gamma: aplica la curva de color (gamma ramp) a todas las pantallas con el
// protocolo wlr-gamma-control. Lo maneja quantum-display: lee por la entrada estándar
// líneas «temperatura brillo contraste gamma» (ej. «4000 1.0 1.0 1.0») y las aplica al
// instante. La curva la aplica la tarjeta de video, así que no cuesta rendimiento.
// Al cerrarse (o con la entrada cerrada) Wayfire vuelve a la curva normal solo.
#define _GNU_SOURCE
#include <errno.h>
#include <math.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <wayland-client.h>
#include "wlr-gamma-control-unstable-v1-client-protocol.h"

struct out {
    struct wl_output *wl;
    uint32_t name;
    struct zwlr_gamma_control_v1 *ctl;
    uint32_t size;
    int failed;
    struct out *next;
};

static struct zwlr_gamma_control_manager_v1 *manager;
static struct out *outputs;
static double cur_temp = 6500, cur_bright = 1, cur_contrast = 1, cur_gamma = 1;

// Color de una luz de `k` kelvin, normalizado a 6500 K = blanco (Tanner Helland)
static void kelvin_rgb(double k, double *r, double *g, double *b)
{
    double t = k / 100.0;
    *r = t <= 66 ? 1 : 1.292936186 * pow(t - 60, -0.1332047592);
    *g = t <= 66 ? 0.3900815788 * log(t) - 0.6318414438 : 1.129890861 * pow(t - 60, -0.0755148492);
    *b = t >= 66 ? 1 : t <= 19 ? 0 : 0.5432067891 * log(t - 10) - 1.19625408914;
#define CL(x) (*(x) = *(x) < 0 ? 0 : *(x) > 1 ? 1 : *(x))
    CL(r); CL(g); CL(b);
}

static void apply(struct out *o)
{
    if (!o->ctl || !o->size || o->failed)
        return;
    size_t n = o->size, bytes = n * 3 * sizeof(uint16_t);
    int fd = memfd_create("quantum-gamma", MFD_CLOEXEC);
    if (fd < 0 || ftruncate(fd, bytes) < 0) {
        if (fd >= 0) close(fd);
        return;
    }
    uint16_t *t = mmap(NULL, bytes, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (t == MAP_FAILED) {
        close(fd);
        return;
    }
    double wr, wg, wb, w6r, w6g, w6b;
    kelvin_rgb(cur_temp, &wr, &wg, &wb);
    kelvin_rgb(6500, &w6r, &w6g, &w6b);
    double white[3] = {wr / w6r, wg / w6g, wb / w6b};
    for (int c = 0; c < 3; c++) {
        for (size_t i = 0; i < n; i++) {
            double x = n > 1 ? (double)i / (n - 1) : 0;
            x = (x - 0.5) * cur_contrast + 0.5;              // contraste alrededor del gris medio
            x = x < 0 ? 0 : x > 1 ? 1 : x;
            x = pow(x, 1.0 / cur_gamma);                      // gamma > 1 aclara los tonos medios
            x *= cur_bright * (white[c] > 1 ? 1 : white[c]);  // brillo y luz nocturna
            x = x < 0 ? 0 : x > 1 ? 1 : x;
            t[c * n + i] = (uint16_t)(x * 65535.0 + 0.5);
        }
    }
    munmap(t, bytes);
    zwlr_gamma_control_v1_set_gamma(o->ctl, fd);
    close(fd);
}

static void gamma_size(void *data, struct zwlr_gamma_control_v1 *ctl, uint32_t size)
{
    struct out *o = data;
    o->size = size;
    apply(o);
}

static void gamma_failed(void *data, struct zwlr_gamma_control_v1 *ctl)
{
    struct out *o = data;
    // otra app ya controla esta pantalla (o no tiene curva de color)
    fprintf(stderr, "quantum-gamma: la pantalla %u no acepta curva de color\n", o->name);
    o->failed = 1;
    zwlr_gamma_control_v1_destroy(o->ctl);
    o->ctl = NULL;
}

static const struct zwlr_gamma_control_v1_listener gamma_listener = {
    .gamma_size = gamma_size,
    .failed = gamma_failed,
};

static void attach(struct out *o)
{
    if (manager && o->wl && !o->ctl && !o->failed) {
        o->ctl = zwlr_gamma_control_manager_v1_get_gamma_control(manager, o->wl);
        zwlr_gamma_control_v1_add_listener(o->ctl, &gamma_listener, o);
    }
}

static void global(void *data, struct wl_registry *reg, uint32_t name, const char *iface, uint32_t ver)
{
    if (strcmp(iface, zwlr_gamma_control_manager_v1_interface.name) == 0) {
        manager = wl_registry_bind(reg, name, &zwlr_gamma_control_manager_v1_interface, 1);
        for (struct out *o = outputs; o; o = o->next)
            attach(o);
    } else if (strcmp(iface, wl_output_interface.name) == 0) {
        struct out *o = calloc(1, sizeof(*o));
        o->wl = wl_registry_bind(reg, name, &wl_output_interface, 1);
        o->name = name;
        o->next = outputs;
        outputs = o;
        attach(o);
    }
}

static void global_remove(void *data, struct wl_registry *reg, uint32_t name)
{
    for (struct out **p = &outputs; *p; p = &(*p)->next) {
        if ((*p)->name == name) {
            struct out *o = *p;
            *p = o->next;
            if (o->ctl) zwlr_gamma_control_v1_destroy(o->ctl);
            wl_output_destroy(o->wl);
            free(o);
            return;
        }
    }
}

static const struct wl_registry_listener reg_listener = {.global = global, .global_remove = global_remove};

int main(void)
{
    struct wl_display *dpy = wl_display_connect(NULL);
    if (!dpy) {
        fprintf(stderr, "quantum-gamma: no hay sesión de Wayland\n");
        return 1;
    }
    struct wl_registry *reg = wl_display_get_registry(dpy);
    wl_registry_add_listener(reg, &reg_listener, NULL);
    wl_display_roundtrip(dpy);
    if (!manager) {
        fprintf(stderr, "quantum-gamma: el compositor no permite cambiar la curva de color\n");
        return 2;
    }
    wl_display_roundtrip(dpy);

    char line[256];
    size_t len = 0;
    struct pollfd fds[2] = {{.fd = wl_display_get_fd(dpy), .events = POLLIN}, {.fd = 0, .events = POLLIN}};
    for (;;) {
        wl_display_flush(dpy);
        if (poll(fds, 2, -1) < 0) {
            if (errno == EINTR) continue;
            break;
        }
        if (fds[0].revents & POLLIN) {
            if (wl_display_dispatch(dpy) < 0) break;
        }
        if (fds[0].revents & (POLLERR | POLLHUP)) break;
        if (fds[1].revents & (POLLIN | POLLHUP)) {
            ssize_t r = read(0, line + len, sizeof(line) - 1 - len);
            if (r <= 0) break;                       // quantum-display se cerró
            len += r;
            line[len] = 0;
            char *nl;
            while ((nl = strchr(line, '\n'))) {
                *nl = 0;
                double k, b, c, g;
                if (sscanf(line, "%lf %lf %lf %lf", &k, &b, &c, &g) == 4) {
                    cur_temp = k < 1000 ? 1000 : k > 10000 ? 10000 : k;
                    cur_bright = b < 0.1 ? 0.1 : b > 1 ? 1 : b;
                    cur_contrast = c < 0.3 ? 0.3 : c > 2 ? 2 : c;
                    cur_gamma = g < 0.3 ? 0.3 : g > 3 ? 3 : g;
                    for (struct out *o = outputs; o; o = o->next)
                        apply(o);
                }
                memmove(line, nl + 1, strlen(nl + 1) + 1);
                len = strlen(line);
            }
            if (len >= sizeof(line) - 1) len = 0;    // línea demasiado larga: se descarta
        }
    }
    wl_display_disconnect(dpy);
    return 0;
}
