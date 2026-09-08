#!/usr/bin/env python3
"""Text has to be readable in BOTH themes (feedback C, 8 Sep 2026).

The v0.5-test1 VM round: "switch to the light theme and the text breaks
— unreadable, low contrast". It was true, and nothing in CI could have
caught it, because the two halves of the light theme were written in
different places and only one of them was finished:

  * packages/kavis-theme/src/gtk-3.0/gtk-light.css — the GTK theme for
    every application. Careful: it DARKENS the accents for a white
    ground (teal #2DD4BF -> #0F766E, blue -> #2563EB, and its own
    warning/error/success).
  * packages/kavis-panel/src/logic/theme.vala — the palette Kavis' own
    components resolve (@kavis_*). Its light table kept the BRIGHT
    accents. Bright teal on white is 1.7:1: not "low contrast", simply
    not there.

So this measures instead of trusting. Every colour a component paints
TEXT with is checked against every surface that text can sit on, in
both palettes, against WCAG 2.1 contrast:

  4.5:1  body text and secondary text
  3.0:1  large accents (WCAG's large-text threshold)

Disabled text (kavis_text3) is REPORTED with its ratio but not enforced.
WCAG 1.4.3 exempts disabled controls, and the whole point of the colour
is to read as unavailable; holding it to 4.5:1 would mean drawing
disabled text that looks enabled. The number is printed so a change to
it is a decision somebody sees rather than a drift nobody measures.

Usage: tools/check-contrast.py
Exit 1 with the failing pair and its ratio.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# The CANONICAL palette. packages/*/src/logic/theme.vala are copies
# that build-packages.sh writes and .gitignore hides — checking one
# of those would measure a file that is overwritten on every build,
# and pass while the real palette was never touched.
PALETTE = ROOT / "packages" / "kavis-common" / "theme.vala"
GTK_LIGHT = ROOT / "packages" / "kavis-theme" / "src" / "gtk-3.0" / "gtk-light.css"
GTK_DARK = ROOT / "packages" / "kavis-theme" / "src" / "gtk-3.0" / "gtk.css"

BODY = 4.5
LARGE = 3.0

# Which name is text, on which surfaces, at what bar. Written out rather
# than inferred: a checker that guesses which colour is text would be
# guessing about the thing it is supposed to prove.
SURFACES = ["kavis_ground", "kavis_panel", "kavis_surface", "kavis_card",
            "kavis_hover"]
TEXTS = [
    ("kavis_text", BODY),
    ("kavis_text2", BODY),
    ("kavis_menu_category", BODY),
    ("kavis_ok", BODY),
    ("kavis_warn", BODY),
    ("kavis_error", BODY),
    ("kavis_teal", LARGE),
    ("kavis_blue", LARGE),
]
# Text painted ON the accent itself (a button label on the teal fill).
ON_ACCENT = [("kavis_on_teal", "kavis_teal", BODY)]


def parse(text):
    """@define-color name #rrggbb, following one level of aliasing."""
    table = {}
    for name, value in re.findall(
            r"@define-color\s+([A-Za-z0-9_]+)\s+([^;]+);", text):
        table[name] = value.strip()
    out = {}
    for name, value in table.items():
        seen = 0
        while value.startswith("@") and seen < 4:
            value = table.get(value[1:].strip(), value)
            seen += 1
        if re.fullmatch(r"#[0-9A-Fa-f]{6}", value):
            out[name] = value
    return out


def block(text, const):
    """The string body of `private const string NAME = \"\"\"…\"\"\";`"""
    start = text.index("string %s" % const)
    open_q = text.index('"""', start) + 3
    return text[open_q:text.index('"""', open_q)]


def luminance(hex_colour):
    channels = []
    for i in (1, 3, 5):
        c = int(hex_colour[i:i + 2], 16) / 255.0
        channels.append(c / 12.92 if c <= 0.03928
                        else ((c + 0.055) / 1.055) ** 2.4)
    r, g, b = channels
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def ratio(a, b):
    la, lb = luminance(a), luminance(b)
    lo, hi = min(la, lb), max(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def check(label, colours, problems, report):
    checked = 0
    if "kavis_text3" in colours:
        worst = min(
            (ratio(colours["kavis_text3"], colours[s]), s)
            for s in SURFACES if s in colours)
        report.append("%s: disabled text %s is %.2f:1 at its worst (on %s)"
                      % (label, colours["kavis_text3"], worst[0], worst[1]))
    for text_name, bar in TEXTS:
        if text_name not in colours:
            problems.append("%s: %s is not defined" % (label, text_name))
            continue
        for surface in SURFACES:
            if surface not in colours:
                continue
            r = ratio(colours[text_name], colours[surface])
            checked += 1
            if r < bar:
                problems.append(
                    "%s: %s (%s) on %s (%s) is %.2f:1, needs %.1f:1"
                    % (label, text_name, colours[text_name], surface,
                       colours[surface], r, bar))
    for fg, bg, bar in ON_ACCENT:
        if fg in colours and bg in colours:
            r = ratio(colours[fg], colours[bg])
            checked += 1
            if r < bar:
                problems.append(
                    "%s: %s (%s) on %s (%s) is %.2f:1, needs %.1f:1"
                    % (label, fg, colours[fg], bg, colours[bg], r, bar))
    return checked


def main():
    problems = []
    report = []
    total = 0
    palette = PALETTE.read_text(encoding="utf-8")
    for const, label in (("DARK", "panel palette (dark)"),
                         ("LIGHT", "panel palette (light)")):
        total += check(label, parse(block(palette, const)), problems, report)
    for path, label in ((GTK_DARK, "GTK theme (dark)"),
                        (GTK_LIGHT, "GTK theme (light)")):
        if path.exists():
            colours = parse(path.read_text(encoding="utf-8"))
            # The GTK themes define only the names they use; missing
            # ones are not a fault of theirs.
            missing = [n for n, _ in TEXTS if n not in colours]
            for name in missing:
                colours.pop(name, None)
            saved = list(TEXTS)
            try:
                TEXTS[:] = [(n, b) for n, b in TEXTS if n in colours]
                total += check(label, colours, problems, report)
            finally:
                TEXTS[:] = saved
    if problems:
        for problem in problems:
            print("  ERROR: %s" % problem, file=sys.stderr)
        return 1
    for line in report:
        print("  %s" % line)
    print("contrast: %d text/background pairs, all at or above the bar"
          % total)
    return 0


if __name__ == "__main__":
    sys.exit(main())
