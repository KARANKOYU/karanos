#!/usr/bin/env bash
# Kavis — translation percentage generator (Group F language selector infra).
#
# For every language in po/LINGUAS, extracts the translated message count
# with msgfmt --statistics; a language WITHOUT a .po file is 0%. Output is
# JSON — the language selector does no counting at runtime, it reads this
# file. Regenerated on every package build (kavis-panel debian/rules).
#
# Usage: i18n-stats.sh <po-dir> <output.json>

set -euo pipefail

PO_DIR="${1:?po directory required}"
OUT="${2:?output file required}"

POT="$PO_DIR/kavis.pot"
LINGUAS="$PO_DIR/LINGUAS"
[ -f "$POT" ] || { echo "ERROR: $POT missing" >&2; exit 1; }
[ -f "$LINGUAS" ] || { echo "ERROR: $LINGUAS missing" >&2; exit 1; }

# Total messages: msgid count in the pot (minus the header entry).
total=$(( $(grep -c '^msgid ' "$POT") - 1 ))

{
	printf '{\n'
	first=1
	while read -r lang; do
		case "$lang" in ""|\#*) continue ;; esac
		translated=0
		po="$PO_DIR/$lang.po"
		if [ -f "$po" ]; then
			# Counting the po directly misleads: obsolete entries no
			# longer in use also look "translated" (tr came out at 101%).
			# Merge with the pot first — only current msgids remain;
			# fuzzy translations are NOT counted as translated.
			stats=$(LC_ALL=C msgmerge --quiet --no-fuzzy-matching \
					"$po" "$POT" -o - 2>/dev/null \
				| LC_ALL=C msgfmt --statistics -o /dev/null - 2>&1 \
				| tail -1)
			translated=$(printf '%s' "$stats" \
				| sed -n 's/^\([0-9]*\) translated.*/\1/p')
			translated="${translated:-0}"
		fi
		percent=$(( total > 0 ? translated * 100 / total : 0 ))
		[ "$first" -eq 1 ] || printf ',\n'
		first=0
		printf '  "%s": {"translated": %d, "total": %d, "percent": %d}' \
			"$lang" "$translated" "$total" "$percent"
	done < "$LINGUAS"
	printf '\n}\n'
} > "$OUT"

count=$(grep -c '"translated"' "$OUT")
echo "i18n-stats: $count languages, $total messages total -> $OUT"
