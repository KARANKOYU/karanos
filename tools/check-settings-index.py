#!/usr/bin/env python3
"""Keep the Settings index and the shortcut catalogue honest (item 74).

Both are declarative tables that sit next to the code they describe,
and both are only useful while they still agree with it:

  * catalog.vala is what the search box searches. Pages are built
    lazily, so the search cannot ask a page what is in it — the index
    has to be written down. A row renamed in a page and not here sends
    the user to a setting that no longer has that name.
  * shortcuts.list is what the openbox hook, Settings and the selftest
    generator all read. Its ids need a translated label.

This is not a hypothetical: before item 74 the shortcut list in
Settings said Ctrl+Win+Left/Right switched desktops while the hook bound
Ctrl+Alt+Left/Right, and nobody noticed for two rounds.

Usage: tools/check-settings-index.py
Exit code 1 on any mismatch; the lines above say which.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UI = ROOT / "packages" / "kavis-settings" / "src" / "ui"
LOGIC = ROOT / "packages" / "kavis-settings" / "src" / "logic"
CATALOG = LOGIC / "catalog.vala"
SHORTCUT_SRC = LOGIC / "shortcuts.vala"
SHORTCUTS = (ROOT / "iso" / "config" / "includes.chroot" / "usr" / "share"
             / "kavis" / "shortcuts.list")

# The page file of each section id. "system" is page_system.vala
# because `system` is a Vala keyword-ish name the function had to avoid.
PAGE = {
    "appearance": "page_appearance.vala",
    "display": "page_display.vala",
    "sound": "page_sound.vala",
    "keyboard": "page_keyboard.vala",
    "power": "page_power.vala",
    "network": "page_network.vala",
    "taskbar": "page_taskbar.vala",
    "hardware": "page_hardware.vala",
    "system": "page_system.vala",
}

# A title in the table: either _("…") or a bare "…" (brand names like
# Wi-Fi are not translated).
TITLE = r'(?:_\(\s*)?"((?:[^"\\]|\\.)*)"\)?'
SUB_RE = re.compile(r'\{\s*"([a-z]+)",\s*"([a-z-]+)",\s*' + TITLE)
ITEM_RE = re.compile(r'\{\s*"([a-z]+)",\s*"([a-z-]+)",\s*' + TITLE + r'\s*,')

problems = []


def block(text, name):
    """The body of `public X name () { return { … }; }`."""
    start = text.index("public %s" % name)
    open_brace = text.index("return {", start)
    depth = 0
    for i in range(open_brace + 7, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[open_brace:i]
    raise SystemExit("ERROR: could not read the %s table" % name)


def main():
    for path in (CATALOG, SHORTCUT_SRC, SHORTCUTS):
        if not path.exists():
            print("ERROR: %s is missing" % path.relative_to(ROOT),
                  file=sys.stderr)
            return 1

    text = CATALOG.read_text(encoding="utf-8")
    subs = SUB_RE.findall(block(text, "Sub[] subs"))
    items = ITEM_RE.findall(block(text, "Item[] items"))
    if not subs or not items:
        print("ERROR: catalog.vala tables did not parse", file=sys.stderr)
        return 1

    known_subs = {(section, sub): title for section, sub, title in subs}
    shortcut_src = SHORTCUT_SRC.read_text(encoding="utf-8")
    pages = {}
    for section, filename in PAGE.items():
        page = UI / filename
        pages[section] = page.read_text(encoding="utf-8") if page.exists() else None

    # 1. Every sub-section is opened by its page.
    for section, sub, title in subs:
        if pages.get(section) is None:
            problems.append("subs(): unknown section %r" % section)
            continue
        if 'subsection (body, "%s"' % sub not in pages[section]:
            problems.append(
                'subs(): %s > %s has no subsection() call in %s'
                % (section, sub, PAGE[section]))

    # 2. Every search entry points at a real sub-section, and its title
    #    still exists in that page.
    for section, sub, title in items:
        if (section, sub) not in known_subs:
            problems.append("items(): %s > %s is not in subs()"
                            % (section, sub))
            continue
        page = pages.get(section)
        if page is None:
            problems.append("items(): unknown section %r" % section)
            continue
        # Three places a title may legitimately live: the page (an
        # ordinary row), shortcuts.vala (the shortcut list builds its
        # own rows), or the sub-section heading itself — some entries
        # describe a whole block (Wallpaper, VPN, About) rather than
        # one row, and pointing the search at the block is right.
        if ('"%s"' % title not in page
                and '"%s"' % title not in shortcut_src
                and known_subs[(section, sub)] != title):
            problems.append('items(): "%s" is no longer in %s'
                            % (title, PAGE[section]))

    # 3. Every shortcut in the catalogue has a translated label and a
    #    known group.
    groups = set(re.findall(r'case "([a-z]+)":\s*return _\(',
                            shortcut_src.split("public string label")[0]))
    for raw in SHORTCUTS.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        fields = [f.strip() for f in line.split("|")]
        if len(fields) != 4:
            problems.append("shortcuts.list: not four fields: %s" % line)
            continue
        entry_id, group = fields[0], fields[1]
        if 'case "%s":' % entry_id not in shortcut_src:
            problems.append("shortcuts.list: %s has no translated label"
                            % entry_id)
        if group not in groups:
            problems.append("shortcuts.list: %s is in unknown group %r"
                            % (entry_id, group))

    if problems:
        for problem in problems:
            print("  ERROR: %s" % problem, file=sys.stderr)
        return 1
    print("settings index: %d sub-sections, %d search entries, "
          "every title and label still exists" % (len(subs), len(items)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
