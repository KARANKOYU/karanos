#!/usr/bin/env python3
"""Update the "Çeviri durumu" table in README.md (Grup F i18n infra).

Reads the stats JSON produced by tools/i18n-stats.sh and rewrites the
block between the ceviri-durumu markers. Ordering mirrors the future
language selector: 100% first, then descending, then 0% alphabetical.
CI refreshes this on every push ([skip ci] commit).

Usage: gen-ceviri-tablosu.py <i18n-stats.json> [README.md]
"""

import json
import sys
from pathlib import Path

MARK_BEGIN = "<!-- ceviri-durumu-basla -->"
MARK_END = "<!-- ceviri-durumu-bitir -->"


def bar(percent):
    filled = round(percent / 10)
    return "▰" * filled + "▱" * (10 - filled)


def main():
    if len(sys.argv) < 2:
        print("kullanim: gen-ceviri-tablosu.py <stats.json> [README.md]",
              file=sys.stderr)
        return 2
    stats = json.load(open(sys.argv[1]))
    readme = Path(sys.argv[2] if len(sys.argv) > 2 else "README.md")

    items = sorted(stats.items(),
                   key=lambda kv: (-kv[1]["percent"], kv[0]))
    translated = [(k, v) for k, v in items if v["percent"] > 0]
    pending = sorted((k for k, v in items if v["percent"] == 0))

    lines = [MARK_BEGIN,
             "| Dil | Durum |",
             "|---|---|"]
    for lang, v in translated:
        lines.append("| `%s` | %s %%%d (%d/%d) |"
                     % (lang, bar(v["percent"]), v["percent"],
                        v["translated"], v["total"]))
    if pending:
        lines.append("| _çeviri bekleyenler_ | `%s` |"
                     % "` `".join(pending))
    lines.append(MARK_END)

    text = readme.read_text()
    if MARK_BEGIN not in text or MARK_END not in text:
        print("HATA: README işaretleri yok", file=sys.stderr)
        return 1
    before = text[:text.index(MARK_BEGIN)]
    after = text[text.index(MARK_END) + len(MARK_END):]
    readme.write_text(before + "\n".join(lines) + after)
    print(f"çeviri tablosu: {len(translated)} dilde çeviri var, "
          f"{len(pending)} dil bekliyor")
    return 0


if __name__ == "__main__":
    sys.exit(main())
