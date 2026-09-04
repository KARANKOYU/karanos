#!/usr/bin/env bash
# Kavis — build the .deb packages under packages/
#
# Usage:
#   tools/build-packages.sh            # build all
#   tools/build-packages.sh kavis-theme [...]
#
# Output: out/packages/*.deb
#
# Stage 13 will set up a real APT repository with aptly. Until then the
# ISO workflow downloads these .deb files as an artifact and drops them
# into live-build's config/packages.chroot/ directory.

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
	echo "Nothing to build under packages/." >&2
	exit 1
fi

# Asset files live in one place in the repo (assets/) and are copied into
# the package tree. The copy is in .gitignore — so two copies never
# drift apart.
prepare_sources() {
	# Selftest scenarios (item 72): canonical location tests/ui/, the
	# copy in the package tree is gitignored.
	mkdir -p packages/kavis-selftest/scenarios
	install -m644 tests/ui/*.yaml packages/kavis-selftest/scenarios/
	case "$1" in
	kavis-theme)
		install -d packages/kavis-theme/src/logo
		install -m644 assets/logo/koyu-k-logo.svg \
			packages/kavis-theme/src/logo/koyu-k-logo.svg
		install -m644 assets/logo/acik-k-logo.svg \
			packages/kavis-theme/src/logo/acik-k-logo.svg
		;;
	kavis-panel)
		# Shared GTK startup (item 61) + shared string table: canonical
		# copies in packages/kavis-common/; every GTK package pulls them
		# into its own src tree at build time (copies are gitignored).
		install -m644 packages/kavis-common/appinit.vala \
			packages/kavis-panel/src/logic/appinit.vala
		# Emoji/kaomoji/symbol data + generated names (section 5):
		# canonical copy in kavis-common, used by the unified picker.
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
		# C1: the design animation curve as a function — kavis-snap
		# animates the preview and the settle itself.
		install -m644 packages/kavis-common/easing.vala \
			packages/kavis-panel/src/logic/easing.vala
		# Night light schedule (F-Display): the panel is the one process
		# that applies it, Settings only writes the config.
		install -m644 packages/kavis-common/sunclock.vala \
			packages/kavis-panel/src/logic/sunclock.vala
		install -m644 packages/kavis-common/nightlight.vala \
			packages/kavis-panel/src/logic/nightlight.vala
		# Idle screen-off and sleep (item 51): the panel is the watcher.
		install -m644 packages/kavis-common/idlewatch.vala \
			packages/kavis-panel/src/logic/idlewatch.vala
		# F4: the xkeyboard-config catalogue is read by Settings
		# (full list) and by the panel (the configured layouts).
		install -m644 packages/kavis-common/xkb.vala \
			packages/kavis-panel/src/logic/xkb.vala
		# Translations (Group D task c): po/ is canonical; the panel
		# build runs msgfmt and ships kavis.mo in the package.
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
		install -m644 packages/kavis-common/xkb.vala \
			packages/kavis-settings/src/logic/xkb.vala
		# H4: the hardware/system reader is shared by Settings and Task Manager.
		install -m644 packages/kavis-common/sysinfo.vala \
			packages/kavis-settings/src/logic/sysinfo.vala
		# Night light: Settings shows the schedule, the panel applies it.
		install -m644 packages/kavis-common/sunclock.vala \
			packages/kavis-settings/src/logic/sunclock.vala
		install -m644 packages/kavis-common/nightlight.vala \
			packages/kavis-settings/src/logic/nightlight.vala
		;;
	kavis-taskmanager)
		# G1: the task manager is its own package now. It needs the
		# same shared sources kavis-tools used to give it — canonical
		# copies in packages/kavis-common/, copies gitignored.
		install -d packages/kavis-taskmanager/src
		install -m644 packages/kavis-common/appinit.vala \
			packages/kavis-taskmanager/src/appinit.vala
		install -m644 packages/kavis-common/headerbar.vala \
			packages/kavis-taskmanager/src/headerbar.vala
		# Palette (B2): the theme is read from kavis.conf — config.vala needed too.
		install -m644 packages/kavis-common/config.vala \
			packages/kavis-taskmanager/src/config.vala
		install -m644 packages/kavis-common/theme.vala \
			packages/kavis-taskmanager/src/theme.vala
		# H4: the hardware/system reader is shared with Settings.
		install -m644 packages/kavis-common/sysinfo.vala \
			packages/kavis-taskmanager/src/sysinfo.vala
		;;
	kavis-tools)
		install -d packages/kavis-tools/src
		install -m644 packages/kavis-common/appinit.vala \
			packages/kavis-tools/src/appinit.vala
		install -m644 packages/kavis-common/headerbar.vala \
			packages/kavis-tools/src/headerbar.vala
		# Palette (B2): the theme is read from kavis.conf — config.vala needed too.
		install -m644 packages/kavis-common/config.vala \
			packages/kavis-tools/src/config.vala
		install -m644 packages/kavis-common/theme.vala \
			packages/kavis-tools/src/theme.vala
		# fastfetch DE line (item 71): product name from os-release.
		install -m644 packages/kavis-theme/src/os-release \
			packages/kavis-tools/fastfetch/os-release
		# Power actions (6d): the Ctrl+Alt+Del screen uses the same
		# logind commands as the panel's power menu.
		install -m644 packages/kavis-common/power.vala \
			packages/kavis-tools/src/power.vala
		;;
	kavis-boot)
		install -d packages/kavis-boot/src/boot
		# Item 30: no photo in the splash, ALWAYS the dark logo.
		# boot-image.png is no longer used (still kept in assets/).
		install -m644 assets/logo/koyu-k-logo.svg \
			packages/kavis-boot/src/boot/koyu-k-logo.svg
		install -m644 assets/boot/boot-sound.mp3 \
			packages/kavis-boot/src/boot/boot-sound.mp3
		# Product name from a single source: the theme package's os-release.
		install -m644 packages/kavis-theme/src/os-release \
			packages/kavis-boot/src/boot/os-release
		;;
	esac
}

for pkg in "${targets[@]}"; do
	dir="packages/$pkg"
	[[ -f "$dir/debian/control" ]] || {
		echo "ERROR: $dir/debian/control missing" >&2
		exit 1
	}
	echo "==> building $pkg"
	prepare_sources "$pkg"
	( cd "$dir" && dpkg-buildpackage -us -uc -b --no-sign )
	# dpkg-buildpackage drops the .deb in the parent directory (packages/)
	mv -f packages/"$pkg"_*.deb "$OUT"/ 2>/dev/null || \
		mv -f packages/*.deb "$OUT"/
	rm -f packages/"$pkg"_*.{buildinfo,changes}
done

echo
echo "==> Ready:"
ls -lh "$OUT"
