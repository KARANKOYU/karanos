#!/usr/bin/env python3
"""Every Kavis window wears the Kavis title bar (feedback, 8 Sep 2026).

Openbox's themerc cannot draw the 46x32 buttons with a full-height hover
fill — that is why kavis-common/headerbar.vala exists and why Settings,
the Task Manager and Tilix all look the same. A window that forgets to
attach it does not look broken; it looks like a window from another
desktop, which is worse, because nothing about it says anything is
wrong. Four of them had drifted that way by 8 Sep: the calculator,
Open with, the previewer and the drive repair window.

So every class deriving from Gtk.Window must either

  * call Kavis.HeaderBar.attach, or
  * be deliberately chrome-less — a POPUP, a splash screen, an
    undecorated window or a full-screen one — which the code has to say
    out loud in the class itself.

Anything else is the drift this exists to catch.

Usage: tools/check-titlebars.py
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# A window with no frame BY DESIGN says so with one of these.
CHROMELESS = [
    "Gtk.WindowType.POPUP",
    "WindowTypeHint.SPLASHSCREEN",
    "WindowTypeHint.NOTIFICATION",
    "WindowTypeHint.DOCK",
    "WindowTypeHint.TOOLTIP",
    "set_decorated (false)",
    "fullscreen ()",
]

CLASS_RE = re.compile(r"^(\s*)public\s+class\s+(\S+)\s*:\s*Gtk\.Window\b",
                      re.MULTILINE)


def bodies(text):
    """(name, body) for every class deriving from Gtk.Window."""
    hits = list(CLASS_RE.finditer(text))
    for i, hit in enumerate(hits):
        end = hits[i + 1].start() if i + 1 < len(hits) else len(text)
        yield hit.group(2), text[hit.start():end]


def main():
    problems = []
    checked = 0
    for path in sorted(ROOT.glob("packages/*/src/**/*.vala")):
        if "/debian/" in str(path):
            continue
        text = path.read_text(encoding="utf-8")
        for name, body in bodies(text):
            checked += 1
            if "HeaderBar.attach" in body:
                continue
            if any(marker in body for marker in CHROMELESS):
                continue
            problems.append(
                "%s: %s has no Kavis title bar and does not say it is "
                "meant to be frameless"
                % (path.relative_to(ROOT), name))

    if problems:
        for problem in problems:
            print("  ERROR: %s" % problem, file=sys.stderr)
        return 1
    print("title bars: %d windows, every one framed or frameless on "
          "purpose" % checked)
    return 0


if __name__ == "__main__":
    sys.exit(main())
