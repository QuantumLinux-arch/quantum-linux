import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// Sonidos del sistema: activar, volumen y escuchar cada uno.
ColumnLayout {
    id: page

    spacing: 16

    Group {
        title: "Sonidos del sistema"
        help: "Sonidos suaves creados para Quantum: al iniciar sesión, cambiar el volumen, tocar la barra rápida y más."
        icon: "music_note"
        OptionRow {
            title: "Activar sonidos"
            Toggle { checked: Settings.sounds.enabled; onToggled: c => Settings.set("sounds", "enabled", c) }
        }
        OptionRow {
            title: "Volumen de los sonidos"
            help: "Independiente del volumen de tu música y tus juegos."
            enabled: Settings.sounds.enabled
            opacity: enabled ? 1 : 0.5
            Slider {
                implicitWidth: 240
                from: 0.1; to: 1; step: 0.05
                value: Settings.sounds.volume
                text: Math.round(_shown * 100) + " %"
                onMoved: v => { Settings.set("sounds", "volume", v); Sounds.play("volume"); }
            }
        }
        OptionRow {
            title: "Sonido al iniciar sesión"
            enabled: Settings.sounds.enabled
            opacity: enabled ? 1 : 0.5
            Toggle { checked: Settings.sounds.startup; onToggled: c => Settings.set("sounds", "startup", c) }
        }
    }

    Group {
        title: "Escúchalos"
        icon: "graphic_eq"
        Flow {
            Layout.fillWidth: true
            spacing: 10
            Repeater {
                model: [
                    { s: "startup", t: "Inicio", i: "power_settings_new" },
                    { s: "volume", t: "Volumen", i: "volume_up" },
                    { s: "toggle-on", t: "Activar", i: "toggle_on" },
                    { s: "toggle-off", t: "Desactivar", i: "toggle_off" },
                    { s: "notification", t: "Notificación", i: "notifications" },
                    { s: "lock", t: "Bloquear", i: "lock" },
                    { s: "unlock", t: "Desbloquear", i: "lock_open" },
                    { s: "error", t: "Error", i: "error" },
                    { s: "screenshot", t: "Captura", i: "screenshot_region" },
                ]
                PillButton {
                    required property var modelData
                    text: modelData.t
                    icon: modelData.i
                    enabled_: Settings.sounds.enabled
                    onClicked: Sounds.play(modelData.s)
                }
            }
        }
    }
}
