//@ pragma UseQApplication
// Los íconos los elige quantum-shell-start (QS_ICON_THEME) según Personalizar; sin eso, qt6ct.
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "modules"
import "modules/bar"
import "modules/launcher"
import "modules/controlcenter"
import "modules/dashboard"
import "modules/wallpapers"
import "modules/notifications"
import "modules/personalize"
import "modules/assistant"
import "modules/snap"
import "modules/island"
import "modules/gamemode"
import "modules/osd"
import "modules/session"
import "modules/welcome"
import "modules/lock"
import "modules/serpantium"
import "modules/updates"

// Quantum Shell: el escritorio de Quantum Linux.
// Primero aparece la pantalla de carga (liviana) y el resto se carga de fondo, sin
// bloquear; cuando está todo listo, la pantalla se desvanece y aparece el escritorio.
ShellRoot {
    Splash {
        desktopReady: desktop.item !== null
        onSessionStarted: {
            Sounds.play("startup");
            // apps de inicio que no deben competir con la carga del escritorio
            Quickshell.execDetached(["quantum-center", "--autostart"]);
        }
    }

    LazyLoader {
        id: desktop
        activeAsync: true
        Scope {
            Background {}
            // La forma del shell: Caelestial (barra + dock) o Serpantium (píldoras arriba)
            LazyLoader {
                active: !Serp.on
                Scope { Bar {} Dock {} DashboardZone {} }
            }
            LazyLoader {
                active: Serp.on
                Scope {
                    SerpBar {} SerpPanels {} SerpLauncher {}
                    // «Dock abajo»: el mismo dock de Caelestial, con los colores de Serpantium
                    LazyLoader { active: Settings.ui.serpApps === "dock"; Dock {} }
                }
            }
            Lock {}
            Popups {}
            Osd {}
            Launcher {}
            ControlCenter {}
            Dashboard {}
            WallpaperPicker {}
            Personalize {}
            Assistant {}
            SessionMenu {}
            SnapLayouts {}
            Island {}
            GameModeFx {}
            CursorTrail {}
            LazyLoader { active: !Settings.ui.welcomed || Shell.welcomeRequested; Welcome {} }
            IpcHandler {
                target: "welcome"
                function open(): void { if (Shell.welcome) Shell.welcome.show(); else Shell.welcomeRequested = true; }
                function close(): void { if (Shell.welcome) Shell.welcome.open = false; }
                function next(): void { if (Shell.welcome) Shell.welcome.step = Math.min(4, Shell.welcome.step + 1); }
                function step(n: int): void { if (Shell.welcome) Shell.welcome.step = n; }
                function shell(id: string): void { if (Shell.welcome) Serp.choose(id, Shell.welcome.lookTouched, true); }
                function pick(id: string): void { if (Shell.welcome) Shell.welcome.pick(id); }
            }
            // el aviso de reinicio solo existe cuando hace falta reiniciar
            LazyLoader { active: Updates.rebootNeeded; RebootPrompt {} }
        }
    }
}
