#!/usr/bin/env bash
# Kavis — çeviri yüzdesi üretimi (Grup F dil seçici altyapısı).
#
# po/LINGUAS'taki her dil için msgfmt --statistics ile çevrilen ileti
# sayısını çıkarır; .po dosyası OLMAYAN dil %0'dır. Çıktı JSON — dil
# seçici çalışma anında hesap yapmaz, bu dosyayı okur. Her paket
# derlemesinde yeniden üretilir (kavis-panel debian/rules).
#
# Kullanım: i18n-stats.sh <po-dizini> <cikti.json>

set -euo pipefail

PO_DIR="${1:?po dizini gerekli}"
OUT="${2:?cikti dosyasi gerekli}"

POT="$PO_DIR/kavis.pot"
LINGUAS="$PO_DIR/LINGUAS"
[ -f "$POT" ] || { echo "HATA: $POT yok" >&2; exit 1; }
[ -f "$LINGUAS" ] || { echo "HATA: $LINGUAS yok" >&2; exit 1; }

# Toplam ileti: pot'taki msgid sayısı (başlık girdisi hariç).
total=$(( $(grep -c '^msgid ' "$POT") - 1 ))

{
	printf '{\n'
	first=1
	while read -r lang; do
		case "$lang" in ""|\#*) continue ;; esac
		translated=0
		po="$PO_DIR/$lang.po"
		if [ -f "$po" ]; then
			# Doğrudan po'yu saymak yanıltır: artık kullanılmayan
			# eski girdiler de "çevrildi" görünür (tr %101 çıkmıştı).
			# Önce pot'la birleştir — yalnız güncel msgid'ler kalır;
			# bulanık (fuzzy) çeviri "çevrildi" SAYILMAZ.
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
echo "i18n-stats: $count dil, toplam $total ileti -> $OUT"
