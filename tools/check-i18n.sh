#!/usr/bin/env bash
# Kavis — çeviri denetimi (Grup D işi c; --metin-denetimi'nin yerine).
#
# 1. kavis.pot kaynaktan taze üretilir; po/kavis.pot ile msgid kümesi
#    karşılaştırılır (kodda yeni/az metin varsa pot bayat demektir).
# 2. msgcmp: tr.po her msgid'i çevirmiş mi (eksik anahtar taraması).
# 3. msgfmt --check: tüm po dosyaları sözdizimi + biçim dizgeleri.
# 4. xx.po pot'la senkron mu (üretici yeniden koşulmuş mu).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

hata=0
taze=$(mktemp -d)
trap 'rm -rf "$taze"' EXIT

cp po/kavis.pot "$taze/eski.pot"
tools/gen-pot.sh >/dev/null
if ! diff <(grep '^msgid ' "$taze/eski.pot" | sort) \
          <(grep '^msgid ' po/kavis.pot | sort) >/dev/null; then
	echo "HATA: po/kavis.pot bayattı — tools/gen-pot.sh çıktısı commit edilmeli" >&2
	hata=1
else
	# msgid kümesi aynıysa yalnız üretim zamanı değişmiştir —
	# çalışma ağacını kirletme.
	cp "$taze/eski.pot" po/kavis.pot
fi

if ! msgcmp po/tr.po po/kavis.pot; then
	echo "HATA: tr.po eksik/uyumsuz — her msgid çevrilmeli" >&2
	hata=1
fi

for po in po/*.po; do
	if ! msgfmt --check -o /dev/null "$po"; then
		echo "HATA: $po msgfmt denetiminden geçmedi" >&2
		hata=1
	fi
done

cp po/xx.po "$taze/eski-xx.po"
python3 tools/gen-xx-po.py >/dev/null
if ! diff -q "$taze/eski-xx.po" po/xx.po >/dev/null; then
	echo "HATA: xx.po bayattı — tools/gen-xx-po.py çıktısı commit edilmeli" >&2
	hata=1
fi

if [ "$hata" -eq 0 ]; then
	echo "çeviri denetimi: $(grep -c '^msgid ' po/kavis.pot) msgid, sorun yok"
fi
exit $hata
