#!/usr/bin/env python3
"""Generate po/xx.po — the pseudo-long test language (Grup D task c).

Every msgstr is the msgid wrapped in guillemets and lengthened ~40%:
untranslated strings show up as plain English on an xx screenshot, and
layouts that break under longer text (DE/FR-sized) break visibly in
the Xvfb screenshot test. Format specifiers survive because the msgid
is copied verbatim. Regenerate whenever kavis.pot changes.
"""

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
POT = REPO / "po/kavis.pot"
XX = REPO / "po/xx.po"


def main() -> int:
    text = POT.read_text(encoding="utf-8")
    blocks = text.split("\n\n")
    out = [
        'msgid ""',
        'msgstr ""',
        '"Project-Id-Version: kavis\\n"',
        '"MIME-Version: 1.0\\n"',
        '"Content-Type: text/plain; charset=UTF-8\\n"',
        '"Content-Transfer-Encoding: 8bit\\n"',
        '"Language: xx\\n"',
        "",
    ]
    count = 0
    for block in blocks[1:]:
        m = re.search(r'msgid "((?:[^"\\]|\\.)*)"', block)
        if m is None or m.group(1) == "":
            continue
        msgid = m.group(1)
        pad = "·" * max(2, int(len(msgid) * 0.4))
        out.append('msgid "%s"' % msgid)
        if msgid.endswith("\\n"):
            # msgfmt kuralı: iki taraf da \n ile bitmeli — dolgu
            # satır sonundan ÖNCE.
            body = msgid[:-2]
            out.append('msgstr "⟪%s%s⟫\\n"' % (body, pad))
        else:
            out.append('msgstr "⟪%s%s⟫"' % (msgid, pad))
        out.append("")
        count += 1
    XX.write_text("\n".join(out), encoding="utf-8")
    print(f"{count} msgstr -> po/xx.po")
    return 0


if __name__ == "__main__":
    sys.exit(main())
