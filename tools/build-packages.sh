#!/usr/bin/env bash
# Kavis — packages/ altındaki .deb'leri derler
#
# Kullanım:
#   tools/build-packages.sh            # hepsini derle
#   tools/build-packages.sh kavis-theme [...]
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
	kavis-theme)
		install -d packages/kavis-theme/src/logo
		install -m644 assets/logo/koyu-k-logo.svg \
			packages/kavis-theme/src/logo/koyu-k-logo.svg
		install -m644 assets/logo/acik-k-logo.svg \
			packages/kavis-theme/src/logo/acik-k-logo.svg
		;;
	kavis-panel)
		# Ortak GTK başlangıcı (madde 61) + ortak metin tablosu:
		# kanonik kopyalar packages/kavis-common/; her GTK paketi
		# derlemede kendi src ağacına alır (kopyalar .gitignore'da).
		install -m644 packages/kavis-common/appinit.vala \
			packages/kavis-panel/src/logic/appinit.vala
		# Emoji/kaomoji/sembol verisi + üretilen adlar (bölüm 5):
		# kanonik kopya kavis-common'da, paneli birleşik panel kullanır.
		install -m644 packages/kavis-common/picker_data.vala \
			packages/kavis-panel/src/logic/picker_data.vala
		install -m644 packages/kavis-common/emoji_names.vala \
			packages/kavis-panel/src/logic/emoji_names.vala
		install -m644 packages/kavis-common/power.vala \
			packages/kavis-panel/src/logic/power.vala
		install -m644 packages/kavis-common/config.vala \
			packages/kavis-panel/src/logic/config.vala
		install -m644 packages/kavis-common/powerplan.vala \
			packages/kavis-panel/src/logic/powerplan.vala
		install -m644 packages/kavis-common/brightness.vala \
			packages/kavis-panel/src/logic/brightness.vala
		install -m644 packages/kavis-common/theme.vala \
			packages/kavis-panel/src/logic/theme.vala
		# Çeviriler (Grup D işi c): po/ kanonik, panel derlemede
		# msgfmt ile .mo üretir ve kavis.mo'yu paket olarak taşır.
		rm -rf packages/kavis-panel/po
		cp -r po packages/kavis-panel/po
		;;
	kavis-settings)
		install -d packages/kavis-settings/src/logic
		install -m644 packages/kavis-common/appinit.vala \
			packages/kavis-settings/src/appinit.vala
		install -m644 packages/kavis-common/headerbar.vala \
			packages/kavis-settings/src/headerbar.vala
		install -m644 packages/kavis-common/config.vala \
			packages/kavis-settings/src/logic/config.vala
		install -m644 packages/kavis-common/powerplan.vala \
			packages/kavis-settings/src/logic/powerplan.vala
		install -m644 packages/kavis-common/brightness.vala \
			packages/kavis-settings/src/logic/brightness.vala
		install -m644 packages/kavis-common/theme.vala \
			packages/kavis-settings/src/logic/theme.vala
		# H4: donanım/sistem okuyucusu Ayarlar ve Görev Yöneticisi'nde ortak.
		install -m644 packages/kavis-common/sysinfo.vala \
			packages/kavis-settings/src/logic/sysinfo.vala
		;;
	kavis-tools)
		install -d packages/kavis-tools/src
		install -m644 packages/kavis-common/appinit.vala \
			packages/kavis-tools/src/appinit.vala
		install -m644 packages/kavis-common/headerbar.vala \
			packages/kavis-tools/src/headerbar.vala
		# Palet (B2): tema kavis.conf'tan okunur — config.vala da gerek.
		install -m644 packages/kavis-common/config.vala \
			packages/kavis-tools/src/config.vala
		install -m644 packages/kavis-common/theme.vala \
			packages/kavis-tools/src/theme.vala
		install -m644 packages/kavis-common/sysinfo.vala \
			packages/kavis-tools/src/sysinfo.vala
		# Güç eylemleri (6d): Ctrl+Alt+Del ekranı panelin güç
		# menüsüyle aynı logind komutlarını kullanır.
		install -m644 packages/kavis-common/power.vala \
			packages/kavis-tools/src/power.vala
		;;
	kavis-boot)
		install -d packages/kavis-boot/src/boot
		# Madde 30: splash'te fotoğraf yok, HER ZAMAN koyu logo.
		# boot-image.png artık kullanılmıyor (assets/'te duruyor).
		install -m644 assets/logo/koyu-k-logo.svg \
			packages/kavis-boot/src/boot/koyu-k-logo.svg
		install -m644 assets/boot/boot-sound.mp3 \
			packages/kavis-boot/src/boot/boot-sound.mp3
		# Ürün adı tek kaynaktan: tema paketindeki os-release.
		install -m644 packages/kavis-theme/src/os-release \
			packages/kavis-boot/src/boot/os-release
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
