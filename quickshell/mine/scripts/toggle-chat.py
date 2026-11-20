"""Open or recall the Chrome fallback on the clicked output."""

import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def query(subject):
    return json.loads(subprocess.check_output(["niri", "msg", "-j", subject]))


def action(*args):
    subprocess.run(["niri", "msg", "action", *args], check=True)


def chat_window():
    return next((w for w in query("windows")
                 if (w["app_id"] or "").startswith("chrome-chatgpt.com__-")), None)


def show_browser(output):
    workspaces = query("workspaces")
    active = next(w for w in workspaces if w["output"] == output and w["is_active"])
    chat = chat_window()
    if chat is None:
        if not active["is_focused"]:
            action("focus-monitor", output)
        subprocess.Popen(["google-chrome-stable", "--app=https://chatgpt.com/"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        # Keep rapid clicks during Chrome startup from spawning duplicate windows.
        for _ in range(80):
            if chat_window():
                break
            time.sleep(0.1)
        return

    wid = str(chat["id"])
    source = next(w for w in workspaces if w["id"] == chat["workspace_id"])
    if source["id"] == active["id"]:
        action("focus-window", "--id", wid)
        return

    if source["output"] != output:
        action("move-window-to-monitor", "--id", wid, output)
    else:
        action("move-window-to-workspace", "--window-id", wid, str(active["idx"]))
    action("focus-window", "--id", wid)


if __name__ == "__main__":
    with (Path(os.environ["XDG_RUNTIME_DIR"]) / "mine-chat.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            sys.exit(0)
        show_browser(sys.argv[1])
