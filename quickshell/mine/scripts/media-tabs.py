"""Read media tabs from the existing Plasma browser integration over the session bus."""
import json
import sys
from urllib.parse import urlsplit

from gi.repository import Gio, GLib

BUS = Gio.bus_get_sync(Gio.BusType.SESSION, None)
DBUS = "org.freedesktop.DBus"
RUNNER = "org.kde.krunner1"


def call(dest, path, interface, method, args=None):
    return BUS.call_sync(dest, path, interface, method, args, None,
                         Gio.DBusCallFlags.NO_AUTO_START, 1800, None)


def browser_tabs(request):
    def process_id(name):
        return call(DBUS, "/org/freedesktop/DBus", DBUS, "GetConnectionUnixProcessID",
                    GLib.Variant("(s)", (name,))).unpack()[0]

    names, = call(DBUS, "/org/freedesktop/DBus", DBUS, "ListNames").unpack()
    runners = [n for n in names if n == "org.kde.plasma.browser_integration"
               or n.startswith(("org.kde.plasma.browser_integration-", "org.kde.plasma.browser_integration."))]
    owners = {process_id(name): name for name in request if name in names}
    result = {}
    for runner in runners:
        player = owners.get(process_id(runner))
        if not player:
            continue
        hints = request[player]
        # The runner caches its last search until the client ends the query.
        matches = call(runner, "/TabsRunner", RUNNER, "Match", GLib.Variant("(s)", ("/",))).get_child_value(0)
        call(runner, "/TabsRunner", RUNNER, "Teardown")
        tabs = []
        for index in range(matches.n_children()):
            # Skip the runner's icon-data byte arrays when reading tab properties.
            row = matches.get_child_value(index)
            key, title, icon = (row.get_child_value(i).get_string() for i in range(3))
            value = row.get_child_value(5).lookup_value("urls", GLib.VariantType.new("as"))
            urls = value.unpack() if value else []
            if not urls or urlsplit(urls[0]).scheme not in ("https", "http"):
                continue
            url = urls[0]
            audible = icon == "audio-volume-high"
            if (audible or icon == "audio-volume-muted" or url == hints["url"]
                    or title in hints["titles"] or hints["known"].get(key) == url):
                tabs.append(dict(id=key, title=title, url=url, audible=audible))
        result[player] = tabs
    return result


for line in sys.stdin:
    try:
        print(json.dumps(browser_tabs(json.loads(line)), ensure_ascii=False), flush=True)
    except (GLib.Error, ValueError, KeyError, TypeError, OSError):
        # A player or its runner may disappear between ListNames and Match.
        print("{}", flush=True)
