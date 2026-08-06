#!/usr/bin/env bash
# Karan OS — packages/ altındaki .deb'leri derler
#
# Kullanım:
#   tools/build-packages.sh            # hepsini derle
#   tools/build-packages.sh karanos-theme [...]
#
# Çıktı: out/packages/*.deb
#
# 13. aşamada aptly ile gerçek bir APT deposu kurulacak. O zamana kadar
# ISO iş akışı bu .deb'leri yapıt olarak indirip live-build'in
# config/packages.chroot/ dizinine koyuyor.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

OUT="$REPO_ROOT/out/packages"
mkdir -p "$OUT"

if [[ $# -gt 0 ]]; then
	targets=("$@")
else
	targets=()
	for d in packages/*/; do
		[[ -f "$d/debian/control" ]] && targets+=("$(basename "$d")")
	done
fi

if [[ ${#targets[@]} -eq 0 ]]; then
	echo "packages/ altında derlenecek paket yok." >&2
	exit 1
fi

# Kaynak dosyalar depoda tek yerde (assets/) duruyor; paket ağacına
# kopyalanıyorlar. Kopya .gitignore'da — iki yerde durup birbirinden
# ayrı düşmesinler.
prepare_sources() {
	case "$1" in
	karanos-theme)
		install -d packages/karanos-theme/src/logo
		install -m644 assets/logo/k-logo.svg \
			packages/karanos-theme/src/logo/k-logo.svg
		;;
	karanos-boot)
		install -d packages/karanos-boot/src/boot
		install -m644 assets/boot/boot-image.png \
			packages/karanos-boot/src/boot/boot-image.png
		install -m644 assets/boot/boot-sound.mp3 \
			packages/karanos-boot/src/boot/boot-sound.mp3
		;;
	esac
}

for pkg in "${targets[@]}"; do
	dir="packages/$pkg"
	[[ -f "$dir/debian/control" ]] || {
		echo "HATA: $dir/debian/control yok" >&2
		exit 1
	}
	echo "==> $pkg derleniyor"
	prepare_sources "$pkg"
	( cd "$dir" && dpkg-buildpackage -us -uc -b --no-sign )
	# dpkg-buildpackage .deb'i üst dizine (packages/) bırakır
	mv -f packages/"$pkg"_*.deb "$OUT"/ 2>/dev/null || \
		mv -f packages/*.deb "$OUT"/
	rm -f packages/"$pkg"_*.{buildinfo,changes}
done

echo
echo "==> Hazır:"
ls -lh "$OUT"
