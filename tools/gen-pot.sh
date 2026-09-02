#!/usr/bin/env bash
# Kavis — po/kavis.pot'u kaynaktan yeniden üretir (Grup D işi c).
# Kaynak listesi git'ten gelir: appinit/strings kopyaları gibi
# izlenmeyen dosyalar kendiliğinden dışarıda kalır.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
git ls-files 'packages/*/src/**/*.vala' 'packages/*/src/*.vala' 'packages/kavis-common/*.vala' \
	| sort | xgettext \
		--language=C --from-code=UTF-8 \
		--keyword=_ --keyword=N_ \
		--package-name=kavis \
		--msgid-bugs-address=https://github.com/KARANKOYU/karanos/issues \
		--files-from=- \
		-o po/kavis.pot
# Kabuk betikleri (madde 44 terminal-tips): gettext '...' çağrıları.
git ls-files 'iso/config/includes.chroot/usr/share/kavis/*.sh' \
	| sort | xgettext \
		--language=Shell --from-code=UTF-8 \
		--join-existing \
		--files-from=- \
		-o po/kavis.pot
echo "po/kavis.pot guncellendi ($(grep -c '^msgid ' po/kavis.pot) msgid)"
