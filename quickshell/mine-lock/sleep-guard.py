#!/usr/bin/python
"""Bridge logind sleep, lock and idle-inhibit events to the session services."""

import logging
import os
import subprocess

from gi.repository import Gio, GLib


class SleepGuard:
    def __init__(self):
        self.fd = None
        self.manager = Gio.DBusProxy.new_for_bus_sync(
            Gio.BusType.SYSTEM, Gio.DBusProxyFlags.NONE, None,
            "org.freedesktop.login1", "/org/freedesktop/login1",
            "org.freedesktop.login1.Manager", None,
        )
        self.manager.connect("g-signal", self.on_signal)
        session_path, = self.manager.call_sync(
            "GetSession", GLib.Variant("(s)", (os.environ.get("XDG_SESSION_ID") or "auto",)),
            Gio.DBusCallFlags.NONE, -1, None,
        ).unpack()
        self.session = Gio.DBusProxy.new_for_bus_sync(
            Gio.BusType.SYSTEM, Gio.DBusProxyFlags.DO_NOT_LOAD_PROPERTIES, None,
            "org.freedesktop.login1", session_path, "org.freedesktop.login1.Session", None,
        )
        self.session.connect("g-signal", self.on_session_signal)
        self.manager.connect("g-properties-changed", self.on_manager_change)
        self.inhibit()
        self.sync_idle()

    def on_session_signal(self, proxy, sender, signal, parameters):
        if signal == "Lock":
            subprocess.run(["systemctl", "--user", "--no-block", "start", "mine-lock.service"], check=True)

    def on_manager_change(self, proxy, changed, invalidated):
        if "BlockInhibited" in changed.unpack() or "BlockInhibited" in invalidated:
            self.sync_idle()

    def sync_idle(self):
        # Wayland inhibitors are handled by IdleMonitor. Honor logind idle inhibitors as well.
        reply = self.manager.get_connection().call_sync(
            "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.DBus.Properties",
            "Get", GLib.Variant("(ss)", ("org.freedesktop.login1.Manager", "BlockInhibited")),
            None, Gio.DBusCallFlags.NONE, -1, None,
        )
        action = "stop" if "idle" in reply.unpack()[0].split(":") else "start"
        subprocess.run(["systemctl", "--user", "--no-block", action, "mine-idle.service"], check=True)

    def inhibit(self):
        reply, fds = self.manager.call_with_unix_fd_list_sync(
            "Inhibit", GLib.Variant("(ssss)", (
                "sleep", "mine-lock", "Secure every output before sleep", "delay",
            )), Gio.DBusCallFlags.NONE, -1, None, None,
        )
        self.fd = fds.get(reply.unpack()[0])

    def on_signal(self, proxy, sender, signal, parameters):
        if signal != "PrepareForSleep":
            return
        if parameters.unpack()[0]:
            # A notify service completes its start job only after WlSessionLock.secure.
            result = subprocess.run(["/usr/bin/systemctl", "--user", "start", "mine-lock.service"])
            if result.returncode:
                logging.error("Lock failed to start before sleep")
                return
            if self.fd is not None:
                os.close(self.fd)
                self.fd = None
        elif self.fd is None:
            try:
                self.inhibit()
            except GLib.Error:
                logging.exception("Could not reacquire sleep inhibitor")
                loop.quit()


if __name__ == "__main__":
    loop = GLib.MainLoop()
    guard = SleepGuard()
    loop.run()
