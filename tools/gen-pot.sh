#!/usr/bin/env bash
# Kavis — regenerate po/kavis.pot from the sources (Group D task c).
# The source list comes from git: untracked files such as the
# appinit/strings build copies stay out automatically.
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
# Shell scripts (item 44 terminal-tips): gettext '...' calls.
git ls-files 'iso/config/includes.chroot/usr/share/kavis/*.sh' \
	| sort | xgettext \
		--language=Shell --from-code=UTF-8 \
		--join-existing \
		--files-from=- \
		-o po/kavis.pot
echo "po/kavis.pot updated ($(grep -c '^msgid ' po/kavis.pot) msgids)"
