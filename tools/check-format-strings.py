#!/usr/bin/env python3
"""Check that every translation uses the same printf arguments (item 34).

WHY THIS EXISTS SEPARATELY FROM msgfmt: msgfmt --check only checks
entries flagged "#, c-format", and a translation written by hand into
po/tr.po carries no flags at all. A Turkish sentence that puts the
number before the unit — natural, and what a translator will do — then
silently swaps the arguments: "%lld errors in %.0f MB" translated as
"%.0f MB içinde %lld hata" makes printf read a double as an integer.
That is a wrong number at best and a crash at worst, and it shipped
undetected until a msgmerge happened to mark the entry fuzzy.

The rule: msgstr must consume the same arguments as msgid, in the same
ORDER unless it uses positional specifiers (%2$.0f), which is exactly
how a translator is meant to reorder them.

Usage: tools/check-format-strings.py po/tr.po [po/xx.po ...]
Exit: 0 = every translation matches, 1 = at least one does not.
"""
import re
import sys

# %[argnum$][flags][width][.precision][length]conversion
SPEC = re.compile(r"%(?:(\d+)\$)?[-+ #0']*[\d*]*(?:\.[\d*]+)?"
                  r"(?:hh|h|ll|l|L|z|j|t)?([diouxXeEfgGaAcspn%])")


def specifiers(text):
    """[(position or None, conversion)] for one format string."""
    found = []
    for match in SPEC.finditer(text):
        if match.group(2) == "%":
            continue          # "%%" is a literal percent, not an argument
        found.append((int(match.group(1)) if match.group(1) else None,
                      match.group(2)))
    return found


def compatible(source, target):
    """Does the translation consume the same arguments as the original?"""
    want = [conversion for _, conversion in specifiers(source)]
    got = specifiers(target)
    if not got and not want:
        return True
    if any(position is not None for position, _ in got):
        # Positional: every reference must be in range and of the right
        # type. Unused arguments are allowed — a translation may not
        # need to mention all of them.
        for position, conversion in got:
            if position is None:
                return False    # mixing the two forms is undefined
            if position < 1 or position > len(want):
                return False
            if want[position - 1] != conversion:
                return False
        return True
    return want == [conversion for _, conversion in got]


def entries(path):
    """[(line, msgid, [msgstr...])] — plurals give several msgstr."""
    result = []
    msgid = None
    current = None
    line_no = 0
    start = 0
    strings = []
    for number, raw in enumerate(open(path, encoding="utf-8"), 1):
        line = raw.rstrip("\n")
        if line.startswith("#"):
            continue
        head = re.match(r'^(msgid|msgid_plural|msgstr(?:\[\d+\])?)\s+"(.*)"$',
                        line)
        if head:
            if head.group(1) == "msgid":
                if msgid is not None:
                    result.append((start, msgid, strings))
                msgid, strings, start = "", [], number
                current = "id"
                msgid += head.group(2)
            elif head.group(1) == "msgid_plural":
                current = "skip"
            else:
                current = "str"
                strings.append(head.group(2))
            continue
        more = re.match(r'^"(.*)"$', line)
        if more and msgid is not None:
            if current == "id":
                msgid += more.group(1)
            elif current == "str" and strings:
                strings[-1] += more.group(1)
    if msgid is not None:
        result.append((start, msgid, strings))
    return result


def main(argv):
    if not argv:
        print(__doc__, file=sys.stderr)
        return 2
    bad = 0
    checked = 0
    for path in argv:
        for line, msgid, strings in entries(path):
            if msgid == "":
                continue          # the header
            for msgstr in strings:
                if msgstr == "":
                    continue      # untranslated: msgcmp's business
                checked += 1
                if not compatible(msgid, msgstr):
                    bad += 1
                    print(f"{path}:{line}: format mismatch\n"
                          f"  msgid  {msgid}\n"
                          f"  msgstr {msgstr}", file=sys.stderr)
    if bad:
        print(f"ERROR: {bad} translation(s) do not take the same "
              f"arguments as the original", file=sys.stderr)
        return 1
    print(f"format strings: {checked} translations take the same arguments")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
