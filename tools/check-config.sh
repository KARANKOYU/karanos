#!/usr/bin/env bash
# Karan OS — push etmeden önce çalıştırılacak hızlı kontroller
#
# ISO derlemesi CI'da 40 dakika sürüyor. Yazım hatası yüzünden o süreyi
# harcamamak için sözdizimi ve dosya bütünlüğü burada kontrol edilir.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

fail=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31m✗ %s\033[0m\n' "$*"; fail=1; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }

echo "==> POSIX sh script'leri"
for f in iso/auto/config iso/auto/build iso/auto/clean \
         iso/config/hooks/normal/*.hook.chroot \
         iso/config/includes.chroot/usr/lib/karanos/*; do
	[[ -f "$f" ]] || continue
	if sh -n "$f" 2>/dev/null; then ok "$f"; else bad "$f — sözdizimi hatası"; fi
done

echo
echo "==> bash script'leri"
for f in tools/*.sh; do
	if bash -n "$f" 2>/dev/null; then ok "$f"; else bad "$f — sözdizimi hatası"; fi
done

echo
echo "==> Çalıştırma izinleri"
for f in iso/auto/config iso/auto/build iso/auto/clean \
         iso/config/hooks/normal/*.hook.chroot \
         iso/config/includes.chroot/usr/lib/karanos/boot-check \
         tools/*.sh; do
	[[ -f "$f" ]] || continue
	if [[ -x "$f" ]]; then ok "$f"; else bad "$f — çalıştırma izni yok (chmod +x)"; fi
done

echo
echo "==> GitHub Actions YAML"
for f in .github/workflows/*.yml; do
	if python3 -c "import yaml,sys; yaml.safe_load(open('$f'))" 2>/dev/null; then
		ok "$f"
	else
		bad "$f — geçersiz YAML"
	fi
done

echo
echo "==> Elle konulacak kaynak dosyalar"
[[ -f assets/logo/k-logo.svg ]] && ok "assets/logo/k-logo.svg" \
	|| bad "assets/logo/k-logo.svg eksik"
[[ -f assets/boot/boot-image.png ]] && ok "assets/boot/boot-image.png" \
	|| warn "assets/boot/boot-image.png henüz konulmadı (3. aşamada lazım)"
[[ -f assets/boot/boot-sound.mp3 ]] && ok "assets/boot/boot-sound.mp3" \
	|| warn "assets/boot/boot-sound.mp3 henüz konulmadı (3. aşamada lazım)"

echo
echo "==================================================="
if (( fail == 0 )); then
	echo "TAMAM — push edebilirsin."
	echo "Paket adlarını da doğrulamak için: tools/check-packages.sh"
	exit 0
else
	echo "HATA — yukarıdaki ✗ satırlarını düzelt."
	exit 1
fi
