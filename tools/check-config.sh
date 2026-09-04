#!/usr/bin/env bash
# Kavis — quick checks to run before pushing
#
# The ISO build takes 40 minutes in CI. So that a typo does not burn that
# time, syntax and file integrity are checked here first.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

fail=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31m✗ %s\033[0m\n' "$*"; fail=1; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }

# Which interpreter to check with is decided from the file's own shebang.
# includes.chroot holds both sh and Python scripts; trying `sh -n` on all
# of them produced false errors on the Python files.
check_syntax() {
	local f="$1" line
	line=$(head -1 "$f")
	case "$line" in
	*python*) python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$f" 2>/dev/null ;;
	*bash*) bash -n "$f" 2>/dev/null ;;
	*) sh -n "$f" 2>/dev/null ;;
	esac
}

echo "==> Script syntax"
for f in iso/auto/config iso/auto/build iso/auto/clean \
         iso/config/hooks/normal/*.hook.* \
         iso/config/includes.chroot/usr/lib/kavis/* \
         packages/*/tools/*.py \
         packages/*/debian/pre* packages/*/debian/post* \
         tools/*.sh; do
	[[ -f "$f" ]] || continue
	if check_syntax "$f"; then ok "$f"; else bad "$f — syntax error"; fi
done

echo
echo "==> Execute permissions"
for f in iso/auto/config iso/auto/build iso/auto/clean \
         iso/config/hooks/normal/*.hook.* \
         iso/config/includes.chroot/usr/lib/kavis/* \
         packages/*/debian/rules packages/*/tools/*.py \
         tools/*.sh; do
	[[ -f "$f" ]] || continue
	if [[ -x "$f" ]]; then ok "$f"; else bad "$f — not executable (chmod +x)"; fi
done

echo
echo "==> GitHub Actions YAML"
for f in .github/workflows/*.yml; do
	if python3 -c "import yaml,sys; yaml.safe_load(open('$f'))" 2>/dev/null; then
		ok "$f"
	else
		bad "$f — invalid YAML"
	fi
done

echo
echo "==> Host guard in the chroot hooks (4 Sep 2026 incident)"
# A hook without the guard can wreck a developer machine: these scripts
# rewrite /home, /etc, the initramfs and systemd state of whatever system
# they run on. The marker file only exists inside the build chroot.
for f in iso/config/hooks/normal/*.hook.chroot; do
	if grep -q '/usr/share/kavis/build-marker' "$f"; then
		ok "$(basename "$f") — host guard present"
	else
		bad "$(basename "$f") — host guard MISSING"
	fi
done
# The root helpers are the other thing that must never run on a
# workstation; set-power writes /sys and /etc/systemd.
for helper in packages/kavis-settings/scripts/set-power \
	packages/kavis-settings/scripts/set-dns \
	packages/kavis-settings/scripts/hw-report; do
	if grep -q '/run/systemd/system' "$helper" \
		&& grep -q '/usr/share/kavis/build-marker' "$helper"; then
		ok "$(basename "$helper") — host guard present"
	else
		bad "$(basename "$helper") — host guard MISSING (it writes /sys and /etc)"
	fi
done
[[ -f iso/config/includes.chroot/usr/share/kavis/build-marker ]] \
	&& ok "build-marker ships in includes.chroot" \
	|| bad "includes.chroot/usr/share/kavis/build-marker missing — every hook would refuse to run"

echo
echo "==> Application names (D1)"
# The title bar is rewritten from this map, the menu comes from the
# .desktop overrides. A name in one and not the other means the same
# program is called two things on the same screen.
TITLE_MAP=iso/config/includes.chroot/etc/kavis/window-title-map.conf
APP_DIR=iso/config/includes.chroot/etc/kavis/applications
if [[ -f "$TITLE_MAP" ]]; then
	while IFS='=' read -r vendor kavis; do
		vendor="${vendor%"${vendor##*[![:space:]]}"}"
		kavis="${kavis#"${kavis%%[![:space:]]*}"}"
		[[ -z "$vendor" || "$vendor" == \#* ]] && continue
		if grep -qh "^Name=.*\b${kavis}\b" "$APP_DIR"/*.desktop; then
			ok "title map $vendor → $kavis matches a .desktop override"
		else
			bad "title map renames $vendor to '$kavis', but no .desktop override uses that name"
		fi
	done < "$TITLE_MAP"
else
	bad "$TITLE_MAP missing — title bars would keep the vendor names"
fi

echo
echo "==> Hand-placed asset files"
[[ -f assets/logo/koyu-k-logo.svg ]] && ok "assets/logo/koyu-k-logo.svg" \
	|| bad "assets/logo/koyu-k-logo.svg missing"
[[ -f assets/logo/acik-k-logo.svg ]] && ok "assets/logo/acik-k-logo.svg" \
	|| bad "assets/logo/acik-k-logo.svg missing"
[[ -f assets/boot/boot-image.png ]] && ok "assets/boot/boot-image.png" \
	|| warn "assets/boot/boot-image.png not placed yet (needed in stage 3)"
[[ -f assets/boot/boot-sound.mp3 ]] && ok "assets/boot/boot-sound.mp3" \
	|| warn "assets/boot/boot-sound.mp3 not placed yet (needed in stage 3)"

echo
echo "==================================================="
if (( fail == 0 )); then
	echo "OK — safe to push."
	echo "To verify package names as well: tools/check-packages.sh"
	exit 0
else
	echo "ERROR — fix the ✗ lines above."
	exit 1
fi
