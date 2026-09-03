#!/usr/bin/env bash
# Kavis — translation check (Group D task c; replaces --metin-denetimi).
#
# 1. kavis.pot is regenerated from the sources and its msgid set is
#    compared with po/kavis.pot (new/removed strings in code mean the
#    committed pot is stale).
# 2. msgcmp: has tr.po translated every msgid (missing-key scan).
# 3. msgfmt --check: syntax + format strings of every po file.
# 4. Is xx.po in sync with the pot (was the generator re-run).
# 5. No "Windows 10/11" in user-visible strings (feedback F5).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

fail=0
fresh=$(mktemp -d)
trap 'rm -rf "$fresh"' EXIT

cp po/kavis.pot "$fresh/old.pot"
tools/gen-pot.sh >/dev/null
if ! diff <(grep '^msgid ' "$fresh/old.pot" | sort) \
          <(grep '^msgid ' po/kavis.pot | sort) >/dev/null; then
	echo "ERROR: po/kavis.pot was stale — commit the output of tools/gen-pot.sh" >&2
	fail=1
else
	# Same msgid set: only the generation timestamp changed — do not
	# dirty the working tree.
	cp "$fresh/old.pot" po/kavis.pot
fi

if ! msgcmp po/tr.po po/kavis.pot; then
	echo "ERROR: tr.po incomplete/mismatched — every msgid must be translated" >&2
	fail=1
fi

for po in po/*.po; do
	if ! msgfmt --check -o /dev/null "$po"; then
		echo "ERROR: $po failed the msgfmt check" >&2
		fail=1
	fi
done

cp po/xx.po "$fresh/old-xx.po"
python3 tools/gen-xx-po.py >/dev/null
if ! diff -q "$fresh/old-xx.po" po/xx.po >/dev/null; then
	echo "ERROR: xx.po was stale — commit the output of tools/gen-xx-po.py" >&2
	fail=1
fi

# 5. No Windows version names in user-visible strings (feedback C5/F5):
# the desktop may look like Windows, but it never names a version.
if grep -nE 'msgid .*(Windows (10|11)|W10|W11)' po/kavis.pot; then
	echo "ERROR: a user-visible string names a Windows version (feedback F5)" >&2
	fail=1
fi

if [ "$fail" -eq 0 ]; then
	echo "translation check: $(grep -c '^msgid ' po/kavis.pot) msgids, no problems"
fi
exit $fail
