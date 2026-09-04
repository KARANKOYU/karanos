#!/usr/bin/env python3
"""Generate docs/test-kapsami.md — task-list item vs. selftest scenario.

Decision 9b (docs/kararlar.md) wants one scenario per item of
docs/gorev-listesi.md, in tests/ui/<item>-<name>.yaml, and a table that
says which items have one. The table is generated, never hand-edited, so
it cannot drift from the scenario directory.

An item is only REQUIRED to have one once its group has been built. A
missing scenario for the store (Group G) is not a gap, it is work that
has not happened yet, and counting it as a gap is how a report becomes
noise nobody reads. So every item lands in one of three states:

  covered   a scenario names it
  missing   its group is finished and nothing tests it — an ERROR
  planned   its group has not been built yet

A handful of items have no runtime surface at all (a CI workflow, a
reference review, the roadmap). They are listed in NO_RUNTIME with the
reason, because "why is there no test for this" deserves an answer in
the table rather than in someone's memory.

Usage: tools/gen-test-coverage.py [--check] [--strict]
  --check   do not write, only report (exit 1 when there are gaps)
  --strict  also fail on items whose group is not built yet
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TASKS = ROOT / "docs" / "gorev-listesi.md"
SCENARIOS = ROOT / "tests" / "ui"
OUTPUT = ROOT / "docs" / "test-kapsami.md"

ITEM_RE = re.compile(r"^(\d+)\.\s+\*\*(.+?)\*\*", re.M)
GROUP_RE = re.compile(r"- \*\*GRUP ([A-Z0-9]+)\*\*(.*?)(?=\n- \*\*GRUP |\Z)", re.S)

# Groups that have been built. Extend this when a group closes — that
# is the moment its items start being required to have a scenario.
BUILT_GROUPS = ("A", "A2", "B", "C", "D", "E", "F")

# Items with nothing a running system could be asked about.
NO_RUNTIME = {
    22: "CI iş akışı — çalışan sistemde karşılığı yok",
    47: "referans inceleme, çıktısı docs/referans/",
    58: "yol haritası belgesi",
}


def groups():
    """{group name: [item numbers]} from the task list's group order."""
    text = TASKS.read_text(encoding="utf-8")
    start = text.index("## Yapılış sırası (gruplar)")
    end = text.index("### Grup G ek maddesi")
    found = {}
    for match in GROUP_RE.finditer(text[start:end]):
        # Parentheses hold dates and asides ("3 Eyl", "grup sonu");
        # their numbers are not item numbers.
        body = re.sub(r"\([^)]*\)", " ", match.group(2), flags=re.S)
        found[match.group(1)] = {int(n) for n in re.findall(r"\b(\d{1,2})\b", body)}
    return found


def built_items():
    """Item numbers whose group has been built."""
    by_group = groups()
    numbers = set()
    for name in BUILT_GROUPS:
        numbers |= by_group.get(name, set())
    return numbers


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


def table(all_items, by_item, built):
    lines = [
        "# Test kapsamı — madde başına selftest senaryosu",
        "",
        "Bu dosya `tools/gen-test-coverage.py` ile ÜRETİLİR, elle",
        "düzenlenmez. Kaynaklar: `docs/gorev-listesi.md` maddeleri ve",
        "`tests/ui/*.yaml` senaryolarının `item:` alanı (karar 9b).",
        "",
        "Durum sütunu: **var** = senaryosu yazılmış · **EKSİK** =",
        "grubu bitmiş ama testi yok (hata) · **sırada** = grubu henüz",
        "yapılmadı · **yok** = çalışan sistemde karşılığı olmayan madde.",
        "",
    ]
    covered = sum(1 for number, _ in all_items if number in by_item)
    required = [n for n, _ in all_items
                if n in built and n not in NO_RUNTIME]
    gaps = [n for n in required if n not in by_item]
    lines += [
        f"**Kapsam: {covered} / {len(all_items)} madde; bitmiş gruplarda "
        f"{len(required) - len(gaps)} / {len(required)}.**",
        "",
        "| Madde | Başlık | Durum | Senaryo |",
        "|---|---|---|---|",
    ]
    for number, title in all_items:
        names = by_item.get(number, [])
        cell = ", ".join(f"`{n}`" for n in names) if names else "—"
        if names:
            state = "var"
        elif number in NO_RUNTIME:
            state = "yok — " + NO_RUNTIME[number]
        elif number in built:
            state = "**EKSİK**"
        else:
            state = "sırada"
        lines.append(f"| {number} | {title} | {state} | {cell} |")
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
    built = built_items()
    text = table(all_items, by_item, built)
    # A gap is an item whose group is finished, which has something to
    # test, and does not have a scenario.
    missing = [n for n, _ in all_items
               if n in built and n not in NO_RUNTIME and n not in by_item]
    later = [n for n, _ in all_items
             if n not in built and n not in NO_RUNTIME and n not in by_item]

    if not check:
        OUTPUT.write_text(text, encoding="utf-8")
        print(f"wrote {OUTPUT.relative_to(ROOT)}")
    elif OUTPUT.exists() and OUTPUT.read_text(encoding="utf-8") != text:
        print("ERROR: docs/test-kapsami.md is stale — run "
              "tools/gen-test-coverage.py", file=sys.stderr)
        return 1

    covered = sum(1 for n, _ in all_items if n in by_item)
    print(f"coverage: {covered}/{len(all_items)} items have a scenario "
          f"({len(later)} in groups not built yet)")
    if missing:
        print("ERROR: a finished group has items with no scenario: "
              + ", ".join(str(n) for n in missing), file=sys.stderr)
        return 1
    if later and strict:
        print("ERROR (--strict): items waiting for their group: "
              + ", ".join(str(n) for n in later), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
