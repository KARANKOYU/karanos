#!/usr/bin/env bash
# Karan OS — paket listelerini Debian trixie arşivine karşı doğrula
#
# ISO'yu yerelde derlemiyoruz, ama paket adı yazım hatası yüzünden
# 40 dakikalık CI derlemesini çöpe atmak da istemiyoruz.
# Bu script Debian'ın paket indeksini indirip iso/config/package-lists/
# altındaki her adın gerçekten var olduğunu kontrol eder.
#
# Kullanım:  tools/check-packages.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIST_DIR="$REPO_ROOT/iso/config/package-lists"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/karanos-pkgcheck"
SUITE="trixie"
MIRROR="https://deb.debian.org/debian"
AREAS=(main contrib non-free non-free-firmware)

mkdir -p "$CACHE_DIR"

echo "==> Debian $SUITE paket indeksleri (önbellek: $CACHE_DIR)"
INDEX="$CACHE_DIR/paketler.txt"

if [[ ! -s "$INDEX" || -n "${REFRESH:-}" ]]; then
	: > "$INDEX"
	for area in "${AREAS[@]}"; do
		url="$MIRROR/dists/$SUITE/$area/binary-amd64/Packages.xz"
		echo "    indiriliyor: $area"
		curl -fsSL "$url" | xz -d | grep -E '^(Package|Provides): ' >> "$INDEX"
	done
	# "Provides" satırlarındaki sanal paketleri de ayıkla
	{
		grep '^Package: ' "$INDEX" | cut -d' ' -f2
		grep '^Provides: ' "$INDEX" | cut -d' ' -f2- | tr ',' '\n' \
			| sed 's/(.*)//' | tr -d ' '
	} | sort -u > "$INDEX.tmp"
	mv "$INDEX.tmp" "$INDEX"
fi

echo "    $(wc -l < "$INDEX") paket adı yüklendi"
echo

fail=0
total=0

for list in "$LIST_DIR"/*.list.chroot; do
	echo "==> $(basename "$list")"
	while IFS= read -r line; do
		pkg="${line%%#*}"
		pkg="$(echo "$pkg" | tr -d '[:space:]')"
		[[ -z "$pkg" ]] && continue
		total=$((total + 1))
		if grep -qxF "$pkg" "$INDEX"; then
			printf '    \033[32m✓\033[0m %s\n' "$pkg"
		else
			printf '    \033[31m✗ %s — trixie/amd64 arşivinde YOK\033[0m\n' "$pkg"
			fail=$((fail + 1))
		fi
	done < "$list"
	echo
done

echo "==================================================="
if (( fail == 0 )); then
	echo "TAMAM: $total paketin hepsi Debian $SUITE arşivinde var."
	exit 0
else
	echo "HATA: $total paketten $fail tanesi bulunamadı."
	echo "Adı düzelt veya paketi listeden çıkar, sonra tekrar çalıştır."
	exit 1
fi
