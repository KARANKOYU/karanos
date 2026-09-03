#!/usr/bin/env bash
# Kavis — kavis-* paketlerinin sürümlü bağımlılıkları ISO'daki gerçek
# sürümlerle tutuyor mu? (madde 72, kararlar.md 9a: DEPS-RANGE-OK)
#
# Kullanım: tools/check-deps-range.sh <paket-listesi>
#   paket-listesi: live-build'in chroot.packages.live dosyası
#   (`dpkg-query -W` biçimi: "ad<TAB>sürüm", satır başına bir paket).
#
# packages/*/debian/control içindeki "ad (>= x)" / "ad (<< y)" gibi
# sürümlü Depends girdileri okunur; her biri listedeki sürümle
# `dpkg --compare-versions` üstünden sınanır. Listede olmayan paket
# HATA'dır (bağımlılık kuruluşta zaten patlardı; burada adıyla görünsün).
# Çıkış kodu: 0 = hepsi aralıkta, 1 = en az bir sınır dışı / eksik.
set -eu

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
LISTE=${1:-}
if [ -z "$LISTE" ] || [ ! -r "$LISTE" ]; then
	echo "kullanım: $0 <paket-listesi>" >&2
	exit 2
fi

# Listeden sürüm oku (ad -> sürüm). Mimari ekli adlar (ad:amd64) da
# eşleşsin diye iki nokta öncesi alınır.
surum_bul() {
	awk -v ad="$1" -F'\t' '{ split($1, p, ":"); if (p[1] == ad) { print $2; exit } }' "$LISTE"
}

hata=0
sayi=0
# control dosyalarında yalnız Depends bloğundaki (Build-Depends değil)
# sürümlü girdiler: " openbox (>= 3.6.1)," → openbox / >= / 3.6.1
for kontrol in "$REPO_ROOT"/packages/*/debian/control; do
	paket=$(basename "$(dirname "$(dirname "$kontrol")")")
	# sed: yalnız "ad (op sürüm)" deseni; ${shlibs:Depends} gibi alanlar geçilir
	while IFS='|' read -r ad op sinir; do
		[ -n "$ad" ] || continue
		sayi=$((sayi + 1))
		surum=$(surum_bul "$ad")
		if [ -z "$surum" ]; then
			echo "DEPS-RANGE-FAIL $paket: $ad ($op $sinir) — ISO listesinde yok"
			hata=1
			continue
		fi
		if dpkg --compare-versions "$surum" "$op" "$sinir"; then
			echo "DEPS-RANGE $paket: $ad $surum ($op $sinir) tamam"
		else
			echo "DEPS-RANGE-FAIL $paket: $ad $surum, sınır ($op $sinir) dışında"
			hata=1
		fi
	done < <(awk '/^Depends:/ { icinde = 1; next } /^[A-Z]/ { icinde = 0 } icinde' "$kontrol" \
		| sed -n 's/^ *\([a-z0-9.+-]*\) (\(>=\|<<\|>>\|<=\|=\) \([^)]*\)),\{0,1\}$/\1|\2|\3/p')
done

if [ "$sayi" -eq 0 ]; then
	echo "DEPS-RANGE-FAIL control dosyalarında sürümlü bağımlılık bulunamadı"
	exit 1
fi
if [ "$hata" -eq 0 ]; then
	echo "DEPS-RANGE-OK $sayi sınır aralıkta"
	exit 0
fi
exit 1
