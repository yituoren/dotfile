import Quickshell
import Quickshell.Wayland

ShellRoot {
    settings.watchFiles: false

    IdleMonitor {
        timeout: 300
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) Quickshell.execDetached(["systemctl", "--user", "start", "mine-lock.service"])
    }
    IdleMonitor {
        timeout: 600
        respectInhibitors: true
        onIsIdleChanged: Quickshell.execDetached(["niri", "msg", "action", isIdle ? "power-off-monitors" : "power-on-monitors"])
    }
    IdleMonitor {
        timeout: 900
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) Quickshell.execDetached(["systemctl", "suspend"])
    }
}
