#!/usr/bin/env python3
"""Generate docs/test-kapsami.md — task-list item vs. selftest scenario.

Decision 9b (docs/kararlar.md) wants one scenario per item of
docs/gorev-listesi.md, in tests/ui/<item>-<name>.yaml, and a table that
says which items have one. The table is generated, never hand-edited, so
it cannot drift from the scenario directory.

The check is a WARNING for now: five scenarios against seventy-five
items would paint every run red and teach us to ignore it. It turns into
an error once the initial set from decision 9b is in place; `--strict`
already fails today for anyone who wants to try.

Usage: tools/gen-test-coverage.py [--check] [--strict]
  --check   do not write, only report (exit 1 when --strict and gaps)
  --strict  treat missing scenarios as an error
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TASKS = ROOT / "docs" / "gorev-listesi.md"
SCENARIOS = ROOT / "tests" / "ui"
OUTPUT = ROOT / "docs" / "test-kapsami.md"

ITEM_RE = re.compile(r"^(\d+)\.\s+\*\*(.+?)\*\*", re.M)


def items():
    """[(number, title)] from the task list, in file order."""
    text = TASKS.read_text(encoding="utf-8")
    found = []
    for match in ITEM_RE.finditer(text):
        number = int(match.group(1))
        title = match.group(2).rstrip(".").strip()
        # Titles carry a parenthetical date/label often enough that the
        # table reads better without it.
        title = re.sub(r"\s*\(2026[^)]*\)", "", title)
        found.append((number, title))
    return found


def scenarios():
    """{item number: [scenario name]} from the YAML front matter."""
    by_item = {}
    for path in sorted(SCENARIOS.glob("*.yaml")):
        name = path.stem
        item = None
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.startswith("item:"):
                value = line.split(":", 1)[1].strip()
                item = int(value) if value.isdigit() else None
                break
        if item is None:
            print(f"WARNING: {path.name} has no 'item:' line", file=sys.stderr)
            continue
        by_item.setdefault(item, []).append(name)
    return by_item


def table(all_items, by_item):
    lines = [
        "# Test kapsamı — madde başına selftest senaryosu",
        "",
        "Bu dosya `tools/gen-test-coverage.py` ile ÜRETİLİR, elle",
        "düzenlenmez. Kaynaklar: `docs/gorev-listesi.md` maddeleri ve",
        "`tests/ui/*.yaml` senaryolarının `item:` alanı (karar 9b).",
        "",
    ]
    covered = sum(1 for number, _ in all_items if number in by_item)
    lines += [
        f"**Kapsam: {covered} / {len(all_items)} madde.**",
        "",
        "| Madde | Başlık | Senaryo |",
        "|---|---|---|",
    ]
    for number, title in all_items:
        names = by_item.get(number, [])
        cell = ", ".join(f"`{n}`" for n in names) if names else "—"
        lines.append(f"| {number} | {title} | {cell} |")
    orphans = sorted(set(by_item) - {n for n, _ in all_items})
    if orphans:
        lines += ["", "## Listede karşılığı olmayan senaryolar", ""]
        for number in orphans:
            lines.append(f"- madde {number}: "
                         + ", ".join(f"`{n}`" for n in by_item[number]))
    lines.append("")
    return "\n".join(lines)


def main(argv):
    check = "--check" in argv
    strict = "--strict" in argv
    all_items = items()
    by_item = scenarios()
    text = table(all_items, by_item)
    missing = [n for n, _ in all_items if n not in by_item]

    if not check:
        OUTPUT.write_text(text, encoding="utf-8")
        print(f"wrote {OUTPUT.relative_to(ROOT)}")
    elif OUTPUT.exists() and OUTPUT.read_text(encoding="utf-8") != text:
        print("ERROR: docs/test-kapsami.md is stale — run "
              "tools/gen-test-coverage.py", file=sys.stderr)
        return 1

    covered = len(all_items) - len(missing)
    print(f"coverage: {covered}/{len(all_items)} items have a scenario")
    if missing:
        level = "ERROR" if strict else "warning"
        print(f"{level}: no scenario for items "
              + ", ".join(str(n) for n in missing[:20])
              + (" …" if len(missing) > 20 else ""), file=sys.stderr)
        if strict:
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
